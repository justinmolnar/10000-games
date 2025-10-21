-- src/views/shutdown_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local Strings = require('src.utils.strings')
local SpriteLoader = require('src.utils.sprite_loader')

local ShutdownView = Object:extend('ShutdownView')

function ShutdownView:init(di)
    self.di = di
    if di and UIComponents and UIComponents.inject then UIComponents.inject(di) end
    self.title = Strings.get('shutdown.title', 'Shut Down Windows')
    self.prompt = Strings.get('shutdown.prompt', 'What do you want the computer to do?')
    self.buttons = {
        shutdown = { w = 110, h = 28, x = 0, y = 0, label = Strings.get('shutdown.buttons.shutdown','Shut down') },
        restart = { w = 90, h = 28, x = 0, y = 0, label = Strings.get('shutdown.buttons.restart','Restart') },
        cancel = { w = 90, h = 28, x = 0, y = 0, label = Strings.get('shutdown.buttons.cancel','Cancel') },
    }
    self.viewport = { w = 300, h = 180 }
    self.icon_name = 'conn_pcs_off_off'
    self.icon_size = 48
end

function ShutdownView:updateLayout(w, h)
    self.viewport.w = w; self.viewport.h = h
    -- Button layout: right-aligned row
    local spacing = 10
    local right_margin, bottom_margin = 16, 16
    local total_w = self.buttons.shutdown.w + self.buttons.restart.w + self.buttons.cancel.w + spacing * 2
    local bx = math.max(16, w - right_margin - total_w)
    local by = h - bottom_margin - self.buttons.shutdown.h
    self.buttons.shutdown.x = bx; self.buttons.shutdown.y = by
    self.buttons.restart.x = bx + self.buttons.shutdown.w + spacing; self.buttons.restart.y = by
    self.buttons.cancel.x = self.buttons.restart.x + self.buttons.restart.w + spacing; self.buttons.cancel.y = by
end

function ShutdownView:update(dt)
    -- No dynamic behavior needed currently
end

function ShutdownView:drawWindowed(w, h)
    -- Content background
    local colors = (self.di and self.di.config and self.di.config.ui and self.di.config.ui.colors and self.di.config.ui.colors.shutdown_dialog) or {}
    love.graphics.setColor(colors.bg or {0.8, 0.8, 0.8})
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Icon and prompt
    local icon_x = 16
    local icon_y = 44
    local sprite_loader = SpriteLoader.getInstance()
    sprite_loader:drawSprite(self.icon_name, icon_x, icon_y, self.icon_size, self.icon_size, {1,1,1})

    love.graphics.setColor(colors.text or {0, 0, 0})
    love.graphics.print(self.prompt, icon_x + self.icon_size + 12, icon_y + 12)

    -- Draw buttons
    for key, b in pairs(self.buttons) do
        local hovered = false -- Keep simple for now
        UIComponents.drawButton(b.x, b.y, b.w, b.h, b.label, true, hovered)
    end
end

function ShutdownView:mousepressed(x, y, button, w, h)
    if button ~= 1 then return nil end
    -- Ensure layout is current
    if (w and h) then self:updateLayout(w, h) end
    local b = self.buttons
    if x >= b.shutdown.x and x <= b.shutdown.x + b.shutdown.w and y >= b.shutdown.y and y <= b.shutdown.y + b.shutdown.h then
        return { name = 'shutdown_now' }
    end
    if x >= b.restart.x and x <= b.restart.x + b.restart.w and y >= b.restart.y and y <= b.restart.y + b.restart.h then
        return { name = 'restart_now' }
    end
    if x >= b.cancel.x and x <= b.cancel.x + b.cancel.w and y >= b.cancel.y and y <= b.cancel.y + b.cancel.h then
        return { name = 'cancel' }
    end
    return nil
end

return ShutdownView
