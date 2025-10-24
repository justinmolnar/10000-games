-- launcher_view.lua: View class for the game launcher

local Object = require('class')
local UIComponents = require('src.views.ui_components')
local FormulaRenderer = require('src.views.formula_renderer')
local MetricLegend = require('src.views.metric_legend')
local LauncherView = Object:extend('LauncherView')

function LauncherView:init(controller, player_data, game_data)
    self.controller = controller
    self.player_data = player_data
    self.game_data = game_data
    local di = controller and controller.di
    self.di = di
    self.sprite_loader = (di and di.spriteLoader) or nil
    self.sprite_manager = (di and di.spriteManager) or nil
    self.variant_loader = (di and di.gameVariantLoader) or nil  -- Phase 1.5

    self.selected_category = "all"
    self.selected_index = 1
    self.scroll_offset = 1
    self.hovered_game_id = nil
    self.selected_game = nil
    self.detail_panel_open = false
    
    -- UI layout constants
    self.button_height = 80
    self.button_padding = 5
    self.detail_panel_width = 400
    self.category_button_height = 30
    
    -- Double-click tracking
    self.last_click_time = 0
    self.last_click_game = nil
    -- Scrollbar interaction state
    self._sb = { list = { dragging = false, geom = nil, drag = nil } }
end

function LauncherView:update(dt)
    if not self.controller.viewport then
        self.hovered_game_id = nil
        return
    end
    
    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport.x
    local view_y = self.controller.viewport.y
    local local_mx = mx - view_x
    local local_my = my - view_y
    
    if local_mx < 0 or local_mx > self.controller.viewport.width or
       local_my < 0 or local_my > self.controller.viewport.height then
        self.hovered_game_id = nil
        return
    end
    
    local list_y = 50
    local list_h = self.controller.viewport.height - list_y - 10
    local list_x = 10
    local list_width = (self.detail_panel_open and self.selected_game) and 
                       (self.controller.viewport.width - self.detail_panel_width - 20) or 
                       (self.controller.viewport.width - 20)
    
    self.hovered_game_id = self:getGameAtPosition(
        local_mx, local_my,
        self.controller.filtered_games,
        list_x, list_y, list_width, list_h
    )
end

function LauncherView:getVisibleGameCount(list_height)
    return math.floor(list_height / (self.button_height + self.button_padding))
end

function LauncherView:draw(filtered_games, tokens)
    UIComponents.drawWindow(0, 0, love.graphics.getWidth(), love.graphics.getHeight(), "Game Collection - MVP")
    
    self:drawCategoryButtons(10, 50, self.selected_category)
    UIComponents.drawTokenCounter(love.graphics.getWidth() - 200, 10, tokens)
    
    local list_width = self.detail_panel_open and (love.graphics.getWidth() - self.detail_panel_width - 20) or (love.graphics.getWidth() - 20)
    self:drawGameList(10, 90, list_width, love.graphics.getHeight() - 100, 
        filtered_games, self.selected_index, self.hovered_game_id)
    
    if self.detail_panel_open and self.selected_game then
        local panel_x = love.graphics.getWidth() - self.detail_panel_width - 5
        self:drawGameDetailPanel(panel_x, 90, self.detail_panel_width, 
            love.graphics.getHeight() - 100, self.selected_game)
    end
end

