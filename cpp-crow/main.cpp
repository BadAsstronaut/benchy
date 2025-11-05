#include "crow_all.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <map>
#include <sstream>
#include <string>
#include <vector>

using namespace std;

// Utility function to get current timestamp in ISO format
string getCurrentTimestamp() {
    auto now = chrono::system_clock::now();
    auto now_c = chrono::system_clock::to_time_t(now);
    stringstream ss;
    ss << put_time(gmtime(&now_c), "%Y-%m-%dT%H:%M:%SZ");
    return ss.str();
}

// Split string by delimiter
vector<string> split(const string& str, char delimiter) {
    vector<string> tokens;
    stringstream ss(str);
    string token;
    while (getline(ss, token, delimiter)) {
        if (!token.empty()) {
            tokens.push_back(token);
        }
    }
    return tokens;
}

// Trim whitespace
string trim(const string& str) {
    size_t first = str.find_first_not_of(" \t\n\r");
    if (first == string::npos) return "";
    size_t last = str.find_last_not_of(" \t\n\r");
    return str.substr(first, (last - first + 1));
}

// Fibonacci (recursive for CPU load)
long long fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// Check if prime
bool isPrime(int n) {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    int sqrtN = static_cast<int>(sqrt(n));
    for (int i = 3; i <= sqrtN; i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

// Find all primes up to limit
vector<int> findPrimes(int limit) {
    vector<int> primes;
    for (int i = 2; i <= limit; i++) {
        if (isPrime(i)) {
            primes.push_back(i);
        }
    }
    return primes;
}

// Reverse string
string reverseString(const string& str) {
    return string(str.rbegin(), str.rend());
}

// To uppercase
string toUpperCase(const string& str) {
    string result = str;
    transform(result.begin(), result.end(), result.begin(), ::toupper);
    return result;
}

// Count unique characters
int countUniqueChars(const string& str) {
    map<char, bool> charMap;
    for (char c : str) {
        charMap[c] = true;
    }
    return charMap.size();
}

int main() {
    crow::SimpleApp app;

    // Level 1: Hello World
    CROW_ROUTE(app, "/")
    ([]() {
        crow::json::wvalue response;
        response["message"] = "Hello, World!";
        response["service"] = "C++ Crow";
        return response;
    });

    CROW_ROUTE(app, "/health")
    ([]() {
        crow::json::wvalue response;
        response["status"] = "healthy";
        response["timestamp"] = getCurrentTimestamp();
        return response;
    });

    // Level 2: Normal Work
    CROW_ROUTE(app, "/process/normal").methods("POST"_method)
    ([](const crow::request& req) {
        try {
            auto body = crow::json::load(req.body);
            if (!body) {
                return crow::response(400, "Invalid JSON");
            }

            string name = body["name"].s();
            string birthdate = body["birthdate"].s();
            string email = body["email"].s();

            // Parse birthdate and calculate age
            vector<string> dateParts = split(birthdate, '-');
            if (dateParts.empty()) {
                return crow::response(400, "Invalid birthdate format");
            }

            int birthYear = stoi(dateParts[0]);
            auto now = chrono::system_clock::now();
            auto now_c = chrono::system_clock::to_time_t(now);
            int currentYear = 1900 + localtime(&now_c)->tm_year;
            int age = currentYear - birthYear;

            // Extract username from email
            vector<string> emailParts = split(email, '@');
            string username = emailParts.empty() ? "" : emailParts[0];

            // Process name
            vector<string> nameParts = split(name, ' ');
            string firstName = nameParts.empty() ? "" : nameParts[0];
            string lastName = nameParts.size() > 1 ? nameParts.back() : "";

            crow::json::wvalue response;
            response["first_name"] = firstName;
            response["last_name"] = lastName;
            response["age"] = age;
            response["username"] = username;
            response["processed_at"] = getCurrentTimestamp();
            response["is_adult"] = age >= 18;
            response["name_length"] = static_cast<int>(name.length());

            if (body.has("data") && body["data"].t() == crow::json::type::Object) {
                response["extra_data_keys"] = static_cast<int>(body["data"].size());
            }

            return crow::response(response);
        } catch (const exception& e) {
            return crow::response(400, e.what());
        }
    });

    // Level 3: CPU-Intensive Work
    CROW_ROUTE(app, "/process/cpu-intensive").methods("POST"_method)
    ([](const crow::request& req) {
        try {
            auto body = crow::json::load(req.body);
            int n = 35; // default
            if (body && body.has("n")) {
                n = body["n"].i();
            }

            auto startTime = chrono::high_resolution_clock::now();

            // Calculate Fibonacci
            long long fibResult = fibonacci(n);

            // Find primes
            vector<int> primes = findPrimes(10000);

            auto endTime = chrono::high_resolution_clock::now();
            chrono::duration<double> executionTime = endTime - startTime;

            crow::json::wvalue response;
            response["fibonacci_n"] = n;
            response["fibonacci_result"] = fibResult;
            response["primes_count"] = static_cast<int>(primes.size());
            response["largest_prime"] = primes.empty() ? 0 : primes.back();
            response["execution_time_seconds"] = executionTime.count();
            response["service"] = "C++ Crow";

            return crow::response(response);
        } catch (const exception& e) {
            return crow::response(400, e.what());
        }
    });

    // Level 4: String Processing
    CROW_ROUTE(app, "/process/strings").methods("POST"_method)
    ([](const crow::request& req) {
        try {
            auto body = crow::json::load(req.body);
            if (!body || !body.has("text")) {
                return crow::response(400, "Missing text field");
            }

            string text = body["text"].s();
            string operation = body.has("operation") ? string(body["operation"].s()) : string("reverse");

            auto startTime = chrono::high_resolution_clock::now();
            size_t textLength = text.length();

            crow::json::wvalue response;
            response["original_length"] = static_cast<int>(textLength);
            response["operation"] = operation;

            if (operation == "reverse") {
                string processed = reverseString(text);
                response["processed_length"] = static_cast<int>(processed.length());
                response["sample"] = processed.length() > 100 ? processed.substr(0, 100) : processed;

            } else if (operation == "uppercase") {
                string processed = toUpperCase(text);
                response["processed_length"] = static_cast<int>(processed.length());
                response["sample"] = processed.length() > 100 ? processed.substr(0, 100) : processed;

            } else if (operation == "count") {
                int lineCount = 1 + count(text.begin(), text.end(), '\n');

                // Count words
                stringstream ss(text);
                string word;
                int wordCount = 0;
                while (ss >> word) wordCount++;

                response["char_count"] = static_cast<int>(text.length());
                response["word_count"] = wordCount;
                response["line_count"] = lineCount;
                response["unique_chars"] = countUniqueChars(text);

            } else if (operation == "pattern") {
                // Word frequency analysis
                stringstream ss(text);
                string word;
                map<string, int> wordFreq;

                while (ss >> word) {
                    // Convert to lowercase
                    transform(word.begin(), word.end(), word.begin(), ::tolower);
                    // Remove punctuation
                    word.erase(remove_if(word.begin(), word.end(), ::ispunct), word.end());
                    if (!word.empty()) {
                        wordFreq[word]++;
                    }
                }

                // Get top 10 words
                vector<pair<string, int>> wordVec(wordFreq.begin(), wordFreq.end());
                sort(wordVec.begin(), wordVec.end(),
                     [](const pair<string, int>& a, const pair<string, int>& b) {
                         return a.second > b.second;
                     });

                vector<crow::json::wvalue> topWords;
                for (size_t i = 0; i < min(size_t(10), wordVec.size()); i++) {
                    crow::json::wvalue wc;
                    wc["word"] = wordVec[i].first;
                    wc["count"] = wordVec[i].second;
                    topWords.push_back(move(wc));
                }

                response["top_words"] = move(topWords);
                response["unique_words"] = static_cast<int>(wordFreq.size());

            } else if (operation == "concatenate") {
                int iterations = textLength > 0 ? min(10, static_cast<int>(1000000 / textLength)) : 10;
                string processed;
                processed.reserve(textLength * iterations);
                for (int i = 0; i < iterations; i++) {
                    processed += text;
                }
                response["iterations"] = iterations;
                response["final_length"] = static_cast<int>(processed.length());

            } else {
                return crow::response(400, "Unknown operation: " + operation);
            }

            auto endTime = chrono::high_resolution_clock::now();
            chrono::duration<double> executionTime = endTime - startTime;
            response["execution_time_seconds"] = executionTime.count();
            response["service"] = "C++ Crow";

            return crow::response(response);
        } catch (const exception& e) {
            return crow::response(400, e.what());
        }
    });

    app.port(6003).multithreaded().run();
    return 0;
}
