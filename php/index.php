<?php
header('Content-Type: application/json');

// Get request method and path
$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// Router
try {
    if ($method === 'GET' && $path === '/') {
        handleHelloWorld();
    } elseif ($method === 'GET' && $path === '/health') {
        handleHealth();
    } elseif ($method === 'POST' && $path === '/process/normal') {
        handleNormalWork();
    } elseif ($method === 'POST' && $path === '/process/cpu-intensive') {
        handleCPUIntensive();
    } elseif ($method === 'POST' && $path === '/process/strings') {
        handleStringProcessing();
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Not Found']);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}

// Level 1: Hello World
function handleHelloWorld() {
    echo json_encode([
        'message' => 'Hello, World!',
        'service' => 'PHP 8.5'
    ]);
}

function handleHealth() {
    echo json_encode([
        'status' => 'healthy',
        'timestamp' => gmdate('Y-m-d\TH:i:s\Z')
    ]);
}

// Level 2: Normal Work
function handleNormalWork() {
    $input = json_decode(file_get_contents('php://input'), true);

    if (!isset($input['name']) || !isset($input['birthdate']) || !isset($input['email'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing required fields']);
        return;
    }

    // Parse birthdate and calculate age
    $birthYear = (int)explode('-', $input['birthdate'])[0];
    $currentYear = (int)date('Y');
    $age = $currentYear - $birthYear;

    // Transform email to username
    $username = explode('@', $input['email'])[0];

    // Process name
    $nameParts = explode(' ', $input['name']);
    $firstName = $nameParts[0] ?? '';
    $lastName = $nameParts[count($nameParts) - 1] ?? '';
    if (count($nameParts) === 1) {
        $lastName = '';
    }

    $result = [
        'first_name' => $firstName,
        'last_name' => $lastName,
        'age' => $age,
        'username' => $username,
        'processed_at' => gmdate('Y-m-d\TH:i:s\Z'),
        'is_adult' => $age >= 18,
        'name_length' => strlen($input['name'])
    ];

    if (isset($input['data']) && is_array($input['data'])) {
        $result['extra_data_keys'] = count($input['data']);
    }

    echo json_encode($result);
}

// Level 3: CPU-Intensive Work
function fibonacci(int $n): int {
    if ($n <= 1) {
        return $n;
    }
    return fibonacci($n - 1) + fibonacci($n - 2);
}

function isPrime(int $n): bool {
    if ($n < 2) return false;
    if ($n === 2) return true;
    if ($n % 2 === 0) return false;

    $sqrt = (int)sqrt($n);
    for ($i = 3; $i <= $sqrt; $i += 2) {
        if ($n % $i === 0) {
            return false;
        }
    }
    return true;
}

function findPrimes(int $limit): array {
    $primes = [];
    for ($i = 2; $i <= $limit; $i++) {
        if (isPrime($i)) {
            $primes[] = $i;
        }
    }
    return $primes;
}

function handleCPUIntensive() {
    $input = json_decode(file_get_contents('php://input'), true);
    $n = $input['n'] ?? 35;

    $startTime = microtime(true);

    // Calculate Fibonacci
    $fibResult = fibonacci($n);

    // Find primes
    $primes = findPrimes(10000);

    $endTime = microtime(true);
    $executionTime = $endTime - $startTime;

    echo json_encode([
        'fibonacci_n' => $n,
        'fibonacci_result' => $fibResult,
        'primes_count' => count($primes),
        'largest_prime' => end($primes) ?: null,
        'execution_time_seconds' => $executionTime,
        'service' => 'PHP 8.5'
    ]);
}

// Level 4: String Processing
function handleStringProcessing() {
    $input = json_decode(file_get_contents('php://input'), true);

    if (!isset($input['text'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing text field']);
        return;
    }

    $text = $input['text'];
    $operation = $input['operation'] ?? 'reverse';
    $startTime = microtime(true);

    $result = [
        'original_length' => strlen($text),
        'operation' => $operation
    ];

    switch ($operation) {
        case 'reverse':
            $processed = strrev($text);
            $result['processed_length'] = strlen($processed);
            $result['sample'] = strlen($processed) > 100 ? substr($processed, 0, 100) : $processed;
            break;

        case 'uppercase':
            $processed = strtoupper($text);
            $result['processed_length'] = strlen($processed);
            $result['sample'] = strlen($processed) > 100 ? substr($processed, 0, 100) : $processed;
            break;

        case 'count':
            $result['char_count'] = strlen($text);
            $result['word_count'] = str_word_count($text);
            $result['line_count'] = substr_count($text, "\n") + 1;
            $result['unique_chars'] = count(array_unique(str_split($text)));
            break;

        case 'pattern':
            $words = str_word_count(strtolower($text), 1);
            $wordFreq = array_count_values($words);
            arsort($wordFreq);
            $topWords = array_slice($wordFreq, 0, 10, true);

            $result['top_words'] = [];
            foreach ($topWords as $word => $count) {
                $result['top_words'][] = ['word' => $word, 'count' => $count];
            }
            $result['unique_words'] = count($wordFreq);
            break;

        case 'concatenate':
            $textLength = strlen($text);
            $iterations = min(10, intdiv(1000000, max($textLength, 1)));
            $processed = str_repeat($text, $iterations);
            $result['iterations'] = $iterations;
            $result['final_length'] = strlen($processed);
            break;

        default:
            http_response_code(400);
            echo json_encode(['error' => "Unknown operation: $operation"]);
            return;
    }

    $endTime = microtime(true);
    $result['execution_time_seconds'] = $endTime - $startTime;
    $result['service'] = 'PHP 8.5';

    echo json_encode($result);
}
