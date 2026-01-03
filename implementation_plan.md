# Implementation Plan: Network Isolation

Required for Task 4.4: Implement Network Isolation.

## Goal
Create three separate network segments (Frontend, Backend, Database) and migrate services to them. Configure routing to allow traffic flow between tiers while maintaining isolation.

## Proposed Changes

### 1. Network Setup Script (`setup_network_isolation.sh`) [NEW]
- Create bridges: `br-frontend`, `br-backend`, `br-database`.
- Create namespaces:
  - `frontend-ns`: Hosting `api-gateway`.
  - `backend-ns`: Hosting `product-service` (and potentially `order-service` and `service-registry`).
  - `database-ns`: Hosting `redis` and `postgres` (simulated).
- Configure IPs:
  - Frontend: `172.20.0.0/24` (Gateway: `172.20.0.1`)
  - Backend: `172.21.0.0/24` (Gateway: `172.21.0.1`)
  - Database: `172.22.0.0/24` (Gateway: `172.22.0.1`)
- Enable IP forwarding and routing.

### 2. Service Allocation
- **Frontend Tier (`frontend-ns`)**:
  - `api-gateway`: Bind to `172.20.0.10`.
- **Backend Tier (`backend-ns`)**:
  - `service-registry`: Bind to `172.21.0.5`.
  - `product-service` (Instance 1): `172.21.0.10`.
  - `product-service` (Instance 2): `172.21.0.11`.
  - `order-service`: `172.21.0.20`.
- **Database Tier (`database-ns`)**:
  - `redis`: `172.22.0.10`.
  - `postgres`: `172.22.0.20`.

### 3. Update Existing Scripts
- **`start_isolated_services.sh` [NEW]**:
  - Script to start all services in their respective namespaces with the new IP configurations.
  - Will replace usages of `start_all_services.sh` for this task.

### 4. Code Changes
- No code changes needed in Python files if we use environment variables for IPs.
- We need to ensure `start_isolated_services.sh` sets `SERVICE_IP`, `REDIS_HOST`, etc., correctly.

## Verification Plan

### Automated Tests
- Run `setup_network_isolation.sh`.
- Run `start_isolated_services.sh`.
- Execute verifying curls from the host (acting as external client) to the `api-gateway` on `172.20.0.10`.
  - Note: Host needs route to `172.20.0.0/24` via `br-frontend`.
  ```bash
  curl http://172.20.0.10:3000/api/products
  ```

### Manual Verification
- Verify that `frontend-ns` can reach `backend-ns`.
- Verify that `backend-ns` can reach `database-ns`.
- Verify that direct access to Database from Frontend might be blocked (optional security policy, but "Isolation" usually implies separation).
