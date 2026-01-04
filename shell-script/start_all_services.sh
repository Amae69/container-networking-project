#!/bin/bash
# start_all_services.sh
# Starts all services in the background for testing

# Kill existing python processes to clear ports (be careful)
pkill -f "python3 services" || true

echo "Starting Service Registry..."
nohup python3 services/service-registry/service-registry.py > registry.log 2>&1 &
echo $! > registry.pid
sleep 2

echo "Starting Product Service 1 (10.0.0.30)..."
export SERVICE_IP="10.0.0.30"
export SERVICE_PORT=5000
export INSTANCE_ID="product-1"
# Assuming 10.0.0.30 is the host or "container1" namespace, adjust as needed.
# If using the original setup script, 10.0.0.30 was likely just added to the host or a namespace.
# Based on previous context, 10.0.0.30 is likely in 'container3' or similar. 
# But usually the user just runs it on the host if they don't have strict namespaces active for processes.
# HOWEVER, for the NEW nodes (31, 32), we MUST use the namespaces we created.

# Try to run product-1 on host or specific namespace if known?
# Let's assume 10.0.0.30 is on the host or we just run it.
nohup python3 services/product-service/product-service.py > product1.log 2>&1 &
echo $! > product1.pid

echo "Starting Product Service 2 (10.0.0.31)..."
sudo ip netns exec product2 bash -c "export SERVICE_IP='10.0.0.31'; export SERVICE_PORT=5000; export INSTANCE_ID='product-2'; nohup python3 services/product-service/product-service.py > product2.log 2>&1 & echo \$! > product2.pid"

echo "Starting Product Service 3 (10.0.0.32)..."
sudo ip netns exec product3 bash -c "export SERVICE_IP='10.0.0.32'; export SERVICE_PORT=5000; export INSTANCE_ID='product-3'; nohup python3 services/product-service/product-service.py > product3.log 2>&1 & echo \$! > product3.pid"

echo "Starting Order Service..."
nohup python3 services/order-service/order-service.py > order.log 2>&1 &
echo $! > order.pid

echo "Starting API Gateway..."
nohup python3 services/api-gateway/api-gateway.py > gateway.log 2>&1 &
echo $! > gateway.pid

echo "All services started. Logs are in *.log files."
echo "Press Enter to stop all services..."
read
pkill -F registry.pid
pkill -F product1.pid
# Cleaning up namespace processes is harder with pkill -F because the pid file is inside namespace or not?
# The pid file written by bash -c might be tricky.
# Simple pkill python3 should do it for this lab environment.
pkill -f "python3 services"
echo "Services stopped."
