# Copyright (C) 2011 Nippon Telegraph and Telephone Corporation.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# LABORATORY OF NETWORK PROGRAMMABILITY AND AUTOMATION
# 2021
# by Franco Callegati and Chiara Contoli
#
# This modified simple switch controller implements a simple firewall
# it is intended to be used with the mininet topology with 1 switch 3 hosts and 1 controller
# traffic from host1 to host2 is allowed 
# traffic from host2 to host3 is allowed
# traffic from host1 to host3 is NOT allowed
# 


from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet
from ryu.lib.packet import ethernet
from ryu.lib.packet import arp
from ryu.lib.packet import ether_types
from ryu.lib.packet import ipv4
from ryu.ofproto import inet
from ryu.lib.packet import tcp


class SimpleSwitch13(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(SimpleSwitch13, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
        
        # two lists are created
        # Black list of ports is created listing all the ports towards which is not allowed to establish a connection       
        # Firewalled hosts: is the lists of hosts to apply the firewall. The filtering rules are applied for all IP addresses in the list
        self.TCP_dst_Blacklist = []
        self.Hosts_Firewalled = []

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
       
        # Blacklisted ports are added       
        self.TCP_dst_Blacklist.append(80)
        self.TCP_dst_Blacklist.append(8080)
        # Firewalled hosts are added
        self.Hosts_Firewalled.append("10.0.0.2")

        # install table-miss flow entry
        #
        # We specify NO BUFFER to max_len of the output action due to
        # OVS bug. At this moment, if we specify a lesser number, e.g.,
        # 128, OVS will send Packet-In with invalid buffer_id and
        # truncated packet data. In that case, we cannot output packets
        # correctly.  The bug has been fixed in OVS v2.1.0.
        self.logger.info("SWITCH FEATURES - CONFIG_DISPATCHER PHASE")
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                          ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)

        match = parser.OFPMatch(eth_type=0x0806,eth_dst='ff:ff:ff:ff:ff:ff')
        actions = [parser.OFPActionOutput(ofproto.OFPP_FLOOD)]
        self.add_flow(datapath, 1, match, actions)

    def add_flow(self, datapath, priority, match, actions, buffer_id=None):
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        
        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS,actions)]
        if buffer_id:
            mod = parser.OFPFlowMod(datapath=datapath, buffer_id=buffer_id,
                                    priority=priority, match=match,
                                    instructions=inst)
        else:
            mod = parser.OFPFlowMod(datapath=datapath, priority=priority,
                                    match=match, instructions=inst)
        datapath.send_msg(mod)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def _packet_in_handler(self, ev):
        # If you hit this you might want to increase
        # the "miss_send_length" of your switch
        if ev.msg.msg_len < ev.msg.total_len:
            self.logger.debug("packet truncated: only %s of %s bytes",
                              ev.msg.msg_len, ev.msg.total_len)
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']
        self.logger.info("In port %d", in_port) 

        pkt = packet.Packet(msg.data)
        # parse ethernet packet
        eth = pkt.get_protocols(ethernet.ethernet)[0]

        if eth.ethertype == ether_types.ETH_TYPE_LLDP:
            # ignore lldp packet
            return
        dst = eth.dst
        src = eth.src
        
        dpid = format(datapath.id, "d").zfill(16)
        self.mac_to_port.setdefault(dpid, {})

        self.logger.info("packet in %s %s %s %s", dpid, src, dst, in_port)

        # learn a mac address to avoid FLOOD next time.
        self.mac_to_port[dpid][src] = in_port

        # set output port for known MAC destinations
        # this will be used depending on the following logics
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD
                
        match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src, eth_type=0x0806)
        actions = [parser.OFPActionOutput(out_port)]

	# logics to deal with IP packets
        # if ethernet carries IP parses the IP packet           
        if eth.ethertype == ether_types.ETH_TYPE_IP:
            ip_pkt = pkt.get_protocol(ipv4.ipv4)
            ip_dst = ip_pkt.dst
            self.logger.info("Incoming IP packet inside Ethernet")
            # if IP carries TCP parses the TCP packet
            if ip_pkt.proto == inet.IPPROTO_ICMP:
                match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src, eth_type=ether_types.ETH_TYPE_IP, ip_proto=inet.IPPROTO_ICMP)
                self.logger.info("ICMP traffic - SET FLOW RULE")
            if ip_pkt.proto == inet.IPPROTO_UDP:
                match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src, eth_type=ether_types.ETH_TYPE_IP, ip_proto=inet.IPPROTO_UDP)
                actions = []            
                self.logger.info("UDP traffic - DROP")
            if ip_pkt.proto == inet.IPPROTO_TCP:
                tcp_pkt = pkt.get_protocol(tcp.tcp)
                tcp_dst = tcp_pkt.dst_port
                self.logger.info("TCP packet with destination port %s", tcp_dst)
                self.logger.info("IP packet with destination %s", ip_dst)
                if tcp_dst in self.TCP_dst_Blacklist and ip_dst in self.Hosts_Firewalled:
                   block = True
                   self.logger.info("Firewall activated")
                else:
                   block = False
                if int(in_port) == 1 and str(dst) == "00:00:00:00:00:02" and block:
                    self.logger.info("TCP packet to blocked port - DROP")
                    match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src, eth_type=ether_types.ETH_TYPE_IP, ip_proto=inet.IPPROTO_TCP, tcp_dst=tcp_dst)
                    actions = []
                    # self.add_flow(datapath, 1, match, actions)
                else:
                    self.logger.info("TCP packet to allowed port - SET FLOW RULE")
                    match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src, eth_type=ether_types.ETH_TYPE_IP, ip_proto=inet.IPPROTO_TCP, tcp_dst=tcp_dst)
                    # self.add_flow(datapath, 1, match, actions)                
        
       # install a flow to avoid packet_in next time
        if out_port != ofproto.OFPP_FLOOD:
            # verify if we have a valid buffer_id, if yes avoid to send both
            # flow_mod & packet_out
            if msg.buffer_id != ofproto.OFP_NO_BUFFER:
                self.add_flow(datapath, 1, match, actions, msg.buffer_id)
                return
            else:
                # self.logger.info("Install flow")
                self.add_flow(datapath, 1, match, actions)

        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data

        out = parser.OFPPacketOut(datapath=datapath, buffer_id=msg.buffer_id,
                                  in_port=in_port, actions=actions, data=data)
        datapath.send_msg(out)
        
                
