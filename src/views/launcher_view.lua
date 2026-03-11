-- launcher_view.lua: View class for the game launcher

local BaseView = require('src.views.base_view')
local UIComponents = require('src.views.ui_components')
local FormulaRenderer = require('src.views.formula_renderer')
local MetricLegend = require('src.views.metric_legend')
local GameSpriteHelper = require('src.utils.game_sprite_helper')  -- Phase 4
local LauncherView = BaseView:extend('LauncherView')

function LauncherView:init(controller, player_data, game_data)
    LauncherView.super.init(self, controller) -- Initialize BaseView
    self.player_data = player_data
    self.game_data = game_data
    local di = controller and controller.di
    self.di = di
    self.sprite_loader = (di and di.spriteLoader) or nil
    self.sprite_manager = (di and di.spriteManager) or nil
    self.variant_loader = (di and di.gameVariantLoader) or nil  -- Phase 1.5
    self.sprite_set_loader = (di and di.spriteSetLoader) or nil  -- Phase 4

    self.selected_category = "all"
    self.selected_index = 1
    self.scroll_offset = 1
    self.hovered_game_id = nil
    self.selected_game = nil
    self.detail_panel_open = false

    -- View mode: "list" or "thumbnail"
    self.view_mode = "list"

    -- Layout constants (base values, recalculated in updateLayout)
    self.padding = 10
    self.button_height = 80
    self.button_padding = 5
    self.category_button_height = 26

    -- Thumbnail layout constants
    self.thumb_padding = 6
    self.thumb_label_height = 16

    -- Computed layout (set by updateLayout)
    self.layout = {}

    -- Double-click tracking
    self.last_click_time = 0
    self.last_click_game = nil
end

-- Category definitions (shared between draw and hit-testing)
LauncherView.CATEGORIES = {
    {id = "all", name = "All"}, {id = "action", name = "Action"}, {id = "puzzle", name = "Puzzle"},
    {id = "arcade", name = "Arcade"}, {id = "locked", name = "Locked"}, {id = "unlocked", name = "Unlocked"},
    {id = "affordable", name = "$$$"}, {id = "completed", name = "Done"}, {id = "easy", name = "Easy"},
    {id = "medium", name = "Med"}, {id = "hard", name = "Hard"}
}

