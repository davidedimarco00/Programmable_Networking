#!/bin/bash
set -e

echo "[🧹] Cleaning up network topology..."

# --- REMOVE NAMESPACES ---
for ns in H1001 H1002 H11 H21 R1 R2 R3; do
  if ip netns list | grep -qw $ns; then
    sudo ip netns del $ns 2>/dev/null || true
    echo " - Deleted namespace: $ns"
  fi
done

# --- REMOVE OVS BRIDGES ---
for sw in SW1 SW2; do
  if sudo ovs-vsctl br-exists $sw; then
    sudo ovs-vsctl del-br $sw
    echo " - Removed OVS bridge: $sw"
  fi
done

# --- REMOVE LEFTOVER INTERFACES ---
echo " - Removing veth and tunnel interfaces..."
for intf in $(ip link show | grep -E "veth-|L12|G1" | awk -F: '{print $2}' | tr -d ' '); do
  sudo ip link del $intf 2>/dev/null || true
done

# --- REMOVE GRE MODULE (OPTIONAL) ---
if lsmod | grep -q ip_gre; then
  sudo modprobe -r ip_gre 2>/dev/null || true
  echo " - Unloaded ip_gre module"
fi

echo "[✅] Cleanup complete."
