# Docker Migration Walkthrough (Day 5)

## 1. Containerization
We have created Dockerfiles for all services:
- `services/api-gateway/Dockerfile`
- `services/product-service/Dockerfile`
- `services/order-service/Dockerfile`
- `services/service-registry/Dockerfile`

Dependencies are handled via `requirements.txt` in each service directory.

## 3. Optimizations (Task 5.4)
We have optimized the Docker setup with:
- **Multi-stage builds**: Reduced image sizes by separating build and runtime environments.
- **Health Checks**: Containers now monitor their own service status (`docker ps` will show `healthy`).
- **Resource Limits**: CPU and Memory limits are enforced via Docker Compose to prevent resource exhaustion.
- **Ordered Startup**: API Gateway now waits for the Service Registry to be **Healthy** before starting.

**Commands to verify optimizations:**
```bash
# Verify health status
docker ps

# Verify resource limits
docker stats --no-stream
```