function LauncherView:mousepressed(x, y, button, filtered_games, viewport_width, viewport_height)
    if button ~= 1 then return nil end

    local categories = {"all", "action", "puzzle", "arcade", "locked", "unlocked", "completed", "easy", "medium", "hard"}
    local button_width = 75
    local cat_button_y = 10
    local cat_button_x_start = 10

    for i, category in ipairs(categories) do
        local bx = cat_button_x_start + (i - 1) * (button_width + 5)
        local by = cat_button_y

        if x >= bx and x <= bx + button_width and y >= by and y <= by + self.category_button_height then
            self.selected_category = category
            return {name = "filter_changed", category = category}
        end
    end

    local list_y = 50
    local list_h = viewport_height - list_y - 10
    local list_x = 10
    local list_width = (self.detail_panel_open and self.selected_game) and (viewport_width - self.detail_panel_width - 20) or (viewport_width - 20)

    -- Scrollbar interactions (list origin local)
    if self._sb and self._sb.list and self._sb.list.geom then
        local g = self._sb.list.geom
        local lx, ly = x - list_x, y - list_y
        if ly >= 0 and ly <= list_h then
            local UI = UIComponents
            local off_px = ((self.scroll_offset or 1) - 1) * (self.button_height + self.button_padding)
            local res = UI.scrollbarHandlePress(lx, ly, button, g, off_px, nil)
            if res and res.consumed then
                if res.new_offset_px ~= nil then
                    local visible = self:getVisibleGameCount(list_h)
                    local max_index = math.max(1, #filtered_games - visible + 1)
                    local new_idx = math.floor(res.new_offset_px / (self.button_height + self.button_padding)) + 1
                    self.scroll_offset = math.max(1, math.min(max_index, new_idx))
                end
                if res.drag then
                    self._sb.list.dragging = true
                    self._sb.list.drag = { start_y = res.drag.start_y, offset_start_px = res.drag.offset_start_px }
                end
                return { name = 'content_interaction' }
            end
        end
    end

    local clicked_game_id = self:getGameAtPosition(x, y, filtered_games, list_x, list_y, list_width, list_h)
    if clicked_game_id then
        for i, g in ipairs(filtered_games) do
            if g.id == clicked_game_id then
                local is_double_click = (self.last_click_game == clicked_game_id and
                                        love.timer.getTime() - self.last_click_time < 0.5)

                if is_double_click then
                    if self.player_data:isGameUnlocked(clicked_game_id) then
                        return {name = "launch_game", id = clicked_game_id}
                    else
                        self.selected_index = i
                        self.selected_game = g
                        self.detail_panel_open = true
                        self.last_click_game = clicked_game_id
                        self.last_click_time = love.timer.getTime()
                        return {name = "game_selected", game = g}
                    end
                end

                self.selected_index = i
                self.selected_game = g
                self.detail_panel_open = true

                self.last_click_game = clicked_game_id
                self.last_click_time = love.timer.getTime()
                return {name = "game_selected", game = g}
            end
        end
    end

    local detail_panel_hit = false
    if self.detail_panel_open and self.selected_game then
        local effective_detail_width = math.min(self.detail_panel_width, viewport_width * 0.5)
        local current_list_width = viewport_width - effective_detail_width - 20
        local panel_x = list_x + current_list_width + 10
        local panel_y = list_y
        local panel_h = list_h

        if x >= panel_x and x <= panel_x + effective_detail_width and y >= panel_y and y <= panel_y + panel_h then
             detail_panel_hit = true
             local button_y = panel_y + panel_h - 45
             local button_w = effective_detail_width - 20
             local button_h = 35
             local button_x = panel_x + 10

             if x >= button_x and x <= button_x + button_w and
                y >= button_y and y <= button_y + button_h then
                 return {name = "launch_game", id = self.selected_game.id}
             end
             return nil
        end
    end

    if self.detail_panel_open and not detail_panel_hit then
         if not clicked_game_id then
             self.detail_panel_open = false
             return nil
         end
    end

    return nil
end

function LauncherView:mousemoved(x, y, dx, dy)
    if not self.controller or not self.controller.viewport then return end
    local list_y = 50
    local list_h = self.controller.viewport.height - list_y - 10
    local list_x = 10
    local list_width = (self.detail_panel_open and self.selected_game) and 
                       (self.controller.viewport.width - self.detail_panel_width - 20) or 
                       (self.controller.viewport.width - 20)
    if self._sb and self._sb.list and self._sb.list.dragging and self._sb.list.geom then
        local g = self._sb.list.geom
        local lx, ly = x - list_x, y - list_y
        local UI = UIComponents
        local res = UI.scrollbarHandleMove(ly, self._sb.list.drag, g)
        if res and res.consumed and res.new_offset_px ~= nil then
            local visible = self:getVisibleGameCount(list_h)
            local max_index = math.max(1, #self.controller.filtered_games - visible + 1)
            local new_idx = math.floor(res.new_offset_px / (self.button_height + self.button_padding)) + 1
            self.scroll_offset = math.max(1, math.min(max_index, new_idx))
            return { name = 'content_interaction' }
        end
    end
end

function LauncherView:mousereleased(x, y, button)
    if button == 1 and self._sb and self._sb.list and self._sb.list.dragging then
        self._sb.list.dragging = false
        self._sb.list.drag = nil
        return { name = 'content_interaction' }
    end
end

function LauncherView:wheelmoved(x, y, filtered_games, viewport_width, viewport_height)
    local list_y = 50
    local list_h = viewport_height - list_y - 10
    local list_x = 10
    local list_width = (self.detail_panel_open and self.selected_game) and (viewport_width - self.detail_panel_width - 20) or (viewport_width - 20)

    local mx, my = love.mouse.getPosition()
    local window_x = self.controller.viewport and self.controller.viewport.x or 0
    local window_y = self.controller.viewport and self.controller.viewport.y or 0

     if mx >= window_x + list_x and mx <= window_x + list_x + list_width and
        my >= window_y + list_y and my <= window_y + list_y + list_h then

        local visible_games = self:getVisibleGameCount(list_h)
        local max_scroll = math.max(1, #filtered_games - visible_games + 1)

        if y > 0 then
            self.scroll_offset = math.max(1, (self.scroll_offset or 1) - 1)
        elseif y < 0 then
            self.scroll_offset = math.min(max_scroll, (self.scroll_offset or 1) + 1)
        end
     end
end

function LauncherView:getGameAtPosition(x, y, filtered_games, list_x, list_y, list_width, list_height)
    local games = filtered_games or {}

    if not games or #games == 0 then
        return nil
    end

    if x < list_x or x > list_x + list_width or y < list_y or y > list_y + list_height then
        return nil
    end

    local visible_games = self:getVisibleGameCount(list_height)
    local shows_scrollbar = (#games > visible_games)
    local sb_lane_w = shows_scrollbar and UIComponents.getScrollbarLaneWidth() or 0
    if x > list_x + (list_width - sb_lane_w) then
        return nil -- In scrollbar lane
    end
    local start_index = self.scroll_offset or 1

    for i = 0, visible_games - 1 do
        local game_index = start_index + i
        if game_index <= #games then
            local button_y = list_y + i * (self.button_height + self.button_padding)

            if y >= button_y and y <= button_y + self.button_height then
                return games[game_index].id
            end
        end
    end

    return nil
end

function LauncherView:drawCategoryButtons(x, y, selected_category)
    local categories = {
        {id = "all", name = "All"}, {id = "action", name = "Action"}, {id = "puzzle", name = "Puzzle"},
        {id = "arcade", name = "Arcade"}, {id = "locked", name = "Locked"}, {id = "unlocked", name = "Unlocked"},
        {id = "completed", name = "Completed"}, {id = "easy", name = "Easy"}, {id = "medium", name = "Medium"},
        {id = "hard", name = "Hard"}
    }
    local button_width = 75
    local button_height = self.category_button_height
    for i, category in ipairs(categories) do
        local bx = x + (i - 1) * (button_width + 5)
        local by = y
        if category.id == selected_category then
            love.graphics.setColor(0.2, 0.2, 0.6)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle('fill', bx, by, button_width, button_height)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle('line', bx, by, button_width, button_height)
        love.graphics.setColor(1, 1, 1)
        local text_width = love.graphics.getFont():getWidth(category.name)
        love.graphics.print(category.name, bx + (button_width - text_width) / 2, by + 8, 0, 0.8, 0.8)
    end
end

function LauncherView:drawGameList(x, y, w, h, games, selected_index, hovered_game_id)
    local button_height = self.button_height
    local button_padding = self.button_padding
    local visible_games = self:getVisibleGameCount(h)

    local start_index = self.scroll_offset or 1
    start_index = math.max(1, math.min(start_index, math.max(1, #games - visible_games + 1)))
    self.scroll_offset = start_index

    local end_index = math.min(#games, start_index + visible_games - 1)

    local shows_scrollbar = (#games > visible_games)
    local sb_lane_w = shows_scrollbar and 10 or 0
    local content_w = w - sb_lane_w

    for i = start_index, end_index do
        local game_data = games[i]
        if game_data then
            local by = y + (i - start_index) * (button_height + button_padding)
            self:drawGameCard(x, by, content_w, button_height, game_data, i == selected_index,
                hovered_game_id == game_data.id, self.player_data, self.game_data)
        end
    end

    if #games > visible_games then
        local UI = UIComponents
        local item_h = (self.button_height + self.button_padding)
        -- Translate to list origin so helper computes correctly
        love.graphics.push(); love.graphics.translate(x, y)
        local sb_geom = UI.computeScrollbar({
            viewport_w = w,
            viewport_h = h,
            content_h = (#games) * item_h,
            offset = ((start_index - 1) * item_h),
            -- width/margin/arrow heights/min thumb from config defaults
        })
        UI.drawScrollbar(sb_geom)
        self._sb.list.geom = sb_geom
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Showing %d-%d of %d games", start_index, end_index, #games), x, y + h + 5, 0, 0.9, 0.9)
end

function LauncherView:drawGameCard(x, y, w, h, game_data, selected, hovered, player_data, game_data_obj)
    local SpriteLoader = require('src.utils.sprite_loader')
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    local SpriteManager = require('src.utils.sprite_manager')
    local sprite_manager = self.sprite_manager or (self.di and self.di.spriteManager)
    local formula_renderer = FormulaRenderer:new(self.di)
    
    local is_unlocked = player_data:isGameUnlocked(game_data.id)
    local perf = player_data:getGamePerformance(game_data.id)
    local is_completed = perf ~= nil
    
    if selected then
        love.graphics.setColor(0.3, 0.3, 0.7)
    elseif hovered then
        love.graphics.setColor(0.35, 0.35, 0.35)
    else
        love.graphics.setColor(0.25, 0.25, 0.25)
    end
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    
    local icon_size = 64
    local icon_x = x + 8
    local icon_y = y + (h - icon_size) / 2
    
    local sprite_name = game_data.icon_sprite or "game_freecell-0"
    local palette_id = sprite_manager:getPaletteId(game_data)
    local tint = is_unlocked and {1, 1, 1} or {0.5, 0.5, 0.5}
    sprite_loader:drawSprite(sprite_name, icon_x, icon_y, icon_size, icon_size, tint, palette_id)
    
    local badge_x = icon_x + icon_size - 16
    local badge_y = icon_y
    if perf and perf.auto_completed then
        UIComponents.drawBadge(badge_x, badge_y, 16, "A", {0.5, 0.5, 1})
    elseif is_completed then
         UIComponents.drawBadge(badge_x, badge_y, 16, "✓", {0, 1, 0})
    elseif not is_unlocked then
         UIComponents.drawBadge(badge_x, badge_y, 16, "🔒", {1, 0, 0})
    end
    
    local text_x = icon_x + icon_size + 12
    local text_w = w - (text_x - x) - 120
    
    -- Phase 1.5: Display variant name if available
    local display_name = game_data.display_name
    if self.variant_loader then
        local variant = self.variant_loader:getVariantData(game_data.id)
        if variant and variant.name then
            display_name = variant.name
        end
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(display_name, text_x, y + 8, 0, 1.1, 1.1)
    
    local star_y = y + 28
    local difficulty = game_data.difficulty_level or 1
    local stars = math.min(5, math.ceil(difficulty / 2))
    for i = 1, 5 do
        if i <= stars then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.print("★", text_x + (i - 1) * 14, star_y, 0, 0.9, 0.9)
    end
    
    local formula_y = y + 48
    love.graphics.push()
    -- Translate relative to current window/content transform without resetting to screen origin
    love.graphics.translate(text_x, formula_y)
    formula_renderer:draw(game_data, 0, 0, text_w, 16)
    love.graphics.pop()
    
    local stats_x = x + w - 110
    
    if is_completed and perf then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("Power:", stats_x, y + 8, 0, 0.85, 0.85)
        love.graphics.print(math.floor(perf.best_score), stats_x, y + 24, 0, 1.2, 1.2)
    elseif not is_unlocked then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("Cost:", stats_x, y + 8, 0, 0.85, 0.85)
        love.graphics.print(game_data.unlock_cost, stats_x, y + 24, 0, 1.0, 1.0)
    end
    
    love.graphics.setColor(1, 1, 0)
    love.graphics.print(string.format("×%.1f", game_data.variant_multiplier), stats_x, y + h - 22, 0, 1.1, 1.1)
end

function LauncherView:drawWindowed(filtered_games, tokens, viewport_width, viewport_height)
    if type(viewport_width) ~= "number" or type(viewport_height) ~= "number" or viewport_width <= 0 or viewport_height <= 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Launcher Error: Invalid viewport dimensions received.", 5, 5, (self.controller.viewport and self.controller.viewport.width or 200) - 10, "left")
        print("ERROR in LauncherView:drawWindowed - Invalid viewport dimensions:", viewport_width, viewport_height)
        return
    end

    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    self:drawCategoryButtons(10, 10, self.selected_category, viewport_width)
    UIComponents.drawTokenCounter(viewport_width - 200, 10, tokens)

    local list_y = 50
    local list_h = viewport_height - list_y - 10

    if type(list_h) ~= "number" or list_h <= 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Launcher Error: Calculated list height is invalid.", 5, list_y, viewport_width - 10, "left")
        print("ERROR in LauncherView:drawWindowed - Invalid calculated list_h:", list_h, " (viewport_height:", viewport_height, ")")
        return
    end

    local list_x = 10
    local list_width
    local detail_panel_x = 0

    if self.detail_panel_open and self.selected_game then
        local effective_detail_width = math.min(self.detail_panel_width, viewport_width * 0.5)
        list_width = viewport_width - effective_detail_width - 20
        detail_panel_x = list_x + list_width + 10
        self:drawGameDetailPanel(detail_panel_x, list_y, effective_detail_width,
            list_h, self.selected_game)
    else
        list_width = viewport_width - 20
    end

    self:drawGameList(list_x, list_y, list_width, list_h,
        filtered_games, self.selected_index, self.hovered_game_id)
end

function LauncherView:drawGameDetailPanel(x, y, w, h, game_data)
    local SpriteLoader = require('src.utils.sprite_loader')
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    local SpriteManager = require('src.utils.sprite_manager')
    local sprite_manager = self.sprite_manager or (self.di and self.di.spriteManager)
    local formula_renderer = FormulaRenderer:new(self.di)
    local metric_legend = MetricLegend:new(self.di)

    local function drawHeaderPanel()
        UIComponents.drawPanel(x, y, w, h, {0.2, 0.2, 0.2})
        return y + 10, 20 -- line_y, line_height
    end

    local function drawPreview(line_y)
        local preview_size = 80
        local preview_x = x + (w - preview_size) / 2
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.rectangle('fill', preview_x - 5, line_y - 5, preview_size + 10, preview_size + 10)
        local sprite_name = game_data.icon_sprite or "game_freecell-0"
        local palette_id = sprite_manager:getPaletteId(game_data)
        sprite_loader:drawSprite(sprite_name, preview_x, line_y, preview_size, preview_size, {1, 1, 1}, palette_id)
        return line_y + preview_size + 15
    end

    local function drawTitleAndDifficulty(line_y)
        -- Phase 1.5: Display variant name if available
        local display_name = game_data.display_name
        local variant = nil
        if self.variant_loader then
            variant = self.variant_loader:getVariantData(game_data.id)
            if variant and variant.name then
                display_name = variant.name
            end
        end

        love.graphics.setColor(1, 1, 1)
        local title_width = love.graphics.getFont():getWidth(display_name) * 1.2
        love.graphics.print(display_name, x + (w - title_width) / 2, line_y, 0, 1.2, 1.2)
        line_y = line_y + 20 * 1.5

        -- Phase 1.5: Display flavor text if available
        if variant and variant.flavor_text and variant.flavor_text ~= "" then
            love.graphics.setColor(0.8, 0.8, 0.9)
            local wrapped = {}
            local current_line = ""
            for word in variant.flavor_text:gmatch("%S+") do
                local test_line = current_line == "" and word or (current_line .. " " .. word)
                if love.graphics.getFont():getWidth(test_line) > (w - 20) then
                    table.insert(wrapped, current_line)
                    current_line = word
                else
                    current_line = test_line
                end
            end
            if current_line ~= "" then
                table.insert(wrapped, current_line)
            end

            for _, line in ipairs(wrapped) do
                local line_width = love.graphics.getFont():getWidth(line)
                love.graphics.print(line, x + (w - line_width) / 2, line_y, 0, 0.9, 0.9)
                line_y = line_y + 15
            end
            line_y = line_y + 10
        end

        local difficulty = game_data.difficulty_level or 1

        -- Phase 1.5: Apply variant difficulty modifier
        local difficulty_modifier = 1.0
        if variant and variant.difficulty_modifier then
            difficulty_modifier = variant.difficulty_modifier
        end

        local diff_text, diff_color = "Easy", {0, 1, 0}
        if difficulty > 6 then diff_text, diff_color = "HARD", {1, 0, 0}
        elseif difficulty > 3 then diff_text, diff_color = "Medium", {1, 1, 0} end

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Difficulty: ", x + 10, line_y)
        love.graphics.setColor(diff_color)
        love.graphics.print(diff_text, x + 90, line_y)

        -- Phase 1.5: Show difficulty modifier if not 1.0
        if difficulty_modifier ~= 1.0 then
            love.graphics.setColor(1, 0.7, 0)
            love.graphics.print(string.format("×%.1f", difficulty_modifier), x + 160, line_y, 0, 0.9, 0.9)
        end

        line_y = line_y + 20

        -- Show stars
        local stars = math.min(5, math.ceil(difficulty / 2))
        for i = 1, 5 do
            if i <= stars then love.graphics.setColor(1, 1, 0) else love.graphics.setColor(0.3, 0.3, 0.3) end
            love.graphics.print("★", x + 10 + (i - 1) * 16, line_y, 0, 1.0, 1.0)
        end
        return line_y + 20
    end

    local function drawTierAndCost(line_y)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Tier: " .. game_data.tier, x + 10, line_y)
        line_y = line_y + 20

        -- Phase 1.5: Show enemy types if variant has them
        local variant = self.variant_loader and self.variant_loader:getVariantData(game_data.id)
        if variant and variant.enemies and #variant.enemies > 0 then
            love.graphics.setColor(0.9, 0.7, 0.7)
            love.graphics.print("Enemies:", x + 10, line_y)
            line_y = line_y + 18
            for _, enemy in ipairs(variant.enemies) do
                love.graphics.setColor(0.7, 0.7, 0.7)
                love.graphics.print("• " .. enemy.type, x + 20, line_y, 0, 0.85, 0.85)
                line_y = line_y + 15
            end
            line_y = line_y + 5
        end

        local is_unlocked = self.player_data:isGameUnlocked(game_data.id)
        if not is_unlocked then
            love.graphics.setColor(1, 0.5, 0)
            love.graphics.print("Unlock Cost: " .. game_data.unlock_cost .. " tokens", x + 10, line_y)
            line_y = line_y + 20
        end
        return line_y, is_unlocked
    end

    local function drawFormula(line_y)
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("POWER FORMULA:", x + 10, line_y, 0, 1.1, 1.1)
        line_y = line_y + 20 + 5
        line_y = formula_renderer:draw(game_data, x + 10, line_y, w - 20, 18)
        return line_y + 10
    end

    local function drawPerformance(line_y)
        local perf = self.player_data:getGamePerformance(game_data.id)
        if perf then
            love.graphics.setColor(0, 1, 0)
            love.graphics.print("Your Best Performance:", x + 10, line_y)
            line_y = line_y + 20
            line_y = metric_legend:draw(game_data, perf.metrics, x + 10, line_y, w - 20, true)
            line_y = line_y + 5
            love.graphics.setColor(0, 1, 1)
            love.graphics.print("Power: " .. math.floor(perf.best_score), x + 10, line_y, 0, 1.2, 1.2)
            line_y = line_y + 20
            if perf.auto_completed then
                UIComponents.drawBadge(x + 10, line_y, 15, "AUTO", {0.5, 0.5, 1})
                love.graphics.setColor(0.8, 0.8, 1)
                love.graphics.print("[Auto-Completed]", x + 30, line_y, 0, 0.9, 0.9)
                line_y = line_y + 20
            end
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("Not yet played", x + 10, line_y)
            line_y = line_y + 20
        end
        return line_y
    end

    local function drawAutoplay(line_y)
        love.graphics.setColor(0.8, 0.8, 1)
        love.graphics.print("Auto-Play Estimate:", x + 10, line_y)
        line_y = line_y + 20
        local auto_power = game_data.formula_function(game_data.auto_play_performance)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("Power: ~" .. math.floor(auto_power), x + 10, line_y, 0, 0.9, 0.9)
        line_y = line_y + 20
        if (game_data.difficulty_level or 1) > 8 then
            line_y = line_y + 10
            love.graphics.setColor(1, 0, 0)
            love.graphics.print("WARNING: HIGH RISK!", x + 10, line_y, 0, 0.9, 0.9)
        end
        return line_y
    end

    local function drawActionButton()
        local button_y = y + h - 45
        local is_unlocked = self.player_data:isGameUnlocked(game_data.id)
        local button_text = is_unlocked and "PLAY GAME" or "UNLOCK & PLAY"
        local is_launch_hovered = self.hovered_button_id == "launch_" .. game_data.id
        UIComponents.drawButton(x + 10, button_y, w - 20, 35, button_text, true, is_launch_hovered)
    end

    -- Orchestrate section draws
    local line_y = select(1, drawHeaderPanel())
    line_y = drawPreview(line_y)
    line_y = drawTitleAndDifficulty(line_y)
    local is_unlocked
    line_y, is_unlocked = drawTierAndCost(line_y)
    line_y = drawFormula(line_y)
    line_y = drawPerformance(line_y)
    line_y = drawAutoplay(line_y)
    drawActionButton()
end

return LauncherView