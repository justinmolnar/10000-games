-- src/states/cheat_engine_state.lua
-- Controller for dynamic parameter modification system
local Object = require('class')
local Strings = require('src.utils.strings')
local Paths = require('src.paths')
local json = require('lib.json')
local CheatEngineView = require('src.views.cheat_engine_view')
local ScrollbarController = require('src.controllers.scrollbar_controller')
local MessageBox = require('src.utils.message_box')
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

    -- Create two scrollbar controllers (one for game list, one for parameter list)
    self.game_scrollbar = ScrollbarController:new({
        unit_size = 25, -- item height (matches CheatEngineView.item_h)
        step_units = 1
    })
    self.param_scrollbar = ScrollbarController:new({
        unit_size = 32, -- matches CheatEngineView.param_row_h
        step_units = 1
    })

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
    self.step_size = 0.05 -- Default step size as fraction of param range (0.05, 0.10, 0.25, or "max")

    -- Slider drag state
    self.dragging_slider = nil -- { param_index = N, param_key = "key" }

    -- Skill tree tab
    self.active_tab = "params" -- "params" or "skill_tree"
    self.hovered_skill_node = nil

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
        if self.player_data:isGameUnlocked(game.id) and self.player_data:isGameCompleted(game.id) then
            -- Load variant data to get the actual variant name
            local variant_data = self:loadVariantData(game.id)
            local game_entry = {
                id = game.id,
                display_name = (variant_data and variant_data.name) or game.display_name,
                icon_sprite = game.icon_sprite
            }
            table.insert(self.unlocked_games, game_entry)
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
    local decode_ok, variant_file_data = pcall(json.decode, contents)
    if not decode_ok or not variant_file_data then
        print("Error: Could not decode " .. file_path)
        return {}
    end

    -- Phase 3: Variant files now have wrapper with metadata
    local variants_array = variant_file_data.variants or variant_file_data
    if not variants_array then
        print("Error: No variants array in " .. file_path)
        return {}
    end

    -- Find variant with matching clone_index
    for _, variant in ipairs(variants_array) do
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

    -- Clamp value to valid range (param.min/max always set by getModifiableParameters)
    local clamped_value, was_clamped = self.cheat_system:clampParameterValue(param_key, new_value, param.min, param.max)
    if was_clamped then
        print(string.format("Value clamped: %s -> %s (range: %s - %s)",
            tostring(new_value), tostring(clamped_value),
            tostring(param.min), tostring(param.max)))
    end

    -- Apply modification via CheatSystem (with water discount + skill tree discount)
    local water_level = self.player_data:getWaterUpgradeLevel(self.selected_game_id)
    local skill_reduction = self.player_data:getSkillTreeBonus("global_cost_reduction")
    local result = self.cheat_system:applyModification(
        self.player_data,
        self.selected_game_id,
        param_key,
        param.type,
        param.original,
        clamped_value,
        water_level,
        skill_reduction
    )

    if result.success then
        -- Update local state
        param.value = clamped_value
        self.current_modifications = self.player_data:getGameModifications(self.selected_game_id)

        -- Save
        self.save_manager.save(self.player_data)

        print(string.format("Modified %s: %s -> %s (cost: %d, budget: %d)",
            param_key, tostring(param.original), tostring(new_value),
            result.cost, result.new_budget))
    else
        print("Modification failed: " .. (result.error or "Unknown error"))
        if self.di and self.di.systemSounds then
            self.di.systemSounds:playSystemSound('error')
        end
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

function CheatEngineState:snapSliderValue(param, raw_value)
    -- Round to integer for integer-valued params
    if param.original == math.floor(param.original) then
        raw_value = math.floor(raw_value + 0.5)
    end
    return raw_value
end

function CheatEngineState:resolveStep(param)
    if self.step_size == "max" then return 99999 end
    local lo = param.min or 0
    local hi = param.max or math.max(math.abs(param.original) * 2, 1)
    local range = hi - lo
    if range <= 0 then range = 1 end
    local step = range * self.step_size
    -- Keep integer steps for integer-valued params
    if param.original == math.floor(param.original) then
        step = math.max(1, math.floor(step + 0.5))
    end
    return step
end

function CheatEngineState:incrementParameter()
    if not self.modifiable_params[self.selected_param_index] then return end

    local param = self.modifiable_params[self.selected_param_index]

    if param.type == "number" then
        local step = self:resolveStep(param)
        local new_value = param.value + step
        self:modifyParameter(param.key, new_value, self.step_size)
    elseif param.type == "boolean" then
        self:modifyParameter(param.key, not param.value, 1)
    end
