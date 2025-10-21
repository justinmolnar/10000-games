-- vm_manager_view.lua: View class for VM Manager UI

local Object = require('class')
local UIComponents = require('src.views.ui_components')
local FormulaRenderer = require('src.views.formula_renderer')
local SpriteManager = require('src.utils.sprite_manager').getInstance()
-- Config is supplied via DI; avoid requiring src.config here
local Strings = require('src.utils.strings')
local VMManagerView = Object:extend('VMManagerView')

function VMManagerView:init(controller, vm_manager, player_data, game_data, di)
    self.controller = controller -- This is the vm_manager_state
    self.vm_manager = vm_manager
    self.player_data = player_data
    self.game_data = game_data
    self.di = di
    if di then UIComponents.inject(di) end

    self.selected_slot = nil
    self.game_selection_open = false
    self.scroll_offset = 0
    self.hovered_slot = nil
    self.hovered_upgrade = nil
    self.hovered_purchase_vm = false

        -- Layout constants (read from Config or DI)
        local Config_ = (di and di.config) or Config
        local Strings_ = (di and di.strings) or Strings
        local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local G = V.grid or {}
    self.slot_width = G.slot_w or 180
    self.slot_height = G.slot_h or 120
    self.slot_padding = G.padding or 10
    self.slot_cols = 5
    local PB = V.purchase_button or { x = 10, w = 200, h = 40, bottom_margin = 60 }
    self.purchase_button_x = PB.x or 10
    self.purchase_button_y = 540 -- Placeholder, set by updateLayout
    self.purchase_button_w = PB.w or 200
    self.purchase_button_h = PB.h or 40

    local UP = V.upgrade or { x = 230, w = 180, h = 40, spacing = 10, bottom_margin = 60 }
    self.upgrade_x = UP.x or 230
    self.upgrade_y = 540 -- Placeholder, set by updateLayout
    self.upgrade_w = UP.w or 180
    self.upgrade_h = UP.h or 40
    self.upgrade_spacing = UP.spacing or 10

    local M = V.modal or { min_w = 400, max_h = 500, side_margin = 20, top_y = 60, item_h = 40 }
    self.modal_x = 200 -- Placeholder
    self.modal_y = M.top_y or 60 -- Placeholder
    self.modal_w = M.min_w or 400 -- Placeholder
    self.modal_h = 400 -- Placeholder
    self.modal_item_height = M.item_h or 40

    self.formula_renderer = FormulaRenderer:new()
    -- Scrollbar interaction state (for modal list)
    self._sb = { modal = { dragging = false, geom = nil, drag = nil } }
end

function VMManagerView:updateLayout(viewport_width, viewport_height)
    -- Recalculate positions based on new viewport size
        local Config_ = (self.di and self.di.config) or Config
        local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local PB = V.purchase_button or { bottom_margin = 60 }
    local UP = V.upgrade or { bottom_margin = 60 }
    self.purchase_button_y = viewport_height - (PB.bottom_margin or 60)
    self.upgrade_y = viewport_height - (UP.bottom_margin or 60)

    -- Adjust modal size/position
        local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local M = V.modal or { min_w = 400, max_h = 500, side_margin = 20, top_y = 60 }
    self.modal_w = math.min(M.min_w or 400, viewport_width - 2*(M.side_margin or 20))
    self.modal_h = math.min(M.max_h or 500, viewport_height - 120)
    self.modal_x = (viewport_width - self.modal_w) / 2
    self.modal_y = M.top_y or 60

    -- Adjust slot columns based on width
        local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local G = V.grid or {}
    local available_width_for_slots = viewport_width - 2*(G.left_margin or 10) -- Margins
    self.slot_cols = math.max(1, math.floor(available_width_for_slots / (self.slot_width + self.slot_padding)))
    -- Limit columns if desired, e.g., self.slot_cols = math.min(self.slot_cols, 6)
end


