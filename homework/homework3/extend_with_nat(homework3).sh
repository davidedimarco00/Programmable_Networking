#!/bin/bash

# === CREAZIONE SWITCH ESTERNO ===
ovs-vsctl add-br LAN_EXT

# === CREAZIONE HOST ESTERNO ===
ip netns add HEXT
ip link add veth-ext type veth peer name eth-HEXT
ip link set veth-ext netns HEXT
ip netns exec HEXT ip link set veth-ext up
ip netns exec HEXT ip addr add 192.168.1.1/24 dev veth-ext
ip netns exec HEXT ip link set lo up
ovs-vsctl add-port LAN_EXT eth-HEXT
ip link set eth-HEXT up

# === COLLEGAMENTO GATEWAY <-> LAN_EXT ===
ip link add extgw type veth peer name eth-extgw
ip link set eth-extgw netns GW
ip link set extgw up
ovs-vsctl add-port LAN_EXT extgw

# === CONFIGURAZIONE INTERFACCIA ESTERNA DEL GATEWAY ===
ip netns exec GW ip link set eth-extgw up
ip netns exec GW ip addr add 192.168.1.254/24 dev eth-extgw

# === ABILITA IP FORWARDING E CONFIGURA NAT ===
ip netns exec GW sysctl -w net.ipv4.ip_forward=1

# NAT per 10.0.1.0/24 e 10.0.2.0/24 verso 192.168.1.0/24
ip netns exec GW iptables -t nat -A POSTROUTING -s 10.0.1.0/24 -o eth-extgw -j MASQUERADE
ip netns exec GW iptables -t nat -A POSTROUTING -s 10.0.2.0/24 -o eth-extgw -j MASQUERADE

# FIREWALL: blocco traffico tra VLAN 1 e VLAN 2
ip netns exec GW iptables -A FORWARD -s 10.0.1.0/24 -d 10.0.2.0/24 -j DROP
ip netns exec GW iptables -A FORWARD -s 10.0.2.0/24 -d 10.0.1.0/24 -j DROP

# ROUTE DI RITORNO PER HOST ESTERNO
ip netns exec HEXT ip route add default via 192.168.1.254

echo "Topologia estesa con NAT, firewall e host esterno completata."

