#!/bin/bash

# Rimuove tutte le interfacce veth esistenti
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^veth|eth-|gw|gre|r-|tlink'); do
    ip link delete "$iface" 2>/dev/null
done

# Rimuove tutte le namespaces
for ns in $(ip netns list | awk '{print $1}'); do
    echo "Rimuovo namespace: $ns"
    ip netns del "$ns" 2>/dev/null
done

# Rimuove tutti i bridge OVS
for br in $(ovs-vsctl list-br); do
    ovs-vsctl del-br "$br" 2>/dev/null
done

echo "✅ Pulizia forzata completata"

ip netns del H11 2>/dev/null
ip netns del H22 2>/dev/null
ip netns del MGT1 2>/dev/null
ip netns del MGT2 2>/dev/null
ip netns del GW1 2>/dev/null
ip netns del GW2 2>/dev/null
ip netns del R 2>/dev/null

ovs-vsctl --if-exists del-br LAN1
ovs-vsctl --if-exists del-br LAN2

ip link del veth-H11 2>/dev/null
ip link del veth-H22 2>/dev/null
ip link del veth-MGT1 2>/dev/null
ip link del veth-MGT2 2>/dev/null
ip link del gw1-lan 2>/dev/null
ip link del gw2-lan 2>/dev/null
ip link del gw1-r 2>/dev/null
ip link del gw2-r 2>/dev/null

