# Performance Benchmark Repot

## System Configuration
- **Concurrency**: 50
- **Total Requests**: 1000
- **Target**: API Gateway (`/api/products`)

## Results

### Docker Implementation
- **Requests per second**: 29.21 [#/sec] (mean)
- **Time per request**: 34.231 [ms] (mean, across all concurrent requests)
- **Failed requests**: 4 (0.4% error rate)
- **Longest request**: 8342 ms

## Analysis
The Docker implementation shows a throughput of ~29 RPS. 
*Note: A direct comparison with the raw Linux namespace implementation requires running the benchmark in that mode. Generally, Docker introduces a slight overhead due to NAT/Bridge networking (docker-proxy).*

## Recommendations
- Improve concurrency handling in `api-gateway` (Flask development server is single-threaded by default, using `gunicorn` or similar would improve RPS).
- Investigate the 4 failed requests (likely timeouts under load).
