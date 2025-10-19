-- src/views/cheat_engine_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local FormulaRenderer = require('src.views.formula_renderer')
local SpriteManager = require('src.utils.sprite_manager').getInstance()
local Config = require('src.config')
local CheatEngineView = Object:extend('CheatEngineView')

function CheatEngineView:init(controller)
    self.controller = controller -- This is the cheat_engine_state

    -- Base Layout (will be adjusted by updateLayout)
    local V = (Config.ui and Config.ui.views and Config.ui.views.cheat_engine) or {}
    local L = V.list or { x = 10, y = 50, max_w = 300, min_w = 150, item_h = 30 }
    self.list_x = L.x or 10
    self.list_y = 80
    self.list_w = L.max_w or 300
    self.list_h = 400
    self.item_h = L.item_h or 30

    self.detail_x = self.list_x + self.list_w + ((V.spacing and V.spacing.panel_gap) or 10)
    self.detail_y = 80
    self.detail_w = 300
    self.detail_h = 400

    self.hovered_game_id = nil
    self.hovered_cheat_id = nil
    self.hovered_button_id = nil -- Includes unlock_ce, purchase_cheat, launch

    self.formula_renderer = FormulaRenderer:new()
end

function CheatEngineView:updateLayout(viewport_width, viewport_height)
    local V = (Config.ui and Config.ui.views and Config.ui.views.cheat_engine) or {}
    local L = V.list or { x = 10, y = 50, max_w = 300, min_w = 150 }
    self.list_x = L.x or 10
    self.list_y = L.y or 50 -- Below header
    self.list_h = viewport_height - 70 -- Adjust for header/footer

    -- Make list width proportional but capped
    self.list_w = math.min(L.max_w or 300, math.max(L.min_w or 150, viewport_width * 0.4))

    local gap = (V.spacing and V.spacing.panel_gap) or 10
    self.detail_x = self.list_x + self.list_w + gap
    self.detail_y = self.list_y
    self.detail_w = viewport_width - self.detail_x - gap
    self.detail_h = self.list_h
end

function CheatEngineView:update(dt, games, selected_game_id, available_cheats, viewport_width, viewport_height)
    -- Get mouse position relative to the controller's viewport
    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    self.hovered_game_id = nil
    self.hovered_cheat_id = nil
    self.hovered_button_id = nil

    -- Only check hover if mouse is within viewport bounds
    if local_mx < 0 or local_mx > viewport_width or local_my < 0 or local_my > viewport_height then
        return
    end

    -- Check game list hover
    local visible_games = self:getVisibleGameCount(viewport_height)
    local start_index = self.controller.scroll_offset or 1

    for i = 0, visible_games - 1 do
        local game_index = start_index + i
        if game_index <= #games then
            local by = self.list_y + i * self.item_h
            if local_mx >= self.list_x and local_mx <= self.list_x + self.list_w and local_my >= by and local_my <= by + self.item_h then
                self.hovered_game_id = games[game_index].id
                break
            end
        end
    end

    -- Check detail panel hover
    if selected_game_id then
        local game = self.controller.selected_game
        if not game then return end

        local game_is_unlocked = self.controller.player_data:isGameUnlocked(selected_game_id)
        local ce_is_unlocked = self.controller.player_data:isCheatEngineUnlocked(selected_game_id)

        if not game_is_unlocked then
            -- No hover targets

        elseif not ce_is_unlocked then
            -- Check unlock button hover
            local btn_x, btn_y, btn_w, btn_h = self.detail_x + 10, self.detail_y + 100, self.detail_w - 20, 40
            local cost = self.controller:getScaledCost(game.cheat_engine_base_cost or 99999)
            local can_afford = self.controller.player_data:hasTokens(cost)
            if local_mx >= btn_x and local_mx <= btn_x + btn_w and local_my >= btn_y and local_my <= btn_y + btn_h and can_afford then
                self.hovered_button_id = "unlock_ce"
            end
        else
            -- Check cheat list purchase button hover
            local available_height_for_cheats = self.detail_h - 160
            local cheat_item_total_height = self.item_h + 20
            local visible_cheats = math.floor(available_height_for_cheats / cheat_item_total_height)
            local cheat_scroll_offset = self.controller.cheat_scroll_offset or 0
            local cheat_index = 0

            for _, cheat in ipairs(available_cheats) do
                 cheat_index = cheat_index + 1
                 if cheat_index > cheat_scroll_offset and cheat_index <= cheat_scroll_offset + visible_cheats then
                    local display_y = self.detail_y + 100 + (cheat_index - 1 - cheat_scroll_offset) * cheat_item_total_height
                    local btn_x, btn_y, btn_w, btn_h = self.detail_x + self.detail_w - 120, display_y, 110, 30

                    local at_max_level = (cheat.current_level >= cheat.max_level)
                    local can_afford = self.controller.player_data:hasTokens(cheat.cost_for_next)

                    if local_mx >= btn_x and local_mx <= btn_x + btn_w and local_my >= btn_y and local_my <= btn_y + btn_h then
                        if not at_max_level and can_afford then
                           self.hovered_cheat_id = cheat.id
                           self.hovered_button_id = "purchase_cheat"
                        end
                        break
                    end
                 end
            end

            -- Check launch button hover
            local btn_x, btn_y, btn_w, btn_h = self.detail_x + 10, self.detail_y + self.detail_h - 50, self.detail_w - 20, 40
            if game_is_unlocked and local_mx >= btn_x and local_mx <= btn_x + btn_w and local_my >= btn_y and local_my <= btn_y + btn_h then
                self.hovered_button_id = "launch"
            end
        end
    end
