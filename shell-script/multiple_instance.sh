#!/bin/bash
# multiple_instance.sh
# Adds extra network namespaces for load balancing testing

set -e

echo "Setting up extra product service nodes..."

# Create namespaces
sudo ip netns add product2 || true
sudo ip netns add product3 || true

# Create veth pairs
sudo ip link add veth-prod2 type veth peer name veth-prod2-br || true
sudo ip link add veth-prod3 type veth peer name veth-prod3-br || true

# Attach to bridge (assuming br-app exists from previous tasks)
sudo ip link set veth-prod2-br master br-app
sudo ip link set veth-prod3-br master br-app

# Move interfaces to namespaces
sudo ip link set veth-prod2 netns product2
sudo ip link set veth-prod3 netns product3

# Bring up bridge side
sudo ip link set veth-prod2-br up
sudo ip link set veth-prod3-br up

# Configure IPs
sudo ip netns exec product2 ip addr add 10.0.0.31/16 dev veth-prod2
sudo ip netns exec product2 ip link set veth-prod2 up
sudo ip netns exec product2 ip route add default via 10.0.0.1

sudo ip netns exec product3 ip addr add 10.0.0.32/16 dev veth-prod3
sudo ip netns exec product3 ip link set veth-prod3 up
sudo ip netns exec product3 ip route add default via 10.0.0.1

# Enable loopback
sudo ip netns exec product2 ip link set lo up
sudo ip netns exec product3 ip link set lo up

echo "multiple instance of product service complete:"
echo "product2: 10.0.0.31"
echo "product3: 10.0.0.32"
