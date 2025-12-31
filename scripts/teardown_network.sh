#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Tearing Down Network ===${NC}"

NAMESPACES=("nginx-lb" "api-gateway" "product-service" "order-service" "redis-cache" "postgres-db")
BRIDGE="br-app"

# 1. Delete Namespaces
for ns in "${NAMESPACES[@]}"; do
    if ip netns list | grep -q "$ns"; then
        sudo ip netns del "$ns"
        echo "Deleted namespace: $ns"
    fi
done

# 2. Delete Bridge
if ip link show "$BRIDGE" > /dev/null 2>&1; then
    sudo ip link set "$BRIDGE" down
    sudo ip link del "$BRIDGE"
    echo "Deleted bridge: $BRIDGE"
fi

# 3. Cleanup iptables (Optional - be careful not to flush everything if user has other rules)
# Ideally we should delete specific rules, but for this project, we might want to just warn or leave them.
# For now, let's just print a message.
echo "Note: iptables rules were NOT flushed automatically to avoid affecting system configuration."
echo "To remove the specific rules added:"
echo "sudo iptables -t nat -D POSTROUTING -s 10.0.0.0/16 ! -o br-app -j MASQUERADE"
echo "sudo iptables -t nat -D PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.10:80"
echo "sudo iptables -D FORWARD -p tcp -d 10.0.0.10 --dport 80 -j ACCEPT"

echo -e "${GREEN}=== Teardown Complete ===${NC}"
