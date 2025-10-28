-- src/views/cheat_engine_view.lua
-- View for dynamic parameter modification UI
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local CheatEngineView = Object:extend('CheatEngineView')

function CheatEngineView:init(controller, di)
    self.controller = controller
    self.di = di

    if di and UIComponents and UIComponents.inject then
        UIComponents.inject(di)
    end

    self.sprite_manager = (di and di.spriteManager) or nil

    -- Layout configuration
    local C = (self.di and self.di.config) or {}
    local V = (C.ui and C.ui.views and C.ui.views.cheat_engine) or {}

    -- Split panel layout
    self.split_x = 280 -- Divider between game list and parameter panel
    self.padding = 10
    self.item_h = 25

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

    -- Hover state
    self.hovered_game_id = nil
    self.hovered_param_index = nil
    self.hovered_button = nil -- "launch", "reset_all", "reset_X", "step_1", etc.

    -- Scrollbar state
    self._sb = { games = { dragging=false }, params = { dragging=false } }
end

function CheatEngineView:updateLayout(viewport_width, viewport_height)
    self.game_list_h = viewport_height - 80
    self.param_panel_h = viewport_height - 80

    -- Adjust parameter panel width based on viewport
    self.param_panel_w = viewport_width - self.split_x - 20
end

function CheatEngineView:update(dt, games, selected_game_id, params, modifications, step_size, viewport_width, viewport_height)
    -- Get mouse position relative to viewport
    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    self.hovered_game_id = nil
    self.hovered_param_index = nil
    self.hovered_button = nil

    -- Check bounds
    if local_mx < 0 or local_mx > viewport_width or local_my < 0 or local_my > viewport_height then
        return
    end

    -- Check game list hover
    local visible_games = self:getVisibleGameCount(viewport_height)
    local game_scroll = self.controller.game_scroll_offset or 1

    for i = 0, visible_games - 1 do
        local game_index = game_scroll + i
        if game_index <= #games then
            local gy = self.game_list_y + i * self.item_h
            if local_mx >= self.game_list_x and local_mx <= self.game_list_x + self.game_list_w and
               local_my >= gy and local_my <= gy + self.item_h then
                self.hovered_game_id = games[game_index].id
                break
            end
        end
    end

    -- Check parameter list hover
    if #params > 0 then
        local visible_params = self:getVisibleParamCount(viewport_height)
        local param_scroll = self.controller.param_scroll_offset or 0
        local param_table_y = self.param_panel_y + 120

        for i = 0, visible_params - 1 do
            local param_index = param_scroll + i + 1
            if param_index <= #params then
                local py = param_table_y + i * self.item_h
                if local_mx >= self.param_panel_x and local_mx <= self.param_panel_x + self.param_panel_w and
                   local_my >= py and local_my <= py + self.item_h then
                    self.hovered_param_index = param_index
                    break
                end
            end
        end
    end

    -- Check step size buttons
    local step_y = self.param_panel_y + 50
    local step_sizes = {1, 5, 10, 100, "max"}
    for i, size in ipairs(step_sizes) do
        local btn_x = self.param_panel_x + 100 + (i - 1) * 50
        if local_mx >= btn_x and local_mx <= btn_x + 45 and
           local_my >= step_y and local_my <= step_y + 25 then
            self.hovered_button = "step_" .. tostring(size)
        end
    end

    -- Check launch button
    local launch_y = viewport_height - 40
    if selected_game_id and
       local_mx >= self.param_panel_x and local_mx <= self.param_panel_x + 200 and
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

