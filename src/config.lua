-- config.lua: Central configuration for game tuning parameters

local Config = {
    -- Player Data
    start_tokens = 500,
    upgrade_costs = {
        cpu_speed = 500, -- Base cost for level 1
        overclock = 1000,
        auto_dodge = 2000 
        -- Cost multiplier per level: base_cost * (current_level + 1)
    },

    -- VM Manager
    vm_base_cost = 1000, -- Base cost for the first additional VM slot (slot #2)
    vm_cost_exponent = 2, -- Cost scales as base_cost * (exponent ^ (current_slots - 1))
    vm_max_slots = 10,
    vm_base_cycle_time = 60, -- Seconds per cycle before upgrades
    vm_cpu_speed_bonus_per_level = 0.1, -- 10% faster per level
    vm_overclock_bonus_per_level = 0.05, -- 5% more power per level

    -- Game Data
    -- Game Cloning
    clone_cost_exponent = 0.8,            -- Cost scales as base_cost * (multiplier ^ cost_exponent)
    clone_difficulty_step = 5, -- Every 5 clones, the difficulty level increases by 1
    
    -- Auto-Play Performance Scaling (relative to base auto-play performance)
    auto_play_scaling = {
        -- Metrics that should decrease with higher difficulty (harder to achieve)
        performance_reduction_factor = 0.08, -- e.g., kills = base * (1 - diff * factor)
        -- Metrics that should increase with higher difficulty (more penalties)
        penalty_increase_factor = 0.15, -- e.g., deaths = base * (1 + diff * factor)
        -- Time-based metrics that worsen
        time_penalty_factor = 0.05, -- e.g., time = base * (1 - diff*factor) makes sense.
        -- Bonus metrics that decrease
        bonus_reduction_factor = 0.10 -- e.g., perfect = base * (1 - diff * factor)
    },

    -- Save Manager
    save_file_name = "save.json",
    save_version = "1.0",

    -- Cheat Engine
    cheat_costs = {
        speed = 500,       -- Speed Modifiers
        advantage = 1000,  -- Advantage Modifiers
        performance = 2000,  -- Performance Boosters
        aim = 5000,        -- Aim Assist (Fake)
        god = 10000        -- God Mode (Fake)
    }
}

return Config