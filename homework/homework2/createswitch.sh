#!/bin/sh

#Creo i 2 switch
for switch_n in 1 2
do
	ovs-vsctl add-br LAN$switch_n
done

#Creo le porte sullo switch 1 e le attivo

ovs-vsctl add-port LAN1 eth-M1
ovs-vsctl add-port LAN1 eth-H1
ovs-vsctl add-port LAN1 eth-G1

ovs-vsctl set port eth-M1 tag=1
ovs-vsctl set port eth-H1 tag=2
ovs-vsctl set port eth-H1 trunks=1,2
ip link set eth-M1 up
ip link set eth-H1 up
ip link set eth-G1 up

#connetto lo switch LAN1 TO G1 (TODO)

ip link add tlink1 type veth peer name tlink2
ovs-vsctl add-port LAN1 tlink1
ovs-vsctl add-port LAN2 tlink2
ip link set tlink1 up
ip link set tlink2 up


#Creo le porte sullo switch 2 e le attivo

ovs-vsctl add-port LAN2 eth-M2
ovs-vsctl add-port LAN2 eth-H2
ovs-vsctl add-port LAN1 eth-G2
ovs-vsctl set port eth-M2 tag=1
ovs-vsctl set port eth-H2 tag=2
ovs-vsctl set port eth-G2 trunks=1,2
ip link set eth-H12 up
ip link set eth-H22 up
ip link set eth-G2 up


#connetto lo switch LAN2 TO LAN3

ip link add tlink3 type veth peer name tlink4
ovs-vsctl add-port LAN2 tlink3
ip link set tlink3 up
ip link set tlink4 up
