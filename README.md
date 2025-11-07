# Language Performance Benchmark Suite

Comprehensive benchmarking comparison of **Python (FastAPI)**, **PHP 8.5**, **Go (Fiber)**, and **C++ (Crow)** with focus on memory utilization, resource efficiency, and behavior under memory constraints.

## 📝 Synopsis

This benchmark suite provides **isolated, automated performance testing** of four popular web service implementations across multiple workload scenarios. Each service runs in its own container with strict resource limits (512MB RAM, 2 CPU cores) to simulate real-world constraints and identify memory efficiency differences.

Key differentiators:
- **One service at a time**: Eliminates resource contention for accurate measurements
- **OS-level metrics**: Direct cgroup monitoring for precise memory/CPU data
- **Memory pressure testing**: Intentionally stress services to identify OOM behavior
- **Automated pipeline**: From container build to visualization with zero manual intervention
- **Reproducible results**: All tests scripted with consistent methodology

## 🎯 Primary Goals

1. **Memory Utilization Analysis**: Measure and compare memory usage across languages under various workloads
2. **Performance Multipliers**: Quantify performance differences between languages
3. **CPU-Intensive vs Normal Work**: Compare behavior under different computational loads
4. **String Handling Efficiency**: Test memory requirements for string input processing
5. **Visualization**: Generate comprehensive charts and graphs of all metrics
6. **Automation**: Fully scripted benchmarking and analysis pipeline

## 📊 Test Levels

### Level 1: Hello World (Baseline)
- **Purpose**: Measure pure framework overhead and baseline resource usage
- **Endpoint**: `GET /`
- **Returns**: Simple "Hello, World!" response
- **Metrics**:
  - Requests per second
  - Memory footprint (idle and under load)
  - Latency (p50, p95, p99)
  - Container startup time

### Level 2: Normal Work
- **Purpose**: Test typical business logic processing
- **Endpoint**: `POST /process/normal`
- **Function**: JSON validation, data transformation, basic calculations
- **Example**: Parse user data, calculate age from birthdate, format response
- **Metrics**:
  - Throughput with JSON payloads (1KB, 10KB, 100KB)
  - Memory usage during processing
  - Garbage collection impact

### Level 3: CPU-Intensive Work
- **Purpose**: Stress test computational capabilities
- **Endpoint**: `POST /process/cpu-intensive`
- **Function**: Calculate Fibonacci(35), prime number generation, or complex math
- **Metrics**:
  - CPU utilization
  - Memory under computational load
  - Concurrent request handling
  - Response time degradation

### Level 4: String Input Memory Requirements (High Intensity)
- **Purpose**: Test string handling under memory pressure, identify OOM thresholds
- **Endpoint**: `POST /process/strings`
- **Input Sizes**: 10KB, 100KB, 1MB (10x normal load)
- **Operations**:
  - `reverse` - String reversal (2x memory: input + output)
  - `uppercase` - Case conversion (2x memory)
  - `count` - Character/word/line counting (2x + maps)
  - `pattern` - Word frequency analysis (2x + word array + frequency map)
  - `concatenate` - Repeat string up to 10x or 1MB (up to 10MB per request)
- **Load Profile**: 30 → 100 → 200 VUs over 7.5 minutes
- **Memory Behavior**:
  - C++/Go: Typically stay under 512MB limit
  - PHP: May approach limit (~86% utilization projected)
  - Python: **Expected to OOM** (~360% of limit projected)
- **Metrics**:
  - Memory allocation per string size
  - Peak memory usage and OOM incidents
  - Memory release behavior
  - Service crash recovery and continuation

## 🏗️ Project Structure

