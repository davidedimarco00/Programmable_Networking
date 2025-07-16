#!/bin/bash

# 🧹 Pulizia
for ns in M1 M2 H1 H2 G1 G2 G3; do
    ip netns del $ns 2>/dev/null
done

# 🧠 Crea namespace
for ns in M1 M2 H1 H2 G1 G2 G3; do
    ip netns add $ns
done

# 🔌 Crea le interfacce
ip link add m1-g1 type veth peer name g1-m1
ip link set m1-g1 netns M1
ip link set g1-m1 netns G1

ip link add m2-g2 type veth peer name g2-m2
ip link set m2-g2 netns M2
ip link set g2-m2 netns G2

ip link add h1-g1 type veth peer name g1-h1
ip link set h1-g1 netns H1
ip link set g1-h1 netns G1

ip link add h2-g2 type veth peer name g2-h2
ip link set h2-h2 netns H2
ip link set g2-h2 netns G2

ip link add g1-g3 type veth peer name g3-g1
ip link set g1-g3 netns G1
ip link set g3-g1 netns G3

ip link add g2-g3 type veth peer name g3-g2
ip link set g2-g3 netns G2
ip link set g3-g2 netns G3

# 🌐 Configura IP
ip netns exec M1 ip addr add 10.0.100.1/24 dev m1-g1
ip netns exec M1 ip link set m1-g1 up
ip netns exec M1 ip route add default via 10.0.100.254

ip netns exec M2 ip addr add 10.0.100.2/24 dev m2-g2
ip netns exec M2 ip link set m2-g2 up
ip netns exec M2 ip route add default via 10.0.100.253

ip netns exec H1 ip addr add 10.0.1.1/24 dev h1-g1
ip netns exec H1 ip link set h1-g1 up
ip netns exec H1 ip route add default via 10.0.1.254

ip netns exec H2 ip addr add 10.0.2.1/24 dev h2-g2
ip netns exec H2 ip link set h2-g2 up
ip netns exec H2 ip route add default via 10.0.2.254

ip netns exec G1 ip addr add 10.0.1.254/24 dev g1-h1
ip netns exec G1 ip addr add 10.0.100.254/24 dev g1-m1
ip netns exec G1 ip addr add 10.0.10.1/30 dev g1-g3
ip netns exec G1 ip link set g1-h1 up
ip netns exec G1 ip link set g1-m1 up
ip netns exec G1 ip link set g1-g3 up

ip netns exec G2 ip addr add 10.0.2.254/24 dev g2-h2
ip netns exec G2 ip addr add 10.0.100.253/24 dev g2-m2
ip netns exec G2 ip addr add 10.0.10.5/30 dev g2-g3
ip netns exec G2 ip link set g2-h2 up
ip netns exec G2 ip link set g2-m2 up
ip netns exec G2 ip link set g2-g3 up

ip netns exec G3 ip addr add 10.0.10.2/30 dev g3-g1
ip netns exec G3 ip addr add 10.0.10.6/30 dev g3-g2
ip netns exec G3 ip link set g3-g1 up
ip netns exec G3 ip link set g3-g2 up

# 🔁 Loopback
for ns in M1 M2 H1 H2 G1 G2 G3; do
    ip netns exec $ns ip link set lo up
done

# 📤 Abilita forwarding
for ns in G1 G2 G3; do
    ip netns exec $ns sysctl -w net.ipv4.ip_forward=1 >/dev/null
done

# 📡 Routing G3
ip netns exec G3 ip route add 10.0.10.0/30 dev g3-g1
ip netns exec G3 ip route add 10.0.10.4/30 dev g3-g2
ip netns exec G3 ip route add 10.0.100.0/24 via 10.0.10.1

# 📡 Routing statico G1 e G2
ip netns exec G1 ip route add 10.0.10.4/30 via 10.0.10.2
ip netns exec G2 ip route add 10.0.10.0/30 via 10.0.10.6

# GRE Tunnel
ip netns exec G1 ip tunnel add gre1 mode gre local 10.0.10.1 remote 10.0.10.5 ttl 255
ip netns exec G1 ip link set gre1 up
ip netns exec G1 ip addr add 10.1.1.1/30 dev gre1

ip netns exec G2 ip tunnel add gre1 mode gre local 10.0.10.5 remote 10.0.10.1 ttl 255
ip netns exec G2 ip link set gre1 up
ip netns exec G2 ip addr add 10.1.1.2/30 dev gre1

# 📦 Routing GRE: tenant + management
ip netns exec G1 ip route add 10.0.2.0/24 via 10.1.1.2
ip netns exec G2 ip route add 10.0.1.0/24 via 10.1.1.1

ip netns exec G1 ip route add 10.0.100.0/24 via 10.1.1.2

echo ""
echo "✅ Topologia COMPLETA e CORRETTA creata."
echo "Test consigliati:"
echo "➡️  ip netns exec H1 ping 10.0.2.1"
echo "➡️  ip netns exec M1 ping 10.0.100.2"
echo "➡️  ip netns exec G1 ping 10.1.1.2"
