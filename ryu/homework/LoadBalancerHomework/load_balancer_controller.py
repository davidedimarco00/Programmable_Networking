# load_balancer_controller.py
from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import MAIN_DISPATCHER, CONFIG_DISPATCHER, set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, arp, ipv4, tcp, ether_types


class RoundRobinLB(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    VIP_IP   = '192.168.1.100'
    VIP_MAC  = '00:00:00:00:01:00'   # MAC “virtuale” del VIP
    TCP_PORT = 8080

    # I MAC/port dei backend verranno appresi a runtime (ARP o traffico IP)
    BACKENDS = [
        {'ip': '192.168.1.101', 'mac': None, 'port': None},
        {'ip': '192.168.1.102', 'mac': None, 'port': None},
    ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # L2 learning: {dpid: {mac: port}}
        self.mac_to_port = {}
        # Round-robin pointer
        self.rr = 0
        # Stickiness per flusso client (cli_ip, cli_tcp_src) -> backend dict
        self.flow_map = {}

    # -------------------- Helpers --------------------

    def add_flow(self, dp, priority, match, actions, idle=180, hard=0):
        ofp, p = dp.ofproto, dp.ofproto_parser
        inst = [p.OFPInstructionActions(ofp.OFPIT_APPLY_ACTIONS, actions)]
        mod = p.OFPFlowMod(datapath=dp, priority=priority, match=match,
                           instructions=inst, idle_timeout=idle, hard_timeout=hard)
        dp.send_msg(mod)

    def get_client_out_port(self, dpid, cli_mac, default_port):
        """Ritorna la porta per il MAC del client, se nota, altrimenti default_port."""
        table = self.mac_to_port.get(dpid, {})
        return table.get(cli_mac, default_port)

    def send_arp_reply(self, dp, in_port, dst_mac, dst_ip):
        p, ofp = dp.ofproto_parser, dp.ofproto
        e = ethernet.ethernet(dst=dst_mac, src=self.VIP_MAC,
                              ethertype=ether_types.ETH_TYPE_ARP)
        a = arp.arp(opcode=arp.ARP_REPLY,
                    src_mac=self.VIP_MAC, src_ip=self.VIP_IP,
                    dst_mac=dst_mac,   dst_ip=dst_ip)
        pkt = packet.Packet()
        pkt.add_protocol(e)
        pkt.add_protocol(a)
        pkt.serialize()
        actions = [p.OFPActionOutput(in_port)]
        out = p.OFPPacketOut(datapath=dp, buffer_id=ofp.OFP_NO_BUFFER,
                             in_port=ofp.OFPP_CONTROLLER, actions=actions, data=pkt.data)
        dp.send_msg(out)
        self.logger.info("ARP reply: %s is-at %s → %s", self.VIP_IP, self.VIP_MAC, dst_mac)

    def arp_probe(self, dp, target_ip):
        """Invia un ARP request broadcast per imparare MAC/porta del backend target_ip."""
        p, ofp = dp.ofproto_parser, dp.ofproto
        pkt = packet.Packet()
        pkt.add_protocol(ethernet.ethernet(dst='ff:ff:ff:ff:ff:ff',
                                           src=self.VIP_MAC,
                                           ethertype=ether_types.ETH_TYPE_ARP))
        pkt.add_protocol(arp.arp(opcode=arp.ARP_REQUEST,
                                 src_mac=self.VIP_MAC, src_ip=self.VIP_IP,
                                 dst_mac='00:00:00:00:00:00', dst_ip=target_ip))
        pkt.serialize()
        actions = [p.OFPActionOutput(ofp.OFPP_FLOOD)]
        out = p.OFPPacketOut(datapath=dp, buffer_id=ofp.OFP_NO_BUFFER,
                             in_port=ofp.OFPP_CONTROLLER, actions=actions, data=pkt.data)
        dp.send_msg(out)
        self.logger.info("ARP probe inviato per %s (FLOOD)", target_ip)

    # -------------------- Handlers --------------------

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        dp = ev.msg.datapath
        ofp, p = dp.ofproto, dp.ofproto_parser

        # Table-miss: invia i pacchetti al controller
        match = p.OFPMatch()
        actions = [p.OFPActionOutput(ofp.OFPP_CONTROLLER, ofp.OFPCML_NO_BUFFER)]
        inst = [p.OFPInstructionActions(ofp.OFPIT_APPLY_ACTIONS, actions)]
        mod = p.OFPFlowMod(datapath=dp, priority=0, match=match, instructions=inst)
        dp.send_msg(mod)

        # (opzionale) Pre-probe dei backend per popolare mac/port rapidamente
        for b in self.BACKENDS:
            self.arp_probe(dp, b['ip'])

        self.logger.info("Switch %s configurato (table-miss + pre-probe).", dp.id)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in(self, ev):
        msg = ev.msg
        dp = msg.datapath
        ofp, p = dp.ofproto, dp.ofproto_parser
        dpid = dp.id
        in_port = msg.match['in_port']

        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocols(ethernet.ethernet)[0]

        # L2 learning
        self.mac_to_port.setdefault(dpid, {})
        self.mac_to_port[dpid][eth.src] = in_port

        # --- ARP handling ---
        if eth.ethertype == ether_types.ETH_TYPE_ARP:
            a = pkt.get_protocol(arp.arp)
            # Rispondi per il VIP
            if a.opcode == arp.ARP_REQUEST and a.dst_ip == self.VIP_IP:
                self.send_arp_reply(dp, in_port, a.src_mac, a.src_ip)
                return

            # Apprendi MAC/port dei backend
            for b in self.BACKENDS:
                if a.src_ip == b['ip']:
                    b['mac'], b['port'] = eth.src, in_port

            # L2 forward basico per il resto dell’ARP
            out_port = self.mac_to_port[dpid].get(eth.dst, ofp.OFPP_FLOOD)
            actions = [p.OFPActionOutput(out_port)]
            out = p.OFPPacketOut(datapath=dp, buffer_id=ofp.OFP_NO_BUFFER,
                                 in_port=in_port, actions=actions, data=msg.data)
            dp.send_msg(out)
            return

        # --- Solo IPv4 da qui in poi ---
        if eth.ethertype != ether_types.ETH_TYPE_IP:
            return

        ip4 = pkt.get_protocol(ipv4.ipv4)
        if not ip4:
            return

        # Apprendi MAC/port dei backend anche da traffico IP
        for b in self.BACKENDS:
            if ip4.src == b['ip']:
                b['mac'], b['port'] = eth.src, in_port

        # Gestiamo solo TCP e solo verso VIP:8080
        tcph = pkt.get_protocol(tcp.tcp)
        if not tcph:
            return

        if ip4.dst == self.VIP_IP and tcph.dst_port == self.TCP_PORT:
            cli_ip, cli_mac = ip4.src, eth.src
            cli_tcp_src = tcph.src_port
            key = (cli_ip, cli_tcp_src)

            backend = self.flow_map.get(key)
            if backend is None:
                backend = self.BACKENDS[self.rr]
                self.rr = (self.rr + 1) % len(self.BACKENDS)
                self.flow_map[key] = backend
                self.logger.info("Nuova conn %s:%d → VIP:%d → scelto backend %s",
                                 cli_ip, cli_tcp_src, self.TCP_PORT, backend['ip'])

            srv_ip  = backend['ip']
            srv_mac = backend.get('mac')
            s_out   = backend.get('port')

            # Se non conosciamo ancora MAC/porta del server scelto → ARP probe e aspettiamo
            if not srv_mac or not s_out:
                self.arp_probe(dp, srv_ip)
                return

            # ---- Flow client -> server (riscrittura dst IP/MAC) ----
            match_c2s = p.OFPMatch(eth_type=0x0800, ip_proto=6,
                                   ipv4_src=cli_ip, ipv4_dst=self.VIP_IP,
                                   tcp_src=cli_tcp_src, tcp_dst=self.TCP_PORT)
            actions_c2s = [
                p.OFPActionSetField(eth_src=self.VIP_MAC),
                p.OFPActionSetField(eth_dst=srv_mac),
                p.OFPActionSetField(ipv4_dst=srv_ip),
                p.OFPActionOutput(s_out),
            ]
            self.add_flow(dp, 100, match_c2s, actions_c2s, idle=120)

            # ---- Flow server -> client (riscrittura src IP/MAC) ----
            c_out = self.get_client_out_port(dpid, cli_mac, default_port=in_port)
            match_s2c = p.OFPMatch(eth_type=0x0800, ip_proto=6,
                                   ipv4_src=srv_ip, ipv4_dst=cli_ip,
                                   tcp_src=self.TCP_PORT, tcp_dst=cli_tcp_src)
            actions_s2c = [
                p.OFPActionSetField(eth_src=self.VIP_MAC),
                p.OFPActionSetField(eth_dst=cli_mac),
                p.OFPActionSetField(ipv4_src=self.VIP_IP),
                p.OFPActionOutput(c_out),
            ]
            self.add_flow(dp, 100, match_s2c, actions_s2c, idle=120)

            # Inoltra subito il pacchetto corrente lato server
            out = p.OFPPacketOut(datapath=dp, buffer_id=ofp.OFP_NO_BUFFER,
                                 in_port=in_port, actions=actions_c2s, data=msg.data)
            dp.send_msg(out)
            return

        # Per altro traffico: opzionale, fai un semplice L2 forward
        out_port = self.mac_to_port[dpid].get(eth.dst, ofp.OFPP_FLOOD)
        actions = [p.OFPActionOutput(out_port)]
        out = p.OFPPacketOut(datapath=dp, buffer_id=ofp.OFP_NO_BUFFER,
                             in_port=in_port, actions=actions, data=msg.data)
        dp.send_msg(out)
