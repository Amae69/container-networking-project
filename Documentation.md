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

## 1: Foundation - Linux Primitives

**Goals**
- Set up isolated network namespaces
- Create virtual network interfaces
- Implement basic inter-namespace communication

## Tasks

### Task 1.1: Create Network Namespaces

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

**View the NAT rule:**

RUN: `sudo iptables -t nat -L -v -n`

![view-nat-rule](./images/view%20nat%20rule.png)

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

**Traffic Flow Summary:**

External Client (Port 8080) -> Host (Port 8080) -> DNAT -> nginx-lb (Port 80)

![traffic-flow](./images/traffic%20flow%20.png)

| Option / Flag                   | Meaning              | Explanation                                                                                    |
| ------------------------------- | -------------------- | ---------------------------------------------------------------------------------------------- |
| `-t nat`                        | NAT table            | Specifies that the rule applies to the NAT table                                               |
| `-A POSTROUTING`                | POSTROUTING chain    | Appends rule to POSTROUTING chain (applied **after** routing decision)                         |
| `-A PREROUTING`                 | PREROUTING chain     | Appends rule to PREROUTING chain (applied **before** routing decision)                         |
| `-A FORWARD`                    | FORWARD chain        | Appends rule to FORWARD chain (controls forwarded traffic)                                     |
| `-s 10.0.0.0/16`                | Source network       | Matches packets originating from the container network                                         |
| `! -o br-app`                   | Not bridge interface | Matches packets **not** leaving via the bridge interface (i.e., traffic going to the internet) |
| `-p tcp`                        | TCP protocol         | Matches TCP traffic                                                                            |
| `--dport 8080`                  | Destination port     | Matches packets destined to port **8080** on the host                                          |
| `--dport 80`                    | Destination port     | Matches packets destined to port **80**                                                        |
| `-d 10.0.0.10`                  | Destination IP       | Matches destination IP address of the nginx-lb namespace                                       |
| `-j MASQUERADE`                 | SNAT action          | Applies MASQUERADE (dynamic Source NAT), rewriting source IP to host’s external IP             |
| `-j DNAT`                       | DNAT action          | Applies Destination NAT, rewriting destination IP and/or port                                  |
| `--to-destination 10.0.0.10:80` | DNAT target          | Forwards traffic to nginx-lb namespace at IP `10.0.0.10` on port `80`                          |
| `-j ACCEPT`                     | Accept action        | Allows the packet to be forwarded                                                              |

## **2: Application Services**

**Goals**
- Deploy actual services in namespaces
- Implement service-to-service communication
- Test the complete application flow

## Tasks

### Task 2.1: Deploy Nginx Load Balancer

Create a simple nginx configuration that load balances to the API gateway:

Install and run nginx in the namespace:
```
# Create nginx config

sudo ip netns exec nginx-lb bash -c 'cat <<EOF > /tmp/nginx/nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream api_gateway {
        server 10.0.0.20:3000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://api_gateway;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }

        location /health {
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF'
```
Verify the nginx config file has been created in nginx-lb namespace

RUN: `sudo ip netns exec nginx-lb cat /tmp/nginx/nginx.conf`

Start nginx inside nginx-lb namespace

RUN: `sudo ip netns exec nginx-lb nginx -c /tmp/nginx/nginx.conf`

### Deliverable: Working load balancer responding to HTTP requests

**Test from host:** 

RUN: `curl http://192.168.56.104:8080/health`  

![test from host](./images/test%20from%20host.png)

**Test from another namespace:**

RUN: `sudo ip netns exec api-gateway curl http://10.0.0.10/health`  

![test from namespace](./images/test%20from%20another%20namespace.png)

### Task 2.2: Create API Gateway

**Build a Node.js or Python API gateway that routes to backend services.**

