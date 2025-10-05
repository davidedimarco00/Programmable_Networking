#!/bin/bash
set -e


echo " Testing VXLAN connectivity (L2 overlay)"
echo "→ H1001 → H1002"
sudo ip netns exec H1001 ping -c 3 10.0.100.2
echo "→ H1002 → H1001"
sudo ip netns exec H1002 ping -c 3 10.0.100.1
echo "VXLAN ping tests done."

echo
echo "GRE connectivity (L3 routing)"
echo "→ H11 → H21"
sudo ip netns exec H11 ping -c 3 10.0.2.1
echo "→ H21 → H11"
sudo ip netns exec H21 ping -c 3 10.0.1.1
echo " GRE ping tests done."

