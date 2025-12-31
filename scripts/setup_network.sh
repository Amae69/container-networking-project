#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Setting up Network Namespaces ===${NC}"

# 1. Create Namespaces
NAMESPACES=("nginx-lb" "api-gateway" "product-service" "order-service" "redis-cache" "postgres-db")

for ns in "${NAMESPACES[@]}"; do
    if ip netns list | grep -q "$ns"; then
        echo "Namespace $ns already exists"
    else
        sudo ip netns add "$ns"
        echo "Created namespace: $ns"
        # Bring up loopback interface
        sudo ip netns exec "$ns" ip link set lo up
    fi
done

# 2. Create Bridge
echo -e "${GREEN}=== Creating Bridge Network ===${NC}"
BRIDGE="br-app"
BRIDGE_IP="10.0.0.1/16"

if ip link show "$BRIDGE" > /dev/null 2>&1; then
    echo "Bridge $BRIDGE already exists"
else
    sudo ip link add "$BRIDGE" type bridge
    sudo ip addr add "$BRIDGE_IP" dev "$BRIDGE"
    sudo ip link set "$BRIDGE" up
    echo "Created bridge: $BRIDGE with IP $BRIDGE_IP"
fi

# 3. Connect Namespaces to Bridge
# Define IPs for each service
declare -A IPS
IPS=(
    ["nginx-lb"]="10.0.0.10"
    ["api-gateway"]="10.0.0.20"
    ["product-service"]="10.0.0.30"
    ["order-service"]="10.0.0.40"
    ["redis-cache"]="10.0.0.50"
    ["postgres-db"]="10.0.0.60"
)

echo -e "${GREEN}=== Connecting Services to Bridge ===${NC}"

for ns in "${NAMESPACES[@]}"; do
    VETH_NS="veth-$ns"
    VETH_BR="veth-$ns-br"
    IP_ADDR="${IPS[$ns]}"

    # Check if veth pair exists
    if ip link show "$VETH_BR" > /dev/null 2>&1; then
        echo "Interface $VETH_BR already exists, skipping..."
        continue
    fi

    echo "Configuring $ns ($IP_ADDR)..."
    
    # Create veth pair
    sudo ip link add "$VETH_NS" type veth peer name "$VETH_BR"
    
    # Move one end to namespace
    sudo ip link set "$VETH_NS" netns "$ns"
    
    # Attach other end to bridge
    sudo ip link set "$VETH_BR" master "$BRIDGE"
    sudo ip link set "$VETH_BR" up
    
    # Configure interface inside namespace
    sudo ip netns exec "$ns" ip addr add "$IP_ADDR/16" dev "$VETH_NS"
    sudo ip netns exec "$ns" ip link set "$VETH_NS" up
    
    # Add default route
    sudo ip netns exec "$ns" ip route add default via 10.0.0.1
done

echo -e "${GREEN}=== Network Setup Complete ===${NC}"
echo "Verify with: ip netns list"
