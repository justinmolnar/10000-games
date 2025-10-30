-- Comprehensive Balance Analysis for Dodge, Snake, and Memory Match variants
-- This script calculates theoretical max power and power/cost ratios

local json = require("lib.json")

-- Load variant files
local function load_json(path)
    local file = io.open(path, "r")
    if not file then
        print("Error: Could not open " .. path)
        return nil
    end
    local content = file:read("*all")
    file:close()
    return json.decode(content)
end

local dodge_variants = load_json("assets/data/variants/dodge_variants.json")
local snake_variants = load_json("assets/data/variants/snake_variants.json")
local memory_variants = load_json("assets/data/variants/memory_match_variants.json")

-- Base costs and exponents from base_game_definitions.json
local game_configs = {
    dodge = {
        base_cost = 175,
        exponent = 1.5,
        formula = function(dodges, collisions, multiplier)
            return ((dodges * dodges) / (collisions + 1)) * multiplier
        end
    },
    snake = {
        base_cost = 150,
        exponent = 1.5,
        formula = function(length, time, multiplier)
            return ((length * length * length * 5) / time) * multiplier
        end
    },
    memory = {
        base_cost = 200,
        exponent = 1.2,
        formula = function(matches, combo, time, multiplier)
            return ((matches * matches * (combo + 1) * 50) / time) * multiplier
        end
    }
}

-- Calculate cost for a variant
local function calculate_cost(base_cost, exponent, clone_index)
    if clone_index == 0 then
        return base_cost
    else
        return base_cost * (clone_index ^ exponent)
    end
end

-- Calculate multiplier for a variant
local function calculate_multiplier(clone_index)
    if clone_index == 0 or clone_index == 1 then
        return 1
    else
        return clone_index
    end
end

-- Analysis results
local results = {
    dodge = {},
    snake = {},
    memory = {}
}

-- Analyze Dodge variants
print("=== ANALYZING DODGE VARIANTS ===")
for i, variant in ipairs(dodge_variants) do
    local clone_index = variant.clone_index
    local multiplier = calculate_multiplier(clone_index)
    local cost = calculate_cost(game_configs.dodge.base_cost, game_configs.dodge.exponent, clone_index)

    -- Theoretical max assumptions for dodge:
    -- - victory_limit = 30 (default)
    -- - collisions = 0 (perfect play)
    local victory_limit = variant.victory_limit or 30
    local dodges = victory_limit
    local collisions = 0

    local max_power = game_configs.dodge.formula(dodges, collisions, multiplier)
    local power_per_cost = max_power / cost

    table.insert(results.dodge, {
        index = clone_index,
        name = variant.name,
        cost = cost,
        multiplier = multiplier,
        victory_limit = victory_limit,
        max_power = max_power,
        power_per_cost = power_per_cost
    })

    print(string.format("Clone %d: %s", clone_index, variant.name))
    print(string.format("  Cost: %.2f | Multiplier: %d | Victory Limit: %d", cost, multiplier, victory_limit))
    print(string.format("  Max Power: %.2f | Power/Cost: %.4f", max_power, power_per_cost))
end

-- Analyze Snake variants
print("\n=== ANALYZING SNAKE VARIANTS ===")
for i, variant in ipairs(snake_variants) do
    local clone_index = variant.clone_index
    local multiplier = calculate_multiplier(clone_index)
    local cost = calculate_cost(game_configs.snake.base_cost, game_configs.snake.exponent, clone_index)

    -- Theoretical max assumptions for snake:
    -- - victory_limit = 20 (default length)
    -- - time = victory_limit * 2 seconds (optimistic completion time)
    local victory_limit = variant.victory_limit or 20
    local length = victory_limit
    local time = length * 2  -- 2 seconds per segment

    local max_power = game_configs.snake.formula(length, time, multiplier)
    local power_per_cost = max_power / cost

    table.insert(results.snake, {
        index = clone_index,
        name = variant.name,
        cost = cost,
        multiplier = multiplier,
        victory_limit = victory_limit,
        max_power = max_power,
        power_per_cost = power_per_cost
    })

    print(string.format("Clone %d: %s", clone_index, variant.name))
    print(string.format("  Cost: %.2f | Multiplier: %d | Victory Limit: %d", cost, multiplier, victory_limit))
    print(string.format("  Max Power: %.2f | Power/Cost: %.4f", max_power, power_per_cost))