end

function CheatEngineView:drawWindowed(games, selected_game_id, available_cheats, player_data, viewport_width, viewport_height, list_scroll_offset, cheat_scroll_offset_in)
    -- Ensure scroll offsets are numbers
    local scroll_offset = list_scroll_offset or 1
    local cheat_scroll_offset = cheat_scroll_offset_in or 0

    -- Background within viewport
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    -- Use layout calculated in updateLayout

    -- Title area
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("CheatEngine v1.3.3.7 (Cracked by RZR_1911)", 10, 10)
    love.graphics.print("===================================================", 10, 25)
    UIComponents.drawTokenCounter(viewport_width - 200, 10, player_data.tokens) -- Use component

    -- Panels
    self:drawPanel(self.list_x, self.list_y, self.list_w, self.list_h, "Process List")
    self:drawPanel(self.detail_x, self.detail_y, self.detail_w, self.detail_h, "Memory Editor")

    -- Draw Game List (using layout vars)
    local visible_games = self:getVisibleGameCount(viewport_height) -- Use helper
    local start_index = scroll_offset
    local end_index = math.min(#games, start_index + visible_games - 1)

    for i = start_index, end_index do
        local game = games[i]
        local by = self.list_y + (i - start_index) * self.item_h
        local is_selected = (game.id == selected_game_id)
        local is_hovered = (game.id == self.hovered_game_id)
        local is_unlocked = player_data:isGameUnlocked(game.id)

        if is_selected then love.graphics.setColor(0, 0.5, 0)
        elseif is_hovered then love.graphics.setColor(0.1, 0.1, 0.1)
        else love.graphics.setColor(0, 0, 0) end

        love.graphics.rectangle('fill', self.list_x + 2, by, self.list_w - 4, self.item_h)

        if is_unlocked then love.graphics.setColor(0, 1, 0)
        else love.graphics.setColor(0.3, 0.3, 0.3) end
        love.graphics.print(game.display_name, self.list_x + 10, by + 8)
        if not is_unlocked then
            love.graphics.print("[LOCKED]", self.list_x + self.list_w - 70, by + 8)
        end
    end
     -- Draw List Scrollbar
    local V = (Config.ui and Config.ui.views and Config.ui.views.cheat_engine) or {}
    local L = V.list or { scrollbar_w = 6 }
    if #games > visible_games then
        love.graphics.setColor(0.3, 1, 0.3)
        local scroll_track_height = self.list_h
        local scroll_height = math.max(15, (visible_games / #games) * scroll_track_height)
        local scroll_pos_ratio = (start_index - 1) / math.max(1, #games - visible_games)
        local scroll_y = self.list_y + scroll_pos_ratio * (scroll_track_height - scroll_height)
        scroll_y = math.max(self.list_y, math.min(scroll_y, self.list_y + scroll_track_height - scroll_height))
        love.graphics.rectangle('fill', self.list_x + self.list_w - (L.scrollbar_w + 2), scroll_y, (L.scrollbar_w or 6), scroll_height)
    end

    -- Draw Detail Panel (using layout vars)
    if selected_game_id then
        local game = self.controller.selected_game -- Get from controller
        if not game then -- Guard if game data somehow missing
             love.graphics.setColor(1,0,0)
             love.graphics.print("Error: Selected game data not found!", self.detail_x + 10, self.detail_y + 30)
             return
        end

        local is_unlocked = player_data:isGameUnlocked(selected_game_id)
        local ce_is_unlocked = player_data:isCheatEngineUnlocked(selected_game_id)

        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Selected: " .. game.display_name, self.detail_x + 10, self.detail_y + 30)

        if not is_unlocked then
            love.graphics.setColor(1, 0.2, 0)
            love.graphics.printf("Game is [LOCKED]. Purchase from the Game Collection to enable cheats.", self.detail_x + 10, self.detail_y + 70, self.detail_w - 20, "left")
        elseif not ce_is_unlocked then
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("Purchase CheatEngine access for this game:", self.detail_x + 10, self.detail_y + 70)

            local cost = self.controller:getScaledCost(game.cheat_engine_base_cost or 99999)
            local can_afford = player_data:hasTokens(cost)
            local is_hovered = (self.hovered_button_id == "unlock_ce")

            UIComponents.drawButton(
                self.detail_x + 10, self.detail_y + 100, self.detail_w - 20, 40,
                "Unlock CE (" .. cost .. " tokens)",
                can_afford,
                is_hovered
            )
        else
            -- CE is unlocked, draw the cheats
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("Available Cheats:", self.detail_x + 10, self.detail_y + 70)

            local cheat_y = self.detail_y + 100
            local S = V.spacing or { header_h = 70, footer_h = 50, cheat_item_extra_h = 20 }
            local available_height_for_cheats = self.detail_h - ((S.header_h or 70) + (S.footer_h or 50) + 40) -- include margins
            local cheat_item_total_height = self.item_h + (S.cheat_item_extra_h or 20)
            local visible_cheats = math.floor(available_height_for_cheats / cheat_item_total_height)
            visible_cheats = math.max(1, visible_cheats) -- Ensure at least 1

            local num_cheats = 0
            if available_cheats then for _ in ipairs(available_cheats) do num_cheats = num_cheats + 1 end end

            local cheat_index = 0
            -- Use ipairs for potentially ordered available_cheats table
            for _, cheat in ipairs(available_cheats or {}) do
                 cheat_index = cheat_index + 1
                 if cheat_index > cheat_scroll_offset and cheat_index <= cheat_scroll_offset + visible_cheats then
                    local display_y = self.detail_y + 100 + (cheat_index - 1 - cheat_scroll_offset) * cheat_item_total_height

                    local is_hovered_cheat = (self.hovered_cheat_id == cheat.id)
                    local at_max_level = (cheat.current_level >= cheat.max_level)
                    local can_afford = player_data:hasTokens(cheat.cost_for_next)

                    -- Text
                    if cheat.is_fake then love.graphics.setColor(0.5, 0.5, 0.5)
                    else love.graphics.setColor(0, 1, 0) end

                    love.graphics.print(cheat.name, self.detail_x + 10, display_y + 2)
                    love.graphics.print(string.format("LVL: %d / %d", cheat.current_level, cheat.max_level), self.detail_x + 200, display_y + 2)

                    love.graphics.setColor(0.6, 0.6, 0.6)
                    love.graphics.print(cheat.description, self.detail_x + 10, display_y + 20, 0, 0.8, 0.8)

                    -- Purchase Button
                    local btn_text = at_max_level and "[MAX]" or ("Buy (" .. cheat.cost_for_next .. ")")
                    local btn_enabled = (not at_max_level) and can_afford

                    local B = (V.buttons or { small_w = 110, small_h = 30 })
                    UIComponents.drawButton(
                        self.detail_x + self.detail_w - ((B.small_w or 110) + 10), display_y, (B.small_w or 110), (B.small_h or 30),
                        btn_text,
                        btn_enabled,
                        is_hovered_cheat and (self.hovered_button_id == "purchase_cheat") -- Check button ID too
                    )
                 end
            end
             -- Draw Cheat Scrollbar
          if num_cheats > visible_cheats then
                 love.graphics.setColor(0.3, 1, 0.3)
                 local scroll_track_height = available_height_for_cheats
                 local scroll_height = math.max(15, (visible_cheats / num_cheats) * scroll_track_height)
                 local scroll_pos_ratio = cheat_scroll_offset / math.max(1, num_cheats - visible_cheats)
                 local scroll_y = self.detail_y + 100 + scroll_pos_ratio * (scroll_track_height - scroll_height)
                 scroll_y = math.max(self.detail_y + 100, math.min(scroll_y, self.detail_y + 100 + scroll_track_height - scroll_height))
              local L = V.list or { scrollbar_w = 6 }
              love.graphics.rectangle('fill', self.detail_x + self.detail_w - ((L.scrollbar_w or 6) + 2), scroll_y, (L.scrollbar_w or 6), scroll_height)
            end

            -- Launch Button (at bottom)
            local is_hovered_launch = (self.hovered_button_id == "launch")
            local B = (V.buttons or { wide_h = 40 })
            UIComponents.drawButton(
                self.detail_x + 10, self.detail_y + self.detail_h - ((B.wide_h or 40) + 10), self.detail_w - 20, (B.wide_h or 40),
                "Launch with Cheats",
                true, -- Always enabled if CE is unlocked
                is_hovered_launch
            )
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("Select a process from the list...", self.detail_x + 10, self.detail_y + 70, self.detail_w - 20, "left")
    end

    -- Footer / Instructions
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print("ESC to close window", 10, viewport_height - 20)
end


function CheatEngineView:drawPanel(x, y, w, h, title)
    love.graphics.setColor(0, 1, 0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, w, h)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle('fill', x+1, y+1, w-2, 20) -- Title bar background
    love.graphics.setColor(0, 1, 0)
    love.graphics.print(title, x + 5, y + 4)

    -- Inner background for content area
    love.graphics.setColor(0.05, 0.05, 0.05)
    love.graphics.rectangle('fill', x+1, y+21, w-2, h-22)

    -- Phase 7.2: Show game's sprite set when game selected
    if title == "Memory Editor" and self.controller and self.controller.selected_game then
        SpriteManager:ensureLoaded()
        local game = self.controller.selected_game
        local palette_id = SpriteManager:getPaletteId(game)
        local icon_sprite = SpriteManager:getMetricSprite(game, game.metrics_tracked[1] or "default")
        if icon_sprite then
            SpriteManager.sprite_loader:drawSprite(icon_sprite, x + w - 50, y + 25, 48, 48, {1,1,1,0.1}, palette_id)
        end
    end
end

function CheatEngineView:mousepressed(x, y, button, games, selected_game_id, available_cheats, viewport_width, viewport_height)
    -- x, y are LOCAL coords relative to content area (0,0)
    if button ~= 1 then return nil end

    -- Check game list (using local coords)
    local visible_games = self:getVisibleGameCount(viewport_height) -- Use helper
    local start_index = self.controller.scroll_offset or 1 -- Get from controller

    for i = 0, visible_games - 1 do
        local game_index = start_index + i
        if game_index <= #games then
            local by = self.list_y + i * self.item_h -- Relative y
            -- Check using LOCAL x, y
            if x >= self.list_x and x <= self.list_x + self.list_w and y >= by and y <= by + self.item_h then
                return { name = "select_game", id = games[game_index].id }
            end
        end
    end

    -- Check detail panel (using local coords)
    if selected_game_id then
        local game = self.controller.selected_game -- Get from controller
        if not game then return nil end -- Guard against missing game

        local game_is_unlocked = self.controller.player_data:isGameUnlocked(selected_game_id)
        local ce_is_unlocked = self.controller.player_data:isCheatEngineUnlocked(selected_game_id)

        if not game_is_unlocked then
            return nil -- No buttons active

        elseif not ce_is_unlocked then
            -- Check unlock button (using local coords)
            local btn_x, btn_y, btn_w, btn_h = self.detail_x + 10, self.detail_y + 100, self.detail_w - 20, 40 -- Relative positions
            local cost = self.controller:getScaledCost(game.cheat_engine_base_cost or 99999)
            local can_afford = self.controller.player_data:hasTokens(cost)
            -- Check using LOCAL x, y
            if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h and can_afford then
                return { name = "unlock_cheat_engine" }
            end
        else
            -- Check cheat list purchase buttons (using local coords)
            local available_height_for_cheats = self.detail_h - 160
            local cheat_item_total_height = self.item_h + 20
            local visible_cheats = math.floor(available_height_for_cheats / cheat_item_total_height)
            visible_cheats = math.max(1, visible_cheats)
            local cheat_scroll_offset = self.controller.cheat_scroll_offset or 0
            local cheat_index = 0

            for _, cheat in ipairs(available_cheats or {}) do
                 cheat_index = cheat_index + 1
                 if cheat_index > cheat_scroll_offset and cheat_index <= cheat_scroll_offset + visible_cheats then
                     local display_y = self.detail_y + 100 + (cheat_index - 1 - cheat_scroll_offset) * cheat_item_total_height -- Relative y
                     local btn_x, btn_y, btn_w, btn_h = self.detail_x + self.detail_w - 120, display_y, 110, 30 -- Relative positions

                     local at_max_level = (cheat.current_level >= cheat.max_level)
                     local can_afford = self.controller.player_data:hasTokens(cheat.cost_for_next)

                     -- Check using LOCAL x, y
                     if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
                         if not at_max_level and can_afford then
                             return { name = "purchase_cheat", id = cheat.id }
                         else
                             return nil -- Clicked disabled button
                         end
                     end
                 end
            end

            -- Check launch button (using local coords)
            local btn_x, btn_y, btn_w, btn_h = self.detail_x + 10, self.detail_y + self.detail_h - 50, self.detail_w - 20, 40 -- Relative positions
            -- Check using LOCAL x, y
            if game_is_unlocked and x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
                return { name = "launch_game" }
            end
        end
    end

    return nil -- Clicked on empty space within the view's area
end

function CheatEngineView:wheelmoved(x, y, item_count, viewport_width, viewport_height)
    local new_list_offset = nil
    local new_cheat_offset = nil

    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    -- Check if scrolling over game list
    if local_mx >= self.list_x and local_mx <= self.list_x + self.list_w and
       local_my >= self.list_y and local_my <= self.list_y + self.list_h then

        local visible_items = self:getVisibleGameCount(viewport_height)
        local max_scroll = math.max(0, item_count - visible_items)
        local current_offset = self.controller.scroll_offset or 1

        if y > 0 then -- Scroll up
            new_list_offset = math.max(1, current_offset - 1)
        elseif y < 0 then -- Scroll down
            new_list_offset = math.min(max_scroll + 1, current_offset + 1)
        end
    end

    -- Check if scrolling over cheat detail list
    local cheat_list_y_start = self.detail_y + 100
    local cheat_list_h = self.detail_h - 160
    if self.controller.selected_game_id and self.controller.player_data:isCheatEngineUnlocked(self.controller.selected_game_id) and
       local_mx >= self.detail_x and local_mx <= self.detail_x + self.detail_w and
       local_my >= cheat_list_y_start and local_my <= cheat_list_y_start + cheat_list_h then

         local num_cheats = 0
         if self.controller.available_cheats then for _ in ipairs(self.controller.available_cheats) do num_cheats = num_cheats + 1 end end

         local cheat_item_total_height = self.item_h + 20
         local visible_cheats = math.floor(cheat_list_h / cheat_item_total_height)
         visible_cheats = math.max(1, visible_cheats) -- Ensure at least 1
         local max_cheat_scroll = math.max(0, num_cheats - visible_cheats)
         local current_cheat_scroll = self.controller.cheat_scroll_offset or 0

         if y > 0 then -- Scroll up
              new_cheat_offset = math.max(0, current_cheat_scroll - 1)
         elseif y < 0 then -- Scroll down
              new_cheat_offset = math.min(max_cheat_scroll, current_cheat_scroll + 1)
         end
    end

    -- Return offsets so state can update them
    return new_list_offset, new_cheat_offset
end


function CheatEngineView:getVisibleGameCount(viewport_height)
     local list_h = viewport_height - 70 -- Approximate height available
     return math.max(1, math.floor(list_h / self.item_h))
end


return CheatEngineView