**create api-gateway.py:**
```
from flask import Flask, jsonify, request
import requests

app = Flask(__name__)

PRODUCT_SERVICE = "http://10.0.0.30:5000"
ORDER_SERVICE = "http://10.0.0.40:5000"

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "api-gateway"})

@app.route('/api/products', methods=['GET'])
def get_products():
    try:
        response = requests.get(f"{PRODUCT_SERVICE}/products")
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 503

@app.route('/api/products/<id>', methods=['GET'])
def get_product(id):
    try:
        response = requests.get(f"{PRODUCT_SERVICE}/products/{id}")
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 503

@app.route('/api/orders', methods=['POST'])
def create_order():
    try:
        response = requests.post(
            f"{ORDER_SERVICE}/orders",
            json=request.json
        )
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000)
```
```
Copy file to accessible location

sudo ip netns exec api-gateway bash -c 'cat <<EOF > /tmp/api-gateway.py
EOF'

# Install dependencies in namespace or use a Python virtual environment
sudo ip netns exec api-gateway pip install flask requests

# Start api-gateway
sudo ip netns exec api-gateway python3 /tmp/api-gateway.py &
```
**Flask running inside the api-gateway namespace on port 3000:**

RUN: `sudo ip netns exec api-gateway ss -lntp | grep 3000`

![flask running](./images/flask%20running.png)

**Testing the Api health  from inside the namespace:**

RUN: `sudo ip netns exec api-gateway curl http://127:3000/health`

![test-api-health](./images/testing%20api%20health.png)

**Test from other namespaces (e.g., nginx-lb)**

RUN: `sudo ip netns exec nginx-lb curl http://10.0.0.20:3000/health`

![test-api-health-nginx-lb](./images/test%20from%20other%20namespace.png)


### Deliverable: API Gateway responding to requests and routing correctly

- **Test API Gateway Routing to product-service from api-gateway namespace:** 

  RUN: `sudo ip netns exec api-gateway curl http://localhost:3000/api/products`

  ![api-gateway-routing2prod](./images/api%20route%20to%20prod%20from%20api.png)

- **Then test API Gateway Routing to product service via my host port-forwarding to confirm everything works end-to-end:** 

  RUN: `curl http://192.168.56.104:8080/api/products`

  ![api-gateway-routing2prod-host](./images/api%20route%20to%20prod%20from%20host.png)    

- **Test API Gateway Routing to order-service from api-gateway namespace:** 

  RUN: `sudo ip netns exec api-gateway curl http://localhost:3000/api/orders`

  ![api-gateway-routing2order](./images/api%20route%20to%20order%20from%20api.png)

- **Then test API Gateway Routing to order service via my host port-forwarding to confirm everything works end-to-end:** 

  RUN: `curl http://192.168.56.104:8080/api/orders`

  ![api-gateway-routing2order-host](./images/api%20route%20to%20order%20from%20host.png)  

### Task 2.3: Build Product Service

**Create product-service.py:**
```
from flask import Flask, jsonify
import redis
import json

app = Flask(__name__)

# Connect to Redis cache
try:
    cache = redis.Redis(host='10.0.0.50', port=6379, decode_responses=True)
except:
    cache = None

# Mock product database
PRODUCTS = {
    "1": {"id": "1", "name": "Laptop", "price": 999.99, "stock": 50},
    "2": {"id": "2", "name": "Mouse", "price": 29.99, "stock": 200},
    "3": {"id": "3", "name": "Keyboard", "price": 79.99, "stock": 150},
}

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "product-service"})

@app.route('/products', methods=['GET'])
def get_products():
    # Try cache first
    if cache:
        cached = cache.get('all_products')
        if cached:
            return jsonify(json.loads(cached))
    
    # Return products and cache
    products = list(PRODUCTS.values())
    if cache:
        cache.setex('all_products', 300, json.dumps(products))
    
    return jsonify(products)

@app.route('/products/<product_id>', methods=['GET'])
def get_product(product_id):
    # Try cache first
    if cache:
        cached = cache.get(f'product_{product_id}')
        if cached:
            return jsonify(json.loads(cached))
    
    product = PRODUCTS.get(product_id)
    if not product:
        return jsonify({"error": "Product not found"}), 404
    
    if cache:
        cache.setex(f'product_{product_id}', 300, json.dumps(product))
    
    return jsonify(product)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```
**Start product-service:** `sudo ip netns exec product-service python3 /tmp/product-service.py &'`   

**Verify product-service is running:**`sudo ip netns exec product-service ss -lntp | grep 5000`

