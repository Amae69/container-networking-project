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
│  ┌──────────────┐      ┌──────────────┐                         │
│  │  Load        │      │   API        │                         │
│  │  Balancer    │─────▶│   Gateway    │                        │
│  │  (nginx)     │      │   (Node.js)  │                         │
│  └──────────────┘      └──────┬───────┘                         │
└────────────────────────────────┼────────────────────────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────┐
│ APPLICATION LAYER              │                                │
│                    ┌───────────┴──────────┐                     │
│                    │                      │                     │
│         ┌──────────▼─────────┐ ┌─────────▼────────┐             │
│         │   Product Service  │ │   Order Service  │             │
│         │   (Python Flask)   │ │   (Python Flask) │             │
│         └──────────┬─────────┘ └─────────┬────────┘             │
└────────────────────┼───────────────────────┼────────────────────┘
                     │                       │
┌────────────────────┼───────────────────────┼────────────────────┐
│ DATA LAYER         │                       │                    │
│         ┌──────────▼─────────┐  ┌─────────▼────────┐            │
│         │   Redis Cache      │  │   PostgreSQL     │            │
│         │   (Session Store)  │  │   (Database)     │            │
│         └────────────────────┘  └──────────────────┘            │
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

## Day 1: Foundation - Linux Primitives
**Goals**
- Set up isolated network namespaces
- Create virtual network interfaces
- Implement basic inter-namespace communication

## Tasks
### Task 1.1: Create Network Namespaces
---
Create six network namespaces representing my services:

```
# Create namespaces
sudo ip netns add nginx-lb
sudo ip netns add api-gateway
sudo ip netns add product-service
sudo ip netns add order-service
sudo ip netns add redis-cache
sudo ip netns add postgres-db
```
### **Deliverable: Screenshot showing all namespaces created**

Run: `ip netns list`

![namespace-list](./images/ip%20netns%20list.png)

### Task 1.2: Build a Virtual Bridge Network
---

**Create a bridge to connect all services:**

```
# Create bridge
sudo ip link add br-app type bridge
sudo ip addr add 10.0.0.1/16 dev br-app
sudo ip link set br-app up
```
**Connect each namespace to the bridge using veth pairs:**

```
# Example for nginx-lb (repeat for all services)
sudo ip link add veth-nginx type veth peer name veth-nginx-br
sudo ip link set veth-nginx netns nginx-lb
sudo ip link set veth-nginx-br master br-app
sudo ip link set veth-nginx-br up
```

**Configure inside namespace:**

```
sudo ip netns exec nginx-lb ip addr add 10.0.0.10/16 dev veth-nginx
sudo ip netns exec nginx-lb ip link set veth-nginx up
sudo ip netns exec nginx-lb ip link set lo up
sudo ip netns exec nginx-lb ip route add default via 10.0.0.1

IP:
- nginx-lb: 10.0.0.10
- api-gateway: 10.0.0.20
- product-service: 10.0.0.30
- order-service: 10.0.0.40
- redis-cache: 10.0.0.50
- postgres-db: 10.0.0.60
```
### **Deliverable:**

- **Network diagram showing my setup**
![network-diagram](./images/net-diagram.png)

- **Showing bridge with connected interfaces**
![bridge-with-interface](./images/bridge%20with%20interface.png)
![bridge-with-veth](./images/ip%20link%20show%20type%20veth.png)

- **Proof of connectivity (ping tests between all namespaces)**

    Run : `sudo ip netns exec nginx-lb ping -c 2 10.0.0.20`

    nginx-lb –-> api-gateway (10.0.0.20)

    nginx-lb –-> product-service(10.0.0.30)
    ![Ping 1](./images/ping%201.png)

     api-gateway –-> product-service (10.0.0.30)

     api-gateway –-> order-service(10.0.0.40)
     ![Ping 2](./images/ping%202.png)

### Task 1.3: Implement NAT for Internet Access
---
**Enable internet access for all namespaces:**

```
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Add MASQUERADE rule
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/16 ! -o br-app -j MASQUERADE
``` 

### **Deliverable: Test internet connectivity from each namespace**

RUN: `sudo ip netns exec product-service ping -c 3 8.8.8.8`

![test-internet-connect](./images/test%20internet%20connectivity.png)

### Task 1.4: Setup Port Forwarding 

**Forward host port 8080 to nginx-lb:**

```
# Add DNAT rule (PREROUTING - before routing decision)  
sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.10:80

# Allow forwarding in FILTER table
sudo iptables -A FORWARD -p tcp -d 10.0.0.10 --dport 80 -j ACCEPT
```
**Now external clients can access via host IP on port 8080**

Test from host (simulating external client) to confirm request is forwarded to nginx-lb

RUN: `curl http://localhost:8080`

![test-port-forwarding](./images/extenal%20client%20access%20nginx.png)

### **Deliverable: Document all iptables rules with explanations**

**Explanation of the rule:**
```
Rule:

1. sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/16 ! -o br-app -j MASQUERADE

What this rule does:
  - Allows containers/namespaces to access the internet
  - Hides internal IP addresses behind the host IP
  - Required for outbound connectivity

2. sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.10:80

What this rule does:
  - Redirects traffic from host port 8080
  - Sends it to nginx running inside the namespace on port 80
  - Enables external access to internal services

3. sudo iptables -A FORWARD -p tcp -d 10.0.0.10 --dport 80 -j ACCEPT

What this rule does:
  - Explicitly allows forwarded traffic to reach nginx-lb
  - Prevents Linux from dropping forwarded packets
  - Required for DNAT port forwarding to function
```