function VMManagerView:update(dt, viewport_width, viewport_height)
    -- Update hovered slot, buttons based on mouse position relative to viewport
    local mx, my = love.mouse.getPosition()
    -- Get window position from controller's viewport
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    self.hovered_slot = self:getSlotAtPosition(local_mx, local_my, viewport_width, viewport_height)
    self.hovered_upgrade = nil
    self.hovered_purchase_vm = false

    -- Update hovered upgrade (using local coords)
    local upgrades = {"cpu_speed", "overclock"}
    for i, upgrade_type in ipairs(upgrades) do
        local bx = self.upgrade_x + (i - 1) * (self.upgrade_w + self.upgrade_spacing)
        local by = self.upgrade_y -- Use layout-calculated y
        if local_mx >= bx and local_mx <= bx + self.upgrade_w and local_my >= by and local_my <= by + self.upgrade_h then
            self.hovered_upgrade = upgrade_type
            break
        end
    end

    -- Update hovered purchase button (using local coords)
     if self:isPurchaseButtonClicked(local_mx, local_my, viewport_width, viewport_height) then
         self.hovered_purchase_vm = true
     end
end

function VMManagerView:drawUpgradeButton(x, y, w, h, label, desc, level, cost, can_afford, hovered)
    -- Background
        local Config_ = (self.di and self.di.config) or Config
        local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local C = (V.colors and V.colors.upgrade_button) or {}
    if not can_afford then love.graphics.setColor(C.disabled_bg or {0.3, 0.3, 0.3})
    elseif hovered then love.graphics.setColor(C.hover_bg or {0.35, 0.6, 0.35})
    else love.graphics.setColor(C.enabled_bg or {0, 0.5, 0}) end
    love.graphics.rectangle('fill', x, y, w, h)

    -- Border
    love.graphics.setColor((C.border or {0.5, 0.5, 0.5}))
    love.graphics.rectangle('line', x, y, w, h)

    -- Text
    love.graphics.setColor(can_afford and (C.text_enabled or {1,1,1}) or (C.text_disabled or {0.5,0.5,0.5}))
    local lvl_prefix = Strings.get('vm.level_prefix', 'Lv.')
    love.graphics.print(label .. " " .. lvl_prefix .. level, x + 5, y + 5, 0, 0.9, 0.9)
    love.graphics.print(desc, x + 5, y + 20, 0, 0.75, 0.75)

    -- Cost
    love.graphics.setColor(can_afford and (C.cost_enabled or {1,1,0}) or (C.cost_disabled or {0.5,0.5,0}))
    local tokens_unit = Strings.get('tokens.unit', 'tokens')
    love.graphics.printf(cost .. " " .. tokens_unit, x + 5, y + h - 18, w - 10, "right", 0, 0.8, 0.8)
end