function LauncherView:updateLayout(viewport_width, viewport_height)
    local L = {}
    local pad = self.padding
    local font = love.graphics.getFont()

    -- Right side of header: toggle buttons, then token counter
    L.cat_btn_h = self.category_button_height
    L.toggle_w = L.cat_btn_h * 2 + 2
    L.toggle_h = L.cat_btn_h
    L.toggle_x = viewport_width - pad - L.toggle_w
    L.toggle_y = pad

    -- Cheats toggle button
    L.cheats_w = 60
    L.cheats_h = L.cat_btn_h
    L.cheats_x = L.toggle_x - L.cheats_w - 6
    L.cheats_y = pad

    L.token_w = 160
    L.token_x = L.cheats_x - L.token_w - 6
    L.token_y = pad

    -- Category buttons: fit into available width (left of token counter)
    local cats = LauncherView.CATEGORIES
    local cat_area_w = L.token_x - pad - 8  -- leave gap before token counter
    local cat_spacing = 3
    local total_spacing = (cat_spacing * (#cats - 1))
    L.cat_btn_w = math.floor((cat_area_w - total_spacing) / #cats)
    L.cat_btn_w = math.max(32, math.min(75, L.cat_btn_w))
    L.cat_x = pad
    L.cat_y = pad
    L.cat_spacing = cat_spacing

    -- Check if buttons need to wrap to a second row
    local total_btn_w = #cats * L.cat_btn_w + total_spacing
    L.cat_rows = 1
    if total_btn_w > cat_area_w then
        -- Two-row layout: split evenly
        local per_row = math.ceil(#cats / 2)
        local row_area_w = viewport_width - 2 * pad
        L.cat_btn_w = math.floor((row_area_w - (per_row - 1) * cat_spacing) / per_row)
        L.cat_btn_w = math.max(32, L.cat_btn_w)
        L.cat_rows = 2
        L.cat_per_row = per_row
    end

    -- Header height (below category buttons)
    local header_h = L.cat_y + L.cat_rows * (L.cat_btn_h + 3) + 6

    -- Detail panel
    local detail_frac = 0.38
    L.detail_w = math.floor(math.min(400, math.max(200, viewport_width * detail_frac)))

    -- Game list area
    L.list_x = pad
    L.list_y = header_h
    L.list_h = viewport_height - header_h - 24  -- room for "Showing X-Y of Z"

    -- List width depends on whether detail panel is open
    L.list_w_full = viewport_width - 2 * pad
    L.list_w_with_detail = viewport_width - L.detail_w - 3 * pad

    -- Detail panel position
    L.detail_x = viewport_width - L.detail_w - pad
    L.detail_y = header_h
    L.detail_h = L.list_h

    -- Game card internal layout (proportional to card width)
    L.icon_size = math.max(32, math.min(64, math.floor(self.button_height * 0.8)))
    L.stats_col_w = math.max(60, math.min(110, math.floor(viewport_width * 0.12)))

    -- Thumbnail grid layout
    local thumb_pad = self.thumb_padding
    local avail_w = L.list_w_full
    local min_thumb_w = 160
    local max_thumb_w = 240
    L.thumb_cols = math.max(1, math.floor((avail_w + thumb_pad) / (min_thumb_w + thumb_pad)))
    L.thumb_w = math.floor((avail_w - (L.thumb_cols - 1) * thumb_pad) / L.thumb_cols)
    L.thumb_w = math.min(max_thumb_w, L.thumb_w)
    L.thumb_icon_size = L.thumb_w - 8
    L.thumb_h = L.thumb_icon_size + 8

    self.layout = L
end

function LauncherView:getListWidth()
    local L = self.layout
    if not L.list_w_full then return 400 end
    if self.detail_panel_open and self.selected_game then
        return L.list_w_with_detail
    end
    return L.list_w_full
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

    local L = self.layout
    if not L.list_x then return end
    local list_width = self:getListWidth()

    self.hovered_game_id = self:getGameAtPosition(
        local_mx, local_my,
        self.controller.filtered_games,
        L.list_x, L.list_y, list_width, L.list_h
    )
end

function LauncherView:getVisibleGameCount(list_height)
    if self.view_mode == "thumbnail" then
        local L = self.layout
        if not L.thumb_h or L.thumb_h <= 0 then return 1 end
        local rows = math.floor(list_height / (L.thumb_h + self.thumb_padding))
        return math.max(1, rows * self:getThumbCols())
    end
    return math.floor(list_height / (self.button_height + self.button_padding))
end

function LauncherView:getVisibleRowCount(list_height)
    local L = self.layout
    if not L.thumb_h or L.thumb_h <= 0 then return 1 end
    return math.max(1, math.floor(list_height / (L.thumb_h + self.thumb_padding)))
end

function LauncherView:getThumbCols()
    local L = self.layout
    if not L.thumb_w then return 1 end
    local list_width = self:getListWidth()
    return math.max(1, math.floor((list_width + self.thumb_padding) / (L.thumb_w + self.thumb_padding)))
end


function LauncherView:mousepressed(x, y, button, filtered_games, viewport_width, viewport_height)
    if button ~= 1 then return nil end

    local L = self.layout
    if not L.list_x then return nil end

    -- Cheats toggle (only if CE unlocked)
    if self:isCEUnlocked() and L.cheats_x and x >= L.cheats_x and x <= L.cheats_x + L.cheats_w and
       y >= L.cheats_y and y <= L.cheats_y + L.cheats_h then
        return {name = "cheats_toggled"}
    end

    -- View mode toggle
    if L.toggle_x and x >= L.toggle_x and x <= L.toggle_x + L.toggle_w and
       y >= L.toggle_y and y <= L.toggle_y + L.toggle_h then
        local half = math.floor(L.toggle_w / 2)
        if x < L.toggle_x + half then
            self.view_mode = "list"
        else
            self.view_mode = "thumbnail"
        end
        self.scroll_offset = 1
        return {name = "view_mode_changed"}
    end

    local cats = LauncherView.CATEGORIES

    for i, category in ipairs(cats) do
        local bx, by, bw, bh = self:getCategoryButtonRect(i)
        if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
            self.selected_category = category.id
            return {name = "filter_changed", category = category.id}
        end
    end

    local list_x = L.list_x
    local list_y = L.list_y
    local list_h = L.list_h
    local list_width = self:getListWidth()

    -- Scrollbar is now handled by state, not view
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
                        self:scrollToSelected(filtered_games)
                        self.last_click_game = clicked_game_id
                        self.last_click_time = love.timer.getTime()
                        return {name = "game_selected", game = g}
                    end
                end

                self.selected_index = i
                self.selected_game = g
                self.detail_panel_open = true
                self:scrollToSelected(filtered_games)

                self.last_click_game = clicked_game_id
                self.last_click_time = love.timer.getTime()
                return {name = "game_selected", game = g}
            end
        end
    end

    local detail_panel_hit = false
    if self.detail_panel_open and self.selected_game then
        local panel_x = L.detail_x
        local panel_y = L.detail_y
        local panel_w = L.detail_w
        local panel_h = L.detail_h

        if x >= panel_x and x <= panel_x + panel_w and y >= panel_y and y <= panel_y + panel_h then
             detail_panel_hit = true
             local button_y = panel_y + panel_h - 45
             local button_w = panel_w - 20
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

-- Scrollbar interaction removed - now handled by state's ScrollbarController

function LauncherView:wheelmoved(x, y, filtered_games, viewport_width, viewport_height)
    local L = self.layout
    if not L.list_x then return end
    local list_x = L.list_x
    local list_y = L.list_y
    local list_h = L.list_h
    local list_width = self:getListWidth()

    local mx, my = love.mouse.getPosition()
    local window_x = self.controller.viewport and self.controller.viewport.x or 0
    local window_y = self.controller.viewport and self.controller.viewport.y or 0

     if mx >= window_x + list_x and mx <= window_x + list_x + list_width and
        my >= window_y + list_y and my <= window_y + list_y + list_h then

        if self.view_mode == "thumbnail" then
            local cols = self:getThumbCols()
            local total_rows = math.ceil(#filtered_games / cols)
            local visible_rows = self:getVisibleRowCount(list_h)
            local max_scroll = math.max(1, total_rows - visible_rows + 1)

            if y > 0 then
                self.scroll_offset = math.max(1, (self.scroll_offset or 1) - 1)
            elseif y < 0 then
                self.scroll_offset = math.min(max_scroll, (self.scroll_offset or 1) + 1)
            end
        else
            local visible_games = self:getVisibleGameCount(list_h)
            local max_scroll = math.max(1, #filtered_games - visible_games + 1)

            if y > 0 then
                self.scroll_offset = math.max(1, (self.scroll_offset or 1) - 1)
            elseif y < 0 then
                self.scroll_offset = math.min(max_scroll, (self.scroll_offset or 1) + 1)
            end
        end
     end
end

function LauncherView:scrollToSelected(filtered_games)
    if not self.selected_index or not filtered_games or #filtered_games == 0 then return end
    local L = self.layout
    if not L.list_h then return end
    local list_h = L.list_h

    if self.view_mode == "thumbnail" then
        local cols = self:getThumbCols()
        local selected_row = math.ceil(self.selected_index / cols) -- 1-indexed row
        local visible_rows = self:getVisibleRowCount(list_h)
        local total_rows = math.ceil(#filtered_games / cols)
        local max_scroll = math.max(1, total_rows - visible_rows + 1)

        -- If selected row is already visible, don't move
        local current_start = self.scroll_offset or 1
        local current_end = current_start + visible_rows - 1
        if selected_row >= current_start and selected_row <= current_end then return end

        -- Center the selected row in the view
        local target = selected_row - math.floor(visible_rows / 2)
        self.scroll_offset = math.max(1, math.min(max_scroll, target))
    else
        local visible_games = self:getVisibleGameCount(list_h)
        local max_scroll = math.max(1, #filtered_games - visible_games + 1)

        local current_start = self.scroll_offset or 1
        local current_end = current_start + visible_games - 1
        if self.selected_index >= current_start and self.selected_index <= current_end then return end

        local target = self.selected_index - math.floor(visible_games / 2)
        self.scroll_offset = math.max(1, math.min(max_scroll, target))
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

    if self.view_mode == "thumbnail" then
        return self:getGameAtPositionThumbnail(x, y, games, list_x, list_y, list_width, list_height)
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

function LauncherView:getGameAtPositionThumbnail(x, y, games, list_x, list_y, list_width, list_height)
    local L = self.layout
    local cols = self:getThumbCols()
    local thumb_w = L.thumb_w
    local thumb_h = L.thumb_h
    local thumb_pad = self.thumb_padding

    local rel_x = x - list_x
    local rel_y = y - list_y

    local col = math.floor(rel_x / (thumb_w + thumb_pad))
    if col >= cols then return nil end
    -- Check we're actually on a card, not in padding
    if rel_x > col * (thumb_w + thumb_pad) + thumb_w then return nil end

    local start_row = math.max(0, (self.scroll_offset or 1) - 1)
    local row_in_view = math.floor(rel_y / (thumb_h + thumb_pad))
    -- Check we're on a card, not in padding
    if rel_y > row_in_view * (thumb_h + thumb_pad) + thumb_h then return nil end

    local row = start_row + row_in_view
    local game_idx = row * cols + col + 1

    if game_idx >= 1 and game_idx <= #games then
        return games[game_idx].id
    end
    return nil
end

function LauncherView:getCategoryButtonRect(i)
    local L = self.layout
    local cats = LauncherView.CATEGORIES
    if L.cat_rows == 2 then
        local per_row = L.cat_per_row
        local row = math.ceil(i / per_row) - 1
        local col = (i - 1) % per_row
        local bx = L.cat_x + col * (L.cat_btn_w + L.cat_spacing)
        local by = L.cat_y + row * (L.cat_btn_h + 3)
        return bx, by, L.cat_btn_w, L.cat_btn_h
    else
        local bx = L.cat_x + (i - 1) * (L.cat_btn_w + L.cat_spacing)
        local by = L.cat_y
        return bx, by, L.cat_btn_w, L.cat_btn_h
    end
end

function LauncherView:drawCategoryButtons(x, y, selected_category, viewport_width)
    local L = self.layout
    local cats = LauncherView.CATEGORIES
    local font = love.graphics.getFont()

    for i, category in ipairs(cats) do
        local bx, by, bw, bh = self:getCategoryButtonRect(i)
        if category.id == selected_category then
            love.graphics.setColor(0.2, 0.2, 0.6)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle('fill', bx, by, bw, bh)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle('line', bx, by, bw, bh)
        love.graphics.setColor(1, 1, 1)
        local text_width = font:getWidth(category.name)
        local scale = math.min(0.85, (bw - 6) / math.max(1, text_width))
        love.graphics.print(category.name, bx + (bw - text_width * scale) / 2, by + (bh - font:getHeight() * scale) / 2, 0, scale, scale)
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

        -- Use state's scrollbar controller
        local scrollbar = self.controller.scrollbar
        if scrollbar then
            scrollbar:setPosition(x, y)
            local max_scroll = math.max(0, #games - visible_games)
            local sb_geom = scrollbar:compute(w, h, #games * item_h, start_index - 1, max_scroll)

            if sb_geom then
                love.graphics.push()
                love.graphics.translate(x, y)
                UI.drawScrollbar(sb_geom)
                love.graphics.pop()
            end
        end
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Showing %d-%d of %d games", start_index, end_index, #games), x, y + h + 5, 0, 0.9, 0.9)
end

function LauncherView:drawGameIcon(icon_x, icon_y, icon_size, game_data, is_unlocked)
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    local sprite_manager = self.sprite_manager or (self.di and self.di.spriteManager)

    -- Try boxart first (highest priority)
    if self.variant_loader then
        local boxart = self.variant_loader:getBoxart(game_data.id)
        if boxart then
            local tint = is_unlocked and {1, 1, 1} or {0.5, 0.5, 0.5}
            love.graphics.setColor(tint[1], tint[2], tint[3])
            local iw, ih = boxart:getWidth(), boxart:getHeight()
            local scale = math.min(icon_size / iw, icon_size / ih)
            local draw_w, draw_h = iw * scale, ih * scale
            love.graphics.draw(boxart, icon_x + (icon_size - draw_w) / 2,
                icon_y + (icon_size - draw_h) / 2, 0, scale, scale)
            return
        end
    end

    -- Try variant-specific launcher icon
    local launcher_icon = nil
    if self.variant_loader then
        launcher_icon = self.variant_loader:getLauncherIcon(game_data.id, game_data.game_class)
    end

    if launcher_icon then
        local tint = is_unlocked and {1, 1, 1} or {0.5, 0.5, 0.5}
        love.graphics.setColor(tint[1], tint[2], tint[3])
        love.graphics.draw(launcher_icon, icon_x, icon_y, 0,
            icon_size / launcher_icon:getWidth(), icon_size / launcher_icon:getHeight())
        return
    end

    local sprite_name = game_data.icon_sprite or "game_freecell-0"

    -- Try player sprite via GameSpriteHelper
    if sprite_name == "player" and self.sprite_set_loader then
        local player_sprite = GameSpriteHelper.loadPlayerSprite(game_data, self.sprite_set_loader, icon_size)
        if player_sprite then
            local color_tint = self:getVariantTint(game_data)
            local unlock_mult = is_unlocked and 1.0 or 0.5
            love.graphics.setColor(color_tint[1] * unlock_mult, color_tint[2] * unlock_mult, color_tint[3] * unlock_mult)
            love.graphics.draw(player_sprite, icon_x, icon_y, 0,
                icon_size / player_sprite:getWidth(), icon_size / player_sprite:getHeight())
            love.graphics.setColor(1, 1, 1)
            return
        end
        -- Fallback: try metric sprite mapping
        if game_data.visual_identity and game_data.visual_identity.metric_sprite_mappings then
            local first_metric = game_data.metrics_tracked and game_data.metrics_tracked[1]
            if first_metric then
                sprite_name = game_data.visual_identity.metric_sprite_mappings[first_metric] or "game_freecell-0"
            end
        end
    end

    -- Sprite icon fallback
    local palette_id = sprite_manager:getPaletteId(game_data)
    if self.variant_loader then
        local variant = self.variant_loader:getVariantData(game_data.id)
        if variant and variant.palette then palette_id = variant.palette end
    end
    local tint = is_unlocked and {1, 1, 1} or {0.5, 0.5, 0.5}
    sprite_loader:drawSprite(sprite_name, icon_x, icon_y, icon_size, icon_size, tint, palette_id)
end

function LauncherView:getVariantTint(game_data)
    local palette_manager = self.di and self.di.paletteManager
    local config = self.di and self.di.config
    if not (palette_manager and config and config.games and self.variant_loader) then return {1, 1, 1} end

    local variant = self.variant_loader:getVariantData(game_data.id)
    local class_to_config = {
        DodgeGame = "dodge", SnakeGame = "snake", MemoryMatch = "memory_match",
        HiddenObject = "hidden_object", SpaceShooter = "space_shooter",
        Breakout = "breakout", CoinFlip = "coin_flip", RPS = "rps"
    }
    local config_key = class_to_config[game_data.game_class]
    local game_config = config_key and config.games[config_key]
    if variant and game_config then
        return palette_manager:getTintForVariant(variant, game_data.game_class, game_config, true)
    end
    return {1, 1, 1}
end

function LauncherView:drawGameCard(x, y, w, h, game_data, selected, hovered, player_data, game_data_obj)
    local formula_renderer = FormulaRenderer:new(self.di)
    local L = self.layout

    local is_unlocked = player_data:isGameUnlocked(game_data.id)
    local perf = player_data:getGamePerformance(game_data.id)
    local is_completed = perf ~= nil

    -- Card background
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

    -- Responsive icon size
    local icon_size = L.icon_size
    local icon_x = x + 6
    local icon_y = y + (h - icon_size) / 2

    self:drawGameIcon(icon_x, icon_y, icon_size, game_data, is_unlocked)

    -- Badge (completion/lock status)
    local badge_x = icon_x + icon_size - 16
    local badge_y = icon_y
    if perf and perf.auto_completed then
        UIComponents.drawBadge(badge_x, badge_y, 16, "A", {0.5, 0.5, 1})
    elseif is_completed then
        UIComponents.drawBadge(badge_x, badge_y, 16, "OK", {0, 1, 0})
    elseif not is_unlocked then
        UIComponents.drawBadge(badge_x, badge_y, 16, "$", {1, 0, 0})
    end

    -- Text area (responsive to available width)
    local stats_w = L.stats_col_w
    local text_x = icon_x + icon_size + 10
    local text_w = w - (text_x - x) - stats_w - 8
    if text_w < 40 then text_w = 40 end

    -- Fetch variant data once
    local variant = self.variant_loader and self.variant_loader:getVariantData(game_data.id)
    local display_name = (variant and variant.name) or game_data.display_name

    -- Title (truncate if needed)
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local title_scale = 1.1
    local title_pixel_w = font:getWidth(display_name) * title_scale
    if title_pixel_w > text_w then
        title_scale = text_w / math.max(1, font:getWidth(display_name))
        title_scale = math.max(0.7, math.min(1.1, title_scale))
    end
    love.graphics.print(display_name, text_x, y + 6, 0, title_scale, title_scale)

    -- Stars + goal text (second row)
    local star_y = y + 24
    local difficulty = game_data.difficulty_level or 1
    local stars = math.min(5, math.ceil(difficulty / 2))
    for i = 1, 5 do
        if i <= stars then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        local sx = text_x + (i - 1) * 12
        love.graphics.rectangle('fill', sx, star_y + 2, 8, 8)
    end

    -- Goal text only if there's room
    local stars_end_x = text_x + 5 * 12 + 6
    local goal_text = self:getGoalText(game_data, variant)
    if goal_text and (stars_end_x + 30) < (text_x + text_w) then
        love.graphics.setColor(0.6, 0.85, 1)
        local goal_max_w = text_x + text_w - stars_end_x
        local goal_scale = math.min(0.75, goal_max_w / math.max(1, font:getWidth(goal_text)))
        goal_scale = math.max(0.5, goal_scale)
        love.graphics.print(goal_text, stars_end_x, star_y + 1, 0, goal_scale, goal_scale)
    end

    -- Formula (third row)
    local formula_y = y + 42
    if text_w > 60 then
        love.graphics.push()
        love.graphics.translate(text_x, formula_y)
        formula_renderer:draw(game_data, 0, 0, text_w, 14)
        love.graphics.pop()
    end

    -- Stats column (right side, responsive width)
    local stats_x = x + w - stats_w - 4

    if is_completed and perf then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("Power:", stats_x, y + 6, 0, 0.8, 0.8)
        local score_text = tostring(math.floor(perf.best_score))
        local score_scale = math.min(1.1, (stats_w - 4) / math.max(1, font:getWidth(score_text)))
        love.graphics.print(score_text, stats_x, y + 20, 0, score_scale, score_scale)
    elseif not is_unlocked then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("Cost:", stats_x, y + 6, 0, 0.8, 0.8)
        love.graphics.print(game_data.unlock_cost, stats_x, y + 20, 0, 0.95, 0.95)
    end

    love.graphics.setColor(1, 1, 0)
    love.graphics.print(string.format("×%.1f", game_data.variant_multiplier), stats_x, y + h - 20, 0, 0.95, 0.95)
end

-- Schema defaults per game class (victory_condition, victory_limit)
LauncherView.VICTORY_DEFAULTS = {
    DodgeGame = {vc = "dodge_count", limit = 30},
    SnakeGame = {vc = "length", limit = 20},
    SpaceShooter = {vc = "kills", limit = 20},
    Breakout = {vc = "clear_bricks"},
    CoinFlip = {vc = "streak", limit = 10},
    RPS = {vc = "rounds", limit = 3},
    Raycaster = {vc = "goal"},
    HiddenObject = {vc = "find_all"},
    MemoryMatch = {vc = "match_all"},
}

function LauncherView:getGoalText(game_data, variant)
    local defaults = LauncherView.VICTORY_DEFAULTS[game_data.game_class] or {}
    local d = game_data
    local vc = d.victory_condition or defaults.vc
    local limit = d.victory_limit or defaults.limit

    -- Game-specific target fields override generic limit
    if vc == "streak" then
        limit = d.streak_target or limit
    elseif vc == "total" then
        limit = d.total_correct_target or limit
    elseif vc == "ratio" then
        return string.format("%.0f%% accuracy", (d.ratio_target or 0.75) * 100)
    elseif vc == "first_to" or vc == "rounds" then
        limit = d.rounds_to_win or limit
    elseif vc == "score" then
        limit = d.score_target or limit
    elseif vc == "destroy_count" then
        limit = d.destroy_count_target or limit
    elseif vc == "match_all" then
        local pairs = d.num_pairs or d.grid_pairs
        return pairs and string.format("Match %d pairs", pairs) or "Match all pairs"
    end

    local labels = {
        clear_bricks = "Clear all bricks",
        clear_all = "Clear all",
        dodge_count = limit and string.format("Dodge %d", limit),
        kills = limit and string.format("Kill %d", limit) or "Kill all",
        time = limit and string.format("Survive %ds", limit) or "Survive",
        survival = limit and string.format("Survive %ds", limit) or "Survive",
        length = limit and string.format("Reach length %d", limit),
        streak = limit and string.format("%d streak", limit),
        total = limit and string.format("%d correct", limit),
        first_to = limit and string.format("Win %d rounds", limit),
        rounds = limit and string.format("Win %d rounds", limit),
        goal = "Reach the exit",
        dots = "Collect all dots",
        none = "Endless",
        score = limit and string.format("Score %d", limit),
        destroy_count = limit and string.format("Destroy %d", limit),
        find_all = "Find all objects",
        match_all = "Match all pairs",
    }

    return labels[vc]
end

function LauncherView:drawViewToggle()
    local L = self.layout
    local x, y, w, h = L.toggle_x, L.toggle_y, L.toggle_w, L.toggle_h
    local half = math.floor(w / 2)

    -- List button (same style as category buttons)
    if self.view_mode == "list" then
        love.graphics.setColor(0.2, 0.2, 0.6)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle('fill', x, y, half, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, half, h)
    -- Draw list icon (3 horizontal lines)
    love.graphics.setColor(1, 1, 1)
    local cx = x + half / 2
    local cy = y + h / 2
    for i = -1, 1 do
        local ly = cy + i * 5
        love.graphics.rectangle('fill', cx - 7, ly - 1, 14, 2)
    end

    -- Thumbnail button
    if self.view_mode == "thumbnail" then
        love.graphics.setColor(0.2, 0.2, 0.6)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle('fill', x + half, y, half + 1, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x + half, y, half + 1, h)
    -- Draw grid icon (2x2 squares)
    love.graphics.setColor(1, 1, 1)
    local gx = x + half + half / 2
    local gy = y + h / 2
    local gs = 4
    local gap = 2
    love.graphics.rectangle('fill', gx - gs - gap/2, gy - gs - gap/2, gs, gs)
    love.graphics.rectangle('fill', gx + gap/2, gy - gs - gap/2, gs, gs)
    love.graphics.rectangle('fill', gx - gs - gap/2, gy + gap/2, gs, gs)
    love.graphics.rectangle('fill', gx + gap/2, gy + gap/2, gs, gs)
end

function LauncherView:isCEUnlocked()
    local pd = self.player_data
    return pd and (pd.space_defender_level or 1) >= 3
end

function LauncherView:drawCheatsToggle()
    if not self:isCEUnlocked() then return end

    local L = self.layout
    local x, y, w, h = L.cheats_x, L.cheats_y, L.cheats_w, L.cheats_h
    local SettingsManager = require('src.utils.settings_manager')
    local enabled = SettingsManager.get('cheats_enabled')

    if enabled then
        love.graphics.setColor(0.6, 0.2, 0.2)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)

    love.graphics.setColor(enabled and {1, 0.6, 0.6} or {0.6, 0.6, 0.6})
    local font = love.graphics.getFont()
    local label = enabled and "CE:ON" or "CE:OFF"
    local tw = font:getWidth(label)
    local scale = math.min(0.85, (w - 6) / math.max(1, tw))
    love.graphics.print(label, x + (w - tw * scale) / 2, y + (h - font:getHeight() * scale) / 2, 0, scale, scale)
end

function LauncherView:drawThumbnailGrid(x, y, w, h, games, selected_index, hovered_game_id)
    local L = self.layout
    local cols = self:getThumbCols()
    local thumb_w = L.thumb_w
    local thumb_h = L.thumb_h
    local thumb_pad = self.thumb_padding
    local icon_size = L.thumb_icon_size
    local visible_rows = self:getVisibleRowCount(h)

    local total_rows = math.ceil(#games / cols)
    local start_row = math.max(0, (self.scroll_offset or 1) - 1)
    local end_row = math.min(total_rows - 1, start_row + visible_rows - 1)

    local shows_scrollbar = (total_rows > visible_rows)

    for row = start_row, end_row do
        for col = 0, cols - 1 do
            local game_idx = row * cols + col + 1
            if game_idx > #games then break end

            local game_data = games[game_idx]
            local tx = x + col * (thumb_w + thumb_pad)
            local ty = y + (row - start_row) * (thumb_h + thumb_pad)
            local is_selected = (game_idx == selected_index)
            local is_hovered = (hovered_game_id == game_data.id)
            local is_unlocked = self.player_data:isGameUnlocked(game_data.id)

            -- Card background
            if is_selected then
                love.graphics.setColor(0.3, 0.3, 0.7)
            elseif is_hovered then
                love.graphics.setColor(0.35, 0.35, 0.35)
            else
                love.graphics.setColor(0.25, 0.25, 0.25)
            end
            love.graphics.rectangle('fill', tx, ty, thumb_w, thumb_h)
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle('line', tx, ty, thumb_w, thumb_h)

            -- Icon centered in card
            local icon_x = tx + (thumb_w - icon_size) / 2
            local icon_y = ty + 4
            self:drawGameIcon(icon_x, icon_y, icon_size, game_data, is_unlocked)

            -- Badge
            local badge_x = icon_x + icon_size - 16
            local badge_y = icon_y
            local perf = self.player_data:getGamePerformance(game_data.id)
            if perf and perf.auto_completed then
                UIComponents.drawBadge(badge_x, badge_y, 14, "A", {0.5, 0.5, 1})
            elseif perf then
                UIComponents.drawBadge(badge_x, badge_y, 14, "OK", {0, 1, 0})
            elseif not is_unlocked then
                UIComponents.drawBadge(badge_x, badge_y, 14, "$", {1, 0, 0})
            end

        end
    end

    -- Scrollbar (bypass ScrollbarController's unit_size since row height != list item height)
    if shows_scrollbar then
        local row_h = thumb_h + thumb_pad
        local content_h = total_rows * row_h
        local offset_px = start_row * row_h
        local sb_geom = UIComponents.computeScrollbar({
            viewport_w = w,
            viewport_h = h,
            content_h = content_h,
            offset = offset_px,
        })
        if sb_geom then
            love.graphics.push()
            love.graphics.translate(x, y)
            UIComponents.drawScrollbar(sb_geom)
            love.graphics.pop()
        end
    end

    -- Status line
    love.graphics.setColor(1, 1, 1)
    local first = start_row * cols + 1
    local last = math.min(#games, (end_row + 1) * cols)
    love.graphics.print(string.format("Showing %d-%d of %d games", first, last, #games), x, y + h + 5, 0, 0.9, 0.9)
end

-- Override BaseView's drawWindowed to pass extra parameters
function LauncherView:drawWindowed(filtered_games, tokens, viewport_width, viewport_height)
    if type(viewport_width) ~= "number" or type(viewport_height) ~= "number" or viewport_width <= 0 or viewport_height <= 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Launcher Error: Invalid viewport dimensions received.", 5, 5, (self.controller.viewport and self.controller.viewport.width or 200) - 10, "left")
        print("ERROR in LauncherView:drawWindowed - Invalid viewport dimensions:", viewport_width, viewport_height)
        return
    end

    -- Store parameters for drawContent
    self.filtered_games = filtered_games
    self.tokens = tokens

    -- Call BaseView's drawWindowed
    LauncherView.super.drawWindowed(self, viewport_width, viewport_height)
end

-- Implements BaseView's abstract drawContent method
function LauncherView:drawContent(viewport_width, viewport_height)
    self:updateLayout(viewport_width, viewport_height)

    local filtered_games = self.filtered_games
    local tokens = self.tokens
    local L = self.layout

    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    self:drawCategoryButtons(L.cat_x, L.cat_y, self.selected_category, viewport_width)
    UIComponents.drawTokenCounter(L.token_x, L.token_y, tokens)
    self:drawCheatsToggle()
    self:drawViewToggle()

    if type(L.list_h) ~= "number" or L.list_h <= 0 then
        return
    end

    local list_width = self:getListWidth()

    if self.detail_panel_open and self.selected_game then
        self:drawGameDetailPanel(L.detail_x, L.detail_y, L.detail_w,
            L.detail_h, self.selected_game)
    end

    if self.view_mode == "thumbnail" then
        self:drawThumbnailGrid(L.list_x, L.list_y, list_width, L.list_h,
            filtered_games, self.selected_index, self.hovered_game_id)
    else
        self:drawGameList(L.list_x, L.list_y, list_width, L.list_h,
            filtered_games, self.selected_index, self.hovered_game_id)
    end
end

function LauncherView:drawGameDetailPanel(x, y, w, h, game_data)
    local formula_renderer = FormulaRenderer:new(self.di)
    local metric_legend = MetricLegend:new(self.di)

    local function drawHeaderPanel()
        UIComponents.drawPanel(x, y, w, h, {0.2, 0.2, 0.2})
        return y + 10
    end

    local function drawPreview(line_y)
        -- Check if boxart exists for a larger landscape preview
        local boxart = self.variant_loader and self.variant_loader:getBoxart(game_data.id)
        if boxart then
            local iw, ih = boxart:getWidth(), boxart:getHeight()
            local preview_w = w - 20
            local scale = preview_w / iw
            local preview_h = ih * scale
            local preview_x = x + 10
            love.graphics.setColor(0.15, 0.15, 0.15)
            love.graphics.rectangle('fill', preview_x - 3, line_y - 3, preview_w + 6, preview_h + 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(boxart, preview_x, line_y, 0, scale, scale)
            return line_y + preview_h + 12
        else
            local preview_size = math.min(80, math.floor(w * 0.35))
            local preview_x = x + (w - preview_size) / 2
            love.graphics.setColor(0.15, 0.15, 0.15)
            love.graphics.rectangle('fill', preview_x - 5, line_y - 5, preview_size + 10, preview_size + 10)
            self:drawGameIcon(preview_x, line_y, preview_size, game_data, true)
            return line_y + preview_size + 12
        end
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
            love.graphics.rectangle('fill', x + 10 + (i - 1) * 16, line_y + 2, 10, 10)
        end
        line_y = line_y + 22

        -- Victory condition / goal
        local goal_text = self:getGoalText(game_data, variant)
        if goal_text then
            love.graphics.setColor(0.6, 0.85, 1)
            love.graphics.print("Goal: " .. goal_text, x + 10, line_y, 0, 0.95, 0.95)
            line_y = line_y + 18
        end

        return line_y
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

    local function drawDebugBalanceInfo(line_y)
        -- DEBUG: Show theoretical max for balance testing
        line_y = line_y + 10
        love.graphics.setColor(1, 1, 0, 0.7)
        love.graphics.print("[DEBUG - Balance Testing]", x + 10, line_y, 0, 0.8, 0.8)
        line_y = line_y + 15

        local theoretical_max = self.game_data:calculateTheoreticalMax(game_data.id)
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("Theoretical Max Power:", x + 10, line_y, 0, 0.85, 0.85)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(math.floor(theoretical_max), x + 10, line_y + 15, 0, 1.1, 1.1)
        line_y = line_y + 35

        -- Show cost comparison
        love.graphics.setColor(0.8, 0.8, 0.8)
        local unlock_cost = game_data.unlock_cost or 0
        local power_to_cost_ratio = unlock_cost > 0 and (theoretical_max / unlock_cost) or 0
        love.graphics.print(string.format("Cost: %d | Ratio: %.2f", unlock_cost, power_to_cost_ratio),
            x + 10, line_y, 0, 0.75, 0.75)
        line_y = line_y + 15

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
    local line_y = drawHeaderPanel()
    line_y = drawPreview(line_y)
    line_y = drawTitleAndDifficulty(line_y)
    local is_unlocked
    line_y, is_unlocked = drawTierAndCost(line_y)
    line_y = drawFormula(line_y)
    line_y = drawPerformance(line_y)
    line_y = drawAutoplay(line_y)
    line_y = drawDebugBalanceInfo(line_y)
    drawActionButton()
end

return LauncherView