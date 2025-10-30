#!/usr/bin/env python3
"""Comprehensive Balance Analysis for Dodge, Snake, and Memory Match variants"""

import json
import math
from datetime import datetime

# Load variant files
def load_json(path):
    with open(path, 'r') as f:
        return json.load(f)

dodge_variants = load_json('assets/data/variants/dodge_variants.json')
snake_variants = load_json('assets/data/variants/snake_variants.json')
memory_variants = load_json('assets/data/variants/memory_match_variants.json')

# Base costs and exponents from base_game_definitions.json
game_configs = {
    'dodge': {
        'base_cost': 175,
        'exponent': 1.5,
    },
    'snake': {
        'base_cost': 150,
        'exponent': 1.5,
    },
    'memory': {
        'base_cost': 200,
        'exponent': 1.2,
    }
}

# Calculate cost for a variant
def calculate_cost(base_cost, exponent, clone_index):
    if clone_index == 0:
        return base_cost
    else:
        return base_cost * (clone_index ** exponent)

# Calculate multiplier for a variant
def calculate_multiplier(clone_index):
    if clone_index == 0 or clone_index == 1:
        return 1
    else:
        return clone_index

# Formulas
def dodge_formula(dodges, collisions, multiplier):
    return ((dodges * dodges) / (collisions + 1)) * multiplier

def snake_formula(length, time, multiplier):
    return ((length ** 3 * 5) / time) * multiplier

def memory_formula(matches, combo, time, multiplier):
    return ((matches * matches * (combo + 1) * 50) / time) * multiplier

# Analysis results
results = {
    'dodge': [],
    'snake': [],
    'memory': []
}

# Analyze Dodge variants
print("=== ANALYZING DODGE VARIANTS ===")
for variant in dodge_variants:
    clone_index = variant['clone_index']
    multiplier = calculate_multiplier(clone_index)
    cost = calculate_cost(game_configs['dodge']['base_cost'],
                         game_configs['dodge']['exponent'],
                         clone_index)

    # Theoretical max assumptions for dodge:
    # - victory_limit = 30 (default)
    # - collisions = 0 (perfect play)
    victory_limit = variant.get('victory_limit', 30)
    dodges = victory_limit
    collisions = 0

    max_power = dodge_formula(dodges, collisions, multiplier)
    power_per_cost = max_power / cost

    results['dodge'].append({
        'index': clone_index,
        'name': variant['name'],
        'cost': cost,
        'multiplier': multiplier,
        'victory_limit': victory_limit,
        'max_power': max_power,
        'power_per_cost': power_per_cost
    })

    print(f"Clone {clone_index}: {variant['name']}")
    print(f"  Cost: {cost:.2f} | Multiplier: {multiplier} | Victory Limit: {victory_limit}")
    print(f"  Max Power: {max_power:.2f} | Power/Cost: {power_per_cost:.4f}")

# Analyze Snake variants
print("\n=== ANALYZING SNAKE VARIANTS ===")
for variant in snake_variants:
    clone_index = variant['clone_index']
    multiplier = calculate_multiplier(clone_index)
    cost = calculate_cost(game_configs['snake']['base_cost'],
                         game_configs['snake']['exponent'],
                         clone_index)

    # Theoretical max assumptions for snake:
    # - victory_limit = 20 (default length)
    # - time = victory_limit * 2 seconds (optimistic completion time)
    victory_limit = variant.get('victory_limit', 20)
    length = victory_limit
    time = length * 2  # 2 seconds per segment

    max_power = snake_formula(length, time, multiplier)
    power_per_cost = max_power / cost

    results['snake'].append({
        'index': clone_index,
        'name': variant['name'],
        'cost': cost,
        'multiplier': multiplier,
        'victory_limit': victory_limit,
        'max_power': max_power,
        'power_per_cost': power_per_cost
    })

    print(f"Clone {clone_index}: {variant['name']}")
    print(f"  Cost: {cost:.2f} | Multiplier: {multiplier} | Victory Limit: {victory_limit}")
    print(f"  Max Power: {max_power:.2f} | Power/Cost: {power_per_cost:.4f}")

