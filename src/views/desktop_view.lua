-- src/views/desktop_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local Strings = require('src.utils.strings')
local DesktopView = Object:extend('DesktopView')
local Wallpapers = require('src.utils.wallpapers')

function DesktopView:init(program_registry, player_data, window_manager, desktop_icons, recycle_bin, di)
    -- Optional DI for views: forward to UIComponents and allow DI Config/Strings
    self.di = di
    if di then UIComponents.inject(di) end
    self.config = (di and di.config) or {}
    local Strings_ = (di and di.strings) or Strings
    self.program_registry = program_registry
    self.player_data = player_data
    self.window_manager = window_manager
    self.desktop_icons = desktop_icons -- Injected
    self.recycle_bin = recycle_bin -- Injected
    self.file_system = (di and di.fileSystem) or nil
    self.sprite_loader = (di and di.spriteLoader) or nil

    -- Taskbar moved to TaskbarView/TaskbarController
    local taskbar_cfg = (self.config and self.config.ui and self.config.ui.taskbar) or {}
    self.taskbar_height = taskbar_cfg.height or 40  -- Still needed for icon layout calculations

    -- Hover state
    self.hovered_program_id = nil
    self.hovered_start_program_id = nil

    -- Icon layout defaults (dimensions from model now)
    self.icon_width, self.icon_height = self.desktop_icons:getIconDimensions()
    local desktop_cfg = (self.config and self.config.ui and self.config.ui.desktop) or {}
    local grid_cfg = desktop_cfg.grid or {}
    self.icon_padding = grid_cfg.icon_padding or 20
    self.icon_start_x = grid_cfg.start_x or 20
    self.icon_start_y = grid_cfg.start_y or 20
    self.default_icon_positions = {} -- Cache default grid positions

    self:calculateDefaultIconPositionsIfNeeded() -- Calculate defaults once

    -- Start Menu UI is handled by StartMenuView (geometry/state removed from DesktopView)

    -- Legacy inline Run overlay removed (Run is a proper window now)

end

-- Calculate default grid positions if needed
function DesktopView:calculateDefaultIconPositionsIfNeeded()
    local desktop_programs = self.program_registry:getDesktopPrograms()
    if #desktop_programs == #self.default_icon_positions then return end -- Assume up to date

    self.default_icon_positions = {} -- Recalculate

    local available_height = love.graphics.getHeight() - self.taskbar_height - self.icon_start_y
    local icons_per_column = math.max(1, math.floor(available_height / (self.icon_height + self.icon_padding)))

    local col = 0
    local row = 0

    for _, program in ipairs(desktop_programs) do
        -- Store default position associated with program ID
        self.default_icon_positions[program.id] = {
            x = self.icon_start_x + col * (self.icon_width + self.icon_padding),
            y = self.icon_start_y + row * (self.icon_height + self.icon_padding)
        }

        row = row + 1
        if row >= icons_per_column then
            row = 0
            col = col + 1
        end
    end
end

-- Get the default position for an icon
function DesktopView:getDefaultIconPosition(program_id)
    return self.default_icon_positions[program_id] or { x = self.icon_start_x, y = self.icon_start_y } -- Fallback
end


function DesktopView:update(dt, start_menu_open, dragging_icon_id)
    -- Clock update moved to TaskbarController

    -- Update hover states (mouse position relative to screen)
    local mx, my = love.mouse.getPosition()
    self.hovered_program_id = self:getProgramAtPosition(mx, my)
end

-- Clear any pending pressed item in the Start Menu (used when menu opens)
-- Start Menu press handling removed from DesktopView

function DesktopView:draw(wallpaper, tokens, start_menu_open, dragging_icon_id)
    -- Draw wallpaper: either color or image
    if type(wallpaper) == 'table' and wallpaper.type == 'image' and wallpaper.id then
        -- Fill with a fallback color first
        local c = wallpaper.color or {0,0,0}
        love.graphics.setColor(c)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        -- Then draw image using selected scaling mode
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local mode = wallpaper.scale_mode or 'fill'
        local ok = false
        if mode == 'fill' then ok = Wallpapers.drawCover(wallpaper.id, 0, 0, sw, sh)
        elseif mode == 'fit' then ok = Wallpapers.drawFit(wallpaper.id, 0, 0, sw, sh)
        elseif mode == 'stretch' then ok = Wallpapers.drawStretch(wallpaper.id, 0, 0, sw, sh)
        elseif mode == 'center' then ok = Wallpapers.drawCenter(wallpaper.id, 0, 0, sw, sh)
        elseif mode == 'tile' then ok = Wallpapers.drawTile(wallpaper.id, 0, 0, sw, sh)
        end
        if not ok then
            -- fallback to solid color if image unavailable
            love.graphics.setColor(wallpaper.color or {0,0,0})
            love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        end
    else
        love.graphics.setColor(wallpaper)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- Draw desktop icons based on model data
    local desktop_programs = self.program_registry:getDesktopPrograms()
    for _, program in ipairs(desktop_programs) do
        -- Check if deleted
        if not self.desktop_icons:isDeleted(program.id) then
            -- Check if currently being dragged
            if program.id ~= dragging_icon_id then
                local pos = self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
                self:drawIcon(program, program.id == self.hovered_program_id, pos)
            end
             -- The dragged icon itself is drawn separately in DesktopState:draw
        end
    end

    -- Taskbar drawing moved to TaskbarController

    -- Start Menu drawing handled by StartMenuView

    -- Run dialog is now a proper program window; nothing to draw here.
