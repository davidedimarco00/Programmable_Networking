#!/bin/bash

# Pulizia iniziale se serve
ovs-vsctl del-br LAN1 || true
ovs-vsctl del-br LAN2 || true

# ========================
# CREAZIONE HOST VERDI
# ========================
ip netns add H11
ip link add veth-H11 type veth peer name eth-H11
ip link set eth-H11 netns H11
ip netns exec H11 ip link set eth-H11 up
ip netns exec H11 ip addr add 10.0.1.1/24 dev eth-H11
ip netns exec H11 ip route add default via 10.0.1.254

ip netns add H22
ip link add veth-H22 type veth peer name eth-H22
ip link set eth-H22 netns H22
ip netns exec H22 ip link set eth-H22 up
ip netns exec H22 ip addr add 10.0.2.2/24 dev eth-H22
ip netns exec H22 ip route add default via 10.0.2.254

# ========================
# HOST MANAGEMENT
# ========================
ip netns add MGT1
ip link add veth-MGT1 type veth peer name eth-MGT1
ip link set eth-MGT1 netns MGT1
ip netns exec MGT1 ip link set eth-MGT1 up
ip netns exec MGT1 ip addr add 10.0.100.10/24 dev eth-MGT1
ip netns exec MGT1 ip route add default via 10.0.100.1

ip netns add MGT2
ip link add veth-MGT2 type veth peer name eth-MGT2
ip link set eth-MGT2 netns MGT2
ip netns exec MGT2 ip link set eth-MGT2 up
ip netns exec MGT2 ip addr add 10.0.100.20/24 dev eth-MGT2
ip netns exec MGT2 ip route add default via 10.0.100.2

# ========================
# SWITCH LAN1 e LAN2
# ========================
ovs-vsctl add-br LAN1
ovs-vsctl add-br LAN2

# DC1
ovs-vsctl add-port LAN1 veth-H11
ovs-vsctl set port veth-H11 tag=1
ip link set veth-H11 up

ovs-vsctl add-port LAN1 veth-MGT1
ovs-vsctl set port veth-MGT1 tag=100
ip link set veth-MGT1 up

# DC2
ovs-vsctl add-port LAN2 veth-H22
ovs-vsctl set port veth-H22 tag=2
ip link set veth-H22 up

ovs-vsctl add-port LAN2 veth-MGT2
ovs-vsctl set port veth-MGT2 tag=100
ip link set veth-MGT2 up

# ========================
# GATEWAY DC1 - GW1
# ========================
ip netns add GW1
ip link add gw1-lan type veth peer name eth-GW1
ip link set eth-GW1 netns GW1
ovs-vsctl add-port LAN1 gw1-lan
ovs-vsctl set port gw1-lan trunks=1,100
ip link set gw1-lan up

ip netns exec GW1 ip link set eth-GW1 up
ip netns exec GW1 ip link add link eth-GW1 name eth-GW1.1 type vlan id 1
ip netns exec GW1 ip link add link eth-GW1 name eth-GW1.100 type vlan id 100
ip netns exec GW1 ip link set eth-GW1.1 up
ip netns exec GW1 ip link set eth-GW1.100 up
ip netns exec GW1 ip addr add 10.0.1.254/24 dev eth-GW1.1
ip netns exec GW1 ip addr add 10.0.100.1/24 dev eth-GW1.100

# ========================
# GATEWAY DC2 - GW2
# ========================
ip netns add GW2
ip link add gw2-lan type veth peer name eth-GW2
ip link set eth-GW2 netns GW2
ovs-vsctl add-port LAN2 gw2-lan
ovs-vsctl set port gw2-lan trunks=2,100
ip link set gw2-lan up

ip netns exec GW2 ip link set eth-GW2 up
ip netns exec GW2 ip link add link eth-GW2 name eth-GW2.2 type vlan id 2
ip netns exec GW2 ip link add link eth-GW2 name eth-GW2.100 type vlan id 100
ip netns exec GW2 ip link set eth-GW2.2 up
ip netns exec GW2 ip link set eth-GW2.100 up
ip netns exec GW2 ip addr add 10.0.2.254/24 dev eth-GW2.2
ip netns exec GW2 ip addr add 10.0.100.2/24 dev eth-GW2.100

# ========================
# ROUTER CENTRALE (R)
# ========================
ip netns add R

