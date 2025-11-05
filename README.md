# Language Performance Benchmark Suite

Comprehensive benchmarking comparison of **Python (FastAPI)**, **PHP 8.5**, **Go (Gin)**, and **C++ (Crow)** with focus on memory utilization and resource efficiency.

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

### Level 4: String Input Memory Requirements
- **Purpose**: Test string handling and memory efficiency
- **Endpoint**: `POST /process/strings`
- **Function**: Accept strings of varying sizes (1KB, 100KB, 1MB, 10MB)
- **Operations**:
  - String concatenation
  - Pattern matching/regex
  - String manipulation (reverse, split, transform)
  - Large string buffering
- **Metrics**:
  - Memory allocation per string size
  - Peak memory usage
  - Memory release behavior
  - String copy overhead

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

### Go (Gin)
- **Framework**: Gin 1.9+
- **Base Image**: Multi-stage (golang:1.21-alpine → alpine)
- **Key Features**: Goroutines, minimal runtime
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
make install-deps
```

### Complete Automated Benchmark
```bash
# Build, test, analyze, and visualize everything
make full-benchmark
```

### Make Commands

```bash
# Setup & Management
make build              # Build all containers
make up                 # Start all services
make down               # Stop all services
make health             # Check service health
make logs               # View all logs
make stats              # Real-time container stats

# Testing - All Services
make test-hello         # Level 1: Hello World
make test-normal        # Level 2: Normal Work
make test-cpu           # Level 3: CPU-Intensive
make test-strings       # Level 4: String Processing
make test-all           # Run all tests

# Testing - Individual Services
make test-python-cpu    # Python CPU test
make test-php-strings   # PHP string test
make test-go-hello      # Go hello world
make test-cpp-normal    # C++ normal work

# Analysis & Results
make analyze            # Analyze test results
make visualize          # Generate charts
make results            # Both analyze + visualize

# Utility
make clean              # Remove results/visualizations
make clean-all          # Remove everything including containers
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

## 📚 References

- [FastAPI Performance](https://fastapi.tiangolo.com/benchmarks/)
- [PHP 8.5 JIT](https://www.php.net/releases/8.5/en.php)
- [Gin Framework](https://gin-gonic.com/)
- [Crow C++ Framework](https://crowcpp.org/)
- [k6 Documentation](https://k6.io/docs/)

## 📄 License

MIT License - Feel free to use and modify

## 🤝 Contributing

This is a benchmarking suite. Results may vary based on:
- Hardware configuration
- OS and kernel version
- Container runtime version
- Network conditions

Always run benchmarks in your target environment for accurate results.

---

**Status**: ✅ Complete - All code scaffolded and ready to run
**Next Step**: `make full-benchmark` to run complete test suite
