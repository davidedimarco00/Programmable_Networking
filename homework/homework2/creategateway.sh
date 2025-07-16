#!/bin/sh

#Creo il gateway
ip netns add GW
#Aggiungo un solo cavo di rete sul gateway
ip link add veth0 type veth peer name eth-GW
#la connetto al gateway
ip link set veth0 netns GW
ip netns exec GW ip link set veth0 up

ip netns exec GW ip link add link veth0 name veth0-1 type vlan id 1
ip netns exec GW ip link add link veth0 name veth1-2 type vlan id 2
ip netns exec GW ip link set veth0-1 up
ip netns exec GW ip link set veth1-2 up
ip netns exec GW ip addr add 10.0.1.254/24 dev veth0-1
ip netns exec GW ip addr add 10.0.2.254/24 dev veth1-2



#abilito il packaet forwarding sul gateway
ip netns exec GW sysctl -w net.ipv4.ip_forward=1