# GW1 ↔ R
ip link add gw1-r type veth peer name eth-R1
ip link set gw1-r netns GW1
ip link set eth-R1 netns R
ip netns exec GW1 ip link set gw1-r up
ip netns exec GW1 ip addr add 10.0.10.1/30 dev gw1-r
ip netns exec R ip link set eth-R1 up
ip netns exec R ip addr add 10.0.10.2/30 dev eth-R1

# GW2 ↔ R
ip link add gw2-r type veth peer name eth-R2
ip link set gw2-r netns GW2
ip link set eth-R2 netns R
ip netns exec GW2 ip link set gw2-r up
ip netns exec GW2 ip addr add 10.0.10.5/30 dev gw2-r
ip netns exec R ip link set eth-R2 up
ip netns exec R ip addr add 10.0.10.6/30 dev eth-R2

# R ↔ VLAN 100 (solo su LAN1)
ip link add veth-R-mgmt type veth peer name eth-R-mgmt
ip link set eth-R-mgmt netns R
ovs-vsctl add-port LAN1 veth-R-mgmt
ovs-vsctl set port veth-R-mgmt tag=100
ip link set veth-R-mgmt up
ip netns exec R ip link set eth-R-mgmt up
ip netns exec R ip addr add 10.0.100.254/24 dev eth-R-mgmt

# ========================
# FORWARDING + ROUTES
# ========================
ip netns exec R sysctl -w net.ipv4.ip_forward=1
ip netns exec GW1 sysctl -w net.ipv4.ip_forward=1
ip netns exec GW2 sysctl -w net.ipv4.ip_forward=1

# R instrada verso subnet
ip netns exec R ip route add 10.0.1.0/24 via 10.0.10.1
ip netns exec R ip route add 10.0.2.0/24 via 10.0.10.5
ip netns exec R ip route add 10.0.100.0/24 via 10.0.10.6

# GW1 e GW2 verso management via R
ip netns exec GW1 ip route del 10.0.100.0/24 || true
ip netns exec GW1 ip route add 10.0.100.0/24 via 10.0.10.2
ip netns exec GW2 ip route del 10.0.100.0/24 || true
ip netns exec GW2 ip route add 10.0.100.0/24 via 10.0.10.6

# ========================
# GRE SOLO PER HOST VERDI
# ========================
ip netns exec GW1 ip tunnel add gre1 mode gre local 10.0.10.1 remote 10.0.10.6 ttl 255
ip netns exec GW1 ip link set gre1 up
ip netns exec GW1 ip addr add 10.0.200.1/24 dev gre1

ip netns exec GW2 ip tunnel add gre2 mode gre local 10.0.10.5 remote 10.0.10.2 ttl 255
ip netns exec GW2 ip link set gre2 up
ip netns exec GW2 ip addr add 10.0.200.2/24 dev gre2

ip netns exec GW1 ip route add 10.0.2.0/24 via 10.0.10.2
ip netns exec GW2 ip route add 10.0.1.0/24 via 10.0.10.6
ip netns exec R ip route add 10.0.200.0/24 via 10.0.10.1

# ========================
# FORZATURA ARP DA MGT2 → GW2
# ========================
ip netns exec MGT2 ping -c 1 -W 1 10.0.100.2

# ========================
# TEST AUTOMATICI
# ========================
echo
echo "✅ TOPOLOGIA COMPLETATA!"
echo
echo "🧪 TEST RETE MANAGEMENT:"
echo -n "MGT1 → MGT2 (via R): "
if ip netns exec MGT1 ping -c 1 -W 1 10.0.100.20 >/dev/null 2>&1; then echo "✅ OK"; else echo "❌ FAILED"; fi

echo -n "MGT2 → MGT1 (via R): "
if ip netns exec MGT2 ping -c 1 -W 1 10.0.100.10 >/dev/null 2>&1; then echo "✅ OK"; else echo "❌ FAILED"; fi

echo
echo "🧪 TEST HOST VERDI (via GRE):"
echo -n "H11 → H22: "
if ip netns exec H11 ping -c 1 -W 1 10.0.2.2 >/dev/null 2>&1; then echo "✅ OK"; else echo "❌ FAILED"; fi

echo -n "H22 → H11: "
if ip netns exec H22 ping -c 1 -W 1 10.0.1.1 >/dev/null 2>&1; then echo "✅ OK"; else echo "❌ FAILED"; fi