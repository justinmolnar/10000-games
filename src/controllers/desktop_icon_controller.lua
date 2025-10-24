-- src/controllers/desktop_icon_controller.lua
-- Encapsulates desktop icon layout, hit-testing, and drop/arrangement logic

local Object = require('class')
local Collision = require('src.utils.collision')

local DesktopIconController = Object:extend('DesktopIconController')

function DesktopIconController:init(program_registry, desktop_icons, recycle_bin, di)
    self.program_registry = program_registry
    self.desktop_icons = desktop_icons
    self.recycle_bin = recycle_bin
    self.di = di
    self.event_bus = di and di.eventBus
    self.config = di and di.config

    self.default_icon_positions = {}
    self.grid_cfg = (((di and di.config and di.config.ui and di.config.ui.desktop) or {}).grid) or {}
    self.taskbar_height = (((di and di.config and di.config.ui and di.config.ui.taskbar) or {}).height) or 40

    -- Icon interaction state
    self.dragging_icon_id = nil
    self.drag_offset_x = 0
    self.drag_offset_y = 0
    self.last_icon_click_time = 0
    self.last_icon_click_id = nil
    self.hovered_icon_id = nil
end

-- Ensure default grid positions are calculated for the current screen
function DesktopIconController:ensureDefaultPositions(screen_w, screen_h)
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()
    local padding = self.grid_cfg.icon_padding or 20
    local start_x = self.grid_cfg.start_x or 20
    local start_y = self.grid_cfg.start_y or 20

    local desktop_programs = self.program_registry:getDesktopPrograms()
    if #desktop_programs == 0 then
        self.default_icon_positions = {}
        return
    end

    local available_height = (screen_h or 0) - self.taskbar_height - start_y
    local icons_per_column = math.max(1, math.floor(available_height / (icon_h + padding)))

    local positions = {}
    local col, row = 0, 0
    for _, program in ipairs(desktop_programs) do
        positions[program.id] = {
            x = start_x + col * (icon_w + padding),
            y = start_y + row * (icon_h + padding)
        }
        row = row + 1
        if row >= icons_per_column then
            row = 0
            col = col + 1
        end
    end

    self.default_icon_positions = positions
end

function DesktopIconController:getDefaultIconPosition(program_id)
    -- Fallback to top-left if not calculated
    local start_x = self.grid_cfg.start_x or 20
    local start_y = self.grid_cfg.start_y or 20
    return self.default_icon_positions[program_id] or { x = start_x, y = start_y }
end

-- Quantize a raw x,y to the nearest grid slot according to configured start and padding
function DesktopIconController:snapToGrid(x, y)
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()
    local padding = self.grid_cfg.icon_padding or 20
    local start_x = self.grid_cfg.start_x or 20
    local start_y = self.grid_cfg.start_y or 20

    -- Compute indices then map back to top-left of grid cell
    local col = math.max(0, math.floor((x - start_x) / (icon_w + padding) + 0.5))
    local row = math.max(0, math.floor((y - start_y) / (icon_h + padding) + 0.5))
    local gx = start_x + col * (icon_w + padding)
    local gy = start_y + row * (icon_h + padding)
    return gx, gy
end

-- Returns program_id at screen coordinate x,y or nil
function DesktopIconController:getProgramAtPosition(x, y)
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()
    local desktop_programs = self.program_registry:getDesktopPrograms()
    for _, program in ipairs(desktop_programs) do
        if not self.desktop_icons:isDeleted(program.id) then
            local pos = self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
            if x >= pos.x and x <= pos.x + icon_w and y >= pos.y and y <= pos.y + icon_h then
                return program.id
            end
        end
    end
    return nil
end

-- Recycle bin icon position/rect for drop checks
function DesktopIconController:getRecycleBinPosition()
    local program = self.program_registry:getProgram('recycle_bin')
    if not program or self.desktop_icons:isDeleted('recycle_bin') then return nil end
    local pos = self.desktop_icons:getPosition('recycle_bin') or self:getDefaultIconPosition('recycle_bin')
    local w, h = self.desktop_icons:getIconDimensions()
    return { x = pos.x, y = pos.y, w = w, h = h }
end

