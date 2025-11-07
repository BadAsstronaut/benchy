#!/bin/bash

# Benchmark orchestration script
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

# Use RUN_ID from environment or generate one
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$RESULTS_DIR"
echo "$RUN_ID" > "$RESULTS_DIR/run_id.txt"

# Test configuration - accepts test type as argument
# Usage: ./run_benchmarks.sh [test_type]
#   test_type: quick, level1_hello, level2_normal, level3_cpu, level4_strings, all
TEST_TYPE="${1:-quick}"

if [ "$TEST_TYPE" = "all" ]; then
    # Run all level tests
    TESTS=("level1_hello" "level2_normal" "level3_cpu" "level4_strings")
else
    TESTS=("$TEST_TYPE")
fi

# Determine K6 script and metrics duration based on test type
get_test_config() {
    local test=$1
    case "$test" in
        quick)
            echo "loadtest/k6/quick_test.js:100"
            ;;
        level1_hello)
            echo "loadtest/k6/level1_hello.js:300"
            ;;
        level2_normal)
            echo "loadtest/k6/level2_normal.js:600"
            ;;
        level3_cpu)
            echo "loadtest/k6/level3_cpu.js:600"
            ;;
        level4_strings)
            echo "loadtest/k6/level4_strings.js:600"
            ;;
        *)
            echo "ERROR:0"
            ;;
    esac
}

METRICS_INTERVAL=1    # Sample every 1 second
COOLDOWN=10           # Wait between services

mkdir -p "$RESULTS_DIR/raw"
mkdir -p "$METRICS_DIR"
mkdir -p "./visualizations"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Benchmark Suite - Isolated Execution${NC}"
echo -e "${BLUE}One service at a time - Zero contention${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Run ID: ${RUN_ID}"
echo -e "  Tests: ${TESTS[*]}"
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
    local phase=$4  # "idle" or "load"
    local output_file="$METRICS_DIR/${service}_${phase}_${RUN_ID}.csv"

    echo -e "${BLUE}  Collecting OS-level metrics for ${duration}s...${NC}"

    # CSV header
    echo "timestamp,elapsed_sec,cpu_percent,mem_usage_mb,mem_limit_mb,mem_percent,pids,mem_anon_mb,mem_file_mb" > "$output_file"

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
                    KiB|KB|kB) mem_usage=$(echo "scale=2; $mem_value / 1024" | bc) ;;
                    MiB|MB|mB) mem_usage=$mem_value ;;
                    GiB|GB|gB) mem_usage=$(echo "scale=2; $mem_value * 1024" | bc) ;;
                    *) mem_usage=$mem_value ;;
                esac

                case $limit_unit in
                    KiB|KB|kB) mem_limit=$(echo "scale=2; $limit_value / 1024" | bc) ;;
                    MiB|MB|mB) mem_limit=$limit_value ;;
                    GiB|GB|gB) mem_limit=$(echo "scale=2; $limit_value * 1024" | bc) ;;
                    *) mem_limit=$limit_value ;;
                esac
            else
                mem_usage="0"
                mem_limit="0"
            fi

            # Clean mem percent
            mem_pct=$(echo "$mem_pct_raw" | tr -d '%' | tr -d ' ')

            # Get detailed memory breakdown from cgroup v2 if available
            mem_anon="0"
            mem_file="0"

            # Try to get container ID for cgroup access
            container_id=$($RUNTIME inspect "$container_name" -f '{{.Id}}' 2>/dev/null || echo "")
            if [ -n "$container_id" ]; then
                # Check for cgroup v2 path
                cgroup_path="/sys/fs/cgroup/system.slice/libpod-${container_id}.scope"
                if [ -f "$cgroup_path/memory.stat" ]; then
                    # Extract anon and file memory (in bytes)
                    anon_bytes=$(grep "^anon " "$cgroup_path/memory.stat" 2>/dev/null | awk '{print $2}' || echo "0")
                    file_bytes=$(grep "^file " "$cgroup_path/memory.stat" 2>/dev/null | awk '{print $2}' || echo "0")

                    # Convert to MB
                    if [ "$anon_bytes" != "0" ]; then
                        mem_anon=$(echo "scale=2; $anon_bytes / 1024 / 1024" | bc)
                    fi
                    if [ "$file_bytes" != "0" ]; then
                        mem_file=$(echo "scale=2; $file_bytes / 1024 / 1024" | bc)
                    fi
                fi
            fi

            # Write to CSV
            echo "$timestamp,$elapsed,$cpu,$mem_usage,$mem_limit,$mem_pct,$pids_raw,$mem_anon,$mem_file" >> "$output_file"
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

# Run each test type
for test in "${TESTS[@]}"; do
    # Get test configuration
    config=$(get_test_config "$test")
    if [[ "$config" == ERROR:* ]]; then
        echo -e "${RED}Unknown test type: $test${NC}"
        continue
    fi

    K6_SCRIPT="${config%:*}"
    METRICS_DURATION="${config#*:}"

    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Test: $test${NC}"
    echo -e "${YELLOW}Script: $K6_SCRIPT${NC}"
    echo -e "${YELLOW}Duration: ${METRICS_DURATION}s${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""

    # Run each service in complete isolation for this test
    for i in "${!SERVICES[@]}"; do
        service="${SERVICES[$i]}"
        service_name="${SERVICE_NAMES[$i]}"
        port="${SERVICE_PORTS[$i]}"
        container_name="${CONTAINER_NAMES[$i]}"
        image_name="${IMAGE_NAMES[$i]}"

        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}Testing: $service_name${NC}"
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
            echo -e "${YELLOW}Capturing logs and continuing...${NC}"
            $RUNTIME logs "$container_name" > "$RESULTS_DIR/raw/${service}_${test}_${RUN_ID}_startup_failure.log" 2>&1 || true
            $RUNTIME stop "$container_name" > /dev/null 2>&1 || true
            $RUNTIME rm "$container_name" > /dev/null 2>&1 || true
            echo -e "${YELLOW}Skipping to next service${NC}"
            continue
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
        collect_service_metrics "${service}_${test}" "$container_name" 30 "idle"

        # Run k6 tests while collecting metrics
        echo -e "${BLUE}Running load test with metrics collection...${NC}"

        # Start metrics collection in background
        (collect_service_metrics "${service}_${test}" "$container_name" "$METRICS_DURATION" "load") &
        metrics_pid=$!

        # Run k6 test (capture all failures, including OOM-related crashes)
        echo -e "${YELLOW}  Test: $test${NC}"
        SERVICE=$service k6 run --out json="$RESULTS_DIR/raw/${service}_${test}_${RUN_ID}.json" --quiet "$K6_SCRIPT" > "$RESULTS_DIR/raw/${service}_${test}_${RUN_ID}.log" 2>&1 || {
            exit_code=$?
            if [ $exit_code -eq 99 ]; then
                echo -e "${YELLOW}  ⚠ Thresholds failed (expected under heavy load)${NC}"
            else
                echo -e "${RED}  ✗ K6 failed with exit code $exit_code (possible OOM or crash)${NC}"
                echo -e "${YELLOW}  Capturing container logs and continuing...${NC}"
                $RUNTIME logs "$container_name" > "$RESULTS_DIR/raw/${service}_${test}_${RUN_ID}_crash.log" 2>&1 || true
            fi
        }

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
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Tests Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Results saved to:${NC}"
echo -e "  Run ID: ${RUN_ID}"
echo -e "  Metrics: ${METRICS_DIR}"
echo -e "  Logs: ${RESULTS_DIR}/raw"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  make results    # Analyze and visualize"
echo ""
