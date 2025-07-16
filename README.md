to start python script in mininet: 


sudo mn --custom <mytopo.py> --topo mytopo




useful command:
mininet> pingall
*** Ping: testing ping reachability
h1 -> h2 
h2 -> h1 
*** Results: 0% dropped (2/2 received)
mininet> <nodes>
available nodes are: 
h1 h2 s3 s4
mininet> <net>
h1 h1-eth0:s3-eth1
h2 h2-eth0:s4-eth2
s3 lo:  s3-eth1:h1-eth0 s3-eth2:s4-eth1
s4 lo:  s4-eth1:s3-eth2 s4-eth2:h2-eth0
mininet> <links>
h1-eth0<->s3-eth1 (OK OK) 
s3-eth2<->s4-eth1 (OK OK) 
s4-eth2<->h2-eth0 (OK OK) 
mininet> <pingall>
*** Ping: testing ping reachability
h1 -> h2 
h2 -> h1 
*** Results: 0% dropped (2/2 received)
mininet> <xterm h1>
mininet> <h1 ip address> 
mininet> <h1 ip route>
mininet> <ports>
s3 lo:0 s3-eth1:1 s3-eth2:2 
s4 lo:0 s4-eth1:1 s4-eth2:2 
mininet> <h1 ping h2> 


---- clean ----
mn -c --clean
sudo mn --custom topo-2sw-2host.py --topo mytopo --link tc,bw=10 

---- check flows ----
sudo ovs-ofctl dump-flows <Switch_name>


----Ryu------------------ custom controller + topology
Run Mininet custom topology with custom Ryu controller "simple_switch_13.py" and
play with OvS switches:
1) Run Ryu controller: ryu-manager simple_switch_13.py
2) Run Mininet custom topology: sudo mn --custom topo-2sw-2host.py --topo mytopo
--controller remote --switch ovsk
3) List OpenFlow rules on one of the switches: e.g., sudo ovs-ofctl dump-flows s2
4) Test connectivity between h1 and h2, via the node Terminal or the Mininet CLI
5) List the flow entries on the switch again: has anything changed?


ryu-manager --ofp-tcp-listen-port OFP_TCP_LISTEN_PORT <ryu-app_name.py>
where OFP_TCP_LISTEN_PORT is a free port of your choice