-- Resolve final drop position for a dragged icon; returns final_x, final_y
function DesktopIconController:resolveDropPosition(dropped_icon_id, initial_drop_x, initial_drop_y, screen_w, screen_h)
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()
    local padding = 5

    local final_x, final_y = initial_drop_x, initial_drop_y
    local overlap_resolved = false
    local attempts = 0
    local max_attempts = 15

    while not overlap_resolved and attempts < max_attempts do
        attempts = attempts + 1
        overlap_resolved = true

        -- A. Clamp to screen using model validation
        local current_valid_x, current_valid_y = self.desktop_icons:validatePosition(final_x, final_y, screen_w, screen_h)
        final_x, final_y = current_valid_x, current_valid_y

        local overlapping_icon_data = nil
        local desktop_programs = self.program_registry:getDesktopPrograms()

        -- B. Overlap check
        for _, program in ipairs(desktop_programs) do
            if program.id ~= dropped_icon_id and not self.desktop_icons:isDeleted(program.id) then
                local other_pos = self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
                if Collision.checkAABB(final_x, final_y, icon_w, icon_h, other_pos.x, other_pos.y, icon_w, icon_h) then
                    overlapping_icon_data = { program_id = program.id, pos = other_pos }
                    overlap_resolved = false
                    break
                end
            end
        end

        -- C. Nudge to resolve
        if not overlap_resolved and overlapping_icon_data then
            local other_pos = overlapping_icon_data.pos
            local dx = (final_x + icon_w / 2) - (other_pos.x + icon_w / 2)
            local dy = (final_y + icon_h / 2) - (other_pos.y + icon_h / 2)
            local overlap_x = (icon_w) - math.abs(dx)
            local overlap_y = (icon_h) - math.abs(dy)

            local potential_nudges = {}
            if overlap_x < overlap_y then
                if dx > 0 then table.insert(potential_nudges, {x = other_pos.x + icon_w + padding, y = final_y}) else table.insert(potential_nudges, {x = other_pos.x - icon_w - padding, y = final_y}) end
                if dy > 0 then table.insert(potential_nudges, {x = final_x, y = other_pos.y + icon_h + padding}) else table.insert(potential_nudges, {x = final_x, y = other_pos.y - icon_h - padding}) end
            else
                if dy > 0 then table.insert(potential_nudges, {x = final_x, y = other_pos.y + icon_h + padding}) else table.insert(potential_nudges, {x = final_x, y = other_pos.y - icon_h - padding}) end
                if dx > 0 then table.insert(potential_nudges, {x = other_pos.x + icon_w + padding, y = final_y}) else table.insert(potential_nudges, {x = other_pos.x - icon_w - padding, y = final_y}) end
            end

            local found_nudge = false
            for _, nudge in ipairs(potential_nudges) do
                local valid_x, valid_y = self.desktop_icons:validatePosition(nudge.x, nudge.y, screen_w, screen_h)
                local nudge_overlaps = false
                for _, program_check in ipairs(desktop_programs) do
                    if program_check.id ~= dropped_icon_id and not self.desktop_icons:isDeleted(program_check.id) then
                        local check_pos = self.desktop_icons:getPosition(program_check.id) or self:getDefaultIconPosition(program_check.id)
                        if Collision.checkAABB(valid_x, valid_y, icon_w, icon_h, check_pos.x, check_pos.y, icon_w, icon_h) then
                            nudge_overlaps = true; break
                        end
                    end
                end
                if not nudge_overlaps then
                    if math.abs(valid_x - final_x) > 1 or math.abs(valid_y - final_y) > 1 then
                        final_x, final_y = valid_x, valid_y
                        found_nudge = true
                        overlap_resolved = false
                        break
                    end
                end
            end

            if not found_nudge then
                overlap_resolved = true
            end
        end
    end

    return final_x, final_y
end

-- Update hover state based on mouse position
function DesktopIconController:update(dt, mx, my)
    self.hovered_icon_id = self:getProgramAtPosition(mx, my)
end

-- Handle icon click - returns action type or nil
function DesktopIconController:mousepressed(x, y, button)
    if button ~= 1 then return nil end

    local icon_program_id = self:getProgramAtPosition(x, y)
    if not icon_program_id then return nil end

    local program = self.program_registry:getProgram(icon_program_id)
    if not program then return nil end

    -- Check for disabled program
    if program.disabled then
        local Strings = require('src.utils.strings')
        love.window.showMessageBox(
            Strings.get('messages.not_available', 'Not Available'),
            program.name .. " is planned.",
            "info"
        )
        self.last_icon_click_id = nil
        self.last_icon_click_time = 0
        return { type = "disabled_click", program_id = icon_program_id }
    end

    -- Check for double-click
    local dbl = (self.config and self.config.ui and self.config.ui.double_click_time) or 0.5
    local is_double_click = (self.last_icon_click_id == icon_program_id and love.timer.getTime() - self.last_icon_click_time < dbl)

    if is_double_click then
        -- Double-click: open program
        self.last_icon_click_id = nil
        self.last_icon_click_time = 0
        self.dragging_icon_id = nil

        -- Publish event
        if self.event_bus then
            self.event_bus:publish('icon_double_clicked', icon_program_id)
        end

        return { type = "double_click", program_id = icon_program_id }
    end

    -- Single click: start drag
    self.last_icon_click_id = icon_program_id
    self.last_icon_click_time = love.timer.getTime()
    self.dragging_icon_id = icon_program_id

    local icon_pos = self.desktop_icons:getPosition(icon_program_id) or self:getDefaultIconPosition(icon_program_id)
    self.drag_offset_x = x - icon_pos.x
    self.drag_offset_y = y - icon_pos.y

    -- Publish event
    if self.event_bus then
        self.event_bus:publish('icon_drag_started', icon_program_id)
    end

    return { type = "drag_start", program_id = icon_program_id }
end

