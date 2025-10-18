-- progression_manager.lua: Handles auto-completion and progression logic

local Object = require('class')
local ProgressionManager = Object:extend('ProgressionManager')

function ProgressionManager:init()
end

function ProgressionManager:checkAutoCompletion(game_id, specific_game_data, main_game_data_model, player_data)
    -- Only trigger if this is a variant (not base game)
    if not specific_game_data.variant_of then 
        return {}, 0 
    end
    
    -- Get the variant number from the ID
    local variant_num = tonumber(game_id:match("_(%d+)$"))
    if not variant_num or variant_num <= 1 then 
        return {}, 0 
    end
    
    local auto_completed_games = {}
    local auto_complete_power = 0
    
    -- Auto-complete all easier variants of the same base game
    local base_id = specific_game_data.variant_of
    
    for i = 1, variant_num - 1 do
        local variant_id = base_id:gsub("_1$", "_" .. i)
        if variant_id == base_id and i > 1 then
            -- Handle base game pattern
            variant_id = base_id:gsub("_1$", "") .. "_" .. i
        end
        
        local variant = main_game_data_model:getGame(variant_id)
        if variant then
            -- Check if not already completed manually
            local existing_perf = player_data:getGamePerformance(variant_id)
            if not existing_perf then
                -- Calculate baseline performance (70% of auto-play baseline)
                local auto_metrics = variant.auto_play_performance
                local auto_power = variant.formula_function(auto_metrics)
                
                -- Store as completed with auto-completion flag
                player_data:updateGamePerformance(
                    variant_id,
                    auto_metrics,
                    auto_power
                )
                
                auto_complete_power = auto_complete_power + auto_power
                table.insert(auto_completed_games, {
                    id = variant_id,
                    name = variant.display_name,
                    power = auto_power
                })
            end
        end
    end
    
    return auto_completed_games, auto_complete_power
end

return ProgressionManager