```
benchytest/
├── README.md
├── docker-compose.yml
├── results/                      # Benchmark results (JSON & CSV)
├── visualizations/              # Generated charts and graphs
├── scripts/
│   ├── run_benchmarks.sh       # Master orchestration script
│   ├── collect_metrics.sh      # Container metrics collection
│   ├── analyze_results.py      # Data analysis and aggregation
│   └── visualize.py            # Chart generation
├── loadtest/
│   └── k6/
│       ├── level1_hello.js
│       ├── level2_normal.js
│       ├── level3_cpu.js
│       └── level4_strings.js
├── python-fastapi/
│   ├── Containerfile
│   ├── requirements.txt
│   └── app.py
├── php/
│   ├── Containerfile
│   ├── composer.json
│   └── index.php
├── golang-gin/
│   ├── Containerfile
│   ├── go.mod
│   └── main.go
└── cpp-crow/
    ├── Containerfile
    ├── CMakeLists.txt
    └── main.cpp
```

## 🐳 Container Configuration

Each service runs in an isolated container with:
- **Port Range**: 6000-6010
  - Python FastAPI: 6000
  - PHP: 6001
  - Go Gin: 6002
  - C++ Crow: 6003
- **Resource Limits**:
  - Memory: 512MB (configurable for testing)
  - CPU: 2.0 cores
- **Runtime**: Podman/Docker compatible
- **Health Checks**: All services expose `/health` endpoint

## 🔧 Technology Stack

### Python (FastAPI)
- **Framework**: FastAPI 0.104+
- **Server**: Uvicorn with workers
- **Base Image**: python:3.11-slim
- **Key Features**: Async/await, Pydantic validation

### PHP 8.5
- **Server**: PHP-FPM + Nginx
- **Base Image**: php:8.5-fpm-alpine
- **Key Features**: JIT compiler, improved performance
- **Extensions**: opcache, json

### Go (Fiber)
- **Framework**: Fiber 2.x (Express-inspired)
- **Base Image**: Multi-stage (golang:1.21-alpine → alpine)
- **Key Features**: Goroutines, minimal runtime, fasthttp
- **Build**: Static binary compilation

### C++ (Crow)
- **Framework**: Crow (header-only, Flask-like)
- **Base Image**: Multi-stage (gcc:12 → alpine)
- **Key Features**: Zero-overhead abstractions, compiled
- **Build**: Optimized release build (-O3)

## 📈 Metrics Collection

### Performance Metrics
- **Throughput**: Requests per second (RPS)
- **Latency**: p50, p90, p95, p99, max (milliseconds)
- **Error Rate**: Failed requests percentage
- **Concurrent Connections**: Max sustainable connections

### Resource Metrics
- **Memory**:
  - RSS (Resident Set Size)
  - Peak memory usage
  - Memory growth over time
  - Idle vs loaded memory
- **CPU**:
  - Utilization percentage
  - CPU time per request
- **Container**:
  - Image size (MB)
  - Startup time (seconds)
  - Build time

### Efficiency Multipliers
- Memory efficiency: (Best Memory / Language Memory)
- Speed multiplier: (Language RPS / Slowest RPS)
- Cost efficiency: Resource usage → projected cloud costs

## 🧪 Load Testing Strategy

Using **k6** for load testing with progressive scenarios:

```javascript
export let options = {
  stages: [
    { duration: '30s', target: 50 },     // Warmup
    { duration: '2m', target: 50 },      // Baseline
    { duration: '30s', target: 200 },    // Ramp up
    { duration: '2m', target: 200 },     // Sustained load
    { duration: '30s', target: 500 },    // Spike test
    { duration: '1m', target: 500 },     // Peak load
    { duration: '30s', target: 0 },      // Cool down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
  },
};
```

### Test Scenarios
1. **Baseline**: Low load (50 RPS) - measure idle + light load
2. **Normal Load**: Medium load (200 RPS) - typical production
3. **Stress Test**: High load (500 RPS) - breaking point
4. **Soak Test**: Extended duration (10 min) - memory leak detection

## 🎨 Visualizations

Generated charts (using matplotlib/seaborn):

1. **Memory Comparison**
   - Bar chart: Idle memory per language
   - Line chart: Memory growth under load
   - Heatmap: Memory usage vs request size

