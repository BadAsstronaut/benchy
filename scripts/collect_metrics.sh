#!/bin/bash

# Metrics collection script
# Collects real-time OS-level metrics from running containers via podman/docker stats

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SERVICES=("python" "php" "go" "cpp")
INTERVAL=${1:-1}  # Collection interval in seconds (default: 1)
DURATION=${2:-60}  # Total duration in seconds (default: 60)
OUTPUT_DIR="./results/metrics"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Container Resource Monitoring${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Duration: ${YELLOW}${DURATION}s${NC}"
echo -e "Interval: ${YELLOW}${INTERVAL}s${NC}"
echo -e "Output: ${BLUE}${OUTPUT_DIR}${NC}"
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
echo ""

# Function to parse memory string (e.g., "123.4MiB" -> megabytes)
parse_memory() {
    local mem=$1
    if [[ $mem =~ ([0-9.]+)([A-Za-z]+) ]]; then
        local value="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"

        case $unit in
            KiB|KB|kB|kb) echo "scale=2; $value / 1024" | bc ;;
            MiB|MB|mB|mb) echo "$value" ;;
            GiB|GB|gB|gb) echo "scale=2; $value * 1024" | bc ;;
            B|b) echo "scale=2; $value / 1024 / 1024" | bc ;;
            *) echo "$value" ;;
        esac
    else
        echo "0"
    fi
}

# Function to collect stats for a single service
collect_service_stats() {
    local service=$1
    local container_name="benchmark-${service}"
    local output_file="$OUTPUT_DIR/${service}_metrics_${TIMESTAMP}.csv"

    # Check if container is running
    if ! $RUNTIME ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}Warning: Container ${container_name} not running, skipping${NC}"
        return
    fi

    echo -e "${GREEN}✓ Monitoring ${service}${NC}"

    # CSV header
    echo "timestamp,elapsed_sec,cpu_percent,mem_usage_mb,mem_limit_mb,mem_percent,net_rx_mb,net_tx_mb,block_read_mb,block_write_mb,pids" > "$output_file"

    local start_time=$(date +%s)
    local elapsed=0

    while [ $elapsed -lt $DURATION ]; do
        local timestamp=$(date +%s)
        elapsed=$((timestamp - start_time))

        if [ "$RUNTIME" = "podman" ]; then
            # Podman stats output
            local stats=$($RUNTIME stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}" "$container_name" 2>/dev/null || echo "")
        else
            # Docker stats output
            local stats=$($RUNTIME stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}" "$container_name" 2>/dev/null || echo "")
        fi

        if [ -n "$stats" ]; then
            # Parse stats: "5.23%,123.4MiB / 512MiB,24.09%,1.2kB / 3.4kB,0B / 0B,12"
            IFS=',' read -r cpu_raw mem_raw mem_pct_raw netio_raw blockio_raw pids_raw <<< "$stats"

            # Clean CPU (remove %)
            cpu=$(echo "$cpu_raw" | tr -d '%')

            # Parse memory usage (e.g., "123.4MiB / 512MiB")
            if [[ $mem_raw =~ ([^/]+)/(.+) ]]; then
                mem_usage=$(parse_memory "${BASH_REMATCH[1]}")
                mem_limit=$(parse_memory "${BASH_REMATCH[2]}")
            else
                mem_usage="0"
                mem_limit="0"
            fi

            # Clean mem percent
            mem_pct=$(echo "$mem_pct_raw" | tr -d '%')

            # Parse network I/O (e.g., "1.2kB / 3.4kB")
            if [[ $netio_raw =~ ([^/]+)/(.+) ]]; then
                net_rx=$(parse_memory "${BASH_REMATCH[1]}")
                net_tx=$(parse_memory "${BASH_REMATCH[2]}")
            else
                net_rx="0"
                net_tx="0"
            fi

            # Parse block I/O (e.g., "0B / 0B")
            if [[ $blockio_raw =~ ([^/]+)/(.+) ]]; then
                block_read=$(parse_memory "${BASH_REMATCH[1]}")
                block_write=$(parse_memory "${BASH_REMATCH[2]}")
            else
                block_read="0"
                block_write="0"
            fi

            # Write to CSV
            echo "$timestamp,$elapsed,$cpu,$mem_usage,$mem_limit,$mem_pct,$net_rx,$net_tx,$block_read,$block_write,$pids_raw" >> "$output_file"
        fi

        sleep $INTERVAL
    done

    echo -e "${GREEN}✓ ${service} monitoring complete ($(wc -l < "$output_file") samples)${NC}"
}

# Collect stats for all services in parallel
echo -e "${YELLOW}Starting metric collection...${NC}"
echo ""

for service in "${SERVICES[@]}"; do
    collect_service_stats "$service" &
done

# Wait for all background jobs to complete
wait

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Metrics Collection Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "Results saved to: ${BLUE}$OUTPUT_DIR${NC}"
echo ""

# Show summary
for service in "${SERVICES[@]}"; do
    csv_file="$OUTPUT_DIR/${service}_metrics_${TIMESTAMP}.csv"
    if [ -f "$csv_file" ]; then
        samples=$(tail -n +2 "$csv_file" | wc -l)
        echo -e "  ${service}: ${samples} samples"
    fi
done
