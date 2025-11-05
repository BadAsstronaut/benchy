from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import uvicorn
import time
from datetime import datetime

app = FastAPI()

# Models for request validation
class NormalWorkRequest(BaseModel):
    name: str
    birthdate: str  # Format: YYYY-MM-DD
    email: str
    data: Optional[dict] = None

class CPUIntensiveRequest(BaseModel):
    n: int = 35

class StringProcessRequest(BaseModel):
    text: str
    operation: str = "reverse"  # reverse, uppercase, count, pattern

# Level 1: Hello World
@app.get("/")
async def hello_world():
    return {"message": "Hello, World!", "service": "Python FastAPI"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

# Level 2: Normal Work - JSON processing
@app.post("/process/normal")
async def process_normal(request: NormalWorkRequest):
    try:
        # Parse birthdate and calculate age
        birth_year = int(request.birthdate.split("-")[0])
        current_year = datetime.now().year
        age = current_year - birth_year

        # Transform email to username
        username = request.email.split("@")[0]

        # Some basic processing
        name_parts = request.name.split()
        first_name = name_parts[0] if name_parts else ""
        last_name = name_parts[-1] if len(name_parts) > 1 else ""

        result = {
            "first_name": first_name,
            "last_name": last_name,
            "age": age,
            "username": username,
            "processed_at": datetime.utcnow().isoformat(),
            "is_adult": age >= 18,
            "name_length": len(request.name),
        }

        # Include extra data if provided
        if request.data:
            result["extra_data_keys"] = len(request.data.keys())

        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# Level 3: CPU-Intensive Work
def fibonacci(n: int) -> int:
    """Calculate Fibonacci number recursively (intentionally inefficient for CPU load)"""
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

def is_prime(n: int) -> bool:
    """Check if a number is prime"""
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False
    for i in range(3, int(n ** 0.5) + 1, 2):
        if n % i == 0:
            return False
    return True

def find_primes(limit: int) -> list:
    """Find all prime numbers up to limit"""
    return [i for i in range(2, limit + 1) if is_prime(i)]

@app.post("/process/cpu-intensive")
async def process_cpu_intensive(request: CPUIntensiveRequest):
    start_time = time.time()

    # Calculate Fibonacci
    fib_result = fibonacci(request.n)

    # Find primes up to 10000
    primes = find_primes(10000)

    end_time = time.time()
    execution_time = end_time - start_time

    return {
        "fibonacci_n": request.n,
        "fibonacci_result": fib_result,
        "primes_count": len(primes),
        "largest_prime": primes[-1] if primes else None,
        "execution_time_seconds": execution_time,
        "service": "Python FastAPI"
    }

# Level 4: String Input Memory Requirements
@app.post("/process/strings")
async def process_strings(request: StringProcessRequest):
    start_time = time.time()
    text_length = len(request.text)

    result = {
        "original_length": text_length,
        "operation": request.operation,
    }

    if request.operation == "reverse":
        processed = request.text[::-1]
        result["processed_length"] = len(processed)
        result["sample"] = processed[:100] if len(processed) > 100 else processed

    elif request.operation == "uppercase":
        processed = request.text.upper()
        result["processed_length"] = len(processed)
        result["sample"] = processed[:100] if len(processed) > 100 else processed

    elif request.operation == "count":
        result["char_count"] = len(request.text)
        result["word_count"] = len(request.text.split())
        result["line_count"] = len(request.text.splitlines())
        result["unique_chars"] = len(set(request.text))

    elif request.operation == "pattern":
        # Pattern matching - count occurrences of common words
        words = request.text.lower().split()
        word_freq = {}
        for word in words:
            word_freq[word] = word_freq.get(word, 0) + 1

        # Get top 10 most frequent words
        top_words = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)[:10]
        result["top_words"] = [{"word": w, "count": c} for w, c in top_words]
        result["unique_words"] = len(word_freq)

    elif request.operation == "concatenate":
        # Concatenate string with itself multiple times
        iterations = min(10, 1000000 // max(text_length, 1))
        processed = request.text * iterations
        result["iterations"] = iterations
        result["final_length"] = len(processed)

    else:
        raise HTTPException(status_code=400, detail=f"Unknown operation: {request.operation}")

    end_time = time.time()
    result["execution_time_seconds"] = end_time - start_time
    result["service"] = "Python FastAPI"

    return result

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=6000)
