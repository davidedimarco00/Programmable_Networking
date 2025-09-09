#!/bin/bash

echo "Inizio pulizia topologia di rete..."

#Elimina i namespace (host e gateway)
for ns in H11 H12 H21 H22 GW; do
    sudo ip netns del $ns
done

# Elimina i bridge OVS (LAN1, LAN2, LAN3)
for br in LAN1 LAN2 LAN3; do
    sudo ovs-vsctl --if-exists del-br $br
done

# Elimina tutte le interfacce veth e VLAN
for iface in \
    tlink1 tlink2 tlink3 tlink4 \
    veth0 eth-GW eth-G1 \
    eth-H11 eth-H12 eth-H21 eth-H22 \
    veth0-1 veth1-2; do
    sudo ip link del $iface
done

echo "Pulizia completata"

