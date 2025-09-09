#!/bin/bash

echo "🔍 === ANALISI DELLA CONFIGURAZIONE ==="
echo

echo "📋 1. VERIFICA ROUTING TABLES:"
echo "--- GW1 ---"
ip netns exec GW1 ip route show
echo
echo "--- GW2 ---"
ip netns exec GW2 ip route show
echo
echo "--- R ---"
ip netns exec R ip route show
echo

echo "📋 2. VERIFICA INTERFACCE:"
echo "--- GW1 interfaces ---"
ip netns exec GW1 ip addr show
echo
echo "--- GW2 interfaces ---"
ip netns exec GW2 ip addr show
echo
echo "--- R interfaces ---"
ip netns exec R ip addr show
echo

echo "📋 3. TEST CONNETTIVITA BASE:"
echo "--- MGT1 → GW1 (10.0.100.1) ---"
ip netns exec MGT1 ping -c 1 10.0.100.1
echo
echo "--- MGT2 → GW2 (10.0.100.2) ---"
ip netns exec MGT2 ping -c 1 10.0.100.2
echo
echo "--- GW1 → R (10.0.10.2) ---"
ip netns exec GW1 ping -c 1 10.0.10.2
echo
echo "--- GW2 → R (10.0.10.6) ---"
ip netns exec GW2 ping -c 1 10.0.10.6
echo

echo "📋 4. VERIFICA GRE TUNNEL:"
echo "--- GW1 tunnel gre1 ---"
ip netns exec GW1 ip addr show gre1 2>/dev/null || echo "GRE1 non trovato"
echo "--- GW2 tunnel gre2 ---"
ip netns exec GW2 ip addr show gre2 2>/dev/null || echo "GRE2 non trovato"
echo
echo "--- Test GRE connectivity ---"
ip netns exec GW1 ping -c 1 10.0.200.2
echo

echo "📋 5. VERIFICA ARP TABLES:"
echo "--- MGT1 ARP ---"
ip netns exec MGT1 arp -a
echo "--- GW1 ARP ---"
ip netns exec GW1 arp -a
echo