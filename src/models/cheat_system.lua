-- src/models/cheat_system.lua
-- Manages cheat definitions and active cheats for the next game
local Object = require('class')
-- No longer needs config
local CheatSystem = Object:extend('CheatSystem')

function CheatSystem:init()
    
    -- This now just defines the *names* and *descriptions*
    -- The costs and levels are in base_game_definitions.json
    self.cheat_definitions = {
        speed_modifier = {
            id = "speed_modifier",
            name = "Speed Modifier",
            description = "Slows enemies, objects, or timers."
        },
        advantage_modifier = {
            id = "advantage_modifier",
            name = "Advantage",
            description = "Grants extra lives or collisions."
        },
        performance_modifier = {
            id = "performance_modifier",
            name = "Score Multiplier",
            description = "Multiplies your final score/power."
        },
        aim_assist = {
            id = "aim_assist",
            name = "Aim Assist (FAKE)",
            description = "Automatically targets enemies. (Not really)",
            is_fake = true
        },
        god_mode = {
            id = "god_mode",
            name = "God Mode (FAKE)",
            description = "Become invincible! (Or not)",
            is_fake = true
        }
    }
    
    -- This stores the *final calculated values* to be applied, not just booleans
    -- e.g. { game_id = { speed_modifier = 0.7, advantage_modifier = { deaths = 2 } } }
    self.active_cheats = {} 
end

-- Get a list of all cheat definitions
function CheatSystem:getCheatDefinitions()
    return self.cheat_definitions
end

-- Get the *static definition* (name, desc) for a cheat
function CheatSystem:getCheatDefinition(cheat_id)
    return self.cheat_definitions[cheat_id]
end

-- Called by CheatEngineState to set cheats for the next run
-- selected_cheats is now a table of *values*, not booleans
-- e.g. { speed_modifier = 0.7, advantage_modifier = { deaths = 2 } }
function CheatSystem:activateCheats(game_id, selected_cheats)
    self.active_cheats = {} -- Clear previous cheats
    self.active_cheats[game_id] = selected_cheats
    print("Cheats activated for " .. game_id)
end

-- Called by MinigameState to get cheats for the starting game
function CheatSystem:getActiveCheats(game_id)
    return self.active_cheats[game_id]
end

-- Called by MinigameState after applying cheats
function CheatSystem:consumeCheats(game_id)
    self.active_cheats[game_id] = nil
end

return CheatSystem