# Implementation Plan: Docker Optimization

Required for Task 5.4: Optimize Docker Setup.

## Goal
Optimize the existing Docker configuration by reducing image size, implementing health checks, and adding resource limits.

## Proposed Changes

### 1. Optimize Dockerfiles (Multi-Stage Builds)
Update `Dockerfile` for all Python services to use multi-stage builds.
- **Builder Stage**: Install build dependencies (if any) and pip packages.
- **Runtime Stage**: Copy installed packages and application code.
- **Base Image**: Stick to `python:3.11-slim` for balance of size and compatibility.

Example pattern:
```dockerfile
# Builder stage
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime stage
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
# Add HEALTHCHECK instruction
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:<port>/health || exit 1
CMD ["python", "app.py"]
```
*Note: `curl` might need to be installed in slim image if not present, or we write a python healthcheck script to avoid extra deps.*
*Actually, `python:slim` often lacks `curl`. Installing it adds weight. Better to use a simple python one-liner for healthcheck:*
`CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:<port>/health')"`

### 2. Update `docker-compose.yml`
- **Resource Limits**: Add `deploy.resources.limits` (e.g., cpus: '0.5', memory: '128M').
- **Health Checks**: Can be defined here or rely on Dockerfile. Defining in Compose allows orchestrator visibility easily (depends_on condition: service_healthy).

Example addition to services:
```yaml
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: '128M'
    healthcheck:
      test: ["CMD", "python", "-c", "import requests; requests.get('http://localhost:5000/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Verification Plan
1.  Rebuild images: `docker-compose build`.
2.  Check image sizes: `docker images` (compare with previous).
3.  Run stack: `docker-compose up -d`.
4.  Verify health status: `docker ps` (should show "healthy").
5.  Verify resource limits: `docker stats`.