2. **Performance Comparison**
   - Bar chart: Requests per second
   - Box plot: Latency distribution
   - Line chart: Response time vs concurrent users

3. **Efficiency Multipliers**
   - Radar chart: Multi-dimensional comparison
   - Normalized bar chart: Relative performance

4. **String Handling**
   - Line chart: Memory vs string size
   - Bar chart: Processing time vs string size

5. **CPU-Intensive Work**
   - Bar chart: Execution time comparison
   - Line chart: CPU utilization over time

## 💻 Current Test Environment

**Hardware:**
- Model: MacBook Pro (Mac16,1)
- Chip: Apple M4
- CPU: 10 cores (4 performance + 6 efficiency)
- Memory: 16 GB
- OS: macOS 15.6.1 (Sequoia)

**Software:**
- Container Runtime: Podman 5.5.0
- Load Testing: k6 (latest)
- Base Images: Alpine Linux (all services migrated for consistency)
- Python: 3.11 (Alpine)
- PHP: 8.3 with FPM + RoadRunner
- Go: 1.21+ (Fiber framework)
- C++: GCC with Crow framework

**Container Limits:**
- Memory: 512MB per container
- CPU: 2.0 cores per container
- Isolation: One service running at a time

## 🚀 Quick Start

### Prerequisites
```bash
# Install podman (or docker)
brew install podman podman-compose  # macOS
# or
sudo apt install podman podman-compose  # Linux

# Install k6 for load testing
brew install k6  # macOS
# or
sudo apt install k6  # Linux

# Install Python dependencies for analysis
pip install pandas matplotlib seaborn
```

### Complete Automated Benchmark
```bash
# Build all container images
make build

# Run all benchmark levels sequentially (recommended)
make benchmark-all

# Or run individual levels
make benchmark-level1   # Hello World baseline
make benchmark-level2   # Normal work
make benchmark-level3   # CPU-intensive
make benchmark-level4   # String processing (high memory)

# Analyze and visualize results
make results
```

### How Benchmarks Run

The benchmark script (`scripts/run_benchmarks.sh`) ensures **zero resource contention**:

1. **One service at a time**: Only one container runs during each test
2. **Clean state**: All containers stopped/removed between tests
3. **Warmup period**: 10 requests + 2 second settle before metrics
4. **Baseline collection**: 30 seconds of idle metrics captured first
5. **Load testing**: k6 runs while OS metrics collected every 1 second
6. **Cooldown**: 10 seconds between services
7. **Failure handling**: OOM crashes logged, benchmark continues

Each test produces:
- K6 JSON results: `results/raw/{service}_{test}_{run_id}.json`
- K6 text logs: `results/raw/{service}_{test}_{run_id}.log`
- Idle metrics CSV: `results/metrics/{service}_{test}_idle_{run_id}.csv`
- Load metrics CSV: `results/metrics/{service}_{test}_load_{run_id}.csv`
- Crash logs (if OOM): `results/raw/{service}_{test}_{run_id}_crash.log`

### Make Commands Reference

```bash
# Container Management
make build              # Build all containers
make up                 # Start all services (for manual testing)
make down               # Stop all services
make clean-containers   # Remove all containers

# Benchmarking (Automated - Recommended)
make benchmark-all      # Run all 4 levels sequentially
make benchmark-level1   # Hello World only
make benchmark-level2   # Normal work only
make benchmark-level3   # CPU-intensive only
make benchmark-level4   # String processing only

# Verification (Quick manual tests)
make verify-python      # Quick smoke test Python
make verify-go          # Quick smoke test Go
make verify-php         # Quick smoke test PHP
make verify-cpp         # Quick smoke test C++

# Analysis & Visualization
make results            # Analyze + visualize all results
make clean              # Remove results/visualizations

# Development
make help               # Show all available commands
```

## 📊 Expected Outcomes

