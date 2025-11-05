import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const executionTime = new Trend('execution_time');

export const options = {
  stages: [
    { duration: '30s', target: 20 },    // Warmup (lower for CPU-intensive)
    { duration: '2m', target: 20 },     // Baseline
    { duration: '30s', target: 50 },    // Ramp up
    { duration: '2m', target: 50 },     // Sustained load
    { duration: '30s', target: 100 },   // Spike
    { duration: '1m', target: 100 },    // Peak load
    { duration: '30s', target: 0 },     // Cool down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<5000', 'p(99)<10000'],  // Higher thresholds for CPU work
    'http_req_failed': ['rate<0.01'],
    'errors': ['rate<0.01'],
  },
};

const SERVICES = {
  python: 'http://localhost:6000',
  php: 'http://localhost:6001',
  go: 'http://localhost:6002',
  cpp: 'http://localhost:6003',
};

export default function () {
  const service = __ENV.SERVICE || 'python';
  const baseUrl = SERVICES[service];

  if (!baseUrl) {
    console.error(`Unknown service: ${service}`);
    return;
  }

  // Vary the Fibonacci number to test different CPU loads
  const fibNumbers = [30, 32, 35, 37];
  const n = fibNumbers[Math.floor(Math.random() * fibNumbers.length)];

  const payload = {
    n: n,
  };

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const res = http.post(
    `${baseUrl}/process/cpu-intensive`,
    JSON.stringify(payload),
    params
  );

  const result = check(res, {
    'status is 200': (r) => r.status === 200,
    'has fibonacci_result': (r) => r.json('fibonacci_result') !== undefined,
    'has primes_count': (r) => r.json('primes_count') !== undefined,
    'execution_time exists': (r) => r.json('execution_time_seconds') !== undefined,
  });

  errorRate.add(!result);
  responseTime.add(res.timings.duration);

  if (res.status === 200) {
    const body = JSON.parse(res.body);
    if (body.execution_time_seconds) {
      executionTime.add(body.execution_time_seconds * 1000); // Convert to ms
    }
  }

  sleep(0.5); // Longer sleep for CPU-intensive tests
}
