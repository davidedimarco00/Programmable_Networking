# load_balancer_controller.py
from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import MAIN_DISPATCHER, CONFIG_DISPATCHER, set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, arp, ipv4, tcp, ether_types


class RoundRobinLoadBalancer(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    VIP_IP   = '192.168.1.100'
    VIP_MAC  = '00:00:00:00:01:00'   # MAC “virtuale” del VIP
    VIP_TCP_PORT = 8080

    #I backend vengono appresi a runtime
    BACKENDS = [
        {'ip': '192.168.1.101', 'mac': None, 'switch_port': None},
        {'ip': '192.168.1.102', 'mac': None, 'switch_port': None},
    ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.mac_learning_table = {}   # {dpid: {mac: port}}
        self.round_robin_index = 0

   #function

    def add_flow(self, datapath, priority, match, actions, idle_timeout=180, hard_timeout=0):
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        instructions = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
        flow_mod = parser.OFPFlowMod(
            datapath=datapath,
            priority=priority,
            match=match,
            instructions=instructions,
            idle_timeout=idle_timeout,
            hard_timeout=hard_timeout
        )
        datapath.send_msg(flow_mod)

    def get_client_output_port(self, switch_id, client_mac, default_port):
        """Ritorna la porta verso il client, se nota, altrimenti default_port."""
        mac_table = self.mac_learning_table.get(switch_id, {})
        return mac_table.get(client_mac, default_port)

    def send_arp_reply(self, datapath, client_port, client_mac, client_ip):
        """Risponde a una ARP request per il VIP."""
        parser = datapath.ofproto_parser
        ofproto = datapath.ofproto
        eth_reply = ethernet.ethernet(
            dst=client_mac, src=self.VIP_MAC,
            ethertype=ether_types.ETH_TYPE_ARP
        )
        arp_reply = arp.arp(
            opcode=arp.ARP_REPLY,
            src_mac=self.VIP_MAC, src_ip=self.VIP_IP,
            dst_mac=client_mac, dst_ip=client_ip
        )
        pkt = packet.Packet()
        pkt.add_protocol(eth_reply)
        pkt.add_protocol(arp_reply)
        pkt.serialize()
        actions = [parser.OFPActionOutput(client_port)]
        out = parser.OFPPacketOut(
            datapath=datapath,
            buffer_id=ofproto.OFP_NO_BUFFER,
            in_port=ofproto.OFPP_CONTROLLER,
            actions=actions,
            data=pkt.data
        )
        datapath.send_msg(out)
        self.logger.info("ARP reply: %s is-at %s → %s", self.VIP_IP, self.VIP_MAC, client_mac)

    def send_arp_probe(self, datapath, target_ip):
        """Invia un ARP request broadcast per scoprire MAC/porta del backend target_ip."""
        parser = datapath.ofproto_parser
        ofproto = datapath.ofproto
        pkt = packet.Packet()
        pkt.add_protocol(ethernet.ethernet(
            dst='ff:ff:ff:ff:ff:ff',
            src=self.VIP_MAC,
            ethertype=ether_types.ETH_TYPE_ARP
        ))
        pkt.add_protocol(arp.arp(
            opcode=arp.ARP_REQUEST,
            src_mac=self.VIP_MAC, src_ip=self.VIP_IP,
            dst_mac='00:00:00:00:00:00', dst_ip=target_ip
        ))
        pkt.serialize()
        actions = [parser.OFPActionOutput(ofproto.OFPP_FLOOD)]
        out = parser.OFPPacketOut(
            datapath=datapath,
            buffer_id=ofproto.OFP_NO_BUFFER,
            in_port=ofproto.OFPP_CONTROLLER,
            actions=actions,
            data=pkt.data
        )
        datapath.send_msg(out)
        self.logger.info("ARP probe inviato per %s (FLOOD)", target_ip)

    # -------------------- Handlers --------------------

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        # Table-miss: manda i pacchetti al controller
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER, ofproto.OFPCML_NO_BUFFER)]
        instructions = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
        flow_mod = parser.OFPFlowMod(datapath=datapath, priority=0, match=match, instructions=instructions)
        datapath.send_msg(flow_mod)

        # Pre-probe dei backend
        for backend in self.BACKENDS:
            self.send_arp_probe(datapath, backend['ip'])

        self.logger.info("Switch %s configurato (table-miss + pre-probe).", datapath.id)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in(self, ev):
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        switch_id = datapath.id
        in_port = msg.match['in_port']

        pkt = packet.Packet(msg.data)
        eth_frame = pkt.get_protocols(ethernet.ethernet)[0]

        # L2 learning
        self.mac_learning_table.setdefault(switch_id, {})
        self.mac_learning_table[switch_id][eth_frame.src] = in_port

        # --- ARP handling ---
        if eth_frame.ethertype == ether_types.ETH_TYPE_ARP:
            arp_pkt = pkt.get_protocol(arp.arp)
            if arp_pkt.opcode == arp.ARP_REQUEST and arp_pkt.dst_ip == self.VIP_IP:
                self.send_arp_reply(datapath, in_port, arp_pkt.src_mac, arp_pkt.src_ip)
                return

            # Apprendi backend da ARP
            for backend in self.BACKENDS:
                if arp_pkt.src_ip == backend['ip']:
                    backend['mac'], backend['switch_port'] = eth_frame.src, in_port

            # Forward normale per ARP
            out_port = self.mac_learning_table[switch_id].get(eth_frame.dst, ofproto.OFPP_FLOOD)
            actions = [parser.OFPActionOutput(out_port)]
            out = parser.OFPPacketOut(datapath=datapath, buffer_id=ofproto.OFP_NO_BUFFER,
                                      in_port=in_port, actions=actions, data=msg.data)
            datapath.send_msg(out)
            return

        ip_pkt = pkt.get_protocol(ipv4.ipv4)
        if not ip_pkt:
            return

        tcp_pkt = pkt.get_protocol(tcp.tcp)
        if not tcp_pkt:
            return

        # --- Gestione delle connessioni TCP verso VIP:8080 ---
        if ip_pkt.dst == self.VIP_IP and tcp_pkt.dst_port == self.VIP_TCP_PORT:
            client_ip, client_mac = ip_pkt.src, eth_frame.src
            client_tcp_src_port = tcp_pkt.src_port

            backend = self.BACKENDS[self.round_robin_index]
            self.round_robin_index = (self.round_robin_index + 1) % len(self.BACKENDS)

            self.logger.info("Nuova connessione %s:%d → VIP:%d → backend %s",
                             client_ip, client_tcp_src_port, self.VIP_TCP_PORT, backend['ip'])

            backend_ip  = backend['ip']
            backend_mac = backend.get('mac')
            backend_port = backend.get('switch_port')

            # Se non conosciamo ancora MAC/porta del backend scelto
            if not backend_mac or not backend_port:
                self.send_arp_probe(datapath, backend_ip)
                return

            # ---- Flusso client -> backend ----
            match_c2b = parser.OFPMatch(
                eth_type=0x0800, ip_proto=6,
                ipv4_src=client_ip, ipv4_dst=self.VIP_IP,
                tcp_src=client_tcp_src_port, tcp_dst=self.VIP_TCP_PORT
            )
            actions_c2b = [
                parser.OFPActionSetField(eth_src=self.VIP_MAC),
                parser.OFPActionSetField(eth_dst=backend_mac),
                parser.OFPActionSetField(ipv4_dst=backend_ip),
                parser.OFPActionOutput(backend_port),
            ]
            self.add_flow(datapath, 100, match_c2b, actions_c2b, idle_timeout=120)

            # ---- Flusso backend -> client ----
            client_out_port = self.get_client_output_port(switch_id, client_mac, default_port=in_port)
            match_b2c = parser.OFPMatch(
                eth_type=0x0800, ip_proto=6,
                ipv4_src=backend_ip, ipv4_dst=client_ip,
                tcp_src=self.VIP_TCP_PORT, tcp_dst=client_tcp_src_port
            )
            actions_b2c = [
                parser.OFPActionSetField(eth_src=self.VIP_MAC),
                parser.OFPActionSetField(eth_dst=client_mac),
                parser.OFPActionSetField(ipv4_src=self.VIP_IP),
                parser.OFPActionOutput(client_out_port),
            ]
            self.add_flow(datapath, 100, match_b2c, actions_b2c, idle_timeout=120)

            # Inoltra subito il pacchetto corrente
            out = parser.OFPPacketOut(datapath=datapath, buffer_id=ofproto.OFP_NO_BUFFER,
                                      in_port=in_port, actions=actions_c2b, data=msg.data)
            datapath.send_msg(out)
            return
