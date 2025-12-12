"""
Load test results visualization for different scaling configurations.

Generates 4 graphs comparing performance metrics across user personas (p1-p4 and combined).
Each graph shows:
- Max requests per second (green) - higher is better
- Response time 50th percentile in ms (orange) - inverted (lower is better)
- Response time 95th percentile in ms (purple) - inverted (lower is better)
- Number of users (blue) - higher is better

Metrics are normalized to different y-axis scales for better comparison.
"""

import matplotlib.pyplot as plt
import numpy as np

# Data structure: [max_rps, p50_ms, p95_ms, num_users]
data = {
    "Single instance (1x m7g.med, 1x db.m5.large)": {
        "baseline": [63.6, 90, 570, 136],
        "cache-expert-bios": [54.1, 190, 1300, 136],
        "cache-expert-queue": [55.6, 81, 550, 108],
        "conversation-indexes": [40, 250, 1000, 110],
        "combined": [40.7, 110, 500, 90]
    },
    "Vertical scaling (1x m7g.large, 1x db.m5.large)": {
        "baseline": [81.6, 150, 2100, 200],
        "cache-expert-bios": [64.1, 110, 950, 152],
        "cache-expert-queue": [70.2, 890, 2800, 216],
        "conversation-indexes": [52.1, 150, 1400, 152],
        "combined": [58.3, 170, 1700, 176]
    },
    "Horizontal scaling 1 (4x m7g.med, 1x db.m5.large)": {
        "baseline": [135.5, 110, 2000, 312],
        "cache-expert-bios": [100.2, 110, 1700, 240],
        "cache-expert-queue": [124.5, 120, 1400, 296],
        "conversation-indexes": [85.3, 210, 2300, 288],
        "combined": [83.5, 120, 1300, 232]
    },
    "Horizontal scaling 2 (4x m7g.med, 1x db.m5.xlarge)": {
        "baseline": [140.5, 97, 1200, 296],
        "cache-expert-bios": [113.6, 140, 1800, 304],
        "cache-expert-queue": [119, 96, 870, 264],
        "conversation-indexes": [70.3, 110, 840, 208],
        "combined": [72.6, 160, 1400, 252]
    }
}

# Verify data integrity
print("Data Verification:")
print("=" * 80)
for config_name, config_data in data.items():
    print(f"\n{config_name}:")
    for optimization, values in config_data.items():
        rps, p50, p95, users = values
        print(f"  {optimization:22s}: RPS={rps:6.1f}, P50={p50:4.0f}ms, P95={p95:4.0f}ms, Users={users:3.0f}")
print("\n" + "=" * 80)

# Metrics configuration
metrics = [
    {"name": "Max RPS", "color": "green", "idx": 0, "invert": False},
    {"name": "P50 Response Time", "color": "orange", "idx": 1, "invert": True},
    {"name": "P95 Response Time", "color": "purple", "idx": 2, "invert": True},
    {"name": "Number of Users", "color": "blue", "idx": 3, "invert": False}
]

personas = ["baseline", "cache-expert-bios", "cache-expert-queue", "conversation-indexes", "combined"]
x_pos = np.arange(len(personas))
bar_width = 0.2
target_height = 50  # Target height for p1 values (50% of graph)

# Create each configuration graph as separate figure
for config_idx, (config_name, config_data) in enumerate(data.items()):
    # Create individual figure for this configuration
    fig, ax = plt.subplots(1, 1, figsize=(12, 8))
    
    # Calculate standardization factors based on baseline values
    # Each metric's baseline value should reach target_height
    standardization_factors = []
    for metric in metrics:
        baseline_value = config_data["baseline"][metric["idx"]]
        
        # For inverted metrics, use reciprocal (1/value)
        # Lower response time = higher bar
        if metric["invert"]:
            baseline_inverted = 1.0 / baseline_value if baseline_value > 0 else 1
            factor = target_height / baseline_inverted if baseline_inverted > 0 else 1
        else:
            factor = target_height / baseline_value if baseline_value > 0 else 1
        
        standardization_factors.append(factor)
    
    # Extract data for each metric
    for metric_idx, metric in enumerate(metrics):
        values = [config_data[persona][metric["idx"]] for persona in personas]
        original_values = values.copy()
        
        # Invert response times (lower is better)
        # Use reciprocal: 1/value so lower values produce higher bars
        if metric["invert"]:
            values = [1.0 / v if v > 0 else 0 for v in values]
        
        # Apply standardization based on p1
        values = [v * standardization_factors[metric_idx] for v in values]
        
        # Position bars with offset
        offset = (metric_idx - 1.5) * bar_width
        bars = ax.bar(x_pos + offset, values, bar_width, 
                     label=metric["name"], color=metric["color"], alpha=0.8)
        
        # Add value labels on bars
        for bar, original_val in zip(bars, original_values):
            height = bar.get_height()
            if height > 0:
                # Show original value (not inverted or scaled)
                label_text = f'{original_val:.0f}' if original_val >= 10 else f'{original_val:.1f}'
                ax.text(bar.get_x() + bar.get_width()/2., height,
                       label_text,
                       ha='center', va='bottom', fontsize=9, rotation=0)
    
    # Customize subplot
    ax.set_title(config_name + '\n(All metrics standardized: baseline = 50% height, response times inverted)', 
                fontsize=15, fontweight='bold', pad=20)
    ax.set_xticks(x_pos)
    ax.set_xticklabels(personas, fontsize=12)
    ax.legend(loc='upper left', fontsize=11)
    ax.grid(True, alpha=0.3, axis='y')
    ax.set_axisbelow(True)
    # Remove y-axis labels and ticks as values are standardized differently
    ax.set_yticklabels([])
    ax.tick_params(axis='y', which='both', left=False)
    
    # Adjust layout
    plt.tight_layout()
    
    # Save individual figure with descriptive filename
    safe_name = config_name.replace('(', '').replace(')', '').replace(' ', '_').replace(',', '')
    output_path = f'load_test_{config_idx+1}_{safe_name}.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Graph {config_idx+1} saved as: {output_path}")
    
    # Close figure to free memory
    plt.close(fig)

# Print summary statistics
print("\nSummary Statistics:")
print("=" * 80)
for config_name, config_data in data.items():
    print(f"\n{config_name}:")
    
    # Calculate averages across personas
    avg_rps = np.mean([v[0] for v in config_data.values()])
    avg_p50 = np.mean([v[1] for v in config_data.values()])
    avg_p95 = np.mean([v[2] for v in config_data.values()])
    avg_users = np.mean([v[3] for v in config_data.values()])
    
    print(f"  Average RPS: {avg_rps:.1f}")
    print(f"  Average P50: {avg_p50:.0f}ms")
    print(f"  Average P95: {avg_p95:.0f}ms")
    print(f"  Average Users: {avg_users:.0f}")
    
    # Best performing persona
    best_rps_persona = max(config_data.items(), key=lambda x: x[1][0])
    print(f"  Best RPS: {best_rps_persona[0]} ({best_rps_persona[1][0]:.1f})")
    
    best_p50_persona = min(config_data.items(), key=lambda x: x[1][1])
    print(f"  Best P50: {best_p50_persona[0]} ({best_p50_persona[1][1]:.0f}ms)")

print("\n" + "=" * 80)
