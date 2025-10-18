-- src/views/cheat_engine_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local CheatEngineView = Object:extend('CheatEngineView')

function CheatEngineView:init(controller)
    self.controller = controller -- This is the cheat_engine_state
    
    -- Layout
    self.list_x = 10
    self.list_y = 80
    self.list_w = 300
    self.list_h = love.graphics.getHeight() - 100
    self.item_h = 30
    
    self.detail_x = 320
    self.detail_y = 80
    self.detail_w = love.graphics.getWidth() - 330
    self.detail_h = self.list_h
    
    self.hovered_game_id = nil
    self.hovered_cheat_id = nil
    self.hovered_button_id = nil
end

function CheatEngineView:update(dt, games, selected_game_id, available_cheats)
    local mx, my = love.mouse.getPosition()
    
    self.hovered_game_id = nil
    self.hovered_cheat_id = nil
    self.hovered_button_id = nil
    
    -- Check game list
    local visible_games = math.floor(self.list_h / self.item_h)
    local start_index = self.controller.scroll_offset or 1
    
    for i = 0, visible_games - 1 do
        local game_index = start_index + i
        if game_index <= #games then
            local by = self.list_y + i * self.item_h
            if mx >= self.list_x and mx <= self.list_x + self.list_w and my >= by and my <= by + self.item_h then
                self.hovered_game_id = games[game_index].id
                break
            end
        end
    end
    
    -- Check detail panel
    if selected_game_id then
        local game_is_unlocked = self.controller.player_data:isGameUnlocked(selected_game_id)
        local ce_is_unlocked = self.controller.player_data:isCheatEngineUnlocked(selected_game_id)

        if not game_is_unlocked then
            -- No hover targets
        elseif not ce_is_unlocked then
            -- Check unlock button
            local btn_x, btn_y, btn_w, btn_h = self.detail_x + 10, self.detail_y + 100, self.detail_w - 20, 40
            if mx >= btn_x and mx <= btn_x + btn_w and my >= btn_y and my <= btn_y + btn_h then
                self.hovered_button_id = "unlock_ce"
            end
        else
            -- Check cheat list
            local cheat_y = self.detail_y + 100
            for id, def in pairs(available_cheats) do
                local btn_x, btn_y, btn_w, btn_h = self.detail_x + self.detail_w - 120, cheat_y, 110, 30
                if mx >= btn_x and mx <= btn_x + btn_w and my >= btn_y and my <= btn_y + btn_h then
                    self.hovered_cheat_id = def.id
                    self.hovered_button_id = "purchase_cheat"
                end
                cheat_y = cheat_y + self.item_h + 20
            end

            -- Check launch button
            local btn_x, btn_y, btn_w, btn_h = self.detail_x + 10, self.detail_y + self.detail_h - 50, self.detail_w - 20, 40
            if game_is_unlocked and mx >= btn_x and mx <= btn_x + btn_w and my >= btn_y and my <= btn_y + btn_h then
                self.hovered_button_id = "launch"
            end
        end
    end
end