end

-- Analyze Memory Match variants
print("\n=== ANALYZING MEMORY MATCH VARIANTS ===")
for i, variant in ipairs(memory_variants) do
    local clone_index = variant.clone_index
    local multiplier = calculate_multiplier(clone_index)
    local cost = calculate_cost(game_configs.memory.base_cost, game_configs.memory.exponent, clone_index)

    -- Theoretical max assumptions for memory:
    -- - card_count = 12 (default)
    -- - pairs = card_count / 2
    -- - time = pairs * 2.5 (2.5 seconds per pair)
    -- - combo = pairs (perfect combo chain)
    local card_count = variant.card_count or 12
    local pairs = card_count / 2
    local matches = pairs
    local combo = pairs
    local time = pairs * 2.5

    local max_power = game_configs.memory.formula(matches, combo, time, multiplier)
    local power_per_cost = max_power / cost

    table.insert(results.memory, {
        index = clone_index,
        name = variant.name,
        cost = cost,
        multiplier = multiplier,
        card_count = card_count,
        pairs = pairs,
        max_power = max_power,
        power_per_cost = power_per_cost
    })

    print(string.format("Clone %d: %s", clone_index, variant.name))
    print(string.format("  Cost: %.2f | Multiplier: %d | Cards: %d", cost, multiplier, card_count))
    print(string.format("  Max Power: %.2f | Power/Cost: %.4f", max_power, power_per_cost))
end

-- Generate summary statistics
print("\n=== SUMMARY STATISTICS ===")

local function calculate_stats(game_results, game_name)
    local total_power_per_cost = 0
    local count = #game_results
    local max_ratio = {value = 0, name = "", index = 0}
    local min_ratio = {value = math.huge, name = "", index = 0}

    for _, result in ipairs(game_results) do
        total_power_per_cost = total_power_per_cost + result.power_per_cost
        if result.power_per_cost > max_ratio.value then
            max_ratio = {value = result.power_per_cost, name = result.name, index = result.index}
        end
        if result.power_per_cost < min_ratio.value then
            min_ratio = {value = result.power_per_cost, name = result.name, index = result.index}
        end
    end

    local avg_ratio = total_power_per_cost / count

    print(string.format("\n%s:", game_name))
    print(string.format("  Total Variants: %d", count))
    print(string.format("  Average Power/Cost: %.4f", avg_ratio))
    print(string.format("  Best Ratio: %.4f (%s, Clone %d)", max_ratio.value, max_ratio.name, max_ratio.index))
    print(string.format("  Worst Ratio: %.4f (%s, Clone %d)", min_ratio.value, min_ratio.name, min_ratio.index))
end

calculate_stats(results.dodge, "DODGE GAMES")
calculate_stats(results.snake, "SNAKE GAMES")
calculate_stats(results.memory, "MEMORY MATCH GAMES")

-- Generate markdown report
print("\n=== GENERATING MARKDOWN REPORT ===")

