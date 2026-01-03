#!/bin/bash
# setup_network_isolation.sh
# Sets up isolated networks for Frontend, Backend, and Database tiers

set -e
echo "Setting up isolated networks..."

# Function to safely delete namespace and links
cleanup() {
    ns=$1
    echo "Cleaning up $ns..."
    sudo ip netns del $ns 2>/dev/null || true
}

# Cleanup existing interfaces and namespaces to ensure clean state
echo "Cleaning up existing environment..."
sudo ip link del veth-fe-br 2>/dev/null || true
sudo ip link del veth-be-br 2>/dev/null || true
sudo ip link del veth-db-br 2>/dev/null || true

# We should also clean the namespaces themselves to avoid conflict or "already exists" errors 
# that might mask other issues, although "ip netns add" usually errors if exists.
# But if we delete the namespace, the veth end inside it is gone too.
# However, if the veth peer was on host (bridged), "ip link del veth-fe-br" handles it.

# If we don't delete netns, the `ip netns add` below might fail or succeed with "File exists".
# The script currently uses `2>/dev/null || true` for netns add.
# So if NS exists, we keep it. But if the veth inside it exists, we might have issues?
# Better to recreate NS or clean veths inside. 
# Simplest: Delete NS.
sudo ip netns del frontend-ns 2>/dev/null || true
sudo ip netns del backend-ns 2>/dev/null || true
sudo ip netns del database-ns 2>/dev/null || true

# Recreating bridges is also safer to ensure clean slate
sudo ip link del br-frontend type bridge 2>/dev/null || true
sudo ip link del br-backend type bridge 2>/dev/null || true
sudo ip link del br-database type bridge 2>/dev/null || true

# ==========================================
# 1. Create Bridges
# ==========================================
echo "Creating Bridges..."
sudo ip link add br-frontend type bridge 2>/dev/null || true
sudo ip addr add 172.20.0.1/24 dev br-frontend 2>/dev/null || true
sudo ip link set br-frontend up

sudo ip link add br-backend type bridge 2>/dev/null || true
sudo ip addr add 172.21.0.1/24 dev br-backend 2>/dev/null || true
sudo ip link set br-backend up

sudo ip link add br-database type bridge 2>/dev/null || true
sudo ip addr add 172.22.0.1/24 dev br-database 2>/dev/null || true
sudo ip link set br-database up


# ==========================================
# 2. Create Namespaces
# ==========================================
echo "Creating Namespaces..."
sudo ip netns add frontend-ns 2>/dev/null || true
sudo ip netns add backend-ns 2>/dev/null || true
sudo ip netns add database-ns 2>/dev/null || true


# ==========================================
# 3. Connect Frontend NS
# ==========================================
echo "Connecting Frontend NS..."
sudo ip link add veth-fe type veth peer name veth-fe-br 2>/dev/null || true
sudo ip link set veth-fe netns frontend-ns
sudo ip link set veth-fe-br master br-frontend
sudo ip link set veth-fe-br up

sudo ip netns exec frontend-ns ip link set lo up
sudo ip netns exec frontend-ns ip link set veth-fe up
sudo ip netns exec frontend-ns ip addr add 172.20.0.10/24 dev veth-fe 2>/dev/null || true
sudo ip netns exec frontend-ns ip route add default via 172.20.0.1 2>/dev/null || true


# ==========================================
# 4. Connect Backend NS
# ==========================================
echo "Connecting Backend NS..."
sudo ip link add veth-be type veth peer name veth-be-br 2>/dev/null || true
sudo ip link set veth-be netns backend-ns
sudo ip link set veth-be-br master br-backend
sudo ip link set veth-be-br up

sudo ip netns exec backend-ns ip link set lo up
sudo ip netns exec backend-ns ip link set veth-be up
# Primary IP for the namespace (e.g. for the service registry or shared)
sudo ip netns exec backend-ns ip addr add 172.21.0.5/24 dev veth-be 2>/dev/null || true
# We can add alias IPs for multiple services in the same NS if we want, 
# or use multiple veths. For simplicity, let's just bind services to different ports on the same IP 
# OR add secondary IPs.
# Let's add secondary IPs for the product instances as planned.
sudo ip netns exec backend-ns ip addr add 172.21.0.10/24 dev veth-be 2>/dev/null || true
sudo ip netns exec backend-ns ip addr add 172.21.0.11/24 dev veth-be 2>/dev/null || true
sudo ip netns exec backend-ns ip addr add 172.21.0.20/24 dev veth-be 2>/dev/null || true

sudo ip netns exec backend-ns ip route add default via 172.21.0.1 2>/dev/null || true


# ==========================================
# 5. Connect Database NS
# ==========================================
echo "Connecting Database NS..."
sudo ip link add veth-db type veth peer name veth-db-br 2>/dev/null || true
sudo ip link set veth-db netns database-ns
sudo ip link set veth-db-br master br-database
sudo ip link set veth-db-br up

sudo ip netns exec database-ns ip link set lo up
sudo ip netns exec database-ns ip link set veth-db up
sudo ip netns exec database-ns ip addr add 172.22.0.10/24 dev veth-db 2>/dev/null || true  # Redis
sudo ip netns exec database-ns ip addr add 172.22.0.20/24 dev veth-db 2>/dev/null || true  # Postgres

sudo ip netns exec database-ns ip route add default via 172.22.0.1 2>/dev/null || true


# ==========================================
# 6. Configure Host Routing (Inter-subnet communication)
# ==========================================
echo "Configuring Routing..."
# Enable IP forwarding on host
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null

# The host is the gateway for all usage.
# Bridges are L3 interfaces on the host, so host can route between them automatically 
# if forwarding is on and iptables doesn't block it.

# Verify connectivity Setup
echo "Network Isolation Setup Complete."
echo "Frontend: 172.20.0.10"
echo "Backend:  172.21.0.5, .10, .11, .20"
echo "Database: 172.22.0.10, .20"
