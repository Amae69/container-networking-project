#!/bin/bash
# setup_vxlan_host_b.sh
# To be run on Host B (192.168.56.103)

HOST_A_IP="192.168.56.104"
VNI=100
PORT=4789
INTERFACE="eth0" # Adjust if your primary adapter is different
BRIDGE="br-app"

echo "=== Setting up VXLAN on Host B ==="

# Create bridge on Host B
if ! ip link show "$BRIDGE" > /dev/null 2>&1; then
    echo "Creating bridge $BRIDGE..."
    sudo ip link add "$BRIDGE" type bridge
    # Note: Using a different IP range or just no IP if it's purely for bridging
    # For simplicity in this demo, we'll give it the same subnet gateway if it's the only one
    sudo ip addr add 10.0.0.2/16 dev "$BRIDGE"
    sudo ip link set "$BRIDGE" up
fi

# Create VXLAN interface
echo "Creating vxlan100 interface pointing to Host A..."
sudo ip link add vxlan100 type vxlan \
    id $VNI \
    remote $HOST_A_IP \
    dstport $PORT \
    dev $INTERFACE

# Attach to bridge
echo "Attaching vxlan100 to $BRIDGE..."
sudo ip link set vxlan100 master $BRIDGE
sudo ip link set vxlan100 up

echo "VXLAN setup complete on Host B."