end

function CheatEngineState:decrementParameter()
    if not self.modifiable_params[self.selected_param_index] then return end

    local param = self.modifiable_params[self.selected_param_index]

    if param.type == "number" then
        local step = self:resolveStep(param)
        local new_value = param.value - step
        self:modifyParameter(param.key, new_value, self.step_size)
    elseif param.type == "boolean" then
        self:modifyParameter(param.key, not param.value, 1)
    end
end

function CheatEngineState:launchGame()
    if not self.selected_game_id then
        MessageBox.warning(
            Strings.get('messages.error_title', 'Error'),
            "No game selected."
        )
        return nil
    end

    if not self.selected_variant or not next(self.selected_variant) then
        MessageBox.error(
            Strings.get('messages.error_title', 'Error'),
            "Variant data not loaded. Cannot launch game."
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
    -- Pass original variant when modifications exist so token calculation
    -- uses original difficulty values (cheats = efficiency, not penalty)
    return {
        type = "event",
        name = "launch_minigame",
        game_data = self.selected_game,
        variant = modified_variant,
        original_variant = next(self.current_modifications) and self.selected_variant or nil
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
        self.viewport.height,
        self.active_tab,
        self.player_data
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
        self.param_scroll_offset,
        self.active_tab
    )
end

function CheatEngineState:upgradeWater()
    if not self.selected_game_id then
        print("Water upgrade: no game selected")
        return
    end

    local config = self.di and self.di.config
    local water_config = config and config.water_upgrades
    if not water_config then
        print("Water upgrade: no water_config found in di.config")
        return
    end

    local current_level = self.player_data:getWaterUpgradeLevel(self.selected_game_id)
    local max_level = water_config.max_level or 5
    if current_level >= max_level then
        print("Water upgrade: already at max level " .. max_level)
        return
    end

    local next_level = current_level + 1
    local costs = water_config.costs or {}
    local cost = costs[next_level]
    if not cost then
        print("Water upgrade: no cost defined for level " .. next_level)
        return
    end

    local current_water = self.player_data:getWater()
    print(string.format("Water upgrade: need %d, have %d", cost, current_water))

    if not self.player_data:hasWater(cost) then
        print("Water upgrade: insufficient water")
        if self.di and self.di.systemSounds then
            self.di.systemSounds:playSystemSound('error')
        end
        return
    end

    self.player_data:spendWater(cost)
    self.player_data:setWaterUpgradeLevel(self.selected_game_id, next_level)
    self.save_manager.save(self.player_data)

    if self.di and self.di.systemSounds then
        self.di.systemSounds:playSystemSound('confirm')
    end

    -- Refresh modifications display (costs changed)
    self.current_modifications = self.player_data:getGameModifications(self.selected_game_id)

    print(string.format("Water upgrade: %s now level %d/%d", self.selected_game_id, next_level, max_level))
end

function CheatEngineState:upgradeSkill(node_id)
    local config = self.di and self.di.config
    if not config then return end

    if not self.player_data:canUnlockSkill(node_id, config) then
        print("Skill upgrade: prerequisites not met for " .. node_id)
        if self.di and self.di.systemSounds then
            self.di.systemSounds:playSystemSound('error')
        end
        return
    end

    local cost = self.player_data:getSkillCost(node_id, config)
    if not self.player_data:hasWater(cost) then
        print(string.format("Skill upgrade: need %d water, have %d", cost, self.player_data:getWater()))
        if self.di and self.di.systemSounds then
            self.di.systemSounds:playSystemSound('error')
        end
        return
    end

    self.player_data:spendWater(cost)
    local new_level = self.player_data:getSkillLevel(node_id) + 1
    self.player_data:setSkillLevel(node_id, new_level)
    self.save_manager.save(self.player_data)

    if self.di and self.di.systemSounds then
        self.di.systemSounds:playSystemSound('confirm')
    end

    local node = config.water_skill_tree.nodes[node_id]
    print(string.format("Skill upgrade: %s now level %d/%d", node_id, new_level, node.max_level))
end

function CheatEngineState:keypressed(key)
    local result_event = nil
    local handled = true

    if key == 'escape' then
        result_event = { type = "close_window" }

    elseif key == 'tab' then
        self.active_tab = (self.active_tab == "params") and "skill_tree" or "params"

    -- Water upgrade
    elseif key == 'w' then
        self:upgradeWater()

    -- Game navigation (up/down)
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

    elseif key == 'down' or key == 's' then
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
        self.step_size = 0.05
        print("Step size: 5%")

    elseif key == '2' then
        self.step_size = 0.10
        print("Step size: 10%")

    elseif key == '3' then
        self.step_size = 0.25
        print("Step size: 25%")

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

    -- Handle game list scrollbar first
    local game_scroll_event = self.game_scrollbar:mousepressed(x, y, button, (self.game_scroll_offset or 1) - 1)
    if game_scroll_event then
        if game_scroll_event.scrolled then
            self.game_scroll_offset = math.max(1, math.min(math.floor(game_scroll_event.new_offset) + 1, math.max(1, #self.unlocked_games)))
        end
        return { type = "content_interaction" }
    end

    -- Handle parameter list scrollbar
    local param_scroll_event = self.param_scrollbar:mousepressed(x, y, button, self.param_scroll_offset or 0)
    if param_scroll_event then
        if param_scroll_event.scrolled then
            self.param_scroll_offset = math.max(0, math.floor(param_scroll_event.new_offset))
        end
        return { type = "content_interaction" }
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
        self.viewport.height,
        self.active_tab
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
            local step = self:resolveStep(param)
            self:modifyParameter(param.key, param.value + step, self.step_size)
        end
        result_event = { type = "content_interaction" }

    elseif event.name == "decrement_param" then
        local param = self.modifiable_params[event.index]
        if param and param.type == "number" then
            local step = self:resolveStep(param)
            self:modifyParameter(param.key, param.value - step, self.step_size)
        end
        result_event = { type = "content_interaction" }

    elseif event.name == "slider_set" then
        local param = self.modifiable_params[event.index]
        if param and param.type == "number" then
            self.selected_param_index = event.index
            local snapped = self:snapSliderValue(param, event.value)
            self:modifyParameter(param.key, snapped, self.step_size)
            -- Start dragging
            self.dragging_slider = { param_index = event.index, param_key = param.key }
        end
        result_event = { type = "content_interaction" }

    elseif event.name == "toggle_param" then
        local param = self.modifiable_params[event.index]
        if param and param.type == "boolean" then
            self.selected_param_index = event.index
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

    elseif event.name == "water_upgrade" then
        self:upgradeWater()
        result_event = { type = "content_interaction" }

    elseif event.name == "upgrade_skill" then
        self:upgradeSkill(event.node_id)
        result_event = { type = "content_interaction" }

    elseif event.name == "switch_tab" then
        self.active_tab = event.tab
        result_event = { type = "content_interaction" }

    elseif event.name == "launch_game" then
        result_event = self:launchGame()

    elseif event.name == "content_interaction" then
        -- Scrollbar interaction without scroll change (e.g., started dragging)
        result_event = { type = "content_interaction" }
    end

    return result_event
end

function CheatEngineState:mousemoved(x, y, dx, dy)
    if not self.viewport then return false end

    -- Handle slider dragging first
    if self.dragging_slider then
        local event = self.view:mousemoved(x, y, dx, dy)
        if event and event.name == "slider_drag" then
            local param = self.modifiable_params[event.index]
            if param and param.type == "number" then
                local snapped = self:snapSliderValue(param, event.value)
                self:modifyParameter(param.key, snapped, self.step_size)
            end
            return { type = 'content_interaction' }
        end
    end

    -- Handle game list scrollbar dragging
    local game_scroll_event = self.game_scrollbar:mousemoved(x, y, dx, dy)
    if game_scroll_event and game_scroll_event.scrolled then
        self.game_scroll_offset = math.max(1, math.min(math.floor(game_scroll_event.new_offset) + 1, math.max(1, #self.unlocked_games)))
        return { type = 'content_interaction' }
    end

    -- Handle parameter list scrollbar dragging
    local param_scroll_event = self.param_scrollbar:mousemoved(x, y, dx, dy)
    if param_scroll_event and param_scroll_event.scrolled then
        self.param_scroll_offset = math.max(0, math.floor(param_scroll_event.new_offset))
        return { type = 'content_interaction' }
    end

    return false
end

function CheatEngineState:mousereleased(x, y, button)
    if not self.viewport then return false end

    -- End slider dragging
    if button == 1 and self.dragging_slider then
        self.dragging_slider = nil
        return { type = 'content_interaction' }
    end

    -- End game list scrollbar dragging
    if self.game_scrollbar:mousereleased(x, y, button) then
        return { type = 'content_interaction' }
    end

    -- End parameter list scrollbar dragging
    if self.param_scrollbar:mousereleased(x, y, button) then
        return { type = 'content_interaction' }
    end

    return false
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
