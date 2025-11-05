#!/usr/bin/env python3

"""
Visualization script for benchmark results.
Generates comprehensive charts and graphs comparing language performance.
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
import sys
from pathlib import Path
import numpy as np

# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10

def load_summary_data(results_dir):
    """Load the summary CSV file."""
    csv_path = os.path.join(results_dir, "summary.csv")

    if not os.path.exists(csv_path):
        print(f"Error: Summary CSV not found at {csv_path}")
        print("Please run analyze_results.py first")
        return None

    df = pd.read_csv(csv_path)
    return df

def plot_latency_comparison(df, output_dir):
    """Create latency comparison charts for each level."""
    levels = df['Level'].unique()
    level_names = {
        'level1_hello': 'Level 1: Hello World',
        'level2_normal': 'Level 2: Normal Work',
        'level3_cpu': 'Level 3: CPU-Intensive',
        'level4_strings': 'Level 4: String Processing'
    }

    for level in levels:
        level_data = df[df['Level'] == level]

        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle(f'{level_names.get(level, level)} - Latency Analysis', fontsize=16, fontweight='bold')

        # 1. Mean latency comparison
        ax1 = axes[0, 0]
        services = level_data['Service']
        means = level_data['Mean_ms']
        bars = ax1.bar(services, means, color=['#3498db', '#e74c3c', '#2ecc71', '#f39c12'])
        ax1.set_ylabel('Mean Latency (ms)')
        ax1.set_title('Mean Response Time')
        ax1.grid(axis='y', alpha=0.3)

        # Add value labels on bars
        for bar in bars:
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.2f}',
                    ha='center', va='bottom', fontsize=9)

        # 2. Percentile comparison
        ax2 = axes[0, 1]
        x = np.arange(len(services))
        width = 0.25

        ax2.bar(x - width, level_data['Median_ms'], width, label='P50 (Median)', color='#3498db')
        ax2.bar(x, level_data['P95_ms'], width, label='P95', color='#e74c3c')
        ax2.bar(x + width, level_data['P99_ms'], width, label='P99', color='#f39c12')

        ax2.set_ylabel('Latency (ms)')
        ax2.set_title('Latency Percentiles')
        ax2.set_xticks(x)
        ax2.set_xticklabels(services)
        ax2.legend()
        ax2.grid(axis='y', alpha=0.3)

        # 3. Min/Max range
        ax3 = axes[1, 0]
        ax3.bar(services, level_data['Max_ms'], label='Max', alpha=0.7, color='#e74c3c')
        ax3.bar(services, level_data['Mean_ms'], label='Mean', alpha=0.9, color='#3498db')
        ax3.set_ylabel('Latency (ms)')
        ax3.set_title('Min/Mean/Max Latency')
        ax3.legend()
        ax3.grid(axis='y', alpha=0.3)

        # 4. Requests per second (approximate)
        ax4 = axes[1, 1]
        rps = 1000 / level_data['Mean_ms']
        bars = ax4.bar(services, rps, color=['#3498db', '#e74c3c', '#2ecc71', '#f39c12'])
        ax4.set_ylabel('Requests/Second')
        ax4.set_title('Throughput (Approx. RPS)')
        ax4.grid(axis='y', alpha=0.3)

        # Add value labels
        for bar in bars:
            height = bar.get_height()
            ax4.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.0f}',
                    ha='center', va='bottom', fontsize=9)

        plt.tight_layout()
        output_file = os.path.join(output_dir, f'{level}_latency_comparison.png')
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"Created: {output_file}")

def plot_throughput_comparison(df, output_dir):
    """Create throughput comparison across all levels."""
    levels = df['Level'].unique()
    services = df['Service'].unique()

    fig, ax = plt.subplots(figsize=(14, 8))

    x = np.arange(len(levels))
    width = 0.2

    colors = {'python': '#3498db', 'php': '#e74c3c', 'go': '#2ecc71', 'cpp': '#f39c12'}

    for i, service in enumerate(services):
        service_data = df[df['Service'] == service]
        rps = []
        for level in levels:
            level_row = service_data[service_data['Level'] == level]
            if not level_row.empty:
                rps.append(1000 / level_row['Mean_ms'].values[0])
            else:
                rps.append(0)

        ax.bar(x + i * width, rps, width, label=service.upper(), color=colors.get(service, '#95a5a6'))

    ax.set_ylabel('Requests/Second', fontsize=12)
    ax.set_xlabel('Test Level', fontsize=12)
    ax.set_title('Throughput Comparison Across All Levels', fontsize=14, fontweight='bold')
    ax.set_xticks(x + width * 1.5)
    ax.set_xticklabels(['Hello World', 'Normal Work', 'CPU-Intensive', 'String Processing'])
    ax.legend(loc='upper right')
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    output_file = os.path.join(output_dir, 'throughput_comparison_all_levels.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Created: {output_file}")

def plot_performance_multipliers(df, output_dir):
    """Calculate and visualize performance multipliers."""
    levels = df['Level'].unique()

    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle('Performance Multipliers (Relative to Slowest)', fontsize=16, fontweight='bold')

    for idx, level in enumerate(levels):
        ax = axes[idx // 2, idx % 2]
        level_data = df[df['Level'] == level]

        # Calculate RPS for each service
        services = level_data['Service'].values
        rps = 1000 / level_data['Mean_ms'].values

        # Calculate multipliers relative to slowest
        min_rps = rps.min()
        multipliers = rps / min_rps

        bars = ax.barh(services, multipliers, color=['#3498db', '#e74c3c', '#2ecc71', '#f39c12'])
        ax.set_xlabel('Speed Multiplier')
        ax.set_title(f'{level.replace("_", " ").title()}')
        ax.grid(axis='x', alpha=0.3)

        # Add value labels
        for bar in bars:
            width = bar.get_width()
            ax.text(width, bar.get_y() + bar.get_height()/2.,
                   f'{width:.2f}x',
                   ha='left', va='center', fontsize=9, fontweight='bold')

    plt.tight_layout()
    output_file = os.path.join(output_dir, 'performance_multipliers.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Created: {output_file}")

def plot_memory_efficiency(df, output_dir):
    """Create memory efficiency comparison (placeholder - requires actual memory data)."""
    # This will be populated when we have actual container memory metrics

    fig, ax = plt.subplots(figsize=(12, 6))

    # Placeholder data - will be replaced with actual metrics
    services = ['Python', 'PHP', 'Go', 'C++']
    idle_memory = [150, 120, 15, 8]  # Estimated MB
    loaded_memory = [250, 200, 50, 30]  # Estimated MB

    x = np.arange(len(services))
    width = 0.35

    ax.bar(x - width/2, idle_memory, width, label='Idle', color='#3498db', alpha=0.8)
    ax.bar(x + width/2, loaded_memory, width, label='Under Load', color='#e74c3c', alpha=0.8)

    ax.set_ylabel('Memory Usage (MB)', fontsize=12)
    ax.set_title('Memory Usage Comparison (Estimated)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(services)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    # Add note about placeholder data
    ax.text(0.5, 0.95, 'Note: Placeholder data - run benchmarks for actual metrics',
            transform=ax.transAxes, ha='center', va='top',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5),
            fontsize=9)

    plt.tight_layout()
    output_file = os.path.join(output_dir, 'memory_comparison_estimated.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Created: {output_file}")

def plot_radar_chart(df, output_dir):
    """Create radar chart for multi-dimensional comparison."""
    levels = df['Level'].unique()
    services = df['Service'].unique()

    # Normalize metrics for radar chart (inverse for latency - lower is better)
    categories = levels

    fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(projection='polar'))

    angles = np.linspace(0, 2 * np.pi, len(categories), endpoint=False).tolist()
    angles += angles[:1]  # Complete the circle

    colors = {'python': '#3498db', 'php': '#e74c3c', 'go': '#2ecc71', 'cpp': '#f39c12'}

    for service in services:
        service_data = df[df['Service'] == service]
        values = []

        for level in categories:
            level_row = service_data[service_data['Level'] == level]
            if not level_row.empty:
                # Use inverse of mean latency, normalized
                rps = 1000 / level_row['Mean_ms'].values[0]
                values.append(rps)
            else:
                values.append(0)

        # Normalize values to 0-100 scale
        max_val = max(values) if max(values) > 0 else 1
        values = [v / max_val * 100 for v in values]
        values += values[:1]  # Complete the circle

        ax.plot(angles, values, 'o-', linewidth=2, label=service.upper(), color=colors.get(service, '#95a5a6'))
        ax.fill(angles, values, alpha=0.15, color=colors.get(service, '#95a5a6'))

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels([l.replace('_', '\n').title() for l in categories])
    ax.set_ylim(0, 100)
    ax.set_title('Performance Radar Chart (Normalized)', fontsize=14, fontweight='bold', pad=20)
    ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1))
    ax.grid(True)

    plt.tight_layout()
    output_file = os.path.join(output_dir, 'performance_radar.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Created: {output_file}")

def plot_latency_heatmap(df, output_dir):
    """Create heatmap showing latency across services and levels."""
    pivot_data = df.pivot(index='Service', columns='Level', values='Mean_ms')

    # Reorder columns
    level_order = ['level1_hello', 'level2_normal', 'level3_cpu', 'level4_strings']
    pivot_data = pivot_data[level_order]

    fig, ax = plt.subplots(figsize=(12, 6))

    sns.heatmap(pivot_data, annot=True, fmt='.2f', cmap='RdYlGn_r',
                cbar_kws={'label': 'Mean Latency (ms)'},
                linewidths=0.5, ax=ax)

    ax.set_title('Latency Heatmap - Lower is Better', fontsize=14, fontweight='bold', pad=20)
    ax.set_xlabel('Test Level', fontsize=12)
    ax.set_ylabel('Service', fontsize=12)

    # Format x-axis labels
    ax.set_xticklabels(['Hello World', 'Normal Work', 'CPU-Intensive', 'String Processing'], rotation=45, ha='right')
    ax.set_yticklabels([s.upper() for s in pivot_data.index], rotation=0)

    plt.tight_layout()
    output_file = os.path.join(output_dir, 'latency_heatmap.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Created: {output_file}")

def main():
    if len(sys.argv) < 2:
        results_dir = "./results"
    else:
        results_dir = sys.argv[1]

    if len(sys.argv) < 3:
        output_dir = "./visualizations"
    else:
        output_dir = sys.argv[2]

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    print("Loading benchmark data...")
    df = load_summary_data(results_dir)

    if df is None or df.empty:
        print("No data to visualize")
        return

    print(f"Loaded {len(df)} data points")
    print("\nGenerating visualizations...")

    # Generate all visualizations
    plot_latency_comparison(df, output_dir)
    plot_throughput_comparison(df, output_dir)
    plot_performance_multipliers(df, output_dir)
    plot_latency_heatmap(df, output_dir)
    plot_radar_chart(df, output_dir)
    plot_memory_efficiency(df, output_dir)

    print(f"\n✓ All visualizations saved to: {output_dir}")
    print("\nGenerated charts:")
    print("  - Latency comparison charts (per level)")
    print("  - Throughput comparison (all levels)")
    print("  - Performance multipliers")
    print("  - Latency heatmap")
    print("  - Performance radar chart")
    print("  - Memory comparison (estimated)")

if __name__ == "__main__":
    main()
