#!/bin/bash
# start_isolated_services.sh
# Starts services in isolated network namespaces

# Kill existing
pkill -f "python3 services" || true
pkill -f "redis-server" || true

# Start from directory where script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -d "$DIR/services" ]; then
  echo "❌ Error: 'services' directory not found in $DIR."
  echo "It looks like you are running inside a VM or remote machine."
  echo "You must copy the 'services' folder from your project to $DIR on this machine."
  exit 1
fi

echo "Starting Database Tier..."
if command -v redis-server >/dev/null; then
    sudo ip netns exec database-ns redis-server --bind 172.22.0.10 --port 6379 --daemonize yes
    echo "Redis started at 172.22.0.10"
else
    echo "Redis server not found, skipping"
fi

echo "Starting Backend Tier..."
# Service Registry
sudo ip netns exec backend-ns bash -c "nohup python3 \"$DIR/services/service-registry/service-registry.py\" > \"$DIR/registry.log\" 2>&1 & echo \$! > \"$DIR/registry.pid\""

# Order Service
sudo ip netns exec backend-ns bash -c "export SERVICE_IP='172.21.0.20'; export SERVICE_PORT=5000; export SERVICE_REGISTRY='http://172.21.0.5:8500'; export DB_HOST='172.22.0.20'; nohup python3 \"$DIR/services/order-service/order-service.py\" > \"$DIR/order.log\" 2>&1 & echo \$! > \"$DIR/order.pid\""

# Product Service 1
sudo ip netns exec backend-ns bash -c "export SERVICE_IP='172.21.0.10'; export SERVICE_PORT=5000; export INSTANCE_ID='product-1'; export REDIS_HOST='172.22.0.10'; export SERVICE_REGISTRY='http://172.21.0.5:8500'; nohup python3 \"$DIR/services/product-service/product-service.py\" > \"$DIR/product1.log\" 2>&1 & echo \$! > \"$DIR/product1.pid\""

# Product Service 2
sudo ip netns exec backend-ns bash -c "export SERVICE_IP='172.21.0.11'; export SERVICE_PORT=5000; export INSTANCE_ID='product-2'; export REDIS_HOST='172.22.0.10'; export SERVICE_REGISTRY='http://172.21.0.5:8500'; nohup python3 \"$DIR/services/product-service/product-service.py\" > \"$DIR/product2.log\" 2>&1 & echo \$! > \"$DIR/product2.pid\""


echo "Starting Frontend Tier..."
# API Gateway
# Use explicit path for log to capture errors
sudo ip netns exec frontend-ns bash -c "export SERVICE_IP='172.20.0.10'; export SERVICE_PORT=3000; export SERVICE_REGISTRY='http://172.21.0.5:8500'; export PRODUCT_SERVICE_URLS='http://172.21.0.10:5000,http://172.21.0.11:5000'; nohup python3 \"$DIR/services/api-gateway/api-gateway.py\" > \"$DIR/gateway.log\" 2>&1 & echo \$! > \"$DIR/gateway.pid\""

echo "All isolated services started."
echo "Gateway: http://172.20.0.10:3000"