local function generate_markdown()
    local md = {}

    table.insert(md, "# Comprehensive Balance Analysis")
    table.insert(md, "")
    table.insert(md, "**Generated:** " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(md, "")
    table.insert(md, "## Methodology")
    table.insert(md, "")
    table.insert(md, "### Formulas Used")
    table.insert(md, "")
    table.insert(md, "- **Dodge**: `(dodges² / (collisions + 1)) × multiplier`")
    table.insert(md, "- **Snake**: `((length³ × 5) / time) × multiplier`")
    table.insert(md, "- **Memory**: `((matches² × (combo + 1) × 50) / time) × multiplier`")
    table.insert(md, "")
    table.insert(md, "### Cost Calculation")
    table.insert(md, "")
    table.insert(md, "- **Dodge**: base_cost = 175, exponent = 1.5")
    table.insert(md, "- **Snake**: base_cost = 150, exponent = 1.5")
    table.insert(md, "- **Memory**: base_cost = 200, exponent = 1.2")
    table.insert(md, "")
    table.insert(md, "Cost Formula: `cost = base_cost × (clone_index ^ exponent)` (for clone_index > 0)")
    table.insert(md, "")
    table.insert(md, "### Multiplier Calculation")
    table.insert(md, "")
    table.insert(md, "- Clone 0 and 1: multiplier = 1")
    table.insert(md, "- Clone 2+: multiplier = clone_index")
    table.insert(md, "")
    table.insert(md, "### Theoretical Max Assumptions")
    table.insert(md, "")
    table.insert(md, "- **Dodge**: victory_limit dodges, 0 collisions (perfect play)")
    table.insert(md, "- **Snake**: victory_limit length, time = length × 2 seconds")
    table.insert(md, "- **Memory**: pairs = card_count / 2, time = pairs × 2.5, combo = pairs")
    table.insert(md, "")

    -- Dodge variants table
    table.insert(md, "## Dodge Variants (First 15 + Last 5)")
    table.insert(md, "")
    table.insert(md, "| Clone | Name | Cost | Multiplier | Victory Limit | Max Power | Power/Cost |")
    table.insert(md, "|-------|------|------|------------|---------------|-----------|------------|")

    -- First 15
    for i = 1, math.min(15, #results.dodge) do
        local r = results.dodge[i]
        table.insert(md, string.format("| %d | %s | %.2f | %d | %d | %.2f | %.4f |",
            r.index, r.name, r.cost, r.multiplier, r.victory_limit, r.max_power, r.power_per_cost))
    end

    if #results.dodge > 20 then
        table.insert(md, "| ... | ... | ... | ... | ... | ... | ... |")
    end

    -- Last 5
    for i = math.max(16, #results.dodge - 4), #results.dodge do
        local r = results.dodge[i]
        table.insert(md, string.format("| %d | %s | %.2f | %d | %d | %.2f | %.4f |",
            r.index, r.name, r.cost, r.multiplier, r.victory_limit, r.max_power, r.power_per_cost))
    end

    table.insert(md, "")

    -- Snake variants table
    table.insert(md, "## Snake Variants (First 15 + Last 5)")
    table.insert(md, "")
    table.insert(md, "| Clone | Name | Cost | Multiplier | Victory Limit | Max Power | Power/Cost |")
    table.insert(md, "|-------|------|------|------------|---------------|-----------|------------|")

    -- First 15
    for i = 1, math.min(15, #results.snake) do
        local r = results.snake[i]
        table.insert(md, string.format("| %d | %s | %.2f | %d | %d | %.2f | %.4f |",
            r.index, r.name, r.cost, r.multiplier, r.victory_limit, r.max_power, r.power_per_cost))
    end

    if #results.snake > 20 then
        table.insert(md, "| ... | ... | ... | ... | ... | ... | ... |")
    end

    -- Last 5
    for i = math.max(16, #results.snake - 4), #results.snake do
        local r = results.snake[i]
        table.insert(md, string.format("| %d | %s | %.2f | %d | %d | %.2f | %.4f |",
            r.index, r.name, r.cost, r.multiplier, r.victory_limit, r.max_power, r.power_per_cost))
    end

    table.insert(md, "")

    -- Memory variants table
    table.insert(md, "## Memory Match Variants (All Variants)")
    table.insert(md, "")
    table.insert(md, "| Clone | Name | Cost | Multiplier | Cards | Pairs | Max Power | Power/Cost |")
    table.insert(md, "|-------|------|------|------------|-------|-------|-----------|------------|")

    for i = 1, #results.memory do
        local r = results.memory[i]
        table.insert(md, string.format("| %d | %s | %.2f | %d | %d | %d | %.2f | %.4f |",
            r.index, r.name, r.cost, r.multiplier, r.card_count, r.pairs, r.max_power, r.power_per_cost))
    end

    table.insert(md, "")

    -- Summary statistics
    table.insert(md, "## Summary Statistics")
    table.insert(md, "")

    local function add_game_stats(game_results, game_name)
        local total_power_per_cost = 0
        local count = #game_results
        local max_ratio = {value = 0, name = "", index = 0}
        local min_ratio = {value = math.huge, name = "", index = 0}

        for _, result in ipairs(game_results) do
            total_power_per_cost = total_power_per_cost + result.power_per_cost
            if result.power_per_cost > max_ratio.value then
                max_ratio = {value = result.power_per_cost, name = result.name, index = result.index}
            end
            if result.power_per_cost < min_ratio.value then
                min_ratio = {value = result.power_per_cost, name = result.name, index = result.index}
            end
        end

        local avg_ratio = total_power_per_cost / count

        table.insert(md, string.format("### %s", game_name))
        table.insert(md, "")
        table.insert(md, string.format("- **Total Variants**: %d", count))
        table.insert(md, string.format("- **Average Power/Cost Ratio**: %.4f", avg_ratio))
        table.insert(md, string.format("- **Best Ratio**: %.4f (%s, Clone %d)", max_ratio.value, max_ratio.name, max_ratio.index))
        table.insert(md, string.format("- **Worst Ratio**: %.4f (%s, Clone %d)", min_ratio.value, min_ratio.name, min_ratio.index))
        table.insert(md, "")
    end

    add_game_stats(results.dodge, "Dodge Games")
    add_game_stats(results.snake, "Snake Games")
    add_game_stats(results.memory, "Memory Match Games")

    -- Comparison analysis
    table.insert(md, "## Comparison Analysis")
    table.insert(md, "")

    local dodge_avg = 0
    for _, r in ipairs(results.dodge) do dodge_avg = dodge_avg + r.power_per_cost end
    dodge_avg = dodge_avg / #results.dodge

    local snake_avg = 0
    for _, r in ipairs(results.snake) do snake_avg = snake_avg + r.power_per_cost end
    snake_avg = snake_avg / #results.snake

    local memory_avg = 0
    for _, r in ipairs(results.memory) do memory_avg = memory_avg + r.power_per_cost end
    memory_avg = memory_avg / #results.memory

    table.insert(md, "| Game Type | Avg Power/Cost | Relative Value |")
    table.insert(md, "|-----------|----------------|----------------|")
    table.insert(md, string.format("| Dodge | %.4f | 1.00x |", dodge_avg))
    table.insert(md, string.format("| Snake | %.4f | %.2fx |", snake_avg, snake_avg / dodge_avg))
    table.insert(md, string.format("| Memory | %.4f | %.2fx |", memory_avg, memory_avg / dodge_avg))
    table.insert(md, "")

    table.insert(md, "### Key Findings")
    table.insert(md, "")

    -- Determine which game type is most efficient
    local best_game = "Dodge"
    local best_avg = dodge_avg
    if snake_avg > best_avg then
        best_game = "Snake"
        best_avg = snake_avg
    end
    if memory_avg > best_avg then
        best_game = "Memory"
        best_avg = memory_avg
    end

    table.insert(md, string.format("- **Most Efficient Game Type**: %s (%.4f avg power/cost)", best_game, best_avg))
    table.insert(md, "")
    table.insert(md, "### Progression Analysis")
    table.insert(md, "")
    table.insert(md, "**Early Game (Clone 0-5)**:")
    table.insert(md, "- Low costs, multiplier = 1 for first two variants")
    table.insert(md, "- Power/cost ratios are highest in early game")
    table.insert(md, "")
    table.insert(md, "**Mid Game (Clone 6-20)**:")
    table.insert(md, "- Costs increase exponentially")
    table.insert(md, "- Multipliers scale linearly (= clone_index)")
    table.insert(md, "- Power/cost ratios decline due to exponential cost growth")
    table.insert(md, "")
    table.insert(md, "**Late Game (Clone 21+)**:")
    table.insert(md, "- Extremely high costs due to exponential scaling")
    table.insert(md, "- High multipliers partially offset cost growth")
    table.insert(md, "- Diminishing returns on power per token invested")
    table.insert(md, "")

    return table.concat(md, "\n")
end

local markdown_content = generate_markdown()

-- Save to file
local output_file = io.open("documentation/comprehensive_balance_analysis.md", "w")
if output_file then
    output_file:write(markdown_content)
    output_file:close()
    print("Report saved to documentation/comprehensive_balance_analysis.md")
else
    print("Error: Could not write to output file")
    print("\n--- MARKDOWN OUTPUT ---\n")
    print(markdown_content)
end

print("\n=== ANALYSIS COMPLETE ===")
