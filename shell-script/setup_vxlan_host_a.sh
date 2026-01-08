#!/bin/bash
# setup_vxlan_host_a.sh
# To be run on Host A (192.168.56.104)

HOST_B_IP="192.168.56.103"
VNI=100
PORT=4789
INTERFACE="enp0s3" # Adjust if your primary adapter is different (e.g., enp0s8)
BRIDGE="br-app"

echo "=== Setting up VXLAN on Host A ==="

# Check if bridge exists, create if missing (assuming Task 1.2 logic)
if ! ip link show "$BRIDGE" > /dev/null 2>&1; then
    echo "Creating bridge $BRIDGE..."
    sudo ip link add "$BRIDGE" type bridge
    sudo ip addr add 10.0.0.1/16 dev "$BRIDGE"
    sudo ip link set "$BRIDGE" up
fi

# Create VXLAN interface
echo "Creating vxlan100 interface..."
sudo ip link add vxlan100 type vxlan \
    id $VNI \
    remote $HOST_B_IP \
    dstport $PORT \
    dev $INTERFACE

# Attach to bridge
echo "Attaching vxlan100 to $BRIDGE..."
sudo ip link set vxlan100 master $BRIDGE
sudo ip link set vxlan100 up

echo "VXLAN setup complete on Host A."
echo "Don't forget to run the corresponding script on Host B ($HOST_B_IP)."