function VMManagerView:drawWindowed(filtered_games, viewport_width, viewport_height)
    -- Draw background
    local Config_ = (self.di and self.di.config) or Config
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local C = (V.colors and V.colors.bg) or {0.15, 0.15, 0.15}
    love.graphics.setColor(C)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    -- Use relative positions based on viewport_width, viewport_height

    -- Token counter (Top right)
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    UIComponents.drawTokenCounter(viewport_width - ((V.tokens and V.tokens.right_offset) or 200), 10, self.player_data.tokens)

    -- Tokens per minute display (Top left)
    self:drawTokensPerMinute(10, 10, self.vm_manager.total_tokens_per_minute)

    -- VM slots grid (Uses self.slot_cols calculated in updateLayout)
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local G = V.grid or { start_y = 50, left_margin = 10, bottom_reserved = 70 }
    local slots = self.vm_manager.vm_slots
    local grid_start_y = G.start_y or 50 -- Below header info
    for i, slot in ipairs(slots) do
        local col = (i - 1) % self.slot_cols
        local row = math.floor((i - 1) / self.slot_cols)
        local x = (G.left_margin or 10) + col * (self.slot_width + self.slot_padding)
        local y = grid_start_y + row * (self.slot_height + self.slot_padding)

        if y + self.slot_height < viewport_height - (G.bottom_reserved or 70) then -- Leave space for buttons
            local view_context = { game_data = self.game_data, player_data = self.player_data, vm_manager = self.vm_manager }
            self:drawVMSlot(x, y, self.slot_width, self.slot_height, slot,
                i == self.selected_slot, i == self.hovered_slot, view_context)
        end
    end

     -- Purchase VM button (Bottom left)
    if #slots < self.vm_manager.max_slots then
        local cost = self.vm_manager:getVMCost(#slots)
        local can_afford = self.player_data:hasTokens(cost)
        -- Use button coords calculated in updateLayout
        self:drawPurchaseVMButton(self.purchase_button_x, self.purchase_button_y, cost, can_afford, self.hovered_purchase_vm)
    end

    -- Upgrade buttons (Bottom, next to purchase)
    local upgrades = {
        {type = "cpu_speed", label = Strings.get('vm.upgrades.cpu_speed.label','CPU Speed'), desc = Strings.get('vm.upgrades.cpu_speed.desc','Faster cycles')},
        {type = "overclock", label = Strings.get('vm.upgrades.overclock.label','Overclock'), desc = Strings.get('vm.upgrades.overclock.desc','More power')}
    }
    for i, upgrade in ipairs(upgrades) do
        local bx = self.upgrade_x + (i - 1) * (self.upgrade_w + self.upgrade_spacing)
        -- Use button coords calculated in updateLayout
        local by = self.upgrade_y
    local current_level = (self.player_data.upgrades and self.player_data.upgrades[upgrade.type]) or 0
    local Config_ = (self.di and self.di.config) or Config
    local cost = Config_.upgrade_costs[upgrade.type] * (current_level + 1)
        local can_afford = self.player_data:hasTokens(cost)
        local is_hovered = (self.hovered_upgrade == upgrade.type)

        self:drawUpgradeButton(bx, by, self.upgrade_w, self.upgrade_h,
            upgrade.label, upgrade.desc, current_level, cost, can_afford, is_hovered)
    end

    -- Game selection modal (uses modal coords from updateLayout)
    if self.game_selection_open then
        local view_context = { game_data = self.game_data, player_data = self.player_data, vm_manager = self.vm_manager }
        self:drawGameSelectionModal(filtered_games, self.scroll_offset, view_context)
    end

    -- Instructions (Bottom fixed)
    love.graphics.setColor( (V.colors and V.colors.slot and V.colors.slot.header_text) or {0.7,0.7,0.7} )
    love.graphics.print(Strings.get('vm.instructions', 'Click empty slot to assign | Click assigned to remove | ESC in modal to cancel'),
        10, viewport_height - ((V.instructions and V.instructions.bottom_offset) or 25), 0, 0.8, 0.8)
end

function VMManagerView:mousepressed(x, y, button, filtered_games, viewport_width, viewport_height)
    -- x, y are LOCAL coords relative to content area (0,0)
    if button ~= 1 then return nil end

    -- Check game selection modal first (using local coords for checks)
    if self.game_selection_open then
        -- Check click relative to modal's position *within the content area*
        if x >= self.modal_x and x <= self.modal_x + self.modal_w and y >= self.modal_y and y <= self.modal_y + self.modal_h then
            -- Handle scrollbar interactions first if present
            local list_area_y_start = self.modal_y + 40
            local list_h = self.modal_h - 70
            local visible_items = math.max(1, math.floor(list_h / self.modal_item_height))
            if self._sb and self._sb.modal and self._sb.modal.geom and #filtered_games > visible_items then
                local UI = UIComponents
                local lx = x - self.modal_x
                local ly = y - list_area_y_start
                local off_px = (self.scroll_offset or 0) * self.modal_item_height
                local res = UI.scrollbarHandlePress(lx, ly, button, self._sb.modal.geom, off_px, nil)
                if res and res.consumed then
                    if res.new_offset_px ~= nil then
                        local new_off = math.floor(res.new_offset_px / self.modal_item_height + 0.0001)
                        local max_off = math.max(0, #filtered_games - visible_items)
                        self.scroll_offset = math.max(0, math.min(max_off, new_off))
                    end
                    if res.drag then
                        self._sb.modal.dragging = true
                        self._sb.modal.drag = { start_y = res.drag.start_y, offset_start_px = res.drag.offset_start_px }
                    end
                    return { name = 'content_interaction' }
                end
            end
            local clicked_game = self:getGameAtPosition(x, y, filtered_games, viewport_width, viewport_height) -- Pass local coords
            if clicked_game then
                self.game_selection_open = false
                local slot_to_assign = self.selected_slot
                self.selected_slot = nil
                return {name = "assign_game", slot_index = slot_to_assign, game_id = clicked_game.id}
            else
                 -- Clicked inside modal but not on a game item or scrollbar etc.
                 return nil -- Consume click inside modal background
            end
        else
            -- Clicked outside the modal, close it
            self.game_selection_open = false
            self.selected_slot = nil
            return {name="modal_closed"}
    end
    end

    -- Check VM slots (using local coords)
    local clicked_slot_index = self:getSlotAtPosition(x, y, viewport_width, viewport_height) -- Pass local coords
    if clicked_slot_index then
        local slot = self.vm_manager.vm_slots[clicked_slot_index]
        if slot.active then
            -- Click on active slot removes the assigned game
            return {name = "remove_game", slot_index = clicked_slot_index}
        else
            self.selected_slot = clicked_slot_index
            self.game_selection_open = true
            return {name = "modal_opened", slot_index = clicked_slot_index}
        end
    end

    -- Check upgrade buttons (using local coords)
    local upgrades = {"cpu_speed", "overclock"}
    for i, upgrade_type in ipairs(upgrades) do
        local bx = self.upgrade_x + (i - 1) * (self.upgrade_w + self.upgrade_spacing)
        local by = self.upgrade_y -- Use layout-calculated y
        -- Check using LOCAL x, y
        if x >= bx and x <= bx + self.upgrade_w and y >= by and y <= by + self.upgrade_h then
            -- Emit intent; controller/state validates affordability
            return {name = "purchase_upgrade", upgrade_type = upgrade_type}
        end
    end

    -- Check purchase button (using local coords)
    if self:isPurchaseButtonClicked(x, y, viewport_width, viewport_height) then -- Pass local coords
        -- Emit intent; controller/state validates affordability and limits
        return {name = "purchase_vm"}
    end

    return nil -- Clicked nothing interactive
end

function VMManagerView:wheelmoved(x, y, item_count, viewport_width, viewport_height)
    if not self.game_selection_open then return 0 end
    -- Calculate visible items based on modal height
    local visible_items = math.floor((self.modal_h - 70) / self.modal_item_height) -- Approx header/footer space
    visible_items = math.max(1, visible_items) -- Ensure at least 1
    local max_scroll = math.max(0, (item_count or 0) - visible_items)

    if y > 0 then -- Scroll up
        self.scroll_offset = math.max(0, math.min(max_scroll, (self.scroll_offset or 0) - 1))
    elseif y < 0 then -- Scroll down
        self.scroll_offset = math.max(0, math.min(max_scroll, (self.scroll_offset or 0) + 1))
    end
    return self.scroll_offset
end


-- Helper functions
function VMManagerView:getSlotAtPosition(x, y, viewport_width, viewport_height)
     local grid_start_y = 50
     for i = 1, #self.vm_manager.vm_slots do
        local col = (i - 1) % self.slot_cols
        local row = math.floor((i - 1) / self.slot_cols)
        local sx = 10 + col * (self.slot_width + self.slot_padding)
        local sy = grid_start_y + row * (self.slot_height + self.slot_padding)

         -- Check if slot is potentially visible before checking click
         if sy + self.slot_height < viewport_height - 70 then
             if x >= sx and x <= sx + self.slot_width and y >= sy and y <= sy + self.slot_height then
                 return i
             end
         end
    end
    return nil
end

-- Interactive scrollbar drag support for modal
function VMManagerView:mousemoved(x, y, dx, dy, filtered_games, viewport_width, viewport_height)
    if not (self.game_selection_open and self._sb and self._sb.modal and self._sb.modal.dragging and self._sb.modal.geom) then return nil end
    local UI = UIComponents
    local list_area_y_start = self.modal_y + 40
    local ly = y - list_area_y_start
    local g = self._sb.modal.geom
    local res = UI.scrollbarHandleMove(ly, self._sb.modal.drag, g)
    if res and res.consumed and res.new_offset_px ~= nil then
        local list_h = self.modal_h - 70
        local visible_items = math.max(1, math.floor(list_h / self.modal_item_height))
        local new_off = math.floor(res.new_offset_px / self.modal_item_height + 0.0001)
        local max_off = math.max(0, (filtered_games and #filtered_games or 0) - visible_items)
        self.scroll_offset = math.max(0, math.min(max_off, new_off))
        return { name = 'content_interaction' }
    end
end

function VMManagerView:mousereleased(x, y, button)
    if button == 1 and self._sb and self._sb.modal then
        self._sb.modal.dragging = false
        self._sb.modal.drag = nil
    end
end

function VMManagerView:getGameAtPosition(x, y, filtered_games, viewport_width, viewport_height)
    -- Check bounding box of the modal list area using modal coords from updateLayout
    local list_area_y_start = self.modal_y + 50 -- Below title
    local list_area_y_end = self.modal_y + self.modal_h - 30 -- Above footer text

    if x < self.modal_x + 10 or x > self.modal_x + self.modal_w - 10 or
       y < list_area_y_start or y > list_area_y_end then
        return nil
    end

    local relative_y = y - list_area_y_start
    local index_in_view = math.floor(relative_y / self.modal_item_height)
    local actual_index = index_in_view + 1 + (self.scroll_offset or 0) -- Use view's scroll offset

    if actual_index >= 1 and actual_index <= #filtered_games then
        return filtered_games[actual_index]
    end

    return nil
end

function VMManagerView:isPurchaseButtonClicked(x, y, viewport_width, viewport_height)
    if #self.vm_manager.vm_slots >= self.vm_manager.max_slots then
        return false
    end

    -- Use button coords calculated in updateLayout
    local bx = self.purchase_button_x
    local by = self.purchase_button_y

    return x >= bx and x <= bx + self.purchase_button_w and
           y >= by and y <= by + self.purchase_button_h
end

-- Draw methods
function VMManagerView:drawTokensPerMinute(x, y, rate)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(Strings.get('vm.total_rate_label','Total Generation Rate:'), x, y)
    love.graphics.setColor(rate > 0 and {0, 1, 0} or {0.5, 0.5, 0.5})
    local rate_units = Strings.get('vm.rate_units','tokens/minute')
    love.graphics.print(string.format("%.1f %s", rate, rate_units), x + 200, y, 0, 1.2, 1.2)
end

function VMManagerView:drawVMSlot(x, y, w, h, slot, selected, hovered, context)
    SpriteManager:ensureLoaded()
    local Config_ = (self.di and self.di.config) or {}
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local S = (V.colors and V.colors.slot) or {}
    if selected then love.graphics.setColor(S.selected_bg or {0.3, 0.3, 0.7})
    elseif hovered then love.graphics.setColor(S.hovered_bg or {0.35, 0.35, 0.35})
    else love.graphics.setColor(S.normal_bg or {0.25, 0.25, 0.25}) end
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(S.border or {0.5, 0.5, 0.5})
    love.graphics.rectangle('line', x, y, w, h)
    love.graphics.setColor(S.header_text or {0.7, 0.7, 0.7})
    local vm_prefix = Strings.get('vm.vm_prefix', 'VM')
    love.graphics.print(vm_prefix .. " " .. slot.slot_index, x + 5, y + 5, 0, 0.8, 0.8)

    if slot.active and slot.assigned_game_id then
        local game = context.game_data:getGame(slot.assigned_game_id)
        if game then
            -- Phase 7.1: Show game's sprite thumbnail
            local palette_id = SpriteManager:getPaletteId(game)
            local icon_sprite = SpriteManager:getMetricSprite(game, game.metrics_tracked[1] or "default")
            if icon_sprite then
                SpriteManager.sprite_loader:drawSprite(icon_sprite, x + 8, y + 35, 48, 48, nil, palette_id)
            end

            love.graphics.setColor(S.name_text or {1,1,1})
            love.graphics.printf(game.display_name, x + 5, y + 20, w - 10, "center", 0, 0.8, 0.8)

            -- Phase 7.1: Display formula with icons for tokens/minute
            love.graphics.setColor(S.power_label or {0,1,1})
            love.graphics.print(Strings.get('vm.power_label','Power:'), x + 65, y + 45, 0, 0.7, 0.7)
            self.formula_renderer:draw(game, x + 65, y + 60, w - 70, 14)


            local progress = 0
            if slot.cycle_time and slot.cycle_time > 0 then
               progress = 1 - (math.max(0, slot.time_remaining or 0) / slot.cycle_time)
            end
            love.graphics.setColor(S.progress_bg or {0.3, 0.3, 0.3})
            love.graphics.rectangle('fill', x + 5, y + h - 25, w - 10, 15)
            
            -- Phase 7.1: Use game's palette for progress bar
            local palette = SpriteManager.palette_manager:getPalette(palette_id)
            local progress_color = (palette and palette.colors and palette.colors.primary) or {0, 1, 0}
            love.graphics.setColor(progress_color)
            love.graphics.rectangle('fill', x + 5, y + h - 25, (w - 10) * progress, 15)

            love.graphics.setColor(S.time_text or {1,1,1})
            local time_text = string.format("%.1fs", math.max(0, slot.time_remaining or 0))
            love.graphics.printf(time_text, x+5, y + h - 23, w - 10, "center", 0, 0.8, 0.8)

            if slot.is_auto_completed then
                love.graphics.setColor(S.auto_badge or {0.5, 0.5, 1})
                love.graphics.print(Strings.get('vm.auto_badge','[AUTO]'), x + w - 45, y + 5, 0, 0.7, 0.7)
            end
        else
            love.graphics.setColor(S.error_text or {1,0,0})
            love.graphics.print(Strings.get('vm.error_missing_game_data','Error: Missing game data!'), x + 5, y + 25)
        end
    else
    love.graphics.setColor(S.empty_text or {0.5, 0.5, 0.5})
        love.graphics.printf(Strings.get('vm.empty_slot','Empty'), x, y + h/2 - 10, w, "center")
        love.graphics.printf(Strings.get('vm.click_to_assign','Click to assign'), x, y + h/2 + 5, w, "center", 0, 0.8, 0.8)
    end
end

function VMManagerView:drawGameSelectionModal(games, scroll_offset, context)
    -- Dark overlay
    local Config_ = (self.di and self.di.config) or {}
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local overlay_alpha = (V.modal and V.modal.overlay_alpha) or (V.colors and V.colors.modal and V.colors.modal.overlay_alpha) or 0.7
    love.graphics.setColor(0, 0, 0, overlay_alpha)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight()) -- Cover whole screen relative to parent

    -- Modal panel using UIComponents
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local MC = (V.colors and V.colors.modal) or {}
    UIComponents.drawPanel(self.modal_x, self.modal_y, self.modal_w, self.modal_h, (MC.panel_bg or {0.2, 0.2, 0.2}))

    love.graphics.setColor(MC.item_text or {1,1,1})
    love.graphics.print(Strings.get('vm.modal_title','Select Game to Assign'), self.modal_x + 10, self.modal_y + 10, 0, 1.2, 1.2)

    local list_y_start = self.modal_y + 40
    local list_h = self.modal_h - 70 -- Space for header and footer text
    local visible_items = math.floor(list_h / self.modal_item_height)
    visible_items = math.max(1, visible_items) -- Ensure at least 1

    local start_index = scroll_offset + 1
    local end_index = math.min(#games, start_index + visible_items - 1)

    for i = start_index, end_index do
        local game_data = games[i]
        local item_y = list_y_start + (i - start_index) * self.modal_item_height
        local is_assigned = context.vm_manager:isGameAssigned(game_data.id)

        -- Item background (could add hover effect here)
    love.graphics.setColor(is_assigned and (MC.item_bg_assigned or {0.15,0.15,0.15}) or (MC.item_bg or {0.25,0.25,0.25}))
        love.graphics.rectangle('fill', self.modal_x + 10, item_y, self.modal_w - 20, self.modal_item_height - 2)

        -- Game Name
    love.graphics.setColor(is_assigned and (MC.item_text_assigned or {0.5,0.5,0.5}) or (MC.item_text or {1,1,1}))
        love.graphics.print(game_data.display_name, self.modal_x + 15, item_y + 5)

    local perf = context.player_data:getGamePerformance(game_data.id)
        if perf then
            -- Power
            love.graphics.setColor(is_assigned and (MC.item_text_assigned or {0.4,0.4,0.4}) or (MC.power_label or {0,1,1}))
            love.graphics.print(Strings.get('vm.power_label','Power:') .. " " .. math.floor(perf.best_score or 0), self.modal_x + 15, item_y + 20, 0, 0.8, 0.8)

            -- Status / Rate (Right aligned)
            local status_text = ""
            if is_assigned then
                love.graphics.setColor(MC.status_in_use or {1,0,0})
                status_text = Strings.get('vm.in_use_badge','[IN USE]')
            else
                love.graphics.setColor(MC.status_text or {0.7,0.7,0.7})
                -- Calculate potential rate based on current upgrades
                local overclock_lvl = (context.player_data.upgrades and context.player_data.upgrades.overclock) or 0
                local cpu_lvl = (context.player_data.upgrades and context.player_data.upgrades.cpu_speed) or 0
                local overclock_bonus = 1 + (overclock_lvl * ((Config_ and Config_.vm_overclock_bonus_per_level) or 0))
                local cpu_bonus = 1 + (cpu_lvl * ((Config_ and Config_.vm_cpu_speed_bonus_per_level) or 0))
                local potential_power = (perf.best_score or 0) * overclock_bonus
                local base_cycle = (Config_ and Config_.vm_base_cycle_time) or 60
                local potential_cycle_time = base_cycle / math.max(0.0001, cpu_bonus)
                local potential_rate = 0
                if potential_cycle_time > 0 then
                    potential_rate = potential_power * (60 / potential_cycle_time)
                end
                local per_minute_suffix = Strings.get('tokens.per_minute_suffix','/min')
                status_text = string.format("~%.0f%s", potential_rate, per_minute_suffix)
            end
            -- Reserve a scrollbar lane so text doesn't run under it
            local lane_w = UIComponents.getScrollbarLaneWidth()
            love.graphics.printf(status_text, self.modal_x + 15, item_y + 20, (self.modal_w - 30) - lane_w, "right", 0, 0.8, 0.8)
        end
    end

    -- Scrollbar (using UIComponents helper)
    if #games > visible_items then
        local UI = UIComponents
        local item_h = self.modal_item_height
        -- Translate so computeScrollbar can operate from modal origin
        love.graphics.push(); love.graphics.translate(self.modal_x, list_y_start)
        local sb_geom = UI.computeScrollbar({
            viewport_w = self.modal_w,
            viewport_h = list_h,
            content_h = (#games) * item_h,
            offset = (scroll_offset or 0) * item_h,
            -- width/margin/arrow heights/min thumb from config defaults
        })
        UI.drawScrollbar(sb_geom)
        -- Store geometry for interactive handling (list-local coordinates)
        self._sb.modal.geom = sb_geom
        love.graphics.pop()
    end


    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(Strings.get('vm.modal_footer','Click game to assign | Click outside or ESC to cancel'), self.modal_x + 10, self.modal_y + self.modal_h - 25, 0, 0.8, 0.8)
end

function VMManagerView:drawPurchaseVMButton(x, y, cost, can_afford, hovered)
     -- Use UIComponents.drawButton
    local purchase_label = string.format(Strings.get('vm.purchase_button','Purchase VM (%d)'), cost)
    UIComponents.drawButton(x, y, self.purchase_button_w, self.purchase_button_h,
        purchase_label, can_afford, hovered)
end

return VMManagerView