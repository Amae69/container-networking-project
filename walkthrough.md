# Day 1: Network Setup Walkthrough

## Overview
We have created the foundational scripts for the container networking project. These scripts use Linux network namespaces and bridges to simulate a microservices environment.

## Scripts Created
- **[setup_network.sh](file:///c:/Users/CRMSysAdm.Win11Desktop/Desktop/Container-Networking/scripts/setup_network.sh)**: Creates namespaces (`nginx-lb`, `api-gateway`, etc.), the bridge `br-app`, and connects them.
- **[setup_nat.sh](file:///c:/Users/CRMSysAdm.Win11Desktop/Desktop/Container-Networking/scripts/setup_nat.sh)**: Configures NAT and port forwarding so services can reach the internet and you can reach the load balancer.
- **[teardown_network.sh](file:///c:/Users/CRMSysAdm.Win11Desktop/Desktop/Container-Networking/scripts/teardown_network.sh)**: Cleans up the namespaces and bridge.

## How to Run
Since these scripts require `sudo` privileges, you need to run them in your WSL terminal or Linux VM.

1. **Make scripts executable**:
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Run Network Setup**:
   ```bash
   sudo ./scripts/setup_network.sh
   ```

3. **Run NAT Setup**:
   ```bash
   sudo ./scripts/setup_nat.sh
   ```

## Verification
After running the scripts, verify the setup:

1. **Check Namespaces**:
   ```bash
   ip netns list
   ```
   Should show: `nginx-lb`, `api-gateway`, `product-service`, `order-service`, `redis-cache`, `postgres-db`.

2. **Check Bridge**:
   ```bash
   ip addr show br-app
   ```
   Should show IP `10.0.0.1`.

3. **Test Connectivity**:
   ```bash
   sudo ip netns exec product-service ping -c 3 10.0.0.1
   ```

## Troubleshooting
- If you get "Permission denied", make sure to use `sudo`.
- If `ip netns` is not found, ensure you are running in a Linux environment (WSL or VM) that supports it.

# Day 2: Application Services Walkthrough

## Overview
We have created the application services (Nginx, API Gateway, Product, Order) and a deployment script.

## Services Created
- **Nginx**: Load balancer configuration in `services/nginx/nginx.conf`.
- **API Gateway**: Python Flask app in `services/api-gateway/api-gateway.py`.
- **Product Service**: Python Flask app in `services/product-service/product-service.py`.
- **Order Service**: Python Flask app in `services/order-service/order-service.py`.

## How to Deploy
1. **Make deployment script executable**:
   ```bash
   chmod +x scripts/deploy_services.sh
   ```

2. **Install Dependencies**:
   You need to install the Python dependencies in your environment (or inside the namespaces if you have a way to do that).
   ```bash
   pip install flask redis requests psycopg2-binary
   ```
   *Note: In a real scenario, you would install these inside the namespace or use a virtualenv.*

3. **Run Deployment**:
   ```bash
   sudo ./scripts/deploy_services.sh
   ```

## Verification
1. **Check Processes**:
   ```bash
   sudo ip netns exec api-gateway ps aux
   ```

2. **Test API**:
   ```bash
   # Test Health
   curl http://10.0.0.10/health
   
   # Test Product Service via Gateway
   curl http://10.0.0.10/api/products
   ```
