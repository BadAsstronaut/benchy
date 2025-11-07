#!/usr/bin/env python3

"""
Results analysis script for benchmark suite.
Parses k6 JSON output and container metrics to generate comprehensive reports.
"""

import json
import os
import sys
import glob
from pathlib import Path
from collections import defaultdict
import statistics
from datetime import datetime

def parse_k6_json(file_path):
    """Parse k6 JSON output and extract key metrics."""
    metrics = {
        'http_reqs': [],
        'http_req_duration': [],
        'http_req_failed': [],
        'vus': [],
        'iterations': 0
    }

    try:
        with open(file_path, 'r') as f:
            for line in f:
                try:
                    data = json.loads(line.strip())

                    if data.get('type') == 'Point':
                        metric_name = data.get('metric')
                        value = data.get('data', {}).get('value')

                        if metric_name == 'http_req_duration' and value:
                            metrics['http_req_duration'].append(value)
                        elif metric_name == 'http_reqs' and value:
                            metrics['http_reqs'].append(value)
                        elif metric_name == 'vus' and value:
                            metrics['vus'].append(value)
                        elif metric_name == 'iterations' and value:
                            metrics['iterations'] += value

                except json.JSONDecodeError:
                    continue

    except FileNotFoundError:
        print(f"Warning: File not found: {file_path}")
        return None

    return metrics

def calculate_percentile(data, percentile):
    """Calculate percentile from data."""
    if not data:
        return 0
    sorted_data = sorted(data)
    index = int(len(sorted_data) * percentile / 100)
    return sorted_data[min(index, len(sorted_data) - 1)]

def analyze_metrics(metrics):
    """Calculate summary statistics from metrics."""
    if not metrics or not metrics.get('http_req_duration'):
        return None

    durations = metrics['http_req_duration']

    summary = {
        'total_requests': len(durations),
        'mean_duration_ms': statistics.mean(durations) if durations else 0,
        'median_duration_ms': statistics.median(durations) if durations else 0,
        'p90_ms': calculate_percentile(durations, 90),
        'p95_ms': calculate_percentile(durations, 95),
        'p99_ms': calculate_percentile(durations, 99),
        'min_ms': min(durations) if durations else 0,
        'max_ms': max(durations) if durations else 0,
        'iterations': metrics.get('iterations', 0)
    }

    return summary

def parse_container_stats(file_path):
    """Parse container stats JSON."""
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
            return data
    except (FileNotFoundError, json.JSONDecodeError):
        return None

def generate_markdown_report(results, output_path):
    """Generate a markdown report from results."""

    report = []
    report.append("# Benchmark Results Report\n")
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    report.append("\n---\n\n")

    # Group by level
    levels = ['level1_hello', 'level2_normal', 'level3_cpu', 'level4_strings']
    level_names = {
        'level1_hello': 'Level 1: Hello World',
        'level2_normal': 'Level 2: Normal Work',
        'level3_cpu': 'Level 3: CPU-Intensive',
        'level4_strings': 'Level 4: String Processing'
    }

    for level in levels:
        report.append(f"## {level_names.get(level, level)}\n\n")

        # Create comparison table
        report.append("| Service | Requests | Mean (ms) | Median (ms) | P95 (ms) | P99 (ms) | Max (ms) |\n")
        report.append("|---------|----------|-----------|-------------|----------|----------|----------|\n")

        level_results = {k: v for k, v in results.items() if level in k}

        for service_key in sorted(level_results.keys()):
            summary = level_results[service_key]
            service_name = service_key.split('_')[0].upper()

            report.append(
                f"| {service_name:7} | "
                f"{summary['total_requests']:8} | "
                f"{summary['mean_duration_ms']:9.2f} | "
                f"{summary['median_duration_ms']:11.2f} | "
                f"{summary['p95_ms']:8.2f} | "
                f"{summary['p99_ms']:8.2f} | "
                f"{summary['max_ms']:8.2f} |\n"
            )

        report.append("\n")

    # Performance comparison summary
    report.append("\n## Performance Summary\n\n")
    report.append("### Requests Per Second (Approximate)\n\n")
    report.append("| Service | Level 1 | Level 2 | Level 3 | Level 4 |\n")
    report.append("|---------|---------|---------|---------|----------|\n")

    services = ['python', 'php', 'go', 'cpp']
    for service in services:
        row = [service.upper()]
        for level in levels:
            key = f"{service}_{level}"
            if key in results and results[key]['mean_duration_ms'] > 0:
                rps = 1000 / results[key]['mean_duration_ms']
                row.append(f"{rps:.0f}")
            else:
                row.append("N/A")
        report.append(f"| {' | '.join(row)} |\n")

    report.append("\n")

    # Memory comparison (if available)
    report.append("## Resource Usage\n\n")
    report.append("*Memory and CPU metrics to be collected from container stats*\n\n")

    # Write report
    with open(output_path, 'w') as f:
        f.writelines(report)

    print(f"Report generated: {output_path}")

def main():
    if len(sys.argv) < 2:
        results_dir = "./results"
    else:
        results_dir = sys.argv[1]

    raw_dir = os.path.join(results_dir, "raw")

    if not os.path.exists(raw_dir):
        print(f"Error: Results directory not found: {raw_dir}")
        return

    print("Analyzing results...")

    # Find all JSON result files
    json_files = glob.glob(os.path.join(raw_dir, "*.json"))

    results = {}

    for json_file in json_files:
        filename = os.path.basename(json_file)

        # Extract service and test type from filename
        # Standardized format: service_k6_RUNID.json OR service_levelN_xxx_RUNID.json
        parts = filename.replace('.json', '').split('_')

        if len(parts) >= 3:
            service = parts[0]  # First part is always service
            # Second part determines test type (k6, level1, level2, etc)
            if parts[1] == 'k6':
                level = 'quick'  # k6 quick tests
            else:
                level = '_'.join(parts[1:-1])  # level tests, everything except service and run_id

            print(f"Processing: {service} - {level}")

            metrics = parse_k6_json(json_file)
            if metrics:
                summary = analyze_metrics(metrics)
                if summary:
                    key = f"{service}_{level}"
                    results[key] = summary

    if not results:
        print("No results found to analyze")
        return

    # Generate markdown report
    report_path = os.path.join(results_dir, "summary.md")
    generate_markdown_report(results, report_path)

    # Generate CSV for easy import
    csv_path = os.path.join(results_dir, "summary.csv")
    with open(csv_path, 'w') as f:
        f.write("Service,Level,Total_Requests,Mean_ms,Median_ms,P95_ms,P99_ms,Max_ms\n")
        for key, summary in sorted(results.items()):
            service, level = key.split('_', 1)
            f.write(
                f"{service},{level},"
                f"{summary['total_requests']},"
                f"{summary['mean_duration_ms']:.2f},"
                f"{summary['median_duration_ms']:.2f},"
                f"{summary['p95_ms']:.2f},"
                f"{summary['p99_ms']:.2f},"
                f"{summary['max_ms']:.2f}\n"
            )

    print(f"CSV summary generated: {csv_path}")
    print("\nAnalysis complete!")

if __name__ == "__main__":
    main()
