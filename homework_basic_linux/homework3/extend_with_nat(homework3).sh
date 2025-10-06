#!/bin/bash

#creo lo switch esterno
ovs-vsctl add-br LAN_EXT

#creo l'host esterno attaccato allo switch 
ip netns add EXT
ip link add veth-ext type veth peer name eth-EXT
ip link set veth-ext netns EXT
ip netns exec EXT ip link set veth-ext up
ip netns exec EXT ip addr add 192.168.1.1/24 dev veth-ext
ovs-vsctl add-port LAN_EXT eth-EXT
ip link set eth-EXT up

#collego il gateway allo switch
ip link add extgw type veth peer name eth-extgw
ip link set eth-extgw netns GW
ip link set extgw up
ovs-vsctl add-port LAN_EXT extgw

#configuro l'interfaccia del gateway esterna
ip netns exec GW ip link set eth-extgw up
ip netns exec GW ip addr add 192.168.1.254/24 dev eth-extgw

#abilito l'ip forwarding sul gateway
ip netns exec GW sysctl -w net.ipv4.ip_forward=1

#NAT sul gateway
ip netns exec GW iptables -t nat -A POSTROUTING -s 10.0.1.0/24 -o eth-extgw -j MASQUERADE
ip netns exec GW iptables -t nat -A POSTROUTING -s 10.0.2.0/24 -o eth-extgw -j MASQUERADE

#firewall tra vlan 1 e 2
ip netns exec GW iptables -A FORWARD -s 10.0.1.0/24 -d 10.0.2.0/24 -j DROP
ip netns exec GW iptables -A FORWARD -s 10.0.2.0/24 -d 10.0.1.0/24 -j DROP

#route di ritorno per le VLAN 1 e 2 sul gateway
ip netns exec EXT ip route add default via 192.168.1.254

echo "Topologia estesa con NAT, firewall e host esterno completata."

