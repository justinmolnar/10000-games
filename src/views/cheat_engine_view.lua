-- src/views/cheat_engine_view.lua
-- View for dynamic parameter modification UI
local BaseView = require('src.views.base_view')
local UIComponents = require('src.views.ui_components')
local CracktroEffects = require('src.views.cracktro_effects')
local CheatEngineView = BaseView:extend('CheatEngineView')

-- NFO-style dot-leader: pad label with dots to fill width chars
local function dotLeader(label, width)
    local dots_needed = width - #label - 1
    if dots_needed < 1 then return label .. ":" end
    return label .. string.rep(".", dots_needed) .. ":"
end

function CheatEngineView:init(controller, di)
    CheatEngineView.super.init(self, controller)
    self.controller = controller
    self.di = di

    if di and UIComponents and UIComponents.inject then
        UIComponents.inject(di)
    end

    self.sprite_manager = (di and di.spriteManager) or nil

    -- Split panel layout
    self.split_x = 280
    self.padding = 10
    self.item_h = 25  -- game list row height

    -- Game list panel
    self.game_list_x = 10
    self.game_list_y = 60
    self.game_list_w = self.split_x - 20
    self.game_list_h = 500

    -- Parameter panel
    self.param_panel_x = self.split_x + 10
    self.param_panel_y = 60
    self.param_panel_w = 700
    self.param_panel_h = 500

    -- Slider row layout
    self.param_row_h = 32
    self.rows_start_y = 55  -- relative to param_panel_y (after title + budget/step line)
    self.slider_rects = {}  -- populated during draw: [param_index] = {x, y, w, h, lo, hi}

    -- Hover state
    self.hovered_game_id = nil
    self.hovered_param_index = nil
    self.hovered_button = nil
    self.hovered_skill_node = nil

    -- Skill tree node rects (populated during draw): [node_id] = {x, y, w, h}
    self.skill_node_rects = {}

    -- Cached small font for compact skill tree nodes
    self.skill_node_font = love.graphics.newFont(9)

    -- Cracktro effects
    self.effects = CracktroEffects:new()
    self.dt = 0
end

function CheatEngineView:updateLayout(viewport_width, viewport_height)
    self.game_list_h = viewport_height - 80
    self.param_panel_h = viewport_height - 80
    self.param_panel_w = viewport_width - self.split_x - 20
end

function CheatEngineView:update(dt, games, selected_game_id, params, modifications, step_size, viewport_width, viewport_height, active_tab, player_data)
    self.dt = dt
    self.effects:update(dt)

    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    self.hovered_game_id = nil
    self.hovered_param_index = nil
    self.hovered_button = nil
    self.hovered_skill_node = nil

    if local_mx < 0 or local_mx > viewport_width or local_my < 0 or local_my > viewport_height then
        return
    end

    -- Check game list hover
    local visible_games = self:getVisibleGameCount(viewport_height)
    local game_scroll = self.controller.game_scroll_offset or 1

    for i = 0, visible_games - 1 do
        local game_index = game_scroll + i
        if game_index <= #games then
            local gy = self.game_list_y + 21 + i * self.item_h
            if local_mx >= self.game_list_x and local_mx <= self.game_list_x + self.game_list_w and
               local_my >= gy and local_my <= gy + self.item_h then
                self.hovered_game_id = games[game_index].id
                break
            end
        end
    end

    -- Check tab buttons
    local tab_w = 90
    local tab_x = self.param_panel_x + 120
    local tab_y = self.param_panel_y + 2
    local tabs = { "params", "skill_tree" }
    for i, tab_id in ipairs(tabs) do
        local tx = tab_x + (i - 1) * (tab_w + 4)
        if local_mx >= tx and local_mx <= tx + tab_w and
           local_my >= tab_y and local_my <= tab_y + 18 then
            self.hovered_button = "tab_" .. tab_id
        end
    end

    active_tab = active_tab or "params"

    if active_tab == "skill_tree" then
        -- Check skill tree node hover
        for node_id, rect in pairs(self.skill_node_rects) do
            if local_mx >= rect.x and local_mx <= rect.x + rect.w and
               local_my >= rect.y and local_my <= rect.y + rect.h then
                self.hovered_skill_node = node_id
                break
            end
        end
        return
    end

    -- Check parameter row hover
    if #params > 0 then
        local visible_params = self:getVisibleParamCount(viewport_height)
        local param_scroll = self.controller.param_scroll_offset or 0
        local base_y = self.param_panel_y + self.rows_start_y

        for i = 0, visible_params - 1 do
            local param_index = param_scroll + i + 1
            if param_index <= #params then
                local py = base_y + i * self.param_row_h
                if local_mx >= self.param_panel_x and local_mx <= self.param_panel_x + self.param_panel_w and
                   local_my >= py and local_my <= py + self.param_row_h then
                    self.hovered_param_index = param_index
                    break
                end
            end
        end
    end

    -- Check step size buttons
    local step_sizes = {0.05, 0.10, 0.25, "max"}
    local step_line_y = self.param_panel_y + 28
    for i, size in ipairs(step_sizes) do
        local btn_x = self.param_panel_x + 245 + (i - 1) * 50
        if local_mx >= btn_x and local_mx <= btn_x + 45 and
           local_my >= step_line_y and local_my <= step_line_y + 25 then
            self.hovered_button = "step_" .. tostring(size)
        end
    end

    -- Check water upgrade button
    if selected_game_id then
        local pd = self.controller.player_data
        local wc = self.di and self.di.config and self.di.config.water_upgrades
        local wl = pd and pd:getWaterUpgradeLevel(selected_game_id) or 0
        local ml = (wc and wc.max_level) or 5

        if wl < ml then
            local wy = self.param_panel_y + self.param_panel_h - 80
            local btn_x = self.param_panel_x + self.param_panel_w - 120
            local btn_y = wy + 20
            if local_mx >= btn_x and local_mx <= btn_x + 100 and
               local_my >= btn_y and local_my <= btn_y + 22 then
                self.hovered_button = "water_upgrade"
            end
        end
    end

    -- Check launch button
    local launch_y = self.param_panel_y + self.param_panel_h - 35
    if selected_game_id and
       local_mx >= self.param_panel_x + 10 and local_mx <= self.param_panel_x + 210 and
       local_my >= launch_y and local_my <= launch_y + 30 then
        self.hovered_button = "launch"
    end

    -- Check reset all button
    if selected_game_id and next(modifications) then
        local reset_all_x = self.param_panel_x + 220
        if local_mx >= reset_all_x and local_mx <= reset_all_x + 150 and
           local_my >= launch_y and local_my <= launch_y + 30 then
            self.hovered_button = "reset_all"
        end
    end
