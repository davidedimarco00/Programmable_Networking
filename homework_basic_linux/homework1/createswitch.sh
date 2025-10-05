#!/bin/sh

#Creo i 3 switch
for switch_n in 1 2 3
do
	ovs-vsctl add-br LAN$switch_n
done

#Creo le porte sullo switch 1 e le attivo

ovs-vsctl add-port LAN1 eth-H11
ovs-vsctl add-port LAN1 eth-H21
ovs-vsctl set port eth-H11 tag=1
ovs-vsctl set port eth-H21 tag=2
ip link set eth-H11 up
ip link set eth-H21 up

#connetto lo switch LAN1 TO LAN2

ip link add tlink1 type veth peer name tlink2
ovs-vsctl add-port LAN1 tlink1
ovs-vsctl add-port LAN2 tlink2
ip link set tlink1 up
ip link set tlink2 up


#Creo le porte sullo switch 2 e le attivo

ovs-vsctl add-port LAN2 eth-H12
ovs-vsctl add-port LAN2 eth-H22
ovs-vsctl set port eth-H12 tag=1
ovs-vsctl set port eth-H22 tag=2
ip link set eth-H12 up
ip link set eth-H22 up


#connetto lo switch LAN2 TO LAN3

ip link add tlink3 type veth peer name tlink4
ovs-vsctl add-port LAN2 tlink3
ovs-vsctl add-port LAN3 tlink4
ip link set tlink3 up
ip link set tlink4 up


#Creo LAN3 -> TO GATEWAY

ip link add veth0 type veth peer name eth-G1
ovs-vsctl add-port LAN3 eth-G1
ovs-vsctl set port eth-G1 trunks=1,2
ip link set eth-G1 up


