#!/bin/bash

# Benchmark orchestration script
# Runs all benchmarks across all services and collects metrics

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICES=("python" "php" "go" "cpp")
SERVICE_NAMES=("python-fastapi" "php" "golang-gin" "cpp-crow")
SERVICE_PORTS=(6000 6001 6002 6003)
LEVELS=("level1_hello" "level2_normal" "level3_cpu" "level4_strings")
RESULTS_DIR="./results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Language Performance Benchmark Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR/raw"
mkdir -p "$RESULTS_DIR/metrics"
mkdir -p "./visualizations"

# Check if podman-compose or docker-compose is available
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}Error: Neither podman-compose nor docker-compose found${NC}"
    exit 1
fi

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}Error: k6 is not installed${NC}"
    echo "Install k6: https://k6.io/docs/getting-started/installation/"
    exit 1
fi

# Function to wait for service health
wait_for_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    echo -e "${YELLOW}Waiting for $service_name to be healthy...${NC}"

    while [ $attempt -le $max_attempts ]; do
        if curl -sf "http://localhost:$port/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $service_name is healthy${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo -e "${RED}✗ $service_name failed to become healthy${NC}"
    return 1
}

# Function to collect container stats
collect_container_stats() {
    local service_name=$1
    local level=$2
    local output_file="$RESULTS_DIR/metrics/${service_name}_${level}_${TIMESTAMP}_stats.json"

    if command -v podman &> /dev/null; then
        podman stats --no-stream --format json "benchmark-${service_name}" > "$output_file" 2>/dev/null || echo "{}" > "$output_file"
    elif command -v docker &> /dev/null; then
        docker stats --no-stream --format "{{json .}}" "benchmark-${service_name}" > "$output_file" 2>/dev/null || echo "{}" > "$output_file"
    fi
}

# Function to run k6 test
run_k6_test() {
    local service=$1
    local service_name=$2
    local level=$3
    local output_file="$RESULTS_DIR/raw/${service_name}_${level}_${TIMESTAMP}.json"

    echo -e "${BLUE}Running $level for $service_name...${NC}"

    # Run k6 test with JSON output
    k6 run \
        --out json="$output_file" \
        --env SERVICE="$service" \
        "./loadtest/k6/${level}.js" \
        > "$RESULTS_DIR/raw/${service_name}_${level}_${TIMESTAMP}.log" 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $level completed for $service_name${NC}"
    else
        echo -e "${RED}✗ $level failed for $service_name${NC}"
    fi

    # Collect container stats after test
    collect_container_stats "$service" "$level"
}

# Main execution
echo -e "${YELLOW}Step 1: Building containers...${NC}"
$COMPOSE_CMD build

echo ""
echo -e "${YELLOW}Step 2: Starting services...${NC}"
$COMPOSE_CMD up -d

echo ""
echo -e "${YELLOW}Step 3: Waiting for all services to be healthy...${NC}"

# Wait for all services
for i in "${!SERVICES[@]}"; do
    service_name="${SERVICES[$i]}"
    port="${SERVICE_PORTS[$i]}"

    if ! wait_for_service "$service_name" "$port"; then
        echo -e "${RED}Failed to start $service_name. Exiting.${NC}"
        $COMPOSE_CMD logs "$service_name"
        $COMPOSE_CMD down
        exit 1
    fi
done

echo ""
echo -e "${GREEN}All services are healthy!${NC}"
echo ""

# Warmup phase
echo -e "${YELLOW}Step 4: Warmup phase (30 seconds)...${NC}"
for i in "${!SERVICES[@]}"; do
    port="${SERVICE_PORTS[$i]}"
    echo "Warming up service on port $port..."
    for j in {1..10}; do
        curl -s "http://localhost:$port/" > /dev/null || true
    done
done
sleep 10

echo ""
echo -e "${YELLOW}Step 5: Running benchmarks...${NC}"
echo ""

# Run benchmarks for each service and level
for i in "${!SERVICES[@]}"; do
    service="${SERVICES[$i]}"
    service_name="${SERVICE_NAMES[$i]}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing: $service_name${NC}"
    echo -e "${BLUE}========================================${NC}"

    for level in "${LEVELS[@]}"; do
        run_k6_test "$service" "$service" "$level"

        # Cool down between tests
        echo "Cooling down for 30 seconds..."
        sleep 30
    done

    echo ""
done

echo ""
echo -e "${YELLOW}Step 6: Collecting final metrics...${NC}"

# Collect final container stats
for service in "${SERVICES[@]}"; do
    collect_container_stats "$service" "final"
done

echo ""
echo -e "${YELLOW}Step 7: Analyzing results...${NC}"

# Check if Python analysis script exists
if [ -f "./scripts/analyze_results.py" ]; then
    python3 ./scripts/analyze_results.py "$RESULTS_DIR"
else
    echo -e "${YELLOW}Analysis script not found, skipping...${NC}"
fi

echo ""
echo -e "${YELLOW}Step 8: Generating visualizations...${NC}"

# Check if visualization script exists
if [ -f "./scripts/visualize.py" ]; then
    python3 ./scripts/visualize.py "$RESULTS_DIR" "./visualizations"
else
    echo -e "${YELLOW}Visualization script not found, skipping...${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Benchmark Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Results saved to: ${BLUE}$RESULTS_DIR${NC}"
echo -e "Visualizations saved to: ${BLUE}./visualizations${NC}"
echo ""
echo -e "${YELLOW}To stop services:${NC} $COMPOSE_CMD down"
echo ""

# Ask if user wants to stop services
read -p "Stop services now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Stopping services...${NC}"
    $COMPOSE_CMD down
    echo -e "${GREEN}Services stopped${NC}"
fi
