# Docker Migration Walkthrough (Day 5)

## 1. Containerization
We have created Dockerfiles for all services:
- `services/api-gateway/Dockerfile`
- `services/product-service/Dockerfile`
- `services/order-service/Dockerfile`
- `services/service-registry/Dockerfile`

Dependencies are handled via `requirements.txt` in each service directory.

## 2. Running with Docker Compose
A `docker-compose.yml` file is provided to orchestrate the entire stack.

**To Start:**
```bash
docker-compose up --build -d
```

**To Verify:**
```bash
docker ps
curl http://localhost:3000/api/products
```

**To Stop:**
```bash
docker-compose down
```
