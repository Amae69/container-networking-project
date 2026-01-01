# Container Networking Project

## Project Overview
This project involves building a complete containerized microservices application infrastructure using only Linux primitives (network namespaces, veth pairs, bridges, iptables) to understand the low-level workings of container networking. The infrastructure simulates a real-world e-commerce platform with multiple services.

## System Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    E-COMMERCE PLATFORM                          │
└─────────────────────────────────────────────────────────────────┘

External Users
     │
     ↓
┌─────────────────────────────────────────────────────────────────┐
│ EDGE LAYER                                                      │
│  ┌──────────────┐      ┌──────────────┐                        │
│  │  Load        │      │   API        │                        │
│  │  Balancer    │─────▶│   Gateway    │                        │
│  │  (nginx)     │      │   (Node.js)  │                        │
│  └──────────────┘      └──────┬───────┘                        │
└────────────────────────────────┼────────────────────────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────┐
│ APPLICATION LAYER              │                                │
│                    ┌───────────┴──────────┐                     │
│                    │                      │                     │
│         ┌──────────▼─────────┐ ┌─────────▼────────┐            │
│         │   Product Service  │ │   Order Service  │            │
│         │   (Python Flask)   │ │   (Python Flask) │            │
│         └──────────┬─────────┘ └─────────┬────────┘            │
└────────────────────┼───────────────────────┼────────────────────┘
                     │                       │
┌────────────────────┼───────────────────────┼────────────────────┐
│ DATA LAYER         │                       │                    │
│         ┌──────────▼─────────┐  ┌─────────▼────────┐           │
│         │   Redis Cache      │  │   PostgreSQL     │           │
│         │   (Session Store)  │  │   (Database)     │           │
│         └────────────────────┘  └──────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites
- Linux environment (WSL2 or Linux VM)
- Root/Sudo privileges
- Python 3
- `iproute2` (for `ip` command)
- `iptables`
- `curl`

## Getting Started

### 1. Network Setup
Initialize the network namespaces, bridge, and NAT configuration.

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Create namespaces and bridge
sudo ./scripts/setup_network.sh

# Configure NAT for internet access
sudo ./scripts/setup_nat.sh
```

### 2. Deploy Services
Deploy the application services (Nginx, API Gateway, Product Service, Order Service) into their respective namespaces.

```bash
# Deploy services
sudo ./scripts/deploy_services.sh
```

## Verification

### Check Network Status
Verify that namespaces and the bridge are created correctly.

```bash
# List namespaces
ip netns list
# Expected: nginx-lb, api-gateway, product-service, order-service, redis-cache, postgres-db

# Check bridge IP
ip addr show br-app
# Expected: 10.0.0.1
```

### Test Application
Verify that the services are running and accessible through the load balancer.

```bash
# Check API Gateway health
curl http://10.0.0.10/health

# Test Product Service via Gateway
curl http://10.0.0.10/api/products
```

## Project Status

### Day 1: Foundation - Linux Primitives [COMPLETED]
- [x] Create Network Namespaces
- [x] Build a Virtual Bridge Network
- [x] Implement NAT for Internet Access
- [x] Setup Port Forwarding

### Day 2: Application Services [COMPLETED]
- [x] Deploy Nginx Load Balancer
- [x] Create API Gateway
- [x] Build Product Service
- [x] Build Order Service
- [x] Deploy Redis and PostgreSQL

### Upcoming Tasks
- Day 3: Monitoring and Debugging
- Day 4: Advanced Networking
- Day 5: Docker Migration
- Day 6: Multi-Host Networking