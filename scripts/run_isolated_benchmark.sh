#!/bin/bash

# Isolated benchmark script
# Runs ONE service at a time to eliminate resource contention

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVICES=("cpp" "go" "php" "python")
SERVICE_NAMES=("C++" "Go" "PHP" "Python")
SERVICE_PORTS=(6003 6002 6001 6000)
CONTAINER_NAMES=("benchmark-cpp" "benchmark-go" "benchmark-php" "benchmark-python")
IMAGE_NAMES=("benchmark-cpp" "benchmark-go" "benchmark-php" "benchmark-python")

RESULTS_DIR="./results"
METRICS_DIR="$RESULTS_DIR/metrics"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Test configuration
METRICS_DURATION=100  # Collect metrics for 100 seconds to cover quick k6 test
METRICS_INTERVAL=1    # Sample every 1 second
COOLDOWN=10           # Wait between services

mkdir -p "$RESULTS_DIR/raw"
mkdir -p "$METRICS_DIR"
mkdir -p "./visualizations"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ISOLATED Benchmark Suite${NC}"
echo -e "${BLUE}Sequential Execution - Zero Contention${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Metrics Duration: ${METRICS_DURATION}s per service"
echo -e "  Sample Interval: ${METRICS_INTERVAL}s"
echo -e "  Cooldown: ${COOLDOWN}s between services"
echo ""

# Detect container runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo -e "${RED}Error: Neither podman nor docker found${NC}"
    exit 1
fi

echo -e "${GREEN}Using runtime: ${RUNTIME}${NC}"

# Check for k6
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}Error: k6 is not installed${NC}"
    echo -e "${YELLOW}Install k6:${NC}"
    echo -e "  macOS: brew install k6"
    echo -e "  Linux: https://k6.io/docs/getting-started/installation/"
    exit 1
fi

echo ""

# Function to ensure clean state
cleanup_all() {
    echo -e "${YELLOW}Cleaning up any running containers...${NC}"
    for container in "${CONTAINER_NAMES[@]}"; do
        $RUNTIME stop "$container" > /dev/null 2>&1 || true
        $RUNTIME rm "$container" > /dev/null 2>&1 || true
    done
    echo -e "${GREEN}✓ Clean state achieved${NC}"
}

# Function to wait for service health
wait_for_health() {
    local port=$1
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -sf "http://localhost:$port/health" > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

# Function to collect metrics for a running service
collect_service_metrics() {
    local service=$1
    local container_name=$2
    local duration=$3
    local output_file="$METRICS_DIR/${service}_isolated_${TIMESTAMP}.csv"

    echo -e "${BLUE}  Collecting OS-level metrics for ${duration}s...${NC}"

    # CSV header
    echo "timestamp,elapsed_sec,cpu_percent,mem_usage_mb,mem_limit_mb,mem_percent,pids" > "$output_file"

    local start_time=$(date +%s)
    local elapsed=0

    while [ $elapsed -lt $duration ]; do
        local timestamp=$(date +%s)
        elapsed=$((timestamp - start_time))

        # Get stats from container runtime
        local stats=$($RUNTIME stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.PIDs}}" "$container_name" 2>/dev/null || echo "")

        if [ -n "$stats" ]; then
            IFS=',' read -r cpu_raw mem_raw mem_pct_raw pids_raw <<< "$stats"

            # Clean CPU (remove %)
            cpu=$(echo "$cpu_raw" | tr -d '%' | tr -d ' ')

            # Parse memory usage (e.g., "123.4MiB / 512MiB")
            if [[ $mem_raw =~ ([0-9.]+)([A-Za-z]+)[[:space:]]*/[[:space:]]*([0-9.]+)([A-Za-z]+) ]]; then
                mem_value="${BASH_REMATCH[1]}"
                mem_unit="${BASH_REMATCH[2]}"
                limit_value="${BASH_REMATCH[3]}"
                limit_unit="${BASH_REMATCH[4]}"

                # Convert to MB
                case $mem_unit in
                    KiB|KB) mem_usage=$(echo "scale=2; $mem_value / 1024" | bc) ;;
                    MiB|MB) mem_usage=$mem_value ;;
                    GiB|GB) mem_usage=$(echo "scale=2; $mem_value * 1024" | bc) ;;
                    *) mem_usage=$mem_value ;;
                esac

                case $limit_unit in
                    KiB|KB) mem_limit=$(echo "scale=2; $limit_value / 1024" | bc) ;;
                    MiB|MB) mem_limit=$limit_value ;;
                    GiB|GB) mem_limit=$(echo "scale=2; $limit_value * 1024" | bc) ;;
                    *) mem_limit=$limit_value ;;
                esac
            else
                mem_usage="0"
                mem_limit="0"
            fi

            # Clean mem percent
            mem_pct=$(echo "$mem_pct_raw" | tr -d '%' | tr -d ' ')

            # Write to CSV
            echo "$timestamp,$elapsed,$cpu,$mem_usage,$mem_limit,$mem_pct,$pids_raw" >> "$output_file"
        fi

        sleep $METRICS_INTERVAL
    done

    local samples=$(tail -n +2 "$output_file" | wc -l | tr -d ' ')
    echo -e "${GREEN}  ✓ Collected $samples metric samples${NC}"
}

