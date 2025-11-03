-- debug_state.lua: State for handling debug menu actions

local Object = require('class')
local DebugView = require('src.views.debug_view')
local DebugState = Object:extend('DebugState')

function DebugState:init(di)
    -- DI-first: prefer provided container; fall back to legacy globals if not provided
    self.di = di
    if di then
        self.player_data = di.playerData
        self.game_data = di.gameData
        self.state_machine = di.stateMachine
        self.save_manager = di.saveManager
    else
        -- Fallback legacy assumptions (not expected once DI rolled out everywhere)
        self.player_data = rawget(_G, 'player_data')
        self.game_data = rawget(_G, 'game_data')
        self.state_machine = rawget(_G, 'state_machine')
        self.save_manager = rawget(_G, 'SaveManager')
    end

    self.view = DebugView:new(self)
    self.previous_state_name = 'desktop' -- Default return state
end

function DebugState:enter(previous_state_name)
    -- Store the name of the state we came from so we can return
    self.previous_state_name = previous_state_name or 'desktop'
    print("Entered Debug Menu from: " .. self.previous_state_name)
end

function DebugState:update(dt)
    self.view:update(dt)
end

function DebugState:draw()
    -- Important: Draw the *previous* state underneath the overlay
    local prev_state = self.state_machine.states[self.previous_state_name]
    if prev_state and prev_state.draw then
        prev_state:draw()
    end
    
    -- Draw the debug menu overlay on top
    self.view:draw()
end

function DebugState:keypressed(key)
    if key == 'f5' or key == 'escape' then
        self:closeMenu()
        return true -- Handled
    end
    return false -- Not handled
end

function DebugState:mousepressed(x, y, button)
    local event = self.view:mousepressed(x, y, button)
    if not event then return false end

    if event.name == "button_click" then
        self:handleAction(event.id)
        return true -- Handled
    end
    return false
end

function DebugState:handleAction(action_id)
    print("Debug action: " .. action_id)
    if action_id == "add_tokens" then
        self.player_data:addTokens(10000)
        print("Added 10000 tokens. Total: " .. self.player_data.tokens)
        
    elseif action_id == "unlock_all" then
        local all_games = self.game_data:getAllGames()
        local count = 0
        for _, game in ipairs(all_games) do
            if self.player_data:unlockGame(game.id) then
                 count = count + 1
            end
        end
        print("Unlocked " .. count .. " new games.")
        
    elseif action_id == "complete_all" then
        local all_games = self.game_data:getAllGames()
        local count = 0
        local total_power = 0
        for _, game in ipairs(all_games) do
            local auto_metrics = game.auto_play_performance or {}
             local auto_power = game.formula_function(auto_metrics)
             -- Use updateGamePerformance's 4th arg to mark as auto-completion
             if self.player_data:updateGamePerformance(game.id, auto_metrics, auto_power, true) then
                 count = count + 1
                 total_power = total_power + auto_power
             end
             -- Also unlock if not already
             self.player_data:unlockGame(game.id)
        end
        print("Auto-completed " .. count .. " games. Total base power added: " .. math.floor(total_power))

    elseif action_id == "wipe_save" then
    local Config = rawget(_G, 'DI_CONFIG') or {}
    local save_file = (Config and Config.save_file_name) or 'save.json'
        local removed, err = love.filesystem.remove(save_file)
        if removed then
            print("Save file deleted.")
        else
            print("Could not delete save file: " .. tostring(err))
        end

        -- Re-initialize player data to its default state
        if self.player_data and self.player_data.init then
            -- We need to preserve the statistics instance
            local stats_instance = self.player_data.statistics
            self.player_data:init(stats_instance)
            print("Player data has been reset in memory.")
        end

        -- For a full reset, we restart the game.
        love.event.quit('restart')
        
    elseif action_id == "close" then
        self:closeMenu()
    end
    
    -- Save changes immediately after most actions (except wipe)
    if action_id ~= "wipe_save" and action_id ~= "close" then
       self.save_manager.save(self.player_data)
    end
end

function DebugState:closeMenu()
    print("Closing Debug Menu, returning to: " .. self.previous_state_name)
    self.state_machine:switch(self.previous_state_name)
end

return DebugState