function CheatEngineView:draw(games, selected_game_id, available_cheats, player_data)
    -- Background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Title
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("CheatEngine v1.3.3.7 (Cracked by RZR_1911)", 10, 10)
    love.graphics.print("===================================================", 10, 25)
    love.graphics.print("Tokens: " .. player_data.tokens, love.graphics.getWidth() - 200, 10)
    
    -- Panels
    self:drawPanel(self.list_x, self.list_y, self.list_w, self.list_h, "Process List")
    self:drawPanel(self.detail_x, self.detail_y, self.detail_w, self.detail_h, "Memory Editor")
    
    -- Draw Game List
    local visible_games = math.floor(self.list_h / self.item_h)
    local start_index = self.controller.scroll_offset or 1
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
        
        if is_unlocked then
            love.graphics.setColor(0, 1, 0)
        else
            love.graphics.setColor(0.3, 0.3, 0.3) -- Locked
        end
        love.graphics.print(game.display_name, self.list_x + 10, by + 8)
        if not is_unlocked then
            love.graphics.print("[LOCKED]", self.list_x + self.list_w - 70, by + 8)
        end
    end
    
    -- Draw Detail Panel
    if selected_game_id then
        local game = self.controller.selected_game
        local is_unlocked = player_data:isGameUnlocked(selected_game_id)
        local ce_is_unlocked = player_data:isCheatEngineUnlocked(selected_game_id)
        
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Selected: " .. (game and game.display_name or "N/A"), self.detail_x + 10, self.detail_y + 30)
        
        if not is_unlocked then
            love.graphics.setColor(1, 0.2, 0)
            love.graphics.print("Game is [LOCKED]. Purchase from the", self.detail_x + 10, self.detail_y + 70)
            love.graphics.print("Game Collection to enable cheats.", self.detail_x + 10, self.detail_y + 90)
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
            for _, cheat in ipairs(available_cheats) do
                local is_hovered = (self.hovered_cheat_id == cheat.id)
                local at_max_level = (cheat.current_level >= cheat.max_level)
                local can_afford = player_data:hasTokens(cheat.cost_for_next)

                -- Text
                if cheat.is_fake then love.graphics.setColor(0.5, 0.5, 0.5)
                else love.graphics.setColor(0, 1, 0) end
                
                love.graphics.print(cheat.name, self.detail_x + 10, cheat_y + 2)
                love.graphics.print(string.format("LVL: %d / %d", cheat.current_level, cheat.max_level), self.detail_x + 200, cheat_y + 2)
                
                love.graphics.setColor(0.6, 0.6, 0.6)
                love.graphics.print(cheat.description, self.detail_x + 10, cheat_y + 20, 0, 0.8, 0.8)
                
                -- Purchase Button
                local btn_text = at_max_level and "[MAX]" or ("Buy (" .. cheat.cost_for_next .. ")")
                local btn_enabled = (not at_max_level) and can_afford
                
                UIComponents.drawButton(
                    self.detail_x + self.detail_w - 120, cheat_y, 110, 30,
                    btn_text,
                    btn_enabled,
                    is_hovered
                )
                
                cheat_y = cheat_y + self.item_h + 20
            end

            -- Launch Button
            local is_hovered = (self.hovered_button_id == "launch")
            UIComponents.drawButton(
                self.detail_x + 10, self.detail_y + self.detail_h - 50, self.detail_w - 20, 40,
                "Launch with Cheats",
                true, -- Always enabled if CE is unlocked
                is_hovered
            )
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("Select a process from the list...", self.detail_x + 10, self.detail_y + 70)
    end
end

function CheatEngineView:drawPanel(x, y, w, h, title)
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle('line', x, y, w, h)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle('fill', x+1, y+1, w-2, 20)
    love.graphics.setColor(0, 1, 0)
    love.graphics.print(title, x + 5, y + 4)
end

function CheatEngineView:mousepressed(x, y, button, games, selected_game_id, available_cheats)
    if button ~= 1 then return nil end
    
    -- Check game list
    local visible_games = math.floor(self.list_h / self.item_h)
    local start_index = self.controller.scroll_offset or 1
    
    for i = 0, visible_games - 1 do
        local game_index = start_index + i
        if game_index <= #games then
            local by = self.list_y + i * self.item_h
            if x >= self.list_x and x <= self.list_x + self.list_w and y >= by and y <= by + self.item_h then
                return { name = "select_game", id = games[game_index].id }
            end
        end
    end
    
    -- Check detail panel
    if selected_game_id then
        local game_is_unlocked = self.controller.player_data:isGameUnlocked(selected_game_id)
        local ce_is_unlocked = self.controller.player_data:isCheatEngineUnlocked(selected_game_id)
        
        if not game_is_unlocked then
            return nil -- No buttons
        elseif not ce_is_unlocked then
            -- Check unlock button
            local btn_x, btn_y, btn_w, btn_h = self.detail_x + 10, self.detail_y + 100, self.detail_w - 20, 40
            if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
                return { name = "unlock_cheat_engine" }
            end
        else
            -- Check cheat list
            local cheat_y = self.detail_y + 100
            for id, def in pairs(available_cheats) do
                local btn_x, btn_y, btn_w, btn_h = self.detail_x + self.detail_w - 120, cheat_y, 110, 30
                if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
                    return { name = "purchase_cheat", id = def.id }
                end
                cheat_y = cheat_y + self.item_h + 20
            end

            -- Check launch button
            local btn_x, btn_y, btn_w, btn_h = self.detail_x + 10, self.detail_y + self.detail_h - 50, self.detail_w - 20, 40
            if game_is_unlocked and x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
                return { name = "launch_game" }
            end
        end
    end
    
    return nil
end

function CheatEngineView:wheelmoved(x, y, item_count)
    local visible_items = math.floor(self.list_h / self.item_h)
    local max_scroll = math.max(1, item_count - visible_items + 1)
    
    if y > 0 then -- Scroll up
        self.controller.scroll_offset = math.max(1, (self.controller.scroll_offset or 1) - 1)
    elseif y < 0 then -- Scroll down
        self.controller.scroll_offset = math.min(max_scroll, (self.controller.scroll_offset or 1) + 1)
    end
end

return CheatEngineView