-- Handle icon drop - returns action type or nil
function DesktopIconController:mousereleased(x, y, button)
    if button ~= 1 or not self.dragging_icon_id then return nil end

    local dropped_icon_id = self.dragging_icon_id
    self.dragging_icon_id = nil -- Stop drag state

    local initial_drop_x = x - self.drag_offset_x
    local initial_drop_y = y - self.drag_offset_y
    local screen_w, screen_h = love.graphics.getDimensions()

    -- Check if dropped on Recycle Bin
    local recycle_bin_rect = self:getRecycleBinPosition()
    if recycle_bin_rect and dropped_icon_id ~= "recycle_bin" then
        local icon_w, icon_h = self.desktop_icons:getIconDimensions()
        -- Check if dragged icon overlaps with recycle bin icon
        if Collision.checkAABB(initial_drop_x, initial_drop_y, icon_w, icon_h,
                               recycle_bin_rect.x, recycle_bin_rect.y, recycle_bin_rect.w, recycle_bin_rect.h) then
            -- Publish recycle event
            if self.event_bus then
                self.event_bus:publish('icon_dropped_on_recycle_bin', dropped_icon_id)
            end
            return { type = "recycle", program_id = dropped_icon_id }
        end
    end

    -- Normal drop: resolve position and update
    local icon_snap = (self.config and self.config.ui and self.config.ui.desktop and self.config.ui.desktop.icon_snap)
    if icon_snap == nil then icon_snap = true end

    local final_x, final_y
    if icon_snap then
        local snapped_x, snapped_y = self:snapToGrid(initial_drop_x, initial_drop_y)
        final_x, final_y = self:resolveDropPosition(dropped_icon_id, snapped_x, snapped_y, screen_w, screen_h)
    else
        final_x, final_y = self:resolveDropPosition(dropped_icon_id, initial_drop_x, initial_drop_y, screen_w, screen_h)
    end

    self.desktop_icons:setPosition(dropped_icon_id, final_x, final_y, screen_w, screen_h)
    self.desktop_icons:save()

    -- Publish event
    if self.event_bus then
        self.event_bus:publish('icon_dropped', dropped_icon_id, final_x, final_y)
    end

    return { type = "drop", program_id = dropped_icon_id, x = final_x, y = final_y }
end

-- Draw dragged icon (if any)
function DesktopIconController:drawDraggedIcon(desktop_view)
    if not self.dragging_icon_id then return end

    local program = self.program_registry:getProgram(self.dragging_icon_id)
    if not program then return end

    local mx, my = love.mouse.getPosition()
    local drag_x = mx - self.drag_offset_x
    local drag_y = my - self.drag_offset_y
    local temp_pos = { x = drag_x, y = drag_y }

    desktop_view:drawIcon(program, true, temp_pos, true) -- Pass dragging flag
end

-- Cancel drag (called when clicking outside icons)
function DesktopIconController:cancelDrag()
    self.last_icon_click_id = nil
    self.dragging_icon_id = nil
end

-- Check if currently dragging
function DesktopIconController:isDragging()
    return self.dragging_icon_id ~= nil
end

-- Find next available grid position for a new icon
function DesktopIconController:findNextAvailablePosition(program_id_to_place, desktop_view)
    local occupied_positions = {} -- Store positions currently in use
    local desktop_programs = self.program_registry:getDesktopPrograms()
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()

    for _, program in ipairs(desktop_programs) do
        -- Consider a spot occupied if the icon is visible and is NOT the one we are currently placing
        if program.id ~= program_id_to_place and self.desktop_icons:isIconVisible(program.id) then
             local pos = self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
             -- Use a simple representation for occupied check (e.g., top-left corner)
             occupied_positions[string.format("%.0f,%.0f", pos.x, pos.y)] = true
        end
    end

    -- Get layout info from desktop_view or use defaults
    local icon_start_x = desktop_view and desktop_view.icon_start_x or 20
    local icon_start_y = desktop_view and desktop_view.icon_start_y or 20
    local icon_padding = desktop_view and desktop_view.icon_padding or 10
    local taskbar_height = desktop_view and desktop_view.taskbar_height or 40

    -- Iterate through default positions in order
    local available_height = love.graphics.getHeight() - taskbar_height - icon_start_y
    local icons_per_column = math.max(1, math.floor(available_height / (icon_h + icon_padding)))
    local col = 0
    local row = 0

    while true do -- Loop until a spot is found (should always find one eventually)
         local potential_x = icon_start_x + col * (icon_w + icon_padding)
         local potential_y = icon_start_y + row * (icon_h + icon_padding)
         local pos_key = string.format("%.0f,%.0f", potential_x, potential_y)

         -- Check if this default grid position is occupied
         if not occupied_positions[pos_key] then
             print("Found available grid position:", potential_x, potential_y)
             return { x = potential_x, y = potential_y }
         end

         -- Move to next grid position
         row = row + 1
         if row >= icons_per_column then
             row = 0
             col = col + 1
             -- Add safety break if columns get too high
             if col > 20 then
                  print("Warning: Could not find free grid slot easily, returning default.")
                  return self:getDefaultIconPosition(program_id_to_place) or { x=20, y=20 }
             end
         end
    end
end
return DesktopIconController
