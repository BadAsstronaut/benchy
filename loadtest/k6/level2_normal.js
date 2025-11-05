import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

export const options = {
  stages: [
    { duration: '30s', target: 50 },
    { duration: '2m', target: 50 },
    { duration: '30s', target: 200 },
    { duration: '2m', target: 200 },
    { duration: '30s', target: 500 },
    { duration: '1m', target: 500 },
    { duration: '30s', target: 0 },
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

// Generate test payloads of different sizes
function generatePayload(size) {
  const basePayload = {
    name: 'John Doe Smith',
    birthdate: '1990-05-15',
    email: 'john.doe@example.com',
  };

  if (size === 'small') {
    return basePayload;
  } else if (size === 'medium') {
    basePayload.data = {};
    for (let i = 0; i < 50; i++) {
      basePayload.data[`key${i}`] = `value${i}`.repeat(10);
    }
    return basePayload;
  } else if (size === 'large') {
    basePayload.data = {};
    for (let i = 0; i < 500; i++) {
      basePayload.data[`key${i}`] = `value${i}`.repeat(100);
    }
    return basePayload;
  }
  return basePayload;
}

export default function () {
  const service = __ENV.SERVICE || 'python';
  const baseUrl = SERVICES[service];

  if (!baseUrl) {
    console.error(`Unknown service: ${service}`);
    return;
  }

  // Randomly choose payload size
  const sizes = ['small', 'medium', 'large'];
  const size = sizes[Math.floor(Math.random() * sizes.length)];
  const payload = generatePayload(size);

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const res = http.post(
    `${baseUrl}/process/normal`,
    JSON.stringify(payload),
    params
  );

  const result = check(res, {
    'status is 200': (r) => r.status === 200,
    'has age': (r) => r.json('age') !== undefined,
    'has username': (r) => r.json('username') !== undefined,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });

  errorRate.add(!result);
  responseTime.add(res.timings.duration);

  sleep(0.1);
}
