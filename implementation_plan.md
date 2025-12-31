# Day 1: Foundation - Linux Primitives

## Goal Description
The goal of Day 1 is to establish the networking foundation for the microservices application using raw Linux primitives. We will create network namespaces for isolation, a virtual bridge for connectivity, and configure NAT/port forwarding for external access.

## User Review Required
> [!IMPORTANT]
> This project requires a Linux environment with `ip` and `iptables` commands. Since you are on Windows, we need to confirm if you have WSL (Windows Subsystem for Linux) installed and if we should use it.

## Proposed Changes
### Scripts
#### [NEW] [setup_network.sh](file:///c:/Users/CRMSysAdm.Win11Desktop/Desktop/Container-Networking/scripts/setup_network.sh)
- Script to create namespaces: `nginx-lb`, `api-gateway`, `product-service`, `order-service`, `redis-cache`, `postgres-db`.
- Create bridge `br-app`.
- Create veth pairs and attach to bridge/namespaces.
- Configure IP addresses and routes.

#### [NEW] [setup_nat.sh](file:///c:/Users/CRMSysAdm.Win11Desktop/Desktop/Container-Networking/scripts/setup_nat.sh)
- Enable IP forwarding.
- Configure `iptables` MASQUERADE for internet access.
- Configure Port Forwarding for port 8080 -> 10.0.0.10:80.

#### [NEW] [teardown_network.sh](file:///c:/Users/CRMSysAdm.Win11Desktop/Desktop/Container-Networking/scripts/teardown_network.sh)
- Cleanup script to remove namespaces, bridges, and iptables rules.

## Verification Plan
### Automated Tests
- Run `setup_network.sh` and `setup_nat.sh`.
- Verify namespaces exist: `ip netns list`.
- Verify connectivity:
    - Ping from host to bridge IP.
    - Ping between namespaces.
    - Ping external internet from namespaces.
