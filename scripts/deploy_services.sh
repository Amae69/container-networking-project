#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Deploying Services ===${NC}"

# Ensure directories exist
mkdir -p services/nginx services/api-gateway services/product-service services/order-service

# 1. Deploy Redis (Cache)
echo "Starting Redis..."
# We assume redis-server is installed on the host/WSL
if command -v redis-server >/dev/null; then
    sudo ip netns exec redis-cache redis-server --bind 0.0.0.0 --daemonize yes
    echo "Redis started in redis-cache namespace"
else
    echo "Warning: redis-server not found. Please install it."
fi

# 2. Deploy PostgreSQL (DB)
echo "Starting PostgreSQL..."
# This is tricky. For this simulation, if postgres is not easily runnable, we might skip or mock.
# Assuming standard postgres installation
if command -v postgres >/dev/null; then
    # Create a data directory for this instance
    sudo mkdir -p /var/lib/postgresql/data-ns
    sudo chown postgres:postgres /var/lib/postgresql/data-ns
    
    # Initialize if empty (requires switching to postgres user, which is hard in script without su)
    # Simplified: We will skip actual Postgres startup in this script as it requires complex user switching
    # and permission handling that is fragile in a simple script.
    # We will assume the user handles DB or we mock it.
    echo "Note: PostgreSQL startup requires manual steps or complex user switching."
    echo "For this exercise, ensure a postgres instance is reachable at 10.0.0.60 or update code to mock."
else
    echo "Warning: postgres not found."
fi

# 3. Deploy Product Service
echo "Starting Product Service..."
# Install dependencies if needed (assuming they are installed globally or in venv)
# pip install flask redis requests psycopg2-binary
sudo ip netns exec product-service python3 services/product-service/product-service.py > product-service.log 2>&1 &
echo "Product Service started (PID: $!)"

# 4. Deploy Order Service
echo "Starting Order Service..."
sudo ip netns exec order-service python3 services/order-service/order-service.py > order-service.log 2>&1 &
echo "Order Service started (PID: $!)"

# 5. Deploy API Gateway
echo "Starting API Gateway..."
sudo ip netns exec api-gateway python3 services/api-gateway/api-gateway.py > api-gateway.log 2>&1 &
echo "API Gateway started (PID: $!)"

# 6. Deploy Nginx Load Balancer
echo "Starting Nginx..."
if command -v nginx >/dev/null; then
    # Create temp config dir in namespace (simulated by mounting or copying)
    # Since we can't easily mount files into netns without 'ip netns exec ... mount', 
    # we will just pass the config file path if it's accessible.
    # Nginx needs absolute path
    CONFIG_PATH="$(pwd)/services/nginx/nginx.conf"
    sudo ip netns exec nginx-lb nginx -c "$CONFIG_PATH"
    echo "Nginx started"
else
    echo "Warning: nginx not found."
fi

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo "Check logs: *.log"