# Analyze Memory Match variants
print("\n=== ANALYZING MEMORY MATCH VARIANTS ===")
for variant in memory_variants:
    clone_index = variant['clone_index']
    multiplier = calculate_multiplier(clone_index)
    cost = calculate_cost(game_configs['memory']['base_cost'],
                         game_configs['memory']['exponent'],
                         clone_index)

    # Theoretical max assumptions for memory:
    # - card_count = 12 (default)
    # - pairs = card_count / 2
    # - time = pairs * 2.5 (2.5 seconds per pair)
    # - combo = pairs (perfect combo chain)
    card_count = variant.get('card_count', 12)
    pairs = card_count // 2
    matches = pairs
    combo = pairs
    time = pairs * 2.5

    max_power = memory_formula(matches, combo, time, multiplier)
    power_per_cost = max_power / cost

    results['memory'].append({
        'index': clone_index,
        'name': variant['name'],
        'cost': cost,
        'multiplier': multiplier,
        'card_count': card_count,
        'pairs': pairs,
        'max_power': max_power,
        'power_per_cost': power_per_cost
    })

    print(f"Clone {clone_index}: {variant['name']}")
    print(f"  Cost: {cost:.2f} | Multiplier: {multiplier} | Cards: {card_count}")
    print(f"  Max Power: {max_power:.2f} | Power/Cost: {power_per_cost:.4f}")

# Generate summary statistics
print("\n=== SUMMARY STATISTICS ===")

def calculate_stats(game_results, game_name):
    total_power_per_cost = sum(r['power_per_cost'] for r in game_results)
    count = len(game_results)
    avg_ratio = total_power_per_cost / count

    max_ratio = max(game_results, key=lambda r: r['power_per_cost'])
    min_ratio = min(game_results, key=lambda r: r['power_per_cost'])

    print(f"\n{game_name}:")
    print(f"  Total Variants: {count}")
    print(f"  Average Power/Cost: {avg_ratio:.4f}")
    print(f"  Best Ratio: {max_ratio['power_per_cost']:.4f} ({max_ratio['name']}, Clone {max_ratio['index']})")
    print(f"  Worst Ratio: {min_ratio['power_per_cost']:.4f} ({min_ratio['name']}, Clone {min_ratio['index']})")

    return avg_ratio, max_ratio, min_ratio

dodge_stats = calculate_stats(results['dodge'], "DODGE GAMES")
snake_stats = calculate_stats(results['snake'], "SNAKE GAMES")
memory_stats = calculate_stats(results['memory'], "MEMORY MATCH GAMES")

# Generate markdown report
print("\n=== GENERATING MARKDOWN REPORT ===")

