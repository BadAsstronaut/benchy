import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

// Quick test profile for isolated benchmarking
export const options = {
  stages: [
    { duration: '10s', target: 50 },    // Warmup
    { duration: '30s', target: 50 },    // Baseline
    { duration: '10s', target: 200 },   // Ramp up
    { duration: '30s', target: 200 },   // Sustained load
    { duration: '10s', target: 0 },     // Cool down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],
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

  const res = http.get(`${baseUrl}/`);

  const result = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has message': (r) => r.json('message') !== undefined,
    'response time < 100ms': (r) => r.timings.duration < 100,
  });

  errorRate.add(!result);
  responseTime.add(res.timings.duration);

  sleep(0.1);
}
