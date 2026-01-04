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

### Day 3: Monitoring and Debugging [COMPLETED]
- [x] Network Traffic Analysis (Tcpdump & Python)
- [x] Service Health Monitoring Dashboard
- [x] Connection Tracking & Analysis

### Day 4: Advanced Networking [COMPLETED]
- [x] Implement Simple Service Discovery (Registry)
- [x] Round-Robin Load Balancing (API Gateway)
- [x] Multi-Network Tier Isolation (Frontend, Backend, Database)
- [x] Inter-VLAN Routing via Host
- [ ] Network Security Policies (iptables) - *Optional/Skipped for Docker Migration*

### Day 5: Docker Migration & Optimization [COMPLETED]
- [x] Containerize All Services (Dockerfiles)
- [x] Orchestration with Docker Compose
- [x] Performance Benchmarking (Linux vs Docker)
- [x] Multi-stage Builds & Health Checks
- [x] Resource Limits & Optimization

## Network Isolation (Task 4.4)
The application was re-architected into three isolated security zones:
- **Frontend (172.20.0.0/24)**: API Gateway
- **Backend (172.21.0.0/24)**: Service Registry, Product & Order Services
- **Database (172.22.0.0/24)**: PostgreSQL & Redis

Routing between these tiers is managed by the host machine acting as a router via Linux Bridges (`br-frontend`, `br-backend`, `br-database`).

## Performance Benchmark: Linux vs Docker
Direct comparison of RPS (Requests Per Second) using `ab` benchmark (1000 requests, 50 concurrency):

| Implementation | RPS | Latency (Mean) | Success Rate |
| :--- | :--- | :--- | :--- |
| **Linux Namespaces** | **54.07** | 924.7 ms | 100% |
| **Docker Compose** | 29.21 | 1711.5 ms | 99.6% |

**Insight**: Raw Linux namespaces provided early **2x better throughput** than Docker in this specific test environment, highlighting the overhead of container orchestration layers.

## How to Run (Docker Version)
```bash
# Start the optimized stack
docker-compose up -d

# Check health status
docker ps

# Verify endpoint
curl http://localhost:3000/api/products
```

## Upcoming Tasks
- Day 6: Multi-Host Networking (VXLAN Overlay)