end

-- Override BaseView's drawWindowed to pass extra parameters
function CheatEngineView:drawWindowed(games, selected_game_id, params, modifications, player_data, step_size, selected_param_index, viewport_width, viewport_height, game_scroll, param_scroll, active_tab)
    self.draw_params = {
        games = games,
        selected_game_id = selected_game_id,
        params = params,
        modifications = modifications,
        player_data = player_data,
        step_size = step_size,
        selected_param_index = selected_param_index,
        game_scroll = game_scroll,
        param_scroll = param_scroll,
        active_tab = active_tab or "params",
    }
    CheatEngineView.super.drawWindowed(self, viewport_width, viewport_height)
end

-- Implements BaseView's abstract drawContent method
function CheatEngineView:drawContent(viewport_width, viewport_height)
    local p = self.draw_params
    local games = p.games
    local selected_game_id = p.selected_game_id
    local params = p.params
    local modifications = p.modifications
    local player_data = p.player_data
    local step_size = p.step_size
    local selected_param_index = p.selected_param_index
    local game_scroll = p.game_scroll
    local param_scroll = p.param_scroll
    local active_tab = p.active_tab or "params"

    -- Background: cracktro effects
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    self.effects:draw(viewport_width, viewport_height)

    -- ASCII art logo
    self.effects:drawLogo(viewport_width)

    -- Draw split panels
    self:drawGameListPanel(games, selected_game_id, viewport_height, game_scroll)

    -- Tab bar (top of right panel)
    self:drawTabBar(active_tab)

    if active_tab == "skill_tree" then
        self:drawSkillTreePanel(player_data, viewport_height)
    elseif selected_game_id then
        self:drawParameterPanel(params, modifications, player_data, selected_game_id, step_size, selected_param_index, viewport_height, param_scroll)
    else
        love.graphics.setColor(0.3, 0.5, 0.7)
        love.graphics.printf("No unlocked games available.\n\nUnlock games from the Launcher first.",
            self.param_panel_x, self.param_panel_y + 100,
            self.param_panel_w, "center")
    end

    -- Sine-wave scroller (replaces static footer)
    self.effects:drawScroller(viewport_width, viewport_height)
end

