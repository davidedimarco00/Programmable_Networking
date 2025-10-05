#!/bin/bash
set -e

# --- NAMESPACES ---
for ns in H1001 H1002 H11 H21 R1 R2 R3; do
  sudo ip netns add $ns
done

# --- SWITCHES ---
for sw in SW1 SW2; do
  sudo ovs-vsctl add-br $sw
done

# --- HOST-SWITCH LINKS ---
connect_host() {
  h=$1; sw=$2
  sudo ip link add veth-$h-$sw type veth peer name veth-$sw-$h
  sudo ip link set veth-$h-$sw netns $h
  sudo ovs-vsctl add-port $sw veth-$sw-$h
  sudo ip netns exec $h ip link set veth-$h-$sw up
  sudo ip link set veth-$sw-$h up
}
connect_host H11 SW1
connect_host H1001 SW1
connect_host H21 SW2
connect_host H1002 SW2

# --- ROUTER-SWITCH LINKS ---
connect_router() {
  r=$1; sw=$2
  sudo ip link add veth-$r-$sw type veth peer name veth-$sw-$r
  sudo ip link set veth-$r-$sw netns $r
  sudo ovs-vsctl add-port $sw veth-$sw-$r
  sudo ip netns exec $r ip link set veth-$r-$sw up
  sudo ip link set veth-$sw-$r up
}
connect_router R1 SW1
connect_router R2 SW2

# --- ROUTER INTERCONNECTIONS ---
for link in "R1 R3 10.0.10.0" "R2 R3 10.0.10.4"; do
  set -- $link
  sudo ip link add veth-$1-$2 type veth peer name veth-$2-$1
  sudo ip link set veth-$1-$2 netns $1
  sudo ip link set veth-$2-$1 netns $2
  sudo ip netns exec $1 ip link set veth-$1-$2 up
  sudo ip netns exec $2 ip link set veth-$2-$1 up
done

# --- IP FORWARDING ---
for r in R1 R2 R3; do
  sudo ip netns exec $r sysctl -w net.ipv4.ip_forward=1
done

# --- IP ADDRESSES ---
sudo ip netns exec H1001 ip addr add 10.0.100.1/24 dev veth-H1001-SW1
sudo ip netns exec H1002 ip addr add 10.0.100.2/24 dev veth-H1002-SW2
sudo ip netns exec H11 ip addr add 10.0.1.1/24 dev veth-H11-SW1
sudo ip netns exec H21 ip addr add 10.0.2.1/24 dev veth-H21-SW2

sudo ip netns exec R1 ip addr add 10.0.1.254/24 dev veth-R1-SW1
sudo ip netns exec R2 ip addr add 10.0.2.254/24 dev veth-R2-SW2
sudo ip netns exec R1 ip addr add 10.0.10.1/30 dev veth-R1-R3
sudo ip netns exec R3 ip addr add 10.0.10.2/30 dev veth-R3-R1
sudo ip netns exec R3 ip addr add 10.0.10.5/30 dev veth-R3-R2
sudo ip netns exec R2 ip addr add 10.0.10.6/30 dev veth-R2-R3

# --- ROUTES ---
sudo ip netns exec R1 ip route add 10.0.10.4/30 via 10.0.10.2
sudo ip netns exec R2 ip route add 10.0.10.0/30 via 10.0.10.5
sudo ip netns exec H11 ip route add default via 10.0.1.254
sudo ip netns exec H21 ip route add default via 10.0.2.254

# --- VXLAN (br100) ---
setup_vxlan() {
  ns=$1; localip=$2; remoteip=$3; lan=$4
  sudo ip netns exec $ns ip link add L12 type vxlan id 100 local $localip remote $remoteip dstport 4789
  sudo ip netns exec $ns brctl addbr br100
  sudo ip netns exec $ns brctl addif br100 L12 veth-$ns-$lan
  sudo ip netns exec $ns ip link set L12 up
  sudo ip netns exec $ns ip link set br100 up
}
setup_vxlan R1 10.0.10.1 10.0.10.6 SW1
setup_vxlan R2 10.0.10.6 10.0.10.1 SW2

# --- INTERNAL IFACE PER IP GATEWAY ---
for r in R1 R2; do
  lan=$( [ "$r" = "R1" ] && echo 1 || echo 2 )
  sudo ip netns exec $r ip addr del 10.0.$lan.254/24 dev veth-$r-SW$lan
  sudo ip netns exec $r ip link add int_eth0 type veth
  sudo ip netns exec $r brctl addif br100 veth0
  sudo ip netns exec $r ip link set veth0 up
  sudo ip netns exec $r ip link set int_eth0 up
  sudo ip netns exec $r ip addr add 10.0.$lan.254/24 dev int_eth0
done

# --- GRE TUNNEL ---
sudo modprobe ip_gre
sudo ip netns exec R1 ip tunnel add G1 mode gre remote 10.0.10.6 local 10.0.10.1 ttl 63
sudo ip netns exec R2 ip tunnel add G1 mode gre remote 10.0.10.1 local 10.0.10.6 ttl 63
for ns in R1 R2; do sudo ip netns exec $ns ip link set G1 up; done
sudo ip netns exec R1 ip addr add 192.168.10.1/30 dev G1
sudo ip netns exec R2 ip addr add 192.168.10.2/30 dev G1
sudo ip netns exec R1 ip route replace 10.0.2.0/24 via 192.168.10.2
sudo ip netns exec R2 ip route replace 10.0.1.0/24 via 192.168.10.1
