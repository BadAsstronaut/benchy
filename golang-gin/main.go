package main

import (
	"fmt"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// Request models
type NormalWorkRequest struct {
	Name      string                 `json:"name" binding:"required"`
	Birthdate string                 `json:"birthdate" binding:"required"`
	Email     string                 `json:"email" binding:"required"`
	Data      map[string]interface{} `json:"data"`
}

type CPUIntensiveRequest struct {
	N int `json:"n"`
}

type StringProcessRequest struct {
	Text      string `json:"text" binding:"required"`
	Operation string `json:"operation"`
}

func main() {
	// Set Gin to release mode for production
	gin.SetMode(gin.ReleaseMode)

	r := gin.Default()

	// Level 1: Hello World
	r.GET("/", handleHelloWorld)
	r.GET("/health", handleHealth)

	// Level 2: Normal Work
	r.POST("/process/normal", handleNormalWork)

	// Level 3: CPU-Intensive Work
	r.POST("/process/cpu-intensive", handleCPUIntensive)

	// Level 4: String Processing
	r.POST("/process/strings", handleStringProcessing)

	r.Run(":6002")
}

func handleHelloWorld(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"message": "Hello, World!",
		"service": "Go Gin",
	})
}

func handleHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

func handleNormalWork(c *gin.Context) {
	var req NormalWorkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Parse birthdate and calculate age
	parts := strings.Split(req.Birthdate, "-")
	if len(parts) < 1 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid birthdate format"})
		return
	}

	var birthYear int
	_, err := fmt.Sscanf(parts[0], "%d", &birthYear)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid birth year"})
		return
	}

	currentYear := time.Now().Year()
	age := currentYear - birthYear

	// Extract username from email
	emailParts := strings.Split(req.Email, "@")
	username := emailParts[0]

	// Process name
	nameParts := strings.Fields(req.Name)
	firstName := ""
	lastName := ""
	if len(nameParts) > 0 {
		firstName = nameParts[0]
	}
	if len(nameParts) > 1 {
		lastName = nameParts[len(nameParts)-1]
	}

	result := gin.H{
		"first_name":   firstName,
		"last_name":    lastName,
		"age":          age,
		"username":     username,
		"processed_at": time.Now().UTC().Format(time.RFC3339),
		"is_adult":     age >= 18,
		"name_length":  len(req.Name),
	}

	if req.Data != nil {
		result["extra_data_keys"] = len(req.Data)
	}

	c.JSON(http.StatusOK, result)
}

func fibonacci(n int) int {
	if n <= 1 {
		return n
	}
	return fibonacci(n-1) + fibonacci(n-2)
}

func isPrime(n int) bool {
	if n < 2 {
		return false
	}
	if n == 2 {
		return true
	}
	if n%2 == 0 {
		return false
	}

	sqrt := int(math.Sqrt(float64(n)))
	for i := 3; i <= sqrt; i += 2 {
		if n%i == 0 {
			return false
		}
	}
	return true
}

func findPrimes(limit int) []int {
	primes := []int{}
	for i := 2; i <= limit; i++ {
		if isPrime(i) {
			primes = append(primes, i)
		}
	}
	return primes
}

func handleCPUIntensive(c *gin.Context) {
	var req CPUIntensiveRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		req.N = 35 // Default value
	}

	startTime := time.Now()

	// Calculate Fibonacci
	fibResult := fibonacci(req.N)

	// Find primes
	primes := findPrimes(10000)

	endTime := time.Now()
	executionTime := endTime.Sub(startTime).Seconds()

	largestPrime := 0
	if len(primes) > 0 {
		largestPrime = primes[len(primes)-1]
	}

	c.JSON(http.StatusOK, gin.H{
		"fibonacci_n":             req.N,
		"fibonacci_result":        fibResult,
		"primes_count":            len(primes),
		"largest_prime":           largestPrime,
		"execution_time_seconds":  executionTime,
		"service":                 "Go Gin",
	})
}

func handleStringProcessing(c *gin.Context) {
	var req StringProcessRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Operation == "" {
		req.Operation = "reverse"
	}

	startTime := time.Now()
	textLength := len(req.Text)

	result := gin.H{
		"original_length": textLength,
		"operation":       req.Operation,
	}

	switch req.Operation {
	case "reverse":
		runes := []rune(req.Text)
		for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
			runes[i], runes[j] = runes[j], runes[i]
		}
		processed := string(runes)
		result["processed_length"] = len(processed)
		if len(processed) > 100 {
			result["sample"] = processed[:100]
		} else {
			result["sample"] = processed
		}

	case "uppercase":
		processed := strings.ToUpper(req.Text)
		result["processed_length"] = len(processed)
		if len(processed) > 100 {
			result["sample"] = processed[:100]
		} else {
			result["sample"] = processed
		}

	case "count":
		lines := strings.Split(req.Text, "\n")
		words := strings.Fields(req.Text)
		uniqueChars := make(map[rune]bool)
		for _, ch := range req.Text {
			uniqueChars[ch] = true
		}

		result["char_count"] = len(req.Text)
		result["word_count"] = len(words)
		result["line_count"] = len(lines)
		result["unique_chars"] = len(uniqueChars)

	case "pattern":
		words := strings.Fields(strings.ToLower(req.Text))
		wordFreq := make(map[string]int)
		for _, word := range words {
			wordFreq[word]++
		}

		// Get top 10 words
		type wordCount struct {
			Word  string `json:"word"`
			Count int    `json:"count"`
		}
		var topWords []wordCount
		for word, count := range wordFreq {
			topWords = append(topWords, wordCount{Word: word, Count: count})
		}

		// Sort by count (simple bubble sort for top 10)
		for i := 0; i < len(topWords) && i < 10; i++ {
			for j := i + 1; j < len(topWords); j++ {
				if topWords[j].Count > topWords[i].Count {
					topWords[i], topWords[j] = topWords[j], topWords[i]
				}
			}
		}

		if len(topWords) > 10 {
			topWords = topWords[:10]
		}

		result["top_words"] = topWords
		result["unique_words"] = len(wordFreq)

	case "concatenate":
		iterations := 10
		if textLength > 0 {
			iterations = min(10, 1000000/textLength)
		}
		processed := strings.Repeat(req.Text, iterations)
		result["iterations"] = iterations
		result["final_length"] = len(processed)

	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Unknown operation: " + req.Operation})
		return
	}

	endTime := time.Now()
	result["execution_time_seconds"] = endTime.Sub(startTime).Seconds()
	result["service"] = "Go Gin"

	c.JSON(http.StatusOK, result)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