### Deliverable: Working product service with Redis caching

**Redis running inside its namespace and listening on port 6379:**

RUN: `sudo ip netns exec redis-cache ss -lntp | grep 6379`

![redis running](./images/redis%20cache%20running.png)

**Product-service successfully connect to redis cache:**

RUN: `sudo ip netns exec product-service nc -zv 10.0.0.50 6379`

![prod connect to redis](./images/prod%20connect%20to%20redis.png)

**API Gateway Routing to product-service from api-gateway namespace:** 

RUN: `sudo ip netns exec api-gateway curl http://localhost:3000/api/products`

![api-gateway-routing2prod](./images/api%20route%20to%20prod%20from%20api.png)  

### Task 2.4: Build Order Service

**Create order-service.py:**
```
from flask import Flask, jsonify, request
import psycopg2
from datetime import datetime
import json

app = Flask(__name__)

# Database connection
def get_db():
    return psycopg2.connect(
        host='10.0.0.60',
        database='orders',
        user='postgres',
        password='postgres'
    )

# Initialize database
def init_db():
    conn = get_db()
    cur = conn.cursor()
    cur.execute('''
        CREATE TABLE IF NOT EXISTS orders (
            id SERIAL PRIMARY KEY,
            customer_id VARCHAR(100),
            product_id VARCHAR(100),
            quantity INTEGER,
            total_price DECIMAL(10, 2),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    cur.close()
    conn.close()

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "order-service"})

@app.route('/orders', methods=['POST'])
def create_order():
    data = request.json
    
    conn = get_db()
    cur = conn.cursor()
    
    cur.execute(
        '''INSERT INTO orders (customer_id, product_id, quantity, total_price)
           VALUES (%s, %s, %s, %s) RETURNING id''',
        (data['customer_id'], data['product_id'], 
         data['quantity'], data['total_price'])
    )
    
    order_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    
    return jsonify({"order_id": order_id, "status": "created"}), 201

@app.route('/orders/<order_id>', methods=['GET'])
def get_order(order_id):
    conn = get_db()
    cur = conn.cursor()
    
    cur.execute('SELECT * FROM orders WHERE id = %s', (order_id,))
    order = cur.fetchone()
    
    cur.close()
    conn.close()
    
    if not order:
        return jsonify({"error": "Order not found"}), 404
    
    return jsonify({
        "id": order[0],
        "customer_id": order[1],
        "product_id": order[2],
        "quantity": order[3],
        "total_price": float(order[4]),
        "created_at": order[5].isoformat()
    })

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000)
```

**Start order-service:** `sudo ip netns exec order-service python3 /tmp/order-service.py &'`   

**Verify order-service is running and listening on port 5000:**`sudo ip netns exec order-service ss -lntp | grep 5000`

![order-service-listening](./images/order%20svc%20listening%20on%20port%205000.png)

### Deliverable: Working order service with PostgreSQL integration

**postgres running as a container:** RUN: `sudo docker ps`

![postgres running on docker](./images/postgres%20docker%20ps.png)

**PostgreSQL listening on port 5432:**RUN: `ss -lntp | grep 5432` 

![postgres running](./images/postgress%20running%20on%20port.png)

**Order-service reaching postgres:**

RUN: `sudo ip netns exec order-service nc -zv 10.0.0.1 5432`

![order-service reaching postgres](./images/order%20svc%20connect%20postgres.png)

**To confirm order-service can reach PostgreSQL and data is stored correctly:**

- Creating an order (WRITE to PostgreSQL) to confirm order successfully created via API Gateway (PostgreSQL write)

```
sudo ip netns exec api-gateway curl -X POST http://localhost:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust-101",
    "product_id": "prod-201",
    "quantity": 2,
    "total_price": 150.00
  }'
```
![write to postgres](./images/write%20to%20postgres.png)

- Verify order record exist and persisted in PostgreSQL database

RUN: `psql -U postgres -d orders -h 10.0.0.1 -c "SELECT * FROM orders;"`

![verify order record](./images/verify%20order%20in%20postgres.png)








Create a PostgreSQL container:
```
docker run -d --name postgres \
  -p 5432:5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=orders \
  postgres:15
```