# Main execution
echo -e "${YELLOW}Step 1: Initial cleanup${NC}"
cleanup_all
echo ""

# Run each service in complete isolation
for i in "${!SERVICES[@]}"; do
    service="${SERVICES[$i]}"
    service_name="${SERVICE_NAMES[$i]}"
    port="${SERVICE_PORTS[$i]}"
    container_name="${CONTAINER_NAMES[$i]}"
    image_name="${IMAGE_NAMES[$i]}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing: $service_name (ISOLATED)${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Start this service ONLY
    echo -e "${YELLOW}Starting $service_name container...${NC}"
    $RUNTIME run -d \
        --name "$container_name" \
        -p "$port:$port" \
        --cpus=2.0 \
        --memory=512m \
        "$image_name"

    echo -e "${YELLOW}Waiting for service health...${NC}"
    if ! wait_for_health "$port"; then
        echo -e "${RED}✗ $service_name failed to become healthy${NC}"
        $RUNTIME logs "$container_name"
        cleanup_all
        exit 1
    fi
    echo -e "${GREEN}✓ $service_name is healthy${NC}"

    # Warmup
    echo -e "${YELLOW}Warmup phase (10 requests)...${NC}"
    for j in {1..10}; do
        curl -s "http://localhost:$port/" > /dev/null || true
    done
    sleep 2

    # Collect baseline metrics (idle)
    echo -e "${BLUE}Collecting idle baseline metrics (30s)...${NC}"
    collect_service_metrics "$service" "$container_name" 30

    # Run k6 tests while collecting metrics
    echo -e "${BLUE}Running load tests with metrics collection...${NC}"

    # Start metrics collection in background
    (collect_service_metrics "${service}_load" "$container_name" "$METRICS_DURATION") &
    metrics_pid=$!

    # Run k6 test (quick profile)
    echo -e "${YELLOW}  Quick Load Test${NC}"
    SERVICE=$service k6 run --out json="$RESULTS_DIR/raw/${service}_quick_${TIMESTAMP}.json" --quiet loadtest/k6/quick_test.js > "$RESULTS_DIR/raw/${service}_quick_${TIMESTAMP}.log" 2>&1

    # Wait for metrics collection to complete
    wait $metrics_pid

    echo -e "${GREEN}✓ $service_name testing complete${NC}"

    # Stop and remove this service
    echo -e "${YELLOW}Stopping $service_name...${NC}"
    $RUNTIME stop "$container_name" > /dev/null 2>&1 || true
    $RUNTIME rm "$container_name" > /dev/null 2>&1 || true

    # Cooldown between services
    if [ $i -lt $((${#SERVICES[@]} - 1)) ]; then
        echo -e "${YELLOW}Cooldown period (${COOLDOWN}s)...${NC}"
        sleep $COOLDOWN
    fi

    echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Isolated Tests Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Results saved to:${NC}"
echo -e "  Metrics: ${METRICS_DIR}"
echo -e "  Logs: ${RESULTS_DIR}/raw"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  make visualize    # Generate charts from metrics"
echo ""
