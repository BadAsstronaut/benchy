import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const executionTime = new Trend('execution_time');

export const options = {
  stages: [
    { duration: '30s', target: 30 },
    { duration: '2m', target: 30 },
    { duration: '30s', target: 100 },
    { duration: '2m', target: 100 },
    { duration: '30s', target: 200 },
    { duration: '1m', target: 200 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<2000', 'p(99)<5000'],
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

// Generate strings of different sizes
function generateString(size) {
  const base = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ';

  if (size === '1kb') {
    return base.repeat(Math.ceil(1024 / base.length));
  } else if (size === '10kb') {
    return base.repeat(Math.ceil(10240 / base.length));
  } else if (size === '100kb') {
    return base.repeat(Math.ceil(102400 / base.length));
  } else if (size === '1mb') {
    return base.repeat(Math.ceil(1048576 / base.length));
  }
  return base;
}

export default function () {
  const service = __ENV.SERVICE || 'python';
  const baseUrl = SERVICES[service];

  if (!baseUrl) {
    console.error(`Unknown service: ${service}`);
    return;
  }

  // Test different string sizes and operations
  const sizes = ['1kb', '10kb', '100kb'];  // Excluding 1mb for regular tests
  const operations = ['reverse', 'uppercase', 'count', 'pattern'];

  const size = sizes[Math.floor(Math.random() * sizes.length)];
  const operation = operations[Math.floor(Math.random() * operations.length)];

  const text = generateString(size);

  const payload = {
    text: text,
    operation: operation,
  };

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const res = http.post(
    `${baseUrl}/process/strings`,
    JSON.stringify(payload),
    params
  );

  const result = check(res, {
    'status is 200': (r) => r.status === 200,
    'has original_length': (r) => r.json('original_length') !== undefined,
    'has operation': (r) => r.json('operation') !== undefined,
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

  sleep(0.2);
}
