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

    self.default_icon_positions = {}
    self.grid_cfg = (((di and di.config and di.config.ui and di.config.ui.desktop) or {}).grid) or {}
    self.taskbar_height = (((di and di.config and di.config.ui and di.config.ui.taskbar) or {}).height) or 40
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

return DesktopIconController
