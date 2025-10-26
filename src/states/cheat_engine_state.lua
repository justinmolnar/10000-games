-- src/states/cheat_engine_state.lua
-- Controller for dynamic parameter modification system
local Object = require('class')
local Strings = require('src.utils.strings')
local Paths = require('src.paths')
local json = require('lib.json')
local CheatEngineView = require('src.views.cheat_engine_view')
local CheatEngineState = Object:extend('CheatEngineState')

function CheatEngineState:init(player_data, game_data, state_machine, save_manager, cheat_system, di)
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.cheat_system = cheat_system
    self.di = di
    self.event_bus = di and di.eventBus

    self.view = CheatEngineView:new(self, di)

    -- Game selection
    self.unlocked_games = {} -- Only show unlocked games
    self.game_scroll_offset = 1
    self.selected_game_id = nil
    self.selected_game = nil
    self.selected_variant = nil -- The actual variant JSON data

    -- Parameter modification
    self.modifiable_params = {} -- Array of parameter definitions
    self.current_modifications = {} -- Current modifications for selected game
    self.param_scroll_offset = 0
    self.selected_param_index = 1

    -- Modification controls
    self.step_size = 1 -- Default step size (1, 5, 10, 100, or "max")

    self.viewport = nil
end

function CheatEngineState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    self.view:updateLayout(width, height)
end

function CheatEngineState:enter()
    -- Load only UNLOCKED games
    local all_games = self.game_data:getAllGames()
    self.unlocked_games = {}

    for _, game in ipairs(all_games) do
        if self.player_data:isGameUnlocked(game.id) then
            table.insert(self.unlocked_games, game)
        end
    end

    -- Sort by ID with natural number sorting
    table.sort(self.unlocked_games, function(a, b)
        local a_base, a_num = a.id:match("^(.-)_(%d+)$")
        local b_base, b_num = b.id:match("^(.-)_(%d+)$")
        if a_base and b_base and a_num and b_num then
            if a_base == b_base then
                return tonumber(a_num) < tonumber(b_num)
            else
                return a_base < b_base
            end
        end
        return a.id < b.id
    end)

    -- Select the first game by default
    if #self.unlocked_games > 0 then
        self:selectGame(self.unlocked_games[1].id)
        self.game_scroll_offset = 1
    else
        self:resetSelection()
    end

    print("CheatEngine loaded " .. #self.unlocked_games .. " unlocked games")
end

function CheatEngineState:resetSelection()
    self.selected_game_id = nil
    self.selected_game = nil
    self.selected_variant = nil
    self.modifiable_params = {}
    self.current_modifications = {}
    self.param_scroll_offset = 0
    self.selected_param_index = 1
end

function CheatEngineState:selectGame(game_id)
    if not game_id then
        self:resetSelection()
        return
    end

    self.selected_game_id = game_id
    self.selected_game = self.game_data:getGame(game_id)

    if not self.selected_game then
        print("Error: Could not find game data for " .. game_id)
        self:resetSelection()
        return
    end

    -- Load variant data from JSON
    self.selected_variant = self:loadVariantData(game_id)

    if not self.selected_variant or not next(self.selected_variant) then
        print("Warning: No variant data loaded for " .. game_id)
        self.modifiable_params = {}
        self.current_modifications = {}
        return
    end

    -- Get current modifications from player_data
    self.current_modifications = self.player_data:getGameModifications(game_id)

    -- Build modifiable parameters list from variant
    self.modifiable_params = self.cheat_system:getModifiableParameters(self.selected_variant)

    -- Apply current modifications to displayed values
    for _, param in ipairs(self.modifiable_params) do
        if self.current_modifications[param.key] then
            param.value = self.current_modifications[param.key].modified
        end
    end

    self.selected_param_index = 1
    self.param_scroll_offset = 0

    print("Loaded " .. #self.modifiable_params .. " parameters for " .. game_id)
end

function CheatEngineState:loadVariantData(game_id)
    -- Parse game_id to determine which variant file and clone_index
    -- Format: "dodge_1" -> "dodge", clone 0 (0-indexed)
    -- Format: "dodge_42" -> "dodge", clone 41
    local base_name, clone_number = game_id:match("^(.-)_(%d+)$")

    if not base_name or not clone_number then
        print("Error: Invalid game_id format: " .. game_id)
        return {}
    end

    local clone_index = tonumber(clone_number) - 1 -- Convert to 0-indexed
    local variant_file = "variants/" .. base_name .. "_variants.json"
    local file_path = Paths.assets.data .. variant_file

    -- Read variant file
    local read_ok, contents = pcall(love.filesystem.read, file_path)
    if not read_ok or not contents then
        print("Error: Could not read " .. file_path)
        return {}
    end

    -- Parse JSON
    local decode_ok, variants = pcall(json.decode, contents)
    if not decode_ok or not variants then
        print("Error: Could not decode " .. file_path)
        return {}
    end

    -- Find variant with matching clone_index
    for _, variant in ipairs(variants) do
        if variant.clone_index == clone_index then
            return variant
        end
    end

    print("Error: Could not find variant with clone_index " .. clone_index .. " in " .. file_path)
    return {}
end

function CheatEngineState:modifyParameter(param_key, new_value, step_size)
    if not self.selected_game_id then
        print("No game selected")
        return
    end

    -- Find parameter
    local param = nil
    for _, p in ipairs(self.modifiable_params) do
        if p.key == param_key then
            param = p
            break
        end
    end

    if not param then
        print("Parameter not found: " .. param_key)
        return
    end

    -- Apply modification via CheatSystem
    local result = self.cheat_system:applyModification(
        self.player_data,
        self.selected_game_id,
        param_key,
        param.type,
        param.original,
        new_value
    )

    if result.success then
        -- Update local state
        param.value = new_value
        self.current_modifications = self.player_data:getGameModifications(self.selected_game_id)

        -- Save
        self.save_manager.save(self.player_data)

        print(string.format("Modified %s: %s -> %s (cost: %d, budget: %d)",
            param_key, tostring(param.original), tostring(new_value),
            result.cost, result.new_budget))
    else
        print("Modification failed: " .. (result.error or "Unknown error"))
        love.window.showMessageBox(
            Strings.get('messages.error_title', 'Error'),
            result.error or "Modification failed",
            "warning"
        )
    end
end

function CheatEngineState:resetParameter(param_key)
    if not self.selected_game_id then return end

    local result = self.cheat_system:resetParameter(self.player_data, self.selected_game_id, param_key)

    if result.success then
        -- Update local state
        for _, param in ipairs(self.modifiable_params) do
            if param.key == param_key then
                param.value = param.original
                break
            end
        end

        self.current_modifications = self.player_data:getGameModifications(self.selected_game_id)
        self.save_manager.save(self.player_data)

        print("Reset " .. param_key .. ", refunded " .. result.refund .. " credits")
    end
end

function CheatEngineState:resetAllParameters()
    if not self.selected_game_id then return end

    local result = self.cheat_system:resetAllModifications(self.player_data, self.selected_game_id)

    if result.success then
        -- Reset all parameter values to original
        for _, param in ipairs(self.modifiable_params) do
            param.value = param.original
        end

        self.current_modifications = {}
        self.save_manager.save(self.player_data)

        print("Reset all parameters, refunded " .. result.refund .. " credits")
    end
end

function CheatEngineState:incrementParameter()
    if not self.modifiable_params[self.selected_param_index] then return end

    local param = self.modifiable_params[self.selected_param_index]

    if param.type == "number" then
        local step = self.step_size == "max" and 99999 or self.step_size
        local new_value = param.value + step
        self:modifyParameter(param.key, new_value, self.step_size)
    elseif param.type == "boolean" then
        self:modifyParameter(param.key, not param.value, 1)
    end
    -- TODO: Handle string/enum and array types
end

function CheatEngineState:decrementParameter()
    if not self.modifiable_params[self.selected_param_index] then return end

    local param = self.modifiable_params[self.selected_param_index]

    if param.type == "number" then
        local step = self.step_size == "max" and 99999 or self.step_size
        local new_value = param.value - step
        self:modifyParameter(param.key, new_value, self.step_size)
    elseif param.type == "boolean" then
        self:modifyParameter(param.key, not param.value, 1)
    end
end

function CheatEngineState:launchGame()
    if not self.selected_game_id then
        love.window.showMessageBox(
            Strings.get('messages.error_title', 'Error'),
            "No game selected.",
            "warning"
        )
        return nil
    end

    if not self.selected_variant or not next(self.selected_variant) then
        love.window.showMessageBox(
            Strings.get('messages.error_title', 'Error'),
            "Variant data not loaded. Cannot launch game.",
            "error"
        )
        return nil
    end

    -- Get modified variant with all modifications applied
    local modified_variant = self.cheat_system:getModifiedVariant(
        self.selected_variant,
        self.current_modifications
    )

    -- Publish event if modifications exist
    if self.event_bus and next(self.current_modifications) then
        pcall(self.event_bus.publish, self.event_bus,
            'cheats_applied_to_launch',
            self.selected_game_id,
            self.current_modifications)
    end

    -- Return event for DesktopState to handle
    return {
        type = "event",
        name = "launch_minigame",
        game_data = self.selected_game,
        variant = modified_variant -- Pass modified variant
    }
end

function CheatEngineState:update(dt)
    if not self.viewport then return end

    -- Delegate to view
    self.view:update(
        dt,
        self.unlocked_games,
        self.selected_game_id,
        self.modifiable_params,
        self.current_modifications,
        self.step_size,
        self.viewport.width,
        self.viewport.height
    )
end

function CheatEngineState:draw()
    if not self.viewport then return end

    self.view:drawWindowed(
        self.unlocked_games,
        self.selected_game_id,
        self.modifiable_params,
        self.current_modifications,
        self.player_data,
        self.step_size,
        self.selected_param_index,
        self.viewport.width,
        self.viewport.height,
        self.game_scroll_offset,
        self.param_scroll_offset
    )
end

function CheatEngineState:keypressed(key)
    local result_event = nil
    local handled = true

    if key == 'escape' then
        result_event = { type = "close_window" }

    -- Game navigation
    elseif key == 'up' then
        if #self.modifiable_params > 0 then
            -- Navigate parameters
            self.selected_param_index = math.max(1, self.selected_param_index - 1)

            -- Adjust scroll if needed
            if self.selected_param_index < self.param_scroll_offset + 1 then
                self.param_scroll_offset = math.max(0, self.selected_param_index - 1)
            end
        else
            -- Navigate game list
            local current_idx = -1
            for i, g in ipairs(self.unlocked_games) do
                if g.id == self.selected_game_id then
                    current_idx = i
                    break
                end
            end

            if current_idx > 1 then
                self:selectGame(self.unlocked_games[current_idx - 1].id)
                if current_idx - 1 < self.game_scroll_offset then
                    self.game_scroll_offset = current_idx - 1
                end
            end
        end

    elseif key == 'down' then
        if #self.modifiable_params > 0 then
            -- Navigate parameters
            self.selected_param_index = math.min(#self.modifiable_params, self.selected_param_index + 1)

            -- Adjust scroll if needed
            local visible_params = self.view:getVisibleParamCount(self.viewport and self.viewport.height or 600)
            if self.selected_param_index > self.param_scroll_offset + visible_params then
                self.param_scroll_offset = self.selected_param_index - visible_params
            end
        else
            -- Navigate game list
            local current_idx = -1
            for i, g in ipairs(self.unlocked_games) do
                if g.id == self.selected_game_id then
                    current_idx = i
                    break
                end
            end

            if current_idx > 0 and current_idx < #self.unlocked_games then
                self:selectGame(self.unlocked_games[current_idx + 1].id)
                local visible_games = self.view:getVisibleGameCount(self.viewport and self.viewport.height or 600)
                if current_idx + 1 >= self.game_scroll_offset + visible_games then
                    self.game_scroll_offset = current_idx + 1 - visible_games + 1
                end
            end
        end

    -- Parameter modification
    elseif key == 'left' or key == 'a' then
        self:decrementParameter()

    elseif key == 'right' or key == 'd' then
        self:incrementParameter()

    -- Step size controls
    elseif key == '1' then
        self.step_size = 1
        print("Step size: 1")

    elseif key == '2' then
        self.step_size = 5
        print("Step size: 5")

    elseif key == '3' then
        self.step_size = 10
        print("Step size: 10")

    elseif key == '4' then
        self.step_size = 100
        print("Step size: 100")

    elseif key == 'm' then
        self.step_size = "max"
        print("Step size: MAX")

    -- Reset controls
    elseif key == 'r' then
        local param = self.modifiable_params[self.selected_param_index]
        if param then
            self:resetParameter(param.key)
        end

    elseif key == 'x' then
        self:resetAllParameters()

    -- Launch game
    elseif key == 'return' then
        result_event = self:launchGame()

    else
        handled = false
    end

    -- Return event or interaction signal
    if result_event then
        return result_event
    elseif handled then
        return { type = "content_interaction" }
    else
        return false
    end
end

function CheatEngineState:mousepressed(x, y, button)
    if not self.viewport then return false end

    -- Check bounds
    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end

    -- Delegate to view
    local event = self.view:mousepressed(
        x, y, button,
        self.unlocked_games,
        self.selected_game_id,
        self.modifiable_params,
        self.current_modifications,
        self.player_data,
        self.step_size,
        self.selected_param_index,
        self.viewport.width,
        self.viewport.height
    )

    if not event then return false end

    local result_event = nil

    -- Handle view events
    if event.name == "select_game" then
        self:selectGame(event.id)
        result_event = { type = "content_interaction" }

    elseif event.name == "select_param" then
        self.selected_param_index = event.index
        result_event = { type = "content_interaction" }

    elseif event.name == "increment_param" then
        local param = self.modifiable_params[event.index]
        if param and param.type == "number" then
            local step = event.step_size == "max" and 99999 or event.step_size
            self:modifyParameter(param.key, param.value + step, event.step_size)
        end
        result_event = { type = "content_interaction" }

    elseif event.name == "decrement_param" then
        local param = self.modifiable_params[event.index]
        if param and param.type == "number" then
            local step = event.step_size == "max" and 99999 or event.step_size
            self:modifyParameter(param.key, param.value - step, event.step_size)
        end
        result_event = { type = "content_interaction" }

    elseif event.name == "toggle_param" then
        local param = self.modifiable_params[event.index]
        if param and param.type == "boolean" then
            self:modifyParameter(param.key, not param.value, 1)
        end
        result_event = { type = "content_interaction" }

    elseif event.name == "reset_param" then
        local param = self.modifiable_params[event.index]
        if param then
            self:resetParameter(param.key)
        end
        result_event = { type = "content_interaction" }

    elseif event.name == "reset_all" then
        self:resetAllParameters()
        result_event = { type = "content_interaction" }

    elseif event.name == "set_step_size" then
        self.step_size = event.value
        print("Step size: " .. tostring(event.value))
        result_event = { type = "content_interaction" }

    elseif event.name == "launch_game" then
        result_event = self:launchGame()
    end

    return result_event
end

function CheatEngineState:mousemoved(x, y, dx, dy)
    if not self.viewport then return end

    if self.view and self.view.mousemoved then
        local ok, ev = pcall(self.view.mousemoved, self.view, x, y, dx, dy)
        if ok and ev and ev.name == 'content_interaction' then
            return { type = 'content_interaction' }
        end
    end
end

function CheatEngineState:mousereleased(x, y, button)
    if not self.viewport then return end

    if self.view and self.view.mousereleased then
        pcall(self.view.mousereleased, self.view, x, y, button)
        return { type = 'content_interaction' }
    end
end

function CheatEngineState:wheelmoved(x, y)
    if not self.viewport then return end

    local mx, my = love.mouse.getPosition()
    local view_x = self.viewport.x
    local view_y = self.viewport.y

    -- Check if mouse is within viewport
    if mx >= view_x and mx <= view_x + self.viewport.width and
       my >= view_y and my <= view_y + self.viewport.height then

        -- Delegate scrolling to view
        local new_game_offset, new_param_offset = self.view:wheelmoved(
            x, y,
            #self.unlocked_games,
            #self.modifiable_params,
            self.viewport.width,
            self.viewport.height
        )

        if new_game_offset then
            self.game_scroll_offset = new_game_offset
        end

        if new_param_offset then
            self.param_scroll_offset = new_param_offset
        end
    end
end

return CheatEngineState