end

function DesktopView:drawIcon(program, hovered, position_override, is_dragging)
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    if not sprite_loader then
        error("DesktopView: sprite_loader not available in DI")
    end

    local pos = position_override or self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
    local px = pos.x
    local py = pos.y
    local pw, ph = self.desktop_icons:getIconDimensions()

    local desktop_cfg = (self.config and self.config.ui and self.config.ui.desktop) or {}
    local icons_cfg = desktop_cfg.icons or {}
    local base_alpha = is_dragging and 0.6 or 1.0

    -- Icon area
    local icon_size = icons_cfg.sprite_size or 48
    local icon_x = px + (pw - icon_size) / 2
    local icon_y = py + (icons_cfg.sprite_offset_y or 10)
    
    -- Draw icon sprite or fallback
    local sprite_name = program.icon_sprite
    local tint = {1, 1, 1, base_alpha}
    
    if hovered then
        tint = {icons_cfg.hover_tint or 1.2, icons_cfg.hover_tint or 1.2, icons_cfg.hover_tint or 1.2, base_alpha}
    end
    
    -- Special handling for Recycle Bin state
    if program.id == "recycle_bin" then
        local isEmpty = self.recycle_bin:isEmpty()
        sprite_name = isEmpty and "recycle_bin_empty-0" or "recycle_bin_full-0"
    end
    
    sprite_loader:drawSprite(sprite_name, icon_x, icon_y, icon_size, icon_size, tint)
    
    -- Recycle bin fullness indicator
    if program.id == "recycle_bin" and not self.recycle_bin:isEmpty() then
        local ind = icons_cfg.recycle_indicator or {}
        love.graphics.setColor(1, 1, 0, base_alpha)
        love.graphics.circle('fill', icon_x + icon_size - (ind.offset_x or 5), icon_y + (ind.offset_y or 5), ind.radius or 4)
    end

    -- Label background and text
    love.graphics.setColor(1, 1, 1, base_alpha)
    local label_y = icon_y + icon_size + (icons_cfg.label_margin_top or 5)
    local font = love.graphics.getFont()
    local text_width = font:getWidth(program.name)
    local label_x = px + (pw - text_width) / 2

    love.graphics.setColor(0, 0, 0, 0.5 * base_alpha)
    love.graphics.rectangle('fill', label_x - (icons_cfg.label_padding_x or 2), label_y - (icons_cfg.label_padding_y or 1), text_width + 2 * (icons_cfg.label_padding_x or 2), font:getHeight() + 2 * (icons_cfg.label_padding_y or 1))
    love.graphics.setColor(1, 1, 1, base_alpha)
    love.graphics.print(program.name, label_x, label_y)

    -- Disabled overlay
    if program.disabled then
        love.graphics.setColor(0, 0, 0, (icons_cfg.disabled_overlay_alpha or 0.5) * base_alpha)
        love.graphics.rectangle('fill', px, py, pw, ph)
    end
end

function DesktopView:mousepressed(x, y, button)
     -- Only needed for initial click detection before state takes over
     if button ~= 1 then return nil end

    -- Check start button
    if self:isStartButtonHovered(x, y) then
        return {name = "start_button_click"} -- Let state handle toggling menu
    end

    -- Check desktop icons (return ID for state to handle drag/launch)
    local program_id = self:getProgramAtPosition(x, y)
    if program_id then
        return {name = "icon_click", program_id = program_id}
    end

    -- Taskbar button clicks are handled directly in DesktopState using getTaskbarButtonAtPosition

    return nil -- Clicked on empty space
end

-- Start Menu mouse handlers moved to StartMenuView


-- Get program at position using model data
function DesktopView:getProgramAtPosition(x, y)
    -- Retained for compatibility; the state now uses DesktopIconController for logic
    local desktop_programs = self.program_registry:getDesktopPrograms()
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()
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


-- Start Menu program hit-test moved to StartMenuView

    -- Helper to check if a point is within the Start Menu bounds
    -- Start Menu bounds checks moved to StartMenuView

    -- Get Recycle Bin icon position (needed for drop detection)
    function DesktopView:getRecycleBinPosition()
        local program = self.program_registry:getProgram("recycle_bin")
        if not program or self.desktop_icons:isDeleted("recycle_bin") then return nil end
        local pos = self.desktop_icons:getPosition("recycle_bin") or self:getDefaultIconPosition("recycle_bin")
        local w, h = self.desktop_icons:getIconDimensions()
        return { x = pos.x, y = pos.y, w = w, h = h }
    end

-- Taskbar functions moved to TaskbarView/TaskbarController

-- Start Menu keyboard selection handled by StartMenuView

-- Determine which main Start Menu item is hovered
-- Start Menu main item hit-test moved to StartMenuView

-- Start Menu submenu bounds moved to StartMenuView

-- Start Menu submenu hit-test moved to StartMenuView

-- Start Menu legacy submenu rendering moved to StartMenuView
return DesktopView