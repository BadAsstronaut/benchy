cmake_minimum_required(VERSION 3.15)
project(benchmark_crow)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optimization flags for release builds
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# Find required packages
find_package(Threads REQUIRED)

# Add executable
add_executable(benchmark_crow main.cpp)

# Link libraries
target_link_libraries(benchmark_crow PRIVATE Threads::Threads)

# Include directories for Crow (header-only library)
target_include_directories(benchmark_crow PRIVATE ${CMAKE_SOURCE_DIR})
