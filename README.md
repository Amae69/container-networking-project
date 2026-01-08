# Container Networking & Microservices Project

![Status](https://img.shields.io/badge/Status-Day%206%20Complete-success?style=for-the-badge)
![Tech](https://img.shields.io/badge/Tech-VXLAN%20%7C%20Docker%20Swarm-orange?style=for-the-badge)

A deep-dive exploration into the low-level mechanics of container networking. This project demonstrates how to build a scalable microservices architecture from scratch using raw **Linux kernel primitives** (namespaces, veth pairs, bridges), migrating to an **optimized Docker environment**, and finally scaling to **Multi-Host Networking** using VXLAN and Docker Swarm.

---

## 🚀 Project Overview

This infrastructure simulates a production-grade e-commerce platform. We started with no container runtime, manually configuring the network stack to achieve isolation, routing, and load balancing, before automating and optimizing it with Docker.

### Key Architecture Components
- **API Gateway**: The entry point, providing round-robin load balancing.
- **Service Registry**: A custom service discovery implementation.
- **Product Service**: Backend logic with **Redis** caching.
- **Order Service**: Persistent storage using **PostgreSQL**.
- **Security Tiers**: Segmented Frontend, Backend, and Database networks.

---

## 🏗️ System Architecture

![system architecture](./images/system%20architecture.png)

---

## 📋 Prerequisites

- **OS**: Linux (Ubuntu recommended) or WSL2.
- **Privileges**: Root/Sudo access for network manipulations.
- **Tools**: `iproute2`, `iptables`, `docker`, `docker-compose`, `python3.11+`.

---

## 🛠️ Setup Guide

### 1. The Manual Way: Linux Primitives
This phase focuses on understanding the "magic" behind containers.

**Network Isolation Script:**
We use a 3-tier bridge architecture to isolate different layers of the application.
```bash
# Example logic for creating a namespace and connecting to a bridge
sudo ip netns add frontend-ns
sudo ip link add veth-fe type veth peer name veth-fe-br
sudo ip link set veth-fe netns frontend-ns
sudo ip link set veth-fe-br master br-frontend
sudo ip netns exec frontend-ns ip addr add 172.20.0.10/24 dev veth-fe
sudo ip netns exec frontend-ns ip route add default via 172.20.0.1
```

**Traffic Routing:**
IP forwarding is enabled on the host to route traffic between the subnets, acting as a virtual router.
```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

### 2. The Optimized Way: Docker Compose
Our Docker implementation leverages advanced optimizations for performance and security.

**Run the Stack:**
```bash
docker-compose up -d --build
```

**Optimizations Included:**
- **Multi-Stage Builds**: Drastically reduced image sizes (using `python:3.11-slim`).
- **Health Checks**: Automated service recovery and dependency management.
- **Resource Limits**: Configured CPU (0.5) and Memory (128MB-256MB) constraints.
- **Ordered Startup**: API Gateway waits for Service Registry and Database health indicators.
### 3. The Distributed Way: Multi-Host Networking
Scale services across multiple physical or virtual hosts.

**VXLAN Tunneling:**
Create an overlay tunnel to bridge network segments across the physical network.
```bash
sudo ip link add vxlan100 type vxlan id 100 remote <REMOTE_IP> dstport 4789 dev eth0
sudo ip link set vxlan100 master br-app
sudo ip link set vxlan100 up
```

**Docker Swarm Orchestration:**
Initialize a cluster and deploy an `overlay` network for seamless cross-host communication.
```bash
docker swarm init --advertise-addr <MANAGER_IP>
docker stack deploy -c docker-compose-swarm.yml myapp
```

---

## 📊 Performance Comparison

We compared raw Linux namespaces against Docker's overlay/bridge layers.
*Results based on 1000 requests @ 50 concurrency:*

| Metric | Linux Namespaces | Docker Compose |
| :--- | :--- | :--- |
| **Requests per Second** | **54.07** | 29.21 |
| **Mean Latency** | **924.7 ms** | 1711.5 ms |
| **Success Rate** | 100% | 99.6% |

> [!NOTE]
> Raw Linux primitives are ~46% faster, but Docker provides significantly better portability and management for modern CI/CD workflows.

---

## 🔍 Monitoring & Operations

### Traffic Analysis
Monitor real-time bridge traffic:
```bash
sudo tcpdump -i br-frontend -n -v
```

### Service Health
Check container health status and resource usage:
```bash
docker ps
docker stats
```

---

## 📄 Full Documentation
For deeper technical details, refer to the following:
- [Technical Implementation Part 1: Linux Primitives (PDF)](./Documentation_Part1.pdf)
- [Technical Implementation Part 2: Docker & Swarm (PDF)](./Documentation_Part2.pdf)
- [Project Architecture & Setup Summary (PDF)](./Technical_Document_Final.pdf)
- [Performance Benchmarks (PDF)](./performance_comparison.pdf)
- [Detailed Security Policies (PDF)](./security-policy-document.pdf)

---
**Project Status: Successfully Completed** ✅
Finalized on 2026-01-08.
