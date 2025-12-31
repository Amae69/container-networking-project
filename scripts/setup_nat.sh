#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Configuring NAT and Port Forwarding ===${NC}"

BRIDGE="br-app"
SUBNET="10.0.0.0/16"
HOST_PORT=8080
LB_IP="10.0.0.10"
LB_PORT=80

# 1. Enable IP Forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null

# 2. Configure NAT (Masquerade)
echo "Configuring NAT for subnet $SUBNET..."
# Check if rule exists to avoid duplicates
if ! sudo iptables -t nat -C POSTROUTING -s "$SUBNET" ! -o "$BRIDGE" -j MASQUERADE 2>/dev/null; then
    sudo iptables -t nat -A POSTROUTING -s "$SUBNET" ! -o "$BRIDGE" -j MASQUERADE
    echo "Added MASQUERADE rule"
else
    echo "MASQUERADE rule already exists"
fi

# 3. Configure Port Forwarding
echo "Forwarding host port $HOST_PORT to $LB_IP:$LB_PORT..."

# DNAT rule
if ! sudo iptables -t nat -C PREROUTING -p tcp --dport "$HOST_PORT" -j DNAT --to-destination "$LB_IP:$LB_PORT" 2>/dev/null; then
    sudo iptables -t nat -A PREROUTING -p tcp --dport "$HOST_PORT" -j DNAT --to-destination "$LB_IP:$LB_PORT"
    echo "Added DNAT rule"
else
    echo "DNAT rule already exists"
fi

# Allow forwarding
if ! sudo iptables -C FORWARD -p tcp -d "$LB_IP" --dport "$LB_PORT" -j ACCEPT 2>/dev/null; then
    sudo iptables -A FORWARD -p tcp -d "$LB_IP" --dport "$LB_PORT" -j ACCEPT
    echo "Added FORWARD ACCEPT rule"
else
    echo "FORWARD ACCEPT rule already exists"
fi

echo -e "${GREEN}=== NAT Setup Complete ===${NC}"
echo "Test connectivity from a namespace: sudo ip netns exec product-service ping -c 3 8.8.8.8"