### Hypothesis
- **C++**: Lowest memory, highest throughput, most complex development
- **Go**: Low memory, high throughput, good balance
- **Python**: Higher memory, moderate throughput, fastest development
- **PHP**: Moderate memory, good throughput with JIT, mature ecosystem

### Key Questions to Answer
1. What is the memory multiplier between most and least efficient?
2. At what request size does memory become a bottleneck?
3. Which language handles CPU-intensive work most efficiently?
4. How do languages compare in string memory allocation?
5. What are the cost implications in cloud environments?

## 📝 Results Format

### results/summary.md
- Executive summary
- Comparison tables
- Winner by category
- Recommendations by use case
- Cost projections

### results/raw/
- JSON files with detailed metrics
- CSV exports for further analysis
- Container stats snapshots

### visualizations/
- PNG charts for reports
- SVG for presentations

## 🔍 Success Criteria

- ✅ All services start and pass health checks
- ✅ Load tests complete without errors
- ✅ Results are reproducible (variance <5%)
- ✅ Memory measurements are accurate (via cgroups)
- ✅ Visualizations clearly show differences
- ✅ Automation requires zero manual intervention
- ✅ Documentation is complete and clear

## 🛠️ Development Notes

### Container Optimization
- Multi-stage builds for compiled languages
- Minimal base images (alpine/scratch)
- Layer caching optimization
- No development dependencies in production images

### Fair Comparison
- Same hardware/VM for all tests
- Same resource limits
- Same test duration
- Warm-up period before measurements
- Multiple runs for statistical significance

### Memory Measurement
Using cgroup metrics for accuracy:
```bash
podman stats --no-stream --format "json"
# Captures: memory usage, memory limit, memory %
```

## 🔬 Methodology Notes

### Why One Service at a Time?
Running all services simultaneously creates resource contention that skews results. By isolating each service:
- No CPU competition between containers
- No memory pressure from other services
- No network port conflicts
- No shared disk I/O contention
- Pure measurement of each service's resource usage

### Memory Metrics Accuracy
Memory measurements use **cgroup v2** directly via `podman stats`:
- `mem_usage_mb`: Actual memory used by container (RSS)
- `mem_anon_mb`: Anonymous memory (heap allocations)
- `mem_file_mb`: File-backed memory (page cache)
- Sampled every 1 second during tests
- Captures both idle baseline and under-load behavior

### OOM Testing Philosophy
Level 4 string tests intentionally push services to their memory limits:
- **Goal**: Identify which languages handle memory pressure gracefully
- **512MB limit**: Realistic constraint for cost-conscious deployments
- **10x intensity**: String sizes increased from [1KB, 10KB, 100KB] to [10KB, 100KB, 1MB]
- **Concatenate operation**: Creates up to 10MB responses per request
- **Failure = Data**: OOM crashes are captured and analyzed, not hidden

### Reproducibility
- All services use Alpine Linux base for consistency
- Multi-stage builds for compiled languages (Go, C++)
- Fixed resource limits (512MB RAM, 2 CPU cores)
- Warmup period before measurement
- Multiple samples per test (hundreds of data points)
- Results tagged with Run ID for comparison across runs

## 📚 References

- [FastAPI Performance](https://fastapi.tiangolo.com/benchmarks/)
- [PHP 8.3 + RoadRunner](https://roadrunner.dev/)
- [Fiber Framework](https://gofiber.io/)
- [Crow C++ Framework](https://crowcpp.org/)
- [k6 Documentation](https://k6.io/docs/)

## 🤝 Contributing

This is a benchmarking suite. Results may vary based on:
- Hardware configuration (CPU architecture, core count)
- OS and kernel version (especially cgroup implementation)
- Container runtime version and configuration
- Thermal throttling and power management
- Background processes and system load

Always run benchmarks in your target environment for accurate results.

---

**Status**: 🚀 Active benchmarking in progress
**Latest**: Level 4 string tests with 10x memory intensity
