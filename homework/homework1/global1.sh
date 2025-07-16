#!/bin/bash

# === CREAZIONE HOST E INTERFACCE ===
for n in 1 2 
do
    for h in 1 2
    do
        namespace_name="H$n$h"
        ip netns add $namespace_name
        ip link add veth0 type veth peer name eth-$namespace_name
        ip link set veth0 netns $namespace_name
        ip netns exec $namespace_name ip link set veth0 up
        ip netns exec $namespace_name ip addr add 10.0.$n.$h/24 dev veth0
        echo "Creato host $namespace_name con IP 10.0.$n.$h"
    done
done

# === AGGIUNTA GATEWAY PER OGNI HOST ===
ip netns exec H11 ip route add default via 10.0.1.254
ip netns exec H12 ip route add default via 10.0.1.254
ip netns exec H21 ip route add default via 10.0.2.254
ip netns exec H22 ip route add default via 10.0.2.254

echo "Aggiunto default gateway agli host"

# === CREAZIONE SWITCH OVS ===
for i in 1 2 3
do
    ovs-vsctl add-br LAN$i
done

# === COLLEGAMENTI HOST A SWITCH E TAG VLAN ===
ovs-vsctl add-port LAN1 eth-H11
ovs-vsctl set port eth-H11 tag=1
ip link set eth-H11 up

ovs-vsctl add-port LAN1 eth-H21
ovs-vsctl set port eth-H21 tag=2
ip link set eth-H21 up

ovs-vsctl add-port LAN2 eth-H12
ovs-vsctl set port eth-H12 tag=1
ip link set eth-H12 up

ovs-vsctl add-port LAN2 eth-H22
ovs-vsctl set port eth-H22 tag=2
ip link set eth-H22 up

# === COLLEGAMENTI TRA SWITCH ===
ip link add tlink1 type veth peer name tlink2
ip link set tlink1 up
ip link set tlink2 up
ovs-vsctl add-port LAN1 tlink1
ovs-vsctl add-port LAN2 tlink2
ovs-vsctl set port tlink1 trunks=1,2
ovs-vsctl set port tlink2 trunks=1,2

ip link add tlink3 type veth peer name tlink4
ip link set tlink3 up
ip link set tlink4 up
ovs-vsctl add-port LAN2 tlink3
ovs-vsctl add-port LAN3 tlink4
ovs-vsctl set port tlink3 trunks=1,2
ovs-vsctl set port tlink4 trunks=1,2

# === COLLEGAMENTO LAN3 <-> GATEWAY ===
ip link add veth0 type veth peer name eth-GW
ip link set veth0 up
ovs-vsctl add-port LAN3 veth0
ovs-vsctl set port veth0 trunks=1,2

ip netns add GW
ip link set eth-GW netns GW
ip netns exec GW ip link set eth-GW up

# === CONFIGURAZIONE INTERFACCE VLAN DEL GATEWAY ===
ip netns exec GW ip link add link eth-GW name eth-GW.1 type vlan id 1
ip netns exec GW ip link add link eth-GW name eth-GW.2 type vlan id 2
ip netns exec GW ip link set eth-GW.1 up
ip netns exec GW ip link set eth-GW.2 up
ip netns exec GW ip addr add 10.0.1.254/24 dev eth-GW.1
ip netns exec GW ip addr add 10.0.2.254/24 dev eth-GW.2

# === ISOLAMENTO: NON abilitiamo il forwarding IP ===
# ip netns exec GW sysctl -w net.ipv4.ip_forward=1  ← NON ATTIVATO!

echo "Configurazione completata con successo (VLAN isolate anche a livello IP)"