function CheatEngineView:drawGameListPanel(games, selected_game_id, viewport_height, game_scroll)
    -- Panel border
    love.graphics.setColor(0.0, 0.67, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', self.game_list_x, self.game_list_y, self.game_list_w, self.game_list_h)
    love.graphics.setLineWidth(1)

    -- Panel title with box-drawing
    love.graphics.setColor(0.02, 0.02, 0.06, 0.85)
    love.graphics.rectangle('fill', self.game_list_x + 1, self.game_list_y + 1, self.game_list_w - 2, 20)
    love.graphics.setColor(0.0, 0.67, 1.0)
    love.graphics.print("[= GAMES (" .. #games .. ") =]", self.game_list_x + 5, self.game_list_y + 4)

    -- Panel background (semi-transparent)
    love.graphics.setColor(0.02, 0.02, 0.06, 0.85)
    love.graphics.rectangle('fill', self.game_list_x + 1, self.game_list_y + 21, self.game_list_w - 2, self.game_list_h - 22)

    -- Game list
    local visible_games = self:getVisibleGameCount(viewport_height)
    local start_index = game_scroll or 1
    local lane_w = UIComponents.getScrollbarLaneWidth()

    for i = 0, visible_games - 1 do
        local game_index = start_index + i
        if game_index <= #games then
            local game = games[game_index]
            local gy = self.game_list_y + 21 + i * self.item_h
            local is_selected = (game.id == selected_game_id)
            local is_hovered = (game.id == self.hovered_game_id)

            -- Background
            if is_selected then
                love.graphics.setColor(0.0, 0.12, 0.25)
            elseif is_hovered then
                love.graphics.setColor(0.05, 0.05, 0.12)
            else
                love.graphics.setColor(0.02, 0.02, 0.06, 0.85)
            end
            love.graphics.rectangle('fill', self.game_list_x + 2, gy, self.game_list_w - 4 - lane_w, self.item_h)

            -- Text
            if is_selected then
                love.graphics.setColor(0.0, 1.0, 1.0)
            else
                love.graphics.setColor(0.0, 0.67, 1.0)
            end
            love.graphics.print(game.display_name or game.id, self.game_list_x + 8, gy + 5)
        end
    end

    -- Scrollbar (using state's ScrollbarController)
    if #games > visible_games then
        local scrollbar = self.controller.game_scrollbar
        if scrollbar then
            scrollbar:setPosition(self.game_list_x, self.game_list_y + 21)
            local max_scroll = math.max(0, #games - visible_games)
            local geom = scrollbar:compute(self.game_list_w, self.game_list_h - 21, #games * self.item_h, start_index - 1, max_scroll)

            if geom then
                love.graphics.push()
                love.graphics.translate(self.game_list_x, self.game_list_y + 21)
                UIComponents.drawScrollbar(geom)
                love.graphics.pop()
            end
        end
    end
end

function CheatEngineView:drawParameterPanel(params, modifications, player_data, game_id, step_size, selected_param_index, viewport_height, param_scroll)
    -- Panel border
    love.graphics.setColor(0.0, 0.67, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', self.param_panel_x, self.param_panel_y, self.param_panel_w, self.param_panel_h)
    love.graphics.setLineWidth(1)

    -- Panel title with box-drawing
    love.graphics.setColor(0.02, 0.02, 0.06, 0.85)
    love.graphics.rectangle('fill', self.param_panel_x + 1, self.param_panel_y + 1, self.param_panel_w - 2, 20)
    love.graphics.setColor(0.0, 0.67, 1.0)
    love.graphics.print("[= PARAMETERS =]", self.param_panel_x + 5, self.param_panel_y + 4)

    -- Panel background (semi-transparent)
    love.graphics.setColor(0.02, 0.02, 0.06, 0.85)
    love.graphics.rectangle('fill', self.param_panel_x + 1, self.param_panel_y + 21, self.param_panel_w - 2, self.param_panel_h - 22)

    -- Budget + Step size (single line)
    local budget_total = player_data:getCheatBudget()
    local budget_spent = player_data:getGameBudgetSpent(game_id)
    local budget_available = budget_total - budget_spent
    local line_y = self.param_panel_y + 28

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Budget:", self.param_panel_x + 10, line_y + 4)
    love.graphics.setColor(1, 1, 0)
    love.graphics.print(string.format("%d / %d", budget_available, budget_total),
        self.param_panel_x + 80, line_y + 4)

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Step:", self.param_panel_x + 200, line_y + 4)

    local step_sizes = {0.05, 0.10, 0.25, "max"}
    for i, size in ipairs(step_sizes) do
        local btn_x = self.param_panel_x + 245 + (i - 1) * 50
        local is_active = (step_size == size)
        local is_hovered = (self.hovered_button == "step_" .. tostring(size))

        local label = size == "max" and "MAX" or (math.floor(size * 100 + 0.5) .. "%")
        UIComponents.drawButton(
            btn_x, line_y, 45, 25,
            label,
            true,
            is_hovered or is_active,
            {0.0, 0.12, 0.3}
        )
    end

    if #params == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("No parameters available for this game variant.",
            self.param_panel_x + 10, self.param_panel_y + 120,
            self.param_panel_w - 20, "center")
        return
    end

    -- Slider rows
    local visible_params = self:getVisibleParamCount(viewport_height)
    local start_index = (param_scroll or 0) + 1
    local lane_w = UIComponents.getScrollbarLaneWidth()
    local base_y = self.param_panel_y + self.rows_start_y

    -- Layout constants for slider positioning
    local name_w = 130
    local slider_x = self.param_panel_x + name_w + 5
    local right_text_w = 130
    local slider_w = self.param_panel_w - name_w - right_text_w - lane_w - 5
    if slider_w < 50 then slider_w = 50 end
    local value_x = slider_x + slider_w + 8
    local cost_x = self.param_panel_x + self.param_panel_w - 60 - lane_w

    self.slider_rects = {}

    for i = 0, visible_params - 1 do
        local param_index = start_index + i
        if param_index <= #params then
            local param = params[param_index]
            local py = base_y + i * self.param_row_h
            local is_selected = (param_index == selected_param_index)
            local is_hovered = (param_index == self.hovered_param_index)
            local is_modified = (param.value ~= param.original)

            -- Row background
            if is_selected then
                love.graphics.setColor(0.05, 0.08, 0.2)
                love.graphics.rectangle('fill', self.param_panel_x + 2, py, self.param_panel_w - 4 - lane_w, self.param_row_h)
            elseif is_hovered then
                love.graphics.setColor(0.03, 0.05, 0.12)
                love.graphics.rectangle('fill', self.param_panel_x + 2, py, self.param_panel_w - 4 - lane_w, self.param_row_h)
            end

            -- Parameter name with NFO dot-leaders
            if is_modified then
                love.graphics.setColor(0.0, 1.0, 1.0)
            else
                love.graphics.setColor(0.7, 0.7, 0.7)
            end
            love.graphics.print(dotLeader(param.key, 18), self.param_panel_x + 10, py + 8)

            if param.type == "number" then
                self:drawNumberSlider(param, param_index, slider_x, py + 6, slider_w, 14, is_modified)

                -- Value text
                if is_modified then
                    love.graphics.setColor(1.0, 0.85, 0.0)
                else
                    love.graphics.setColor(0.6, 0.6, 0.6)
                end
                love.graphics.print(self:formatValue(param.value, "number"), value_x, py + 8)

            elseif param.type == "boolean" then
                self:drawBooleanCheckbox(param, param_index, slider_x, py + 6, is_modified)
            end

            -- Next step cost
            local cheat_sys = self.controller and self.controller.cheat_system
            if cheat_sys and param.type == "number" and step_size ~= "max" then
                local span = (param.max or 1) - (param.min or 0)
                local step_val = span * (step_size or 0.05)
                local next_val = math.min(param.max or 1, param.value + step_val)
                if next_val == param.value then
                    next_val = math.max(param.min or 0, param.value - step_val)
                end
                local preview_water_level = player_data:getWaterUpgradeLevel(game_id)
                local preview_skill_reduction = player_data:getSkillTreeBonus("global_cost_reduction")
                local next_cost = cheat_sys:calculateModificationCost(param.key, param.type, param.original, next_val, nil, nil, preview_water_level, preview_skill_reduction)
                local current_cost = (modifications[param.key] and modifications[param.key].cost_spent) or 0
                local net = next_cost - current_cost
                if net ~= 0 then
                    love.graphics.setColor(1.0, 0.5, 0.0)
                    love.graphics.print(tostring(math.abs(net)), cost_x, py + 8)
                end
            end
        end
    end

    -- Scrollbar for parameters
    if #params > visible_params then
        local scrollbar = self.controller.param_scrollbar
        if scrollbar then
            scrollbar:setPosition(self.param_panel_x, base_y)
            local max_scroll = math.max(0, #params - visible_params)
            local available_height = self.param_panel_h - self.rows_start_y - 80
            local geom = scrollbar:compute(self.param_panel_w, available_height, #params * self.param_row_h, param_scroll or 0, max_scroll)

            if geom then
                love.graphics.push()
                love.graphics.translate(self.param_panel_x, base_y)
                UIComponents.drawScrollbar(geom)
                love.graphics.pop()
            end
        end
    end

    -- Water upgrade section
    local water_y = self.param_panel_y + self.param_panel_h - 80
    love.graphics.setColor(0.0, 0.3, 0.6)
    love.graphics.line(self.param_panel_x + 5, water_y, self.param_panel_x + self.param_panel_w - 5, water_y)

    local config = self.di and self.di.config
    local water_config = config and config.water_upgrades
    local water_level = player_data:getWaterUpgradeLevel(game_id)
    local max_level = (water_config and water_config.max_level) or 5
    local reduction_pct = water_level * math.floor(((water_config and water_config.cost_reduction_per_level) or 0.05) * 100 + 0.5)

    -- "Water Upgrade" label (blue)
    love.graphics.setColor(0.3, 0.6, 1.0)
    love.graphics.print("Water Upgrade", self.param_panel_x + 10, water_y + 5)

    -- Level X/5
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(string.format("Level %d/%d", water_level, max_level), self.param_panel_x + 120, water_y + 5)

    -- Effect text
    if water_level > 0 then
        love.graphics.setColor(0.0, 1.0, 1.0)
        love.graphics.print(string.format("-%d%% Costs", reduction_pct), self.param_panel_x + 200, water_y + 5)
    end

    if water_level >= max_level then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("MAX LEVEL", self.param_panel_x + 10, water_y + 25)
    else
        local costs = water_config and water_config.costs or {}
        local next_cost = costs[water_level + 1] or 0
        local has_water = player_data:hasWater(next_cost)
        local current_water = player_data:getWater()

        love.graphics.setColor(0.3, 0.6, 1.0)
        love.graphics.print(string.format("Cost: %d Water (%d available)", next_cost, current_water), self.param_panel_x + 10, water_y + 25)

        local btn_x = self.param_panel_x + self.param_panel_w - 120
        local btn_y = water_y + 20
        local is_hovered = (self.hovered_button == "water_upgrade")
        UIComponents.drawButton(btn_x, btn_y, 100, 22, "UPGRADE", has_water, is_hovered and has_water, {0.0, 0.12, 0.3})
    end

    -- Launch button
    local launch_y = self.param_panel_y + self.param_panel_h - 35
    local is_launch_hovered = (self.hovered_button == "launch")
    UIComponents.drawButton(
        self.param_panel_x + 10, launch_y, 200, 30,
        "Launch Game",
        true,
        is_launch_hovered,
        {0.0, 0.12, 0.3}
    )

    -- Reset all button (only if modifications exist)
    if next(modifications) then
        local is_reset_hovered = (self.hovered_button == "reset_all")
        UIComponents.drawButton(
            self.param_panel_x + 220, launch_y, 150, 30,
            "Reset All",
            true,
            is_reset_hovered,
            {0.0, 0.12, 0.3}
        )
    end
end

function CheatEngineView:drawTabBar(active_tab)
    local tabs = {
        { id = "params", label = "Parameters" },
        { id = "skill_tree", label = "Skill Tree" },
    }
    local tab_w = 90
    local tab_h = 18
    local tab_x = self.param_panel_x + 120
    local tab_y = self.param_panel_y + 2

    for i, tab in ipairs(tabs) do
        local tx = tab_x + (i - 1) * (tab_w + 4)
        local is_active = (active_tab == tab.id)
        local is_hovered = (self.hovered_button == "tab_" .. tab.id)

        if is_active then
            love.graphics.setColor(0.0, 0.12, 0.25)
            love.graphics.rectangle('fill', tx, tab_y, tab_w, tab_h)
            love.graphics.setColor(0.0, 1.0, 1.0)
        elseif is_hovered then
            love.graphics.setColor(0.05, 0.08, 0.18)
            love.graphics.rectangle('fill', tx, tab_y, tab_w, tab_h)
            love.graphics.setColor(0.0, 0.8, 1.0)
        else
            love.graphics.setColor(0.02, 0.02, 0.06, 0.85)
            love.graphics.rectangle('fill', tx, tab_y, tab_w, tab_h)
            love.graphics.setColor(0.0, 0.4, 0.7)
        end
        love.graphics.rectangle('line', tx, tab_y, tab_w, tab_h)
        love.graphics.printf(tab.label, tx, tab_y + 3, tab_w, "center")
    end
end

function CheatEngineView:drawSkillTreePanel(player_data, viewport_height)
    -- Panel border
    love.graphics.setColor(0.0, 0.67, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', self.param_panel_x, self.param_panel_y, self.param_panel_w, self.param_panel_h)
    love.graphics.setLineWidth(1)

    -- Panel title background with box-drawing
    love.graphics.setColor(0.02, 0.02, 0.06, 0.85)
    love.graphics.rectangle('fill', self.param_panel_x + 1, self.param_panel_y + 1, self.param_panel_w - 2, 20)
    love.graphics.setColor(0.0, 0.67, 1.0)
    love.graphics.print("[= SKILL TREE =]", self.param_panel_x + 5, self.param_panel_y + 4)

    -- Panel background (semi-transparent)
    love.graphics.setColor(0.02, 0.02, 0.06, 0.85)
    love.graphics.rectangle('fill', self.param_panel_x + 1, self.param_panel_y + 21, self.param_panel_w - 2, self.param_panel_h - 22)

    -- Water balance display
    local current_water = player_data:getWater()
    love.graphics.setColor(0.3, 0.6, 1.0)
    love.graphics.print(string.format("Water: %d", current_water), self.param_panel_x + 10, self.param_panel_y + 28)

    local config = self.di and self.di.config
    local skill_tree_config = config and config.water_skill_tree
    if not skill_tree_config or not skill_tree_config.nodes then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("No skill tree data available.",
            self.param_panel_x + 10, self.param_panel_y + 100,
            self.param_panel_w - 20, "center")
        return
    end

    -- Organize nodes by tier
    local tiers = {} -- tiers[tier_number] = { {node_id, node}, ... }
    local max_tier = 0
    for node_id, node in pairs(skill_tree_config.nodes) do
        local tier = node.tier or 1
        if not tiers[tier] then tiers[tier] = {} end
        table.insert(tiers[tier], { id = node_id, node = node })
        if tier > max_tier then max_tier = tier end
    end

    -- Sort nodes within each tier by position
    for _, tier_nodes in pairs(tiers) do
        table.sort(tier_nodes, function(a, b) return a.node.position < b.node.position end)
    end

    -- Layout: tiers arranged bottom-to-top (compact for 6 per row, 5 tiers)
    local node_w = 85
    local node_h = 50
    local node_gap = 10
    local tier_spacing = 70
    local panel_content_y = self.param_panel_y + 50
    local panel_content_h = self.param_panel_h - 70
    local panel_cx = self.param_panel_x + self.param_panel_w / 2

    self.skill_node_rects = {}

    -- Draw connection lines first (behind nodes)
    for tier_num = 1, max_tier do
        if tiers[tier_num] then
            for _, entry in ipairs(tiers[tier_num]) do
                local node = entry.node
                local node_id = entry.id
                -- Position of this node
                local tier_count = #tiers[tier_num]
                local total_w = tier_count * node_w + (tier_count - 1) * node_gap
                local start_x = panel_cx - total_w / 2
                local nx = start_x + (node.position - 1) * (node_w + node_gap)
                local ny = panel_content_y + panel_content_h - tier_num * tier_spacing

                -- Draw lines to required nodes
                for _, req_id in ipairs(node.requires) do
                    local req_node = skill_tree_config.nodes[req_id]
                    if req_node then
                        local req_tier = req_node.tier or 1
                        if tiers[req_tier] then
                            local req_tier_count = #tiers[req_tier]
                            local req_total_w = req_tier_count * node_w + (req_tier_count - 1) * node_gap
                            local req_start_x = panel_cx - req_total_w / 2
                            local req_x = req_start_x + (req_node.position - 1) * (node_w + node_gap)
                            local req_y = panel_content_y + panel_content_h - req_tier * tier_spacing

                            local has_req = player_data:getSkillLevel(req_id) >= 1
                            if has_req then
                                love.graphics.setColor(0.0, 0.5, 1.0, 0.6)
                            else
                                love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
                            end
                            love.graphics.setLineWidth(2)
                            love.graphics.line(
                                nx + node_w / 2, ny + node_h,
                                req_x + node_w / 2, req_y
                            )
                            love.graphics.setLineWidth(1)
                        end
                    end
                end
            end
        end
    end

    -- Draw nodes
    for tier_num = 1, max_tier do
        if tiers[tier_num] then
            local tier_count = #tiers[tier_num]
            local total_w = tier_count * node_w + (tier_count - 1) * node_gap
            local start_x = panel_cx - total_w / 2

            for _, entry in ipairs(tiers[tier_num]) do
                local node = entry.node
                local node_id = entry.id
                local nx = start_x + (node.position - 1) * (node_w + node_gap)
                local ny = panel_content_y + panel_content_h - tier_num * tier_spacing
                local level = player_data:getSkillLevel(node_id)
                local can_unlock = player_data:canUnlockSkill(node_id, config)
                local is_maxed = (level >= node.max_level)
                local is_purchased = (level > 0)
                local is_hovered = (self.hovered_skill_node == node_id)

                self.skill_node_rects[node_id] = { x = nx, y = ny, w = node_w, h = node_h }

                self:drawSkillNode(node, node_id, nx, ny, node_w, node_h,
                    level, can_unlock, is_maxed, is_purchased, is_hovered, player_data, config)
            end
        end
    end
end

function CheatEngineView:drawSkillNode(node, node_id, x, y, w, h, level, can_unlock, is_maxed, is_purchased, is_hovered, player_data, config)
    -- Background
    if is_maxed then
        love.graphics.setColor(0.25, 0.2, 0.0)
    elseif is_purchased then
        love.graphics.setColor(0.0, 0.1, 0.2)
    elseif can_unlock then
        love.graphics.setColor(0.05, 0.05, 0.12)
    else
        love.graphics.setColor(0.04, 0.04, 0.08)
    end
    if is_hovered and (can_unlock or is_purchased) and not is_maxed then
        local r, g, b = love.graphics.getColor()
        love.graphics.setColor(math.min(1, r + 0.08), math.min(1, g + 0.08), math.min(1, b + 0.08))
    end
    love.graphics.rectangle('fill', x, y, w, h)

    -- Border
    if is_maxed then
        love.graphics.setColor(0.9, 0.75, 0.0)
    elseif is_purchased then
        love.graphics.setColor(0.0, 0.67, 1.0)
    elseif can_unlock then
        love.graphics.setColor(0.3, 0.6, 1.0)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.setLineWidth(is_hovered and 2 or 1)
    love.graphics.rectangle('line', x, y, w, h)
    love.graphics.setLineWidth(1)

    -- Name (compact for smaller nodes)
    local small_font = self.skill_node_font
    local prev_font = love.graphics.getFont()
    love.graphics.setFont(small_font)

    if is_maxed then
        love.graphics.setColor(0.9, 0.75, 0.0)
    elseif is_purchased then
        love.graphics.setColor(0.2, 0.8, 1.0)
    elseif can_unlock then
        love.graphics.setColor(0.9, 0.9, 0.9)
    else
        love.graphics.setColor(0.4, 0.4, 0.4)
    end
    love.graphics.printf(node.name, x + 2, y + 3, w - 4, "center")

    -- Level indicator
    local level_text = string.format("%d/%d", level, node.max_level)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf(level_text, x + 2, y + 16, w - 4, "center")

    -- Level dots
    local dot_y = y + 29
    local dot_spacing = math.min(10, (w - 8) / node.max_level)
    local dots_total_w = node.max_level * dot_spacing
    local dot_start_x = x + (w - dots_total_w) / 2
    for i = 1, node.max_level do
        local dx = dot_start_x + (i - 1) * dot_spacing + dot_spacing / 2
        if i <= level then
            if is_maxed then
                love.graphics.setColor(0.9, 0.75, 0.0)
            else
                love.graphics.setColor(0.0, 0.67, 1.0)
            end
        else
            love.graphics.setColor(0.25, 0.25, 0.25)
        end
        love.graphics.circle('fill', dx, dot_y, 2.5)
    end

    -- Cost or MAX text
    if is_maxed then
        love.graphics.setColor(0.9, 0.75, 0.0)
        love.graphics.printf("MAX", x + 2, y + h - 14, w - 4, "center")
    elseif can_unlock then
        local cost = player_data:getSkillCost(node_id, config)
        local has_water = player_data:hasWater(cost)
        if has_water then
            love.graphics.setColor(0.3, 0.6, 1.0)
        else
            love.graphics.setColor(0.6, 0.3, 0.3)
        end
        love.graphics.printf(cost .. "W", x + 2, y + h - 14, w - 4, "center")
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.printf("LOCKED", x + 2, y + h - 14, w - 4, "center")
    end

    love.graphics.setFont(prev_font)

    -- Tooltip on hover: show description
    if is_hovered then
        love.graphics.setFont(small_font)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf(node.description, x - 30, y + h + 3, w + 60, "center")
        love.graphics.setFont(prev_font)
    end
end

function CheatEngineView:drawNumberSlider(param, param_index, x, y, w, h, is_modified)
    local lo = param.min or 0
    local hi = param.max or math.max(math.abs(param.original) * 2, 1)
    local range = hi - lo
    if range <= 0 then range = 1 end

    -- Normalized positions (0..1)
    local orig_t = math.max(0, math.min(1, (param.original - lo) / range))
    local curr_t = math.max(0, math.min(1, (param.value - lo) / range))

    -- Store rect for hit testing
    self.slider_rects[param_index] = {x = x, y = y, w = w, h = h, lo = lo, hi = hi}

    -- Track background
    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle('fill', x, y, w, h)

    -- Fill from original to current (visualizes "how far you've cheated")
    if is_modified then
        local fill_start = math.min(orig_t, curr_t)
        local fill_end = math.max(orig_t, curr_t)
        love.graphics.setColor(0.0, 0.15, 0.35)
        love.graphics.rectangle('fill', x + fill_start * w, y, (fill_end - fill_start) * w, h)
    end

    -- Track border
    love.graphics.setColor(0.0, 0.4, 0.8)
    love.graphics.rectangle('line', x, y, w, h)

    -- Original marker (permanent tick line)
    love.graphics.setColor(0.6, 0.6, 0.6)
    local orig_px = x + orig_t * w
    love.graphics.setLineWidth(2)
    love.graphics.line(orig_px, y - 2, orig_px, y + h + 2)
    love.graphics.setLineWidth(1)

    -- Handle at current value
    local handle_w = 10
    local handle_px = x + curr_t * w - handle_w / 2
    handle_px = math.max(x, math.min(x + w - handle_w, handle_px))

    if is_modified then
        love.graphics.setColor(0.0, 1.0, 1.0)
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
    end
    love.graphics.rectangle('fill', handle_px, y - 2, handle_w, h + 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', handle_px, y - 2, handle_w, h + 4)
end

function CheatEngineView:drawBooleanCheckbox(param, param_index, x, y, is_modified)
    local cb_w, cb_h = 18, 18

    -- Store rect for hit testing (mark as checkbox)
    self.slider_rects[param_index] = {x = x, y = y, w = cb_w, h = cb_h, is_checkbox = true}

    -- Checkbox background
    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle('fill', x, y, cb_w, cb_h)
    love.graphics.setColor(0.0, 0.4, 0.8)
    love.graphics.rectangle('line', x, y, cb_w, cb_h)

    -- Checkmark
    if param.value then
        love.graphics.setColor(0.0, 1.0, 1.0)
        love.graphics.setLineWidth(3)
        love.graphics.line(x + 3, y + cb_h / 2, x + cb_w / 2, y + cb_h - 4, x + cb_w - 3, y + 3)
        love.graphics.setLineWidth(1)
    end

    -- Label
    if is_modified then
        love.graphics.setColor(1.0, 0.85, 0.0)
    else
        love.graphics.setColor(0.6, 0.6, 0.6)
    end
    love.graphics.print(param.value and "ON" or "OFF", x + cb_w + 8, y)
end

function CheatEngineView:formatValue(value, value_type)
    if value_type == "boolean" then
        return value and "true" or "false"
    elseif value_type == "number" then
        if value == math.floor(value) then
            return tostring(math.floor(value))
        end
        return string.format("%.2f", value)
    else
        return tostring(value)
    end
end

function CheatEngineView:getVisibleGameCount(viewport_height)
    local available_height = self.game_list_h - 21
    return math.max(1, math.floor(available_height / self.item_h))
end

function CheatEngineView:getVisibleParamCount(viewport_height)
    -- From rows_start_y to water upgrade area (80px from bottom: 45px water + 35px buttons)
    local available_height = self.param_panel_h - self.rows_start_y - 80
    return math.max(1, math.floor(available_height / self.param_row_h))
end

-- Compute slider value from mouse x position for a given slider rect
function CheatEngineView:sliderValueFromX(mx, rect)
    if not rect or rect.is_checkbox then return nil end
    local fraction = (mx - rect.x) / rect.w
    fraction = math.max(0, math.min(1, fraction))
    return rect.lo + fraction * (rect.hi - rect.lo)
end

function CheatEngineView:mousepressed(x, y, button, games, selected_game_id, params, modifications, player_data, step_size, selected_param_index, viewport_width, viewport_height, active_tab)
    if button ~= 1 then return nil end

    -- Tab bar clicks
    local tab_w = 90
    local tab_x = self.param_panel_x + 120
    local tab_y = self.param_panel_y + 2
    local tabs = { "params", "skill_tree" }
    for i, tab_id in ipairs(tabs) do
        local tx = tab_x + (i - 1) * (tab_w + 4)
        if x >= tx and x <= tx + tab_w and y >= tab_y and y <= tab_y + 18 then
            return { name = "switch_tab", tab = tab_id }
        end
    end

    -- Game list clicks
    local visible_games = self:getVisibleGameCount(viewport_height)
    local game_scroll = self.controller.game_scroll_offset or 1

    for i = 0, visible_games - 1 do
        local game_index = game_scroll + i
        if game_index <= #games then
            local gy = self.game_list_y + 21 + i * self.item_h
            if x >= self.game_list_x and x <= self.game_list_x + self.game_list_w and
               y >= gy and y <= gy + self.item_h then
                return { name = "select_game", id = games[game_index].id }
            end
        end
    end

    -- Skill tree node clicks
    if (active_tab or "params") == "skill_tree" then
        for node_id, rect in pairs(self.skill_node_rects) do
            if x >= rect.x and x <= rect.x + rect.w and
               y >= rect.y and y <= rect.y + rect.h then
                return { name = "upgrade_skill", node_id = node_id }
            end
        end
        return nil
    end

    -- Step size buttons
    local step_sizes = {0.05, 0.10, 0.25, "max"}
    local step_line_y = self.param_panel_y + 28
    for i, size in ipairs(step_sizes) do
        local btn_x = self.param_panel_x + 245 + (i - 1) * 50
        if x >= btn_x and x <= btn_x + 45 and y >= step_line_y and y <= step_line_y + 25 then
            return { name = "set_step_size", value = size }
        end
    end

    -- Slider / checkbox clicks on parameter rows
    if #params > 0 then
        local visible_params = self:getVisibleParamCount(viewport_height)
        local param_scroll = self.controller.param_scroll_offset or 0
        local base_y = self.param_panel_y + self.rows_start_y

        for i = 0, visible_params - 1 do
            local param_index = param_scroll + i + 1
            if param_index <= #params then
                local py = base_y + i * self.param_row_h

                -- Check if click is within this row
                if x >= self.param_panel_x and x <= self.param_panel_x + self.param_panel_w and
                   y >= py and y <= py + self.param_row_h then

                    -- Check if click is on the slider/checkbox control
                    local rect = self.slider_rects[param_index]
                    if rect then
                        if rect.is_checkbox then
                            -- Click anywhere in checkbox row area toggles it
                            if x >= rect.x and x <= rect.x + rect.w + 40 and
                               y >= rect.y - 4 and y <= rect.y + rect.h + 4 then
                                return { name = "toggle_param", index = param_index }
                            end
                        else
                            -- Click on slider track
                            if x >= rect.x - 5 and x <= rect.x + rect.w + 5 and
                               y >= rect.y - 6 and y <= rect.y + rect.h + 6 then
                                local value = self:sliderValueFromX(x, rect)
                                return { name = "slider_set", index = param_index, value = value }
                            end
                        end
                    end

                    -- Click on row but not on control = select param
                    return { name = "select_param", index = param_index }
                end
            end
        end
    end

    -- Water upgrade button
    if selected_game_id then
        local wc = self.di and self.di.config and self.di.config.water_upgrades
        local wl = player_data:getWaterUpgradeLevel(selected_game_id)
        local ml = (wc and wc.max_level) or 5

        if wl < ml then
            local wy = self.param_panel_y + self.param_panel_h - 80
            local btn_x = self.param_panel_x + self.param_panel_w - 120
            local btn_y = wy + 20
            if x >= btn_x and x <= btn_x + 100 and y >= btn_y and y <= btn_y + 22 then
                return { name = "water_upgrade" }
            end
        end
    end

    -- Launch button
    if selected_game_id then
        local launch_y = self.param_panel_y + self.param_panel_h - 35
        if x >= self.param_panel_x + 10 and x <= self.param_panel_x + 210 and
           y >= launch_y and y <= launch_y + 30 then
            return { name = "launch_game" }
        end

        -- Reset all button
        if next(modifications) then
            if x >= self.param_panel_x + 220 and x <= self.param_panel_x + 370 and
               y >= launch_y and y <= launch_y + 30 then
                return { name = "reset_all" }
            end
        end
    end

    return nil
end

function CheatEngineView:wheelmoved(x, y, game_count, param_count, viewport_width, viewport_height)
    local new_game_offset = nil
    local new_param_offset = nil

    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    -- Check if scrolling over game list
    if local_mx >= self.game_list_x and local_mx <= self.game_list_x + self.game_list_w and
       local_my >= self.game_list_y and local_my <= self.game_list_y + self.game_list_h then

        local visible_games = self:getVisibleGameCount(viewport_height)
        local max_scroll = math.max(0, game_count - visible_games)
        local current_offset = self.controller.game_scroll_offset or 1

        if y > 0 then
            new_game_offset = math.max(1, current_offset - 1)
        elseif y < 0 then
            new_game_offset = math.min(max_scroll + 1, current_offset + 1)
        end
    end

    -- Check if scrolling over parameter list
    local param_area_top = self.param_panel_y + self.rows_start_y
    local param_area_bottom = self.param_panel_y + self.param_panel_h - 35
    if local_mx >= self.param_panel_x and local_mx <= self.param_panel_x + self.param_panel_w and
       local_my >= param_area_top and local_my <= param_area_bottom then

        local visible_params = self:getVisibleParamCount(viewport_height)
        local max_scroll = math.max(0, param_count - visible_params)
        local current_offset = self.controller.param_scroll_offset or 0

        if y > 0 then
            new_param_offset = math.max(0, current_offset - 1)
        elseif y < 0 then
            new_param_offset = math.min(max_scroll, current_offset + 1)
        end
    end

    return new_game_offset, new_param_offset
end

function CheatEngineView:mousemoved(x, y, dx, dy)
    -- Check if dragging a slider (state tracks this)
    local dragging = self.controller.dragging_slider
    if dragging then
        local rect = self.slider_rects[dragging.param_index]
        if rect and not rect.is_checkbox then
            local value = self:sliderValueFromX(x, rect)
            return { name = "slider_drag", index = dragging.param_index, value = value }
        end
    end

    return { name = 'content_interaction' }
end

function CheatEngineView:mousereleased(x, y, button)
    if button == 1 then
        if self.controller.dragging_slider then
            return { name = "slider_drag_end" }
        end
    end
end

return CheatEngineView
