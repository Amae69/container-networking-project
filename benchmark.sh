#!/bin/bash
# benchmark.sh
# Usage: 
#   ./benchmark.sh linux   (Run while start_isolated_services.sh is active)
#   ./benchmark.sh docker  (Run while docker-compose up is active)

# Configuration from our setup
URL_LINUX="http://172.20.0.10:3000/api/products"
URL_DOCKER="http://127.0.0.1:3000/api/products"

# Requests to send
REQUESTS=1000
CONCURRENCY=50

echo "=== Performance Benchmark ==="

# Check for Apache Benchmark
if ! command -v ab &> /dev/null; then
    echo "Error: 'ab' command not found."
    echo "Please install it: sudo apt-get install -y apache2-utils"
    exit 1
fi

MODE=$1

if [ "$MODE" == "linux" ]; then
    echo "Benchmarking Linux Namespace Implementation..."
    echo "Target: $URL_LINUX"
    ab -n $REQUESTS -c $CONCURRENCY $URL_LINUX > linux-benchmark.txt
    echo "Saved to linux-benchmark.txt"
    grep "Requests per second" linux-benchmark.txt

elif [ "$MODE" == "docker" ]; then
    echo "Benchmarking Docker Implementation..."
    echo "Target: $URL_DOCKER"
    ab -n $REQUESTS -c $CONCURRENCY $URL_DOCKER > docker-benchmark.txt
    echo "Saved to docker-benchmark.txt"
    grep "Requests per second" docker-benchmark.txt

else
    echo "Usage: ./benchmark.sh [linux|docker]"
    echo ""
    echo "Steps to compare:"
    echo "1. Start Linux setup (bash start_isolated_services.sh)"
    echo "2. Run: ./benchmark.sh linux"
    echo "3. Stop Linux setup (pkill -f python3; pkill redis; ...)"
    echo "4. Start Docker setup (docker-compose up -d)"
    echo "5. Run: ./benchmark.sh docker"
    echo "6. Compare results"
fi