def generate_markdown():
    md = []

    md.append("# Comprehensive Balance Analysis")
    md.append("")
    md.append(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    md.append("")
    md.append("## Methodology")
    md.append("")
    md.append("### Formulas Used")
    md.append("")
    md.append("- **Dodge**: `(dodges² / (collisions + 1)) × multiplier`")
    md.append("- **Snake**: `((length³ × 5) / time) × multiplier`")
    md.append("- **Memory**: `((matches² × (combo + 1) × 50) / time) × multiplier`")
    md.append("")
    md.append("### Cost Calculation")
    md.append("")
    md.append("- **Dodge**: base_cost = 175, exponent = 1.5")
    md.append("- **Snake**: base_cost = 150, exponent = 1.5")
    md.append("- **Memory**: base_cost = 200, exponent = 1.2")
    md.append("")
    md.append("Cost Formula: `cost = base_cost × (clone_index ^ exponent)` (for clone_index > 0)")
    md.append("")
    md.append("### Multiplier Calculation")
    md.append("")
    md.append("- Clone 0 and 1: multiplier = 1")
    md.append("- Clone 2+: multiplier = clone_index")
    md.append("")
    md.append("### Theoretical Max Assumptions")
    md.append("")
    md.append("- **Dodge**: victory_limit dodges, 0 collisions (perfect play)")
    md.append("- **Snake**: victory_limit length, time = length × 2 seconds")
    md.append("- **Memory**: pairs = card_count / 2, time = pairs × 2.5, combo = pairs")
    md.append("")

    # Dodge variants table
    md.append("## Dodge Variants (First 15 + Last 5)")
    md.append("")
    md.append("| Clone | Name | Cost | Multiplier | Victory Limit | Max Power | Power/Cost |")
    md.append("|-------|------|------|------------|---------------|-----------|------------|")

    # First 15
    for r in results['dodge'][:15]:
        md.append(f"| {r['index']} | {r['name']} | {r['cost']:.2f} | {r['multiplier']} | {r['victory_limit']} | {r['max_power']:.2f} | {r['power_per_cost']:.4f} |")

    if len(results['dodge']) > 20:
        md.append("| ... | ... | ... | ... | ... | ... | ... |")

    # Last 5
    for r in results['dodge'][-5:]:
        md.append(f"| {r['index']} | {r['name']} | {r['cost']:.2f} | {r['multiplier']} | {r['victory_limit']} | {r['max_power']:.2f} | {r['power_per_cost']:.4f} |")

    md.append("")

    # Snake variants table
    md.append("## Snake Variants (First 15 + Last 5)")
    md.append("")
    md.append("| Clone | Name | Cost | Multiplier | Victory Limit | Max Power | Power/Cost |")
    md.append("|-------|------|------|------------|---------------|-----------|------------|")

    # First 15
    for r in results['snake'][:15]:
        md.append(f"| {r['index']} | {r['name']} | {r['cost']:.2f} | {r['multiplier']} | {r['victory_limit']} | {r['max_power']:.2f} | {r['power_per_cost']:.4f} |")

    if len(results['snake']) > 20:
        md.append("| ... | ... | ... | ... | ... | ... | ... |")

    # Last 5
    for r in results['snake'][-5:]:
        md.append(f"| {r['index']} | {r['name']} | {r['cost']:.2f} | {r['multiplier']} | {r['victory_limit']} | {r['max_power']:.2f} | {r['power_per_cost']:.4f} |")

    md.append("")

    # Memory variants table
    md.append("## Memory Match Variants (All Variants)")
    md.append("")
    md.append("| Clone | Name | Cost | Multiplier | Cards | Pairs | Max Power | Power/Cost |")
    md.append("|-------|------|------|------------|-------|-------|-----------|------------|")

    for r in results['memory']:
        md.append(f"| {r['index']} | {r['name']} | {r['cost']:.2f} | {r['multiplier']} | {r['card_count']} | {r['pairs']} | {r['max_power']:.2f} | {r['power_per_cost']:.4f} |")

    md.append("")

    # Summary statistics
    md.append("## Summary Statistics")
    md.append("")

    for game_type, game_name in [('dodge', 'Dodge Games'), ('snake', 'Snake Games'), ('memory', 'Memory Match Games')]:
        game_results = results[game_type]
        total_power_per_cost = sum(r['power_per_cost'] for r in game_results)
        count = len(game_results)
        avg_ratio = total_power_per_cost / count
        max_ratio = max(game_results, key=lambda r: r['power_per_cost'])
        min_ratio = min(game_results, key=lambda r: r['power_per_cost'])

        md.append(f"### {game_name}")
        md.append("")
        md.append(f"- **Total Variants**: {count}")
        md.append(f"- **Average Power/Cost Ratio**: {avg_ratio:.4f}")
        md.append(f"- **Best Ratio**: {max_ratio['power_per_cost']:.4f} ({max_ratio['name']}, Clone {max_ratio['index']})")
        md.append(f"- **Worst Ratio**: {min_ratio['power_per_cost']:.4f} ({min_ratio['name']}, Clone {min_ratio['index']})")
        md.append("")

    # Comparison analysis
    md.append("## Comparison Analysis")
    md.append("")

    dodge_avg = sum(r['power_per_cost'] for r in results['dodge']) / len(results['dodge'])
    snake_avg = sum(r['power_per_cost'] for r in results['snake']) / len(results['snake'])
    memory_avg = sum(r['power_per_cost'] for r in results['memory']) / len(results['memory'])

    md.append("| Game Type | Avg Power/Cost | Relative Value |")
    md.append("|-----------|----------------|----------------|")
    md.append(f"| Dodge | {dodge_avg:.4f} | 1.00x |")
    md.append(f"| Snake | {snake_avg:.4f} | {snake_avg / dodge_avg:.2f}x |")
    md.append(f"| Memory | {memory_avg:.4f} | {memory_avg / dodge_avg:.2f}x |")
    md.append("")

    md.append("### Key Findings")
    md.append("")

    # Determine which game type is most efficient
    best_game = "Dodge"
    best_avg = dodge_avg
    if snake_avg > best_avg:
        best_game = "Snake"
        best_avg = snake_avg
    if memory_avg > best_avg:
        best_game = "Memory"
        best_avg = memory_avg

    md.append(f"- **Most Efficient Game Type**: {best_game} ({best_avg:.4f} avg power/cost)")
    md.append("")
    md.append("### Progression Analysis")
    md.append("")
    md.append("**Early Game (Clone 0-5)**:")
    md.append("- Low costs, multiplier = 1 for first two variants")
    md.append("- Power/cost ratios are highest in early game")
    md.append("- Clone 0 and 1 offer identical multipliers but different costs")
    md.append("")
    md.append("**Mid Game (Clone 6-20)**:")
    md.append("- Costs increase exponentially (^1.5 for Dodge/Snake, ^1.2 for Memory)")
    md.append("- Multipliers scale linearly (= clone_index)")
    md.append("- Power/cost ratios decline due to exponential cost growth outpacing linear multiplier growth")
    md.append("")
    md.append("**Late Game (Clone 21+)**:")
    md.append("- Extremely high costs due to exponential scaling")
    md.append("- High multipliers partially offset cost growth")
    md.append("- Diminishing returns on power per token invested")
    md.append("- Late-game variants are primarily for completionist players")
    md.append("")

    # Special victory limit analysis for dodge
    md.append("### Dodge Victory Limit Variations")
    md.append("")

    # Find dodge variants with different victory limits
    dodge_by_victory_limit = {}
    for r in results['dodge']:
        vl = r['victory_limit']
        if vl not in dodge_by_victory_limit:
            dodge_by_victory_limit[vl] = []
        dodge_by_victory_limit[vl].append(r)

    if len(dodge_by_victory_limit) > 1:
        md.append("Some Dodge variants have custom victory limits:")
        md.append("")
        for vl in sorted(dodge_by_victory_limit.keys()):
            variants = dodge_by_victory_limit[vl]
            if vl != 30:  # Only show non-default
                md.append(f"- **Victory Limit {vl}**: {len(variants)} variants")
                avg_power = sum(v['max_power'] for v in variants) / len(variants)
                md.append(f"  - Average Max Power: {avg_power:.2f}")
        md.append("")

    # Special victory limit analysis for snake
    md.append("### Snake Victory Limit Variations")
    md.append("")

    snake_by_victory_limit = {}
    for r in results['snake']:
        vl = r['victory_limit']
        if vl not in snake_by_victory_limit:
            snake_by_victory_limit[vl] = []
        snake_by_victory_limit[vl].append(r)

    if len(snake_by_victory_limit) > 1:
        md.append("Some Snake variants have custom victory limits:")
        md.append("")
        for vl in sorted(snake_by_victory_limit.keys()):
            variants = snake_by_victory_limit[vl]
            if vl != 20:  # Only show non-default
                md.append(f"- **Victory Limit {vl}**: {len(variants)} variants")
                avg_power = sum(v['max_power'] for v in variants) / len(variants)
                md.append(f"  - Average Max Power: {avg_power:.2f}")
        md.append("")

    # Memory card count variations
    md.append("### Memory Match Card Count Variations")
    md.append("")

    memory_by_cards = {}
    for r in results['memory']:
        cards = r['card_count']
        if cards not in memory_by_cards:
            memory_by_cards[cards] = []
        memory_by_cards[cards].append(r)

    md.append("Memory Match variants have different card counts:")
    md.append("")
    for cards in sorted(memory_by_cards.keys()):
        variants = memory_by_cards[cards]
        avg_power = sum(v['max_power'] for v in variants) / len(variants)
        avg_ratio = sum(v['power_per_cost'] for v in variants) / len(variants)
        md.append(f"- **{cards} Cards ({cards//2} pairs)**: {len(variants)} variants")
        md.append(f"  - Average Max Power: {avg_power:.2f}")
        md.append(f"  - Average Power/Cost: {avg_ratio:.4f}")
    md.append("")

    return '\n'.join(md)

markdown_content = generate_markdown()

# Save to file
output_path = 'documentation/comprehensive_balance_analysis.md'
with open(output_path, 'w') as f:
    f.write(markdown_content)

print(f"Report saved to {output_path}")
print("\n=== ANALYSIS COMPLETE ===")
