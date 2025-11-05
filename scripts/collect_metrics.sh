#!/bin/bash

# Metrics collection script
# Collects real-time metrics from running containers

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICES=("python" "php" "go" "cpp")
INTERVAL=${1:-5}  # Collection interval in seconds (default: 5)
DURATION=${2:-60}  # Total duration in seconds (default: 60)
OUTPUT_DIR="./results/metrics"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}Collecting metrics for $DURATION seconds (interval: ${INTERVAL}s)${NC}"
echo ""

# Detect container runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo "Error: Neither podman nor docker found"
    exit 1
fi

# Function to collect stats for a single service
collect_service_stats() {
    local service=$1
    local container_name="benchmark-${service}"
    local output_file="$OUTPUT_DIR/${service}_metrics_${TIMESTAMP}.csv"

    echo "timestamp,cpu_percent,memory_usage_mb,memory_limit_mb,memory_percent,net_io_rx_mb,net_io_tx_mb" > "$output_file"

    local elapsed=0
    while [ $elapsed -lt $DURATION ]; do
        local timestamp=$(date +%s)

        if [ "$RUNTIME" = "podman" ]; then
            local stats=$(podman stats --no-stream --format json "$container_name" 2>/dev/null)
        else
            local stats=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}" "$container_name" 2>/dev/null | tail -n 1)
        fi

        if [ ! -z "$stats" ]; then
            # Parse and append stats (this is simplified, actual parsing depends on runtime)
            echo "$timestamp,$stats" >> "$output_file"
        fi

        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
    done
}

# Collect stats for all services in parallel
echo -e "${YELLOW}Starting metric collection...${NC}"

for service in "${SERVICES[@]}"; do
    collect_service_stats "$service" &
done

# Wait for all background jobs to complete
wait

echo ""
echo -e "${GREEN}Metrics collection complete!${NC}"
echo -e "Results saved to: ${BLUE}$OUTPUT_DIR${NC}"
