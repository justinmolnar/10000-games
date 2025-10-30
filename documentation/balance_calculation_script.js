// Balance calculation for all game variants
// Run with: node documentation/balance_calculation_script.js

const fs = require('fs');

// Read variant files
const dodgeVariants = JSON.parse(fs.readFileSync('assets/data/variants/dodge_variants.json', 'utf8'));
const snakeVariants = JSON.parse(fs.readFileSync('assets/data/variants/snake_variants.json', 'utf8'));
const memoryVariants = JSON.parse(fs.readFileSync('assets/data/variants/memory_match_variants.json', 'utf8'));

// Base costs and exponents
const DODGE_BASE_COST = 175;
const DODGE_EXPONENT = 1.5;
const SNAKE_BASE_COST = 150;
const SNAKE_EXPONENT = 1.5;
const MEMORY_BASE_COST = 200;
const MEMORY_EXPONENT = 1.2;

// Calculate cost
function calculateCost(baseRost, cloneIndex, exponent) {
    if (cloneIndex === 0) return baseCost;
    return Math.floor(baseCost * Math.pow(cloneIndex, exponent));
}

// Dodge formula: (dodges² / (collisions + 1)) × multiplier
function calculateDodgePower(variant) {
    const victoryLimit = variant.victory_limit || 30;
    const cloneIndex = variant.clone_index;
    const multiplier = (cloneIndex === 0 || cloneIndex === 1) ? 1 : cloneIndex;
    const basePower = (victoryLimit * victoryLimit) / 1; // 0 collisions
    return Math.floor(basePower * multiplier);
}

// Snake formula: ((length³ × 5) / time) × multiplier
function calculateSnakePower(variant) {
    const victoryLimit = variant.victory_limit || 20;
    const cloneIndex = variant.clone_index;
    const multiplier = (cloneIndex === 0 || cloneIndex === 1) ? 1 : cloneIndex;
    const time = victoryLimit * 2; // 2 seconds per food
    const basePower = (Math.pow(victoryLimit, 3) * 5) / time;
    return Math.floor(basePower * multiplier);
}

// Memory formula: ((matches² × (combo + 1) × 50) / time) × multiplier
function calculateMemoryPower(variant) {
    const cardCount = variant.card_count || 12;
    const pairs = cardCount / 2;
    const cloneIndex = variant.clone_index;
    const multiplier = (cloneIndex === 0 || cloneIndex === 1) ? 1 : cloneIndex;
    const time = pairs * 2.5; // 2.5 seconds per pair
    const basePower = (pairs * pairs * (pairs + 1) * 50) / time;
    return Math.floor(basePower * multiplier);
}

// Analyze game type
function analyzeGameType(variants, gameName, baseCost, exponent, powerFunc) {
    console.log(`\n## ${gameName} Analysis\n`);
    console.log(`Base cost: ${baseCost}, Exponent: ${exponent}\n`);
    console.log('| Clone | Name | Victory/Cards | Cost | Power | Ratio |');
    console.log('|-------|------|---------------|------|-------|-------|');

    const results = [];

    for (let i = 0; i < Math.min(15, variants.length); i++) {
        const variant = variants[i];
        const cost = calculateCost(baseCost, variant.clone_index, exponent);
        const power = powerFunc(variant);
        const ratio = cost > 0 ? (power / cost).toFixed(2) : 0;

        const victoryInfo = variant.victory_limit || variant.card_count || 'N/A';

        console.log(`| ${variant.clone_index} | ${variant.name.substring(0, 20)} | ${victoryInfo} | ${cost} | ${power} | ${ratio} |`);

        results.push({ cost, power, ratio: parseFloat(ratio) });
    }

    // Show last 5
    if (variants.length > 15) {
        console.log('| ... | ... | ... | ... | ... | ... |');
        for (let i = Math.max(15, variants.length - 5); i < variants.length; i++) {
            const variant = variants[i];
            const cost = calculateCost(baseCost, variant.clone_index, exponent);
            const power = powerFunc(variant);
            const ratio = cost > 0 ? (power / cost).toFixed(2) : 0;

            const victoryInfo = variant.victory_limit || variant.card_count || 'N/A';

            console.log(`| ${variant.clone_index} | ${variant.name.substring(0, 20)} | ${victoryInfo} | ${cost} | ${power} | ${ratio} |`);

            results.push({ cost, power, ratio: parseFloat(ratio) });
        }
    }

    // Calculate averages
    const avgRatio = results.reduce((sum, r) => sum + r.ratio, 0) / results.length;
    console.log(`\n**Average Ratio:** ${avgRatio.toFixed(2)}`);
    console.log(`**First Variant Ratio:** ${results[0].ratio}`);
    console.log(`**Last Variant Ratio:** ${results[results.length - 1].ratio}`);

    return results;
}

// Run analysis
console.log('# Comprehensive Balance Analysis\n');
console.log('**Formulas:**');
console.log('- Dodge: `(dodges² / (collisions + 1)) × multiplier`');
console.log('- Snake: `((length³ × 5) / time) × multiplier`');
console.log('- Memory: `((matches² × (combo + 1) × 50) / time) × multiplier`\n');

const dodgeResults = analyzeGameType(dodgeVariants, 'Dodge', DODGE_BASE_COST, DODGE_EXPONENT, calculateDodgePower);
const snakeResults = analyzeGameType(snakeVariants, 'Snake', SNAKE_BASE_COST, SNAKE_EXPONENT, calculateSnakePower);
const memoryResults = analyzeGameType(memoryVariants, 'Memory Match', MEMORY_BASE_COST, MEMORY_EXPONENT, calculateMemoryPower);

console.log('\n\n## Cross-Game Comparison\n');
console.log('| Game Type | First Ratio | Last Ratio | Average | Trend |');
console.log('|-----------|-------------|------------|---------|-------|');
console.log(`| Dodge | ${dodgeResults[0].ratio.toFixed(2)} | ${dodgeResults[dodgeResults.length-1].ratio.toFixed(2)} | ${(dodgeResults.reduce((s,r)=>s+r.ratio,0)/dodgeResults.length).toFixed(2)} | ${dodgeResults[0].ratio > dodgeResults[dodgeResults.length-1].ratio ? 'Declining' : 'Improving'} |`);
console.log(`| Snake | ${snakeResults[0].ratio.toFixed(2)} | ${snakeResults[snakeResults.length-1].ratio.toFixed(2)} | ${(snakeResults.reduce((s,r)=>s+r.ratio,0)/snakeResults.length).toFixed(2)} | ${snakeResults[0].ratio > snakeResults[snakeResults.length-1].ratio ? 'Declining' : 'Improving'} |`);
console.log(`| Memory | ${memoryResults[0].ratio.toFixed(2)} | ${memoryResults[memoryResults.length-1].ratio.toFixed(2)} | ${(memoryResults.reduce((s,r)=>s+r.ratio,0)/memoryResults.length).toFixed(2)} | ${memoryResults[0].ratio > memoryResults[memoryResults.length-1].ratio ? 'Declining' : 'Improving'} |`);
