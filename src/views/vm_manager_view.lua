-- vm_manager_view.lua: View class for VM Manager UI

local Object = require('class')
local UIComponents = require('src.views.ui_components')
local FormulaRenderer = require('src.views.formula_renderer')
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
    self.sprite_manager = (di and di.spriteManager) or nil
    self.variant_loader = (di and di.gameVariantLoader) or nil  -- Phase 2.4

    self.selected_slot = nil
    self.selected_game_id = nil
    self.game_selection_open = false
    self.demo_selection_open = false
    self.scroll_offset = 0
    self.hovered_slot = nil
    self.hovered_upgrade = nil
    self.hovered_purchase_vm = false
    self.hovered_speed_upgrade = nil

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

    self.formula_renderer = FormulaRenderer:new(self.di)
    -- Scrollbar is now handled by ScrollbarController in the state
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
    local grid_scroll_offset = self.grid_scroll_offset or 0

    -- Calculate grid area for scissor and scrollbar
    local grid_area_height = viewport_height - grid_start_y - (G.bottom_reserved or 70)

    -- Apply scissor to clip slots outside visible area
    local viewport = self.controller.viewport
    local screen_x = viewport and viewport.x or 0
    local screen_y = viewport and viewport.y or 0
    love.graphics.setScissor(screen_x, screen_y + grid_start_y, viewport_width, grid_area_height)

    for i, slot in ipairs(slots) do
        local col = (i - 1) % self.slot_cols
        local row = math.floor((i - 1) / self.slot_cols)
        local x = (G.left_margin or 10) + col * (self.slot_width + self.slot_padding)
        local y = grid_start_y + row * (self.slot_height + self.slot_padding) - grid_scroll_offset

        -- Draw if within visible area (with some margin for partial visibility)
        if y + self.slot_height >= grid_start_y - 10 and y < grid_start_y + grid_area_height + 10 then
            local view_context = { game_data = self.game_data, player_data = self.player_data, vm_manager = self.vm_manager }
            self:drawVMSlot(x, y, self.slot_width, self.slot_height, slot,
                i == self.selected_slot, i == self.hovered_slot, view_context)
        end
    end

    love.graphics.setScissor()

    -- Draw grid scrollbar if needed
    local total_rows = math.ceil(#slots / self.slot_cols)
    local total_grid_height = total_rows * (self.slot_height + self.slot_padding)
    local max_scroll = math.max(0, total_grid_height - grid_area_height)

    if max_scroll > 0 and not self.game_selection_open and not self.demo_selection_open then
        local scrollbar = self.controller.grid_scrollbar
        if scrollbar then
            scrollbar:setPosition(0, grid_start_y)
            local geom = scrollbar:compute(viewport_width, grid_area_height, total_grid_height, grid_scroll_offset, max_scroll)

            if geom then
                love.graphics.push()
                love.graphics.translate(0, grid_start_y)
                UIComponents.drawScrollbar(geom)
                love.graphics.pop()
            end
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

    -- Demo selection modal
    if self.demo_selection_open then
        local view_context = { game_data = self.game_data, player_data = self.player_data, vm_manager = self.vm_manager }
        self:drawDemoSelectionModal(self.controller.filtered_demos, self.scroll_offset, view_context)
    end

    -- Instructions (Bottom fixed)
    love.graphics.setColor( (V.colors and V.colors.slot and V.colors.slot.header_text) or {0.7,0.7,0.7} )
    love.graphics.print(Strings.get('vm.instructions', 'Click empty slot to assign demo | Click buttons to control | ESC in modal to cancel'),
        10, viewport_height - ((V.instructions and V.instructions.bottom_offset) or 25), 0, 0.8, 0.8)
end

function VMManagerView:mousepressed(x, y, button, filtered_games, viewport_width, viewport_height)
    -- x, y are LOCAL coords relative to content area (0,0)
    if button ~= 1 then return nil end

    -- Check demo selection modal first
    if self.demo_selection_open then
        if x >= self.modal_x and x <= self.modal_x + self.modal_w and y >= self.modal_y and y <= self.modal_y + self.modal_h then
            local list_area_y_start = self.modal_y + 40
            local list_h = self.modal_h - 70
            local visible_items = math.max(1, math.floor(list_h / self.modal_item_height))
            local demos = self.controller.filtered_demos or {}

            -- Scrollbar is now handled by ScrollbarController in the state

            -- Check if delete button was clicked first
            local delete_demo = self:getDeleteButtonAtPosition(x, y, demos)
            if delete_demo then
                return {name = "delete_demo", demo_id = delete_demo.demo_id}
            end

            -- Check clicked demo
            local clicked_demo = self:getDemoAtPosition(x, y, demos)
            if clicked_demo then
                local slot_to_assign = self.selected_slot
                self.demo_selection_open = false
                self.game_selection_open = false
                self.selected_slot = nil
                return {name = "assign_demo", slot_index = slot_to_assign, demo_id = clicked_demo.demo_id}
            else
                return nil -- Consume click inside modal
            end
        else
            -- Clicked outside modal, go back to game selection
            self.demo_selection_open = false
            self.game_selection_open = true
            return {name="modal_closed"}
        end
    end

    -- Check game selection modal
    if self.game_selection_open then
        if x >= self.modal_x and x <= self.modal_x + self.modal_w and y >= self.modal_y and y <= self.modal_y + self.modal_h then
            local list_area_y_start = self.modal_y + 40
            local list_h = self.modal_h - 70
            local visible_items = math.max(1, math.floor(list_h / self.modal_item_height))

            -- Handle scrollbar
            -- Scrollbar is now handled by ScrollbarController in the state

            local clicked_game = self:getGameAtPosition(x, y, filtered_games, viewport_width, viewport_height)
            if clicked_game then
                -- Don't close yet - show demo selection next
                return {name = "assign_game", slot_index = self.selected_slot, game_id = clicked_game.id}
            else
                return nil -- Consume click inside modal
            end
        else
            -- Clicked outside modal, close it
            self.game_selection_open = false
            self.selected_slot = nil
            return {name="modal_closed"}
        end
    end

    -- Check VM slot controls (Stop/Start, Speed Upgrade)
    local clicked_slot_index = self:getSlotAtPosition(x, y, viewport_width, viewport_height)
    if clicked_slot_index then
        local slot = self.vm_manager.vm_slots[clicked_slot_index]
        local Config_ = (self.di and self.di.config) or {}
        local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
        local G = V.grid or { start_y = 50, left_margin = 10 }

        local col = (clicked_slot_index - 1) % self.slot_cols
        local row = math.floor((clicked_slot_index - 1) / self.slot_cols)
        local slot_x = (G.left_margin or 10) + col * (self.slot_width + self.slot_padding)
        local slot_y = (G.start_y or 50) + row * (self.slot_height + self.slot_padding)

        local local_x = x - slot_x
        local local_y = y - slot_y

        -- Check if slot is assigned
        if slot.state ~= "IDLE" then
            -- Click anywhere on assigned slot - remove game (could add confirmation dialog later)
            return {name = "remove_game", slot_index = clicked_slot_index}
        else
            -- Empty slot - open game selection
            self.selected_slot = clicked_slot_index
            self.game_selection_open = true
            self.scroll_offset = 0
            return {name = "modal_opened", slot_index = clicked_slot_index}
        end
    end

    -- Check upgrade buttons
    local upgrades = {"cpu_speed", "overclock"}
    for i, upgrade_type in ipairs(upgrades) do
        local bx = self.upgrade_x + (i - 1) * (self.upgrade_w + self.upgrade_spacing)
        local by = self.upgrade_y
        if x >= bx and x <= bx + self.upgrade_w and y >= by and y <= by + self.upgrade_h then
            return {name = "purchase_upgrade", upgrade_type = upgrade_type}
        end
    end

    -- Check purchase VM button
    if self:isPurchaseButtonClicked(x, y, viewport_width, viewport_height) then
        return {name = "purchase_vm"}
    end

    return nil
end

function VMManagerView:wheelmoved(x, y, item_count, viewport_width, viewport_height)
    if not (self.game_selection_open or self.demo_selection_open) then return 0 end

    -- Use the appropriate item count
    local items = item_count
    if self.demo_selection_open then
        items = #(self.controller.filtered_demos or {})
    end

    -- Calculate visible items based on modal height
    local visible_items = math.floor((self.modal_h - 70) / self.modal_item_height)
    visible_items = math.max(1, visible_items)
    local max_scroll = math.max(0, items - visible_items)

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
    -- Scrollbar dragging is now handled by ScrollbarController in the state
    return nil
end

function VMManagerView:mousereleased(x, y, button)
    -- Scrollbar dragging is now handled by ScrollbarController in the state
    return nil
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

function VMManagerView:getDemoAtPosition(x, y, demos)
    -- Check bounding box of the modal list area
    local list_area_y_start = self.modal_y + 40
    local list_area_y_end = self.modal_y + self.modal_h - 30

    if x < self.modal_x + 10 or x > self.modal_x + self.modal_w - 20 or
       y < list_area_y_start or y > list_area_y_end then
        return nil
    end

    local relative_y = y - list_area_y_start
    local index_in_view = math.floor(relative_y / self.modal_item_height)
    local actual_index = index_in_view + 1 + (self.scroll_offset or 0)

    if actual_index >= 1 and actual_index <= #demos then
        local demo = demos[actual_index]
        -- Return demo with ID for easy lookup
        return { demo_id = demo.demo_id, demo = demo }
    end

    return nil
end

function VMManagerView:getDeleteButtonAtPosition(x, y, demos)
    local list_area_y_start = self.modal_y + 40
    local list_area_y_end = self.modal_y + self.modal_h - 30

    if y < list_area_y_start or y > list_area_y_end then
        return nil
    end

    local relative_y = y - list_area_y_start
    local index_in_view = math.floor(relative_y / self.modal_item_height)
    local actual_index = index_in_view + 1 + (self.scroll_offset or 0)

    if actual_index >= 1 and actual_index <= #demos then
        local demo = demos[actual_index]
        local item_y = list_area_y_start + index_in_view * self.modal_item_height

        -- Check if click is on delete button
        local delete_btn_size = 20
        local delete_btn_x = self.modal_x + self.modal_w - 35
        local delete_btn_y = item_y + (self.modal_item_height - delete_btn_size) / 2

        if x >= delete_btn_x and x <= delete_btn_x + delete_btn_size and
           y >= delete_btn_y and y <= delete_btn_y + delete_btn_size then
            return { demo_id = demo.demo_id, demo = demo }
        end
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
    local Config_ = (self.di and self.di.config) or {}
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local S = (V.colors and V.colors.slot) or {}

    -- Border
    love.graphics.setColor(S.border or {0.5, 0.5, 0.5})
    love.graphics.rectangle('line', x, y, w, h)

    -- Header bar (20px)
    local header_h = 20
    if selected then love.graphics.setColor(S.selected_bg or {0.3, 0.3, 0.7})
    elseif hovered then love.graphics.setColor(S.hovered_bg or {0.35, 0.35, 0.35})
    else love.graphics.setColor(S.normal_bg or {0.25, 0.25, 0.25}) end
    love.graphics.rectangle('fill', x, y, w, header_h)

    love.graphics.setColor(S.header_text or {0.7, 0.7, 0.7})
    local vm_prefix = Strings.get('vm.vm_prefix', 'VM')
    love.graphics.print(vm_prefix .. " " .. slot.slot_index, x + 5, y + 3, 0, 0.7, 0.7)

    -- Speed indicator in header
    if slot.state ~= "IDLE" then
        local speed_text = ""
        if slot.headless_mode then
            speed_text = Config_.vm_demo and Config_.vm_demo.headless_speed_label or "INSTANT"
        elseif slot.speed_multiplier and slot.speed_multiplier > 1 then
            speed_text = slot.speed_multiplier .. "x"
        else
            speed_text = "1x"
        end
        love.graphics.setColor(S.speed_text or {1, 1, 0})
        love.graphics.print(speed_text, x + w - 40, y + 3, 0, 0.7, 0.7)
    end

    -- Content area (game rendering or info)
    local content_y = y + header_h
    local content_h = h - header_h

    -- Check if slot is assigned
    local is_assigned = slot.state ~= "IDLE"

    if is_assigned and slot.assigned_game_id then
        local game = context.game_data:getGame(slot.assigned_game_id)

        -- Show completion screen during RESTARTING state
        if slot.state == "RESTARTING" and game then
            love.graphics.setColor(S.normal_bg or {0.15, 0.15, 0.15})
            love.graphics.rectangle('fill', x, content_y, w, content_h)

            local info_y = content_y + content_h / 2 - 40

            -- Show completion message
            local stats = slot.stats or {}
            if stats.last_run_success then
                love.graphics.setColor(0, 1, 0)
                love.graphics.printf("VICTORY!", x + 5, info_y, w - 10, "center", 0, 1.5, 1.5)
            else
                love.graphics.setColor(1, 0.3, 0.3)
                love.graphics.printf("DEFEAT", x + 5, info_y, w - 10, "center", 0, 1.5, 1.5)
            end
            info_y = info_y + 30

            -- Show tokens earned
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("+" .. math.floor(stats.last_run_tokens or 0) .. " tokens", x + 5, info_y, w - 10, "center", 0, 1.0, 1.0)
            info_y = info_y + 25

            -- Show restart timer
            love.graphics.setColor(0.7, 0.7, 0.7)
            local restart_time_left = (context.vm_manager.restart_delay or 5) - (slot.restart_timer or 0)
            love.graphics.printf(string.format("Next run in %.1fs", restart_time_left), x + 5, info_y, w - 10, "center", 0, 0.8, 0.8)

        elseif game and slot.game_instance and not slot.headless_mode and slot.state == "RUNNING" then
            -- RENDER THE ACTUAL GAME
            love.graphics.push()
            love.graphics.translate(x, content_y)

            -- Get viewport for scissor (screen coordinates)
            local viewport = self.controller.viewport
            local screen_x = (viewport and viewport.x or 0) + x
            local screen_y = (viewport and viewport.y or 0) + content_y

            -- Scissor to content area
            love.graphics.setScissor(screen_x, screen_y, w, content_h)

            -- Enable VM render mode (hides HUD)
            if slot.game_instance.setVMRenderMode then
                slot.game_instance:setVMRenderMode(true)
            end

            -- Determine rendering approach based on game type
            local render_width, render_height, scale

            -- Check if game has fixed arena (like snake with is_fixed_arena)
            if slot.game_instance.is_fixed_arena then
                -- Fixed arena: zoom out to show whole arena
                render_width = slot.game_instance.game_width
                render_height = slot.game_instance.game_height

                -- Scale to fit in slot while maintaining aspect ratio
                scale_x = w / render_width
                scale_y = content_h / render_height
                scale = math.min(scale_x, scale_y)
            else
                -- Dynamic/viewport games: render at standard 720x400
                render_width = 720
                render_height = 400

                -- Update game dimensions
                slot.game_instance.game_width = render_width
                slot.game_instance.game_height = render_height

                -- Scale down to fit in slot
                scale_x = w / render_width
                scale_y = content_h / render_height
                scale = math.min(scale_x, scale_y)
            end

            love.graphics.scale(scale, scale)

            -- Draw the game
            local success, err = pcall(function()
                slot.game_instance:draw()
            end)

            if not success then
                love.graphics.setColor(1, 0, 0)
                love.graphics.printf("Render error: " .. tostring(err), 0, 200, 400, "center", 0, 0.6, 0.6)
            end

            -- Disable VM render mode
            if slot.game_instance.setVMRenderMode then
                slot.game_instance:setVMRenderMode(false)
            end

            love.graphics.setScissor()
            love.graphics.pop()

            -- Draw HUD overlay at bottom (outside transform and scissor)
            self:drawVMGameHUD(x, y + h - 25, w, 25, slot, game)
        else
            -- Show stats / info instead of game rendering
            love.graphics.setColor(S.normal_bg or {0.15, 0.15, 0.15})
            love.graphics.rectangle('fill', x, content_y, w, content_h)

            local info_y = content_y + 5

            if game then
                love.graphics.setColor(S.name_text or {1,1,1})
                love.graphics.printf(game.display_name, x + 5, info_y, w - 10, "center", 0, 0.7, 0.7)
                info_y = info_y + 15
            end

            -- Show state
            love.graphics.setColor(S.state_text or {0, 1, 1})
            local state_text = slot.state or "IDLE"
            if slot.headless_mode then
                state_text = state_text .. " (HEADLESS)"
            end
            love.graphics.printf(state_text, x + 5, info_y, w - 10, "center", 0, 0.6, 0.6)
            info_y = info_y + 15

            -- Show stats
            local stats = slot.stats or {}
            love.graphics.setColor(S.stats_text or {0.8, 0.8, 0.8})
            love.graphics.printf("Runs: " .. (stats.total_runs or 0), x + 5, info_y, w - 10, "center", 0, 0.6, 0.6)
            info_y = info_y + 12
            local success_rate = (stats.total_runs or 0) > 0 and ((stats.successes or 0) / stats.total_runs * 100) or 0
            love.graphics.printf(string.format("Success: %.0f%%", success_rate), x + 5, info_y, w - 10, "center", 0, 0.6, 0.6)
            info_y = info_y + 12
            love.graphics.printf(string.format("%.1f tk/min", stats.tokens_per_minute or 0), x + 5, info_y, w - 10, "center", 0, 0.6, 0.6)
        end
    else
        -- Empty slot
        love.graphics.setColor(S.normal_bg or {0.15, 0.15, 0.15})
        love.graphics.rectangle('fill', x, content_y, w, content_h)
        love.graphics.setColor(S.empty_text or {0.5, 0.5, 0.5})
        love.graphics.printf(Strings.get('vm.empty_slot','Empty'), x, y + h/2 - 10, w, "center")
        love.graphics.printf(Strings.get('vm.click_to_assign','Click to assign'), x, y + h/2 + 5, w, "center", 0, 0.8, 0.8)
    end
end

function VMManagerView:drawVMGameHUD(x, y, w, h, slot, game)
    -- Draw semi-transparent overlay bar at bottom
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', x, y, w, h)

    love.graphics.setColor(1, 1, 1)
    local padding = 5
    local text_y = y + 5
    local scale = 0.7

    -- Show key game metrics
    if game and slot.game_instance then
        local metrics = slot.game_instance.metrics or {}
        local text = ""

        -- Game-specific metrics (customize per game type)
        if game.game_class == "DodgeGame" then
            local dodged = metrics.objects_dodged or 0
            local target = slot.game_instance.dodge_target or 0
            local lives = (slot.game_instance.lives or 10) - (metrics.collisions or 0)
            text = string.format("Dodged: %d/%d  Lives: %d  Combo: %d", dodged, target, lives, metrics.combo or 0)
        elseif game.game_class == "SnakeGame" then
            local length = metrics.snake_length or 0
            local target = slot.game_instance.target_length or 0
            local time = metrics.survival_time or 0
            text = string.format("Length: %d/%d  Time: %.1fs", length, target, time)
        elseif game.game_class == "MemoryMatch" then
            local matches = metrics.matches or 0
            local total = slot.game_instance.total_pairs or 0
            local time = metrics.time or 0
            text = string.format("Matches: %d/%d  Time: %.1fs", matches, total, time)
        elseif game.game_class == "HiddenObject" then
            local found = metrics.objects_found or 0
            local total = slot.game_instance.target_objects or 0
            local time = metrics.time or 0
            text = string.format("Found: %d/%d  Time: %.1fs", found, total, time)
        elseif game.game_class == "SpaceShooter" then
            local kills = metrics.enemies_killed or 0
            local deaths = metrics.deaths or 0
            text = string.format("Kills: %d  Deaths: %d", kills, deaths)
        else
            -- Generic fallback
            text = "Playing..."
        end

        love.graphics.printf(text, x + padding, text_y, w - 2 * padding, "left", 0, scale, scale)
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

    -- Scrollbar (using state's modal ScrollbarController)
    if #games > visible_items then
        local scrollbar = self.controller.modal_scrollbar
        if scrollbar then
            scrollbar:setPosition(self.modal_x, list_y_start)
            local max_scroll = math.max(0, #games - visible_items)
            local geom = scrollbar:compute(self.modal_w, list_h, #games * self.modal_item_height, scroll_offset or 0, max_scroll)

            if geom then
                love.graphics.push()
                love.graphics.translate(self.modal_x, list_y_start)
                UIComponents.drawScrollbar(geom)
                love.graphics.pop()
            end
        end
    end


    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(Strings.get('vm.modal_footer','Click game to assign | Click outside or ESC to cancel'), self.modal_x + 10, self.modal_y + self.modal_h - 25, 0, 0.8, 0.8)
end

function VMManagerView:drawDemoSelectionModal(demos, scroll_offset, context)
    -- Dark overlay
    local Config_ = (self.di and self.di.config) or {}
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.vm_manager) or {}
    local overlay_alpha = (V.modal and V.modal.overlay_alpha) or (V.colors and V.colors.modal and V.colors.modal.overlay_alpha) or 0.7
    love.graphics.setColor(0, 0, 0, overlay_alpha)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Modal panel
    local MC = (V.colors and V.colors.modal) or {}
    UIComponents.drawPanel(self.modal_x, self.modal_y, self.modal_w, self.modal_h, (MC.panel_bg or {0.2, 0.2, 0.2}))

    love.graphics.setColor(MC.item_text or {1,1,1})
    love.graphics.print(Strings.get('vm.demo_modal_title','Select Demo to Assign'), self.modal_x + 10, self.modal_y + 10, 0, 1.2, 1.2)

    local list_y_start = self.modal_y + 40
    local list_h = self.modal_h - 70
    local visible_items = math.floor(list_h / self.modal_item_height)
    visible_items = math.max(1, visible_items)

    local start_index = scroll_offset + 1
    local end_index = math.min(#demos, start_index + visible_items - 1)

    if #demos == 0 then
        love.graphics.setColor(0.7, 0.5, 0.5)
        love.graphics.printf("No demos available for this game.", self.modal_x + 10, list_y_start + 20, self.modal_w - 20, "center")
    else
        for i = start_index, end_index do
            local demo = demos[i]
            local item_y = list_y_start + (i - start_index) * self.modal_item_height

            -- Item background
            love.graphics.setColor(MC.item_bg or {0.25,0.25,0.25})
            love.graphics.rectangle('fill', self.modal_x + 10, item_y, self.modal_w - 20, self.modal_item_height - 2)

            -- Demo Name
            love.graphics.setColor(MC.item_text or {1,1,1})
            local demo_name = (demo.metadata and demo.metadata.demo_name) or "Unnamed Demo"
            love.graphics.print(demo_name, self.modal_x + 15, item_y + 5)

            -- Demo info
            if demo.recording then
                love.graphics.setColor(MC.power_label or {0,1,1})
                local frame_count = demo.recording.total_frames or 0
                local duration = frame_count * (demo.recording.fixed_dt or (1/60))
                love.graphics.print(string.format("Frames: %d (~%.1fs)", frame_count, duration), self.modal_x + 15, item_y + 20, 0, 0.8, 0.8)
            end

            -- Delete button (small red X on right)
            local delete_btn_size = 20
            local delete_btn_x = self.modal_x + self.modal_w - 35
            local delete_btn_y = item_y + (self.modal_item_height - delete_btn_size) / 2
            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.rectangle('fill', delete_btn_x, delete_btn_y, delete_btn_size, delete_btn_size)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("X", delete_btn_x, delete_btn_y + 2, delete_btn_size, "center", 0, 0.9, 0.9)
        end

        -- Scrollbar (using state's modal ScrollbarController)
        if #demos > visible_items then
            local scrollbar = self.controller.modal_scrollbar
            if scrollbar then
                scrollbar:setPosition(self.modal_x, list_y_start)
                local max_scroll = math.max(0, #demos - visible_items)
                local geom = scrollbar:compute(self.modal_w, list_h, #demos * self.modal_item_height, scroll_offset or 0, max_scroll)

                if geom then
                    love.graphics.push()
                    love.graphics.translate(self.modal_x, list_y_start)
                    UIComponents.drawScrollbar(geom)
                    love.graphics.pop()
                end
            end
        end
    end

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(Strings.get('vm.demo_modal_footer','Click demo to assign | Click outside or ESC to cancel'), self.modal_x + 10, self.modal_y + self.modal_h - 25, 0, 0.8, 0.8)
end

function VMManagerView:drawPurchaseVMButton(x, y, cost, can_afford, hovered)
     -- Use UIComponents.drawButton
    local purchase_label = string.format(Strings.get('vm.purchase_button','Purchase VM (%d)'), cost)
    UIComponents.drawButton(x, y, self.purchase_button_w, self.purchase_button_h,
        purchase_label, can_afford, hovered)
end

return VMManagerView