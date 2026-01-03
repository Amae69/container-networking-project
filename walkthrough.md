# Network Isolation Walkthrough (Task 4.4)

## Architecture
The system is now split into 3 isolated network tiers:
1.  **Frontend Network** (`172.20.0.0/24`)
    *   Hosts: API Gateway (`172.20.0.10`)
2.  **Backend Network** (`172.21.0.0/24`)
    *   Hosts: Service Registry (`172.21.0.5`), Product Services (`172.21.0.10`, `172.21.0.11`), Order Service (`172.21.0.20`)
3.  **Database Network** (`172.22.0.0/24`)
    *   Hosts: Redis (`172.22.0.10`), Postgres (`172.22.0.20`)

## 1. Setup Network Isolation
Run the following script to create the bridges, namespaces, and routing:
```bash
bash setup_network_isolation.sh
```

## 2. Start Services
Services must be started in their respective namespaces with the correct environment variables. Use the provided helper script:
```bash
bash start_isolated_services.sh
```
This script handles starting:
- Redis (mocked/real) in `database-ns`
- Registry, Product, and Order services in `backend-ns`
- API Gateway in `frontend-ns`

## 3. Verification
From the host (which acts as an external client), you can access the API Gateway on its isolated IP:

```bash
curl http://172.20.0.10:3000/api/products
```

To verify load balancing across the isolated backend instances:
```bash
for i in {1..5}; do curl http://172.20.0.10:3000/api/products; echo; done
```

You should see traffic distributed between `product-1` (172.21.0.10) and `product-2` (172.21.0.11).

## 4. Debugging
If you encounter issues, you can check logs for specific services (e.g. `gateway.log`, `product1.log`).
To inspect a specific namespace:
```bash
sudo ip netns exec frontend-ns ip addr
sudo ip netns exec backend-ns ping 172.22.0.10  # Check backend -> db connectivity
```
