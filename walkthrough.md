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