function CheatEngineView:drawWindowed(games, selected_game_id, params, modifications, player_data, step_size, selected_param_index, viewport_width, viewport_height, game_scroll, param_scroll)
    -- Background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    -- Title
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("CheatEngine v2.0.0 (Dynamic Parameter Editor)", 10, 10)
    love.graphics.print("===================================================", 10, 25)

    -- Draw split panels
    self:drawGameListPanel(games, selected_game_id, viewport_height, game_scroll)

    if selected_game_id then
        self:drawParameterPanel(params, modifications, player_data, selected_game_id, step_size, selected_param_index, viewport_height, param_scroll)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("No unlocked games available.\n\nUnlock games from the Launcher first.",
            self.param_panel_x, self.param_panel_y + 100,
            self.param_panel_w, "center")
    end

    -- Footer instructions
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print("ESC: Close | ←→/AD: Modify | ↑↓/WS: Navigate | 1-4/M: Step Size | R: Reset | X: Reset All | Enter: Launch",
        10, viewport_height - 20)
end

function CheatEngineView:drawGameListPanel(games, selected_game_id, viewport_height, game_scroll)
    -- Panel border
    love.graphics.setColor(0, 1, 0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', self.game_list_x, self.game_list_y, self.game_list_w, self.game_list_h)
    love.graphics.setLineWidth(1)

    -- Panel title
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle('fill', self.game_list_x + 1, self.game_list_y + 1, self.game_list_w - 2, 20)
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("Unlocked Games (" .. #games .. ")", self.game_list_x + 5, self.game_list_y + 4)

    -- Panel background
    love.graphics.setColor(0.05, 0.05, 0.05)
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
                love.graphics.setColor(0, 0.5, 0)
            elseif is_hovered then
                love.graphics.setColor(0.1, 0.1, 0.1)
            else
                love.graphics.setColor(0.05, 0.05, 0.05)
            end
            love.graphics.rectangle('fill', self.game_list_x + 2, gy, self.game_list_w - 4 - lane_w, self.item_h)

            -- Text
            love.graphics.setColor(0, 1, 0)
            love.graphics.print(game.display_name or game.id, self.game_list_x + 8, gy + 5)
        end
    end

    -- Scrollbar
    if #games > visible_games then
        local UI = UIComponents
        love.graphics.push()
        love.graphics.translate(self.game_list_x, self.game_list_y + 21)
        local sb_geom = UI.computeScrollbar({
            viewport_w = self.game_list_w,
            viewport_h = self.game_list_h - 21,
            content_h = (#games) * self.item_h,
            offset = (start_index - 1) * self.item_h,
            track_top = 12,
            track_bottom = 12,
        })
        UI.drawScrollbar(sb_geom)
        self._sb.games.geom = sb_geom
        love.graphics.pop()
    end
end

function CheatEngineView:drawParameterPanel(params, modifications, player_data, game_id, step_size, selected_param_index, viewport_height, param_scroll)
    -- Panel border
    love.graphics.setColor(0, 1, 0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', self.param_panel_x, self.param_panel_y, self.param_panel_w, self.param_panel_h)
    love.graphics.setLineWidth(1)

    -- Panel title
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle('fill', self.param_panel_x + 1, self.param_panel_y + 1, self.param_panel_w - 2, 20)
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("Parameter Editor", self.param_panel_x + 5, self.param_panel_y + 4)

    -- Panel background
    love.graphics.setColor(0.05, 0.05, 0.05)
    love.graphics.rectangle('fill', self.param_panel_x + 1, self.param_panel_y + 21, self.param_panel_w - 2, self.param_panel_h - 22)

    -- Budget display
    local budget_total = player_data:getCheatBudget()
    local budget_spent = player_data:getGameBudgetSpent(game_id)
    local budget_available = budget_total - budget_spent

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Budget:", self.param_panel_x + 10, self.param_panel_y + 30)
    love.graphics.setColor(1, 1, 0)
    love.graphics.print(string.format("%d / %d", budget_available, budget_total),
        self.param_panel_x + 100, self.param_panel_y + 30)

    -- Step size selector
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Step Size:", self.param_panel_x + 10, self.param_panel_y + 55)

    local step_sizes = {1, 5, 10, 100, "max"}
    for i, size in ipairs(step_sizes) do
        local btn_x = self.param_panel_x + 100 + (i - 1) * 50
        local btn_y = self.param_panel_y + 50
        local is_selected = (step_size == size)
        local is_hovered = (self.hovered_button == "step_" .. tostring(size))

        UIComponents.drawButton(
            btn_x, btn_y, 45, 25,
            tostring(size):upper(),
            true,
            is_hovered or is_selected
        )
    end

    -- Parameter table
    if #params == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("No parameters available for this game variant.",
            self.param_panel_x + 10, self.param_panel_y + 120,
            self.param_panel_w - 20, "center")
        return
    end

    local table_y = self.param_panel_y + 100
    local header_y = table_y + 10

    -- Table headers
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("Parameter", self.param_panel_x + 10, header_y)
    love.graphics.print("Type", self.param_panel_x + 180, header_y)
    love.graphics.print("Original", self.param_panel_x + 250, header_y)
    love.graphics.print("Modified", self.param_panel_x + 340, header_y)
    love.graphics.print("Cost", self.param_panel_x + 430, header_y)

    -- Separator line
    love.graphics.setColor(0, 0.5, 0)
    love.graphics.line(
        self.param_panel_x + 10, header_y + 18,
        self.param_panel_x + self.param_panel_w - 40, header_y + 18
    )

    -- Parameter rows
    local visible_params = self:getVisibleParamCount(viewport_height)
    local start_index = (param_scroll or 0) + 1
    local lane_w = UIComponents.getScrollbarLaneWidth()

    for i = 0, visible_params - 1 do
        local param_index = start_index + i
        if param_index <= #params then
            local param = params[param_index]
            local py = header_y + 25 + i * self.item_h
            local is_selected = (param_index == selected_param_index)
            local is_hovered = (param_index == self.hovered_param_index)
            local is_modified = (param.value ~= param.original)

            -- Row background
            if is_selected then
                love.graphics.setColor(0.3, 0.3, 0.5)
                love.graphics.rectangle('fill', self.param_panel_x + 2, py - 2, self.param_panel_w - 4 - lane_w, self.item_h)
            elseif is_hovered then
                love.graphics.setColor(0.15, 0.15, 0.15)
                love.graphics.rectangle('fill', self.param_panel_x + 2, py - 2, self.param_panel_w - 4 - lane_w, self.item_h)
            end

            -- Parameter name
            if is_modified then
                love.graphics.setColor(0.2, 1.0, 0.2)
            else
                love.graphics.setColor(0.7, 0.7, 0.7)
            end
            love.graphics.print(param.key, self.param_panel_x + 10, py)

            -- Type
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print(param.type, self.param_panel_x + 180, py)

            -- Original value
            love.graphics.setColor(0.6, 0.6, 0.6)
            local orig_str = self:formatValue(param.original, param.type)
            love.graphics.print(orig_str, self.param_panel_x + 250, py)

            -- Modified value
            if is_modified then
                love.graphics.setColor(1.0, 1.0, 0.2)
            else
                love.graphics.setColor(0.6, 0.6, 0.6)
            end
            local mod_str = self:formatValue(param.value, param.type)
            love.graphics.print(mod_str, self.param_panel_x + 340, py)

            -- Cost
            if is_modified and modifications[param.key] then
                love.graphics.setColor(1.0, 0.5, 0.0)
                love.graphics.print(tostring(modifications[param.key].cost_spent), self.param_panel_x + 430, py)
            end
        end
    end

    -- Scrollbar for parameters
    if #params > visible_params then
        local UI = UIComponents
        love.graphics.push()
        love.graphics.translate(self.param_panel_x, header_y + 25)
        local sb_geom = UI.computeScrollbar({
            viewport_w = self.param_panel_w,
            viewport_h = visible_params * self.item_h,
            content_h = (#params) * self.item_h,
            offset = (param_scroll or 0) * self.item_h,
            track_top = 12,
            track_bottom = 12,
        })
        UI.drawScrollbar(sb_geom)
        self._sb.params.geom = sb_geom
        love.graphics.pop()
    end

    -- Launch button
    local launch_y = self.param_panel_y + self.param_panel_h - 35
    local is_launch_hovered = (self.hovered_button == "launch")

    UIComponents.drawButton(
        self.param_panel_x + 10, launch_y, 200, 30,
        "Launch Game",
        true,
        is_launch_hovered
    )

    -- Reset all button (only if modifications exist)
    if next(modifications) then
        local is_reset_hovered = (self.hovered_button == "reset_all")
        UIComponents.drawButton(
            self.param_panel_x + 220, launch_y, 150, 30,
            "Reset All",
            true,
            is_reset_hovered
        )
    end
end

function CheatEngineView:formatValue(value, value_type)
    if value_type == "boolean" then
        return value and "true" or "false"
    elseif value_type == "number" then
        return tostring(value)
    elseif value_type == "string" then
        return "\"" .. tostring(value) .. "\""
    elseif value_type == "array" or value_type == "table" then
        return "[" .. #value .. " items]"
    else
        return tostring(value)
    end
end

function CheatEngineView:getVisibleGameCount(viewport_height)
    local available_height = self.game_list_h - 21
    return math.max(1, math.floor(available_height / self.item_h))
end

function CheatEngineView:getVisibleParamCount(viewport_height)
    local available_height = self.param_panel_h - 180 -- Account for headers, budget, step size, buttons
    return math.max(1, math.floor(available_height / self.item_h))
end

function CheatEngineView:mousepressed(x, y, button, games, selected_game_id, params, modifications, player_data, step_size, selected_param_index, viewport_width, viewport_height)
    if button ~= 1 then return nil end

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

    -- Step size buttons
    local step_sizes = {1, 5, 10, 100, "max"}
    for i, size in ipairs(step_sizes) do
        local btn_x = self.param_panel_x + 100 + (i - 1) * 50
        local btn_y = self.param_panel_y + 50
        if x >= btn_x and x <= btn_x + 45 and y >= btn_y and y <= btn_y + 25 then
            return { name = "set_step_size", value = size }
        end
    end

    -- Parameter list clicks
    if #params > 0 then
        local visible_params = self:getVisibleParamCount(viewport_height)
        local param_scroll = self.controller.param_scroll_offset or 0
        local header_y = self.param_panel_y + 110

        for i = 0, visible_params - 1 do
            local param_index = param_scroll + i + 1
            if param_index <= #params then
                local py = header_y + 25 + i * self.item_h
                if x >= self.param_panel_x and x <= self.param_panel_x + self.param_panel_w and
                   y >= py - 2 and y <= py - 2 + self.item_h then
                    return { name = "select_param", index = param_index }
                end
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

        if y > 0 then -- Scroll up
            new_game_offset = math.max(1, current_offset - 1)
        elseif y < 0 then -- Scroll down
            new_game_offset = math.min(max_scroll + 1, current_offset + 1)
        end
    end

    -- Check if scrolling over parameter list
    if local_mx >= self.param_panel_x and local_mx <= self.param_panel_x + self.param_panel_w and
       local_my >= self.param_panel_y + 100 and local_my <= self.param_panel_y + self.param_panel_h - 50 then

        local visible_params = self:getVisibleParamCount(viewport_height)
        local max_scroll = math.max(0, param_count - visible_params)
        local current_offset = self.controller.param_scroll_offset or 0

        if y > 0 then -- Scroll up
            new_param_offset = math.max(0, current_offset - 1)
        elseif y < 0 then -- Scroll down
            new_param_offset = math.min(max_scroll, current_offset + 1)
        end
    end

    return new_game_offset, new_param_offset
end

function CheatEngineView:mousemoved(x, y, dx, dy)
    -- Hover updates handled in update()
    return { name = 'content_interaction' }
end

function CheatEngineView:mousereleased(x, y, button)
    if button == 1 and self._sb then
        if self._sb.games and self._sb.games.dragging then
            self._sb.games.dragging = false
            self._sb.games.drag = nil
        end
        if self._sb.params and self._sb.params.dragging then
            self._sb.params.dragging = false
            self._sb.params.drag = nil
        end
    end
end

return CheatEngineView
