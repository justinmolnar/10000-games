-- src/views/message_box_view.lua
-- Win98-styled message box dialog view
local BaseView = require('src.views.base_view')
local UIComponents = require('src.views.ui_components')
local ThemeManager = require('src.utils.theme_manager')

local MessageBoxView = BaseView:extend('MessageBoxView')

function MessageBoxView:init(di)
    MessageBoxView.super.init(self, nil)
    self.di = di
    if di and UIComponents and UIComponents.inject then UIComponents.inject(di) end
    self.sprite_loader = (di and di.spriteLoader) or nil

    self.title = "Message"
    self.message = ""
    self.icon_type = "info"  -- "info", "warning", "error"
    self.button_labels = {"OK"}
    self.buttons = {}
    self.hovered_button = nil
    self.viewport = { w = 360, h = 180 }

    self.icon_map = {
        info = "msg_information-0",
        warning = "msg_warning-0",
        error = "msg_error-0",
    }
    self.icon_size = 32
end

function MessageBoxView:configure(params)
    self.title = params.title or "Message"
    self.message = params.message or ""
    self.icon_type = params.icon_type or "info"
    self.button_labels = params.buttons or {"OK"}
    self:updateLayout(self.viewport.w, self.viewport.h)
end

function MessageBoxView:updateLayout(w, h)
    self.viewport.w = w
    self.viewport.h = h

    local btn_w = 80
    local btn_h = 26
    local spacing = 8
    local right_margin = 12
    local bottom_margin = 12

    self.buttons = {}
    local count = #self.button_labels
    local total_w = count * btn_w + (count - 1) * spacing
    local bx = math.max(12, w - right_margin - total_w)
    local by = h - bottom_margin - btn_h

    for i, label in ipairs(self.button_labels) do
        self.buttons[i] = {
            x = bx + (i - 1) * (btn_w + spacing),
            y = by,
            w = btn_w,
            h = btn_h,
            label = label,
        }
    end
end

function MessageBoxView:drawContent(w, h)
    -- Background
    local mb = ThemeManager.getSection("message_box") or {}
    love.graphics.setColor(mb.bg or {0.75, 0.75, 0.75})
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Icon
    local icon_x = 14
    local icon_y = 14
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    local icon_name = self.icon_map[self.icon_type] or self.icon_map.info
    if sprite_loader then
        sprite_loader:drawSprite(icon_name, icon_x, icon_y, self.icon_size, self.icon_size, {1, 1, 1})
    end

    -- Message text (word-wrapped)
    local text_x = icon_x + self.icon_size + 12
    local text_y = 14
    local text_w = w - text_x - 12
    local btn_top = (#self.buttons > 0) and self.buttons[1].y or (h - 40)
    love.graphics.setColor(mb.text or {0, 0, 0})
    local display_msg = self.message
    if self.countdown and self.countdown > 0 then
        display_msg = display_msg .. "\n\nReverting in " .. self.countdown .. "s..."
    end
    love.graphics.printf(display_msg, text_x, text_y, text_w, "left")

    -- Separator line above buttons
    local sep_y = btn_top - 8
    love.graphics.setColor(mb.button_shadow or {0.6, 0.6, 0.6})
    love.graphics.line(8, sep_y, w - 8, sep_y)
    love.graphics.setColor(mb.button_highlight or {1, 1, 1})
    love.graphics.line(8, sep_y + 1, w - 8, sep_y + 1)

    -- Draw buttons with Win98 3D raised style
    for i, b in ipairs(self.buttons) do
        local hovered = (self.hovered_button == i)
        self:drawWin98Button(b.x, b.y, b.w, b.h, b.label, hovered)
    end
end

function MessageBoxView:drawWin98Button(x, y, w, h, label, hovered)
    local mb = ThemeManager.getSection("message_box") or {}
    -- Face
    if hovered then
        love.graphics.setColor(mb.button_bg_hover or {0.8, 0.8, 0.8})
    else
        love.graphics.setColor(mb.button_bg or {0.75, 0.75, 0.75})
    end
    love.graphics.rectangle('fill', x, y, w, h)

    -- 3D raised borders: top-left highlight, bottom-right shadow
    love.graphics.setColor(mb.button_highlight or {1, 1, 1})
    love.graphics.line(x, y, x + w - 1, y)          -- top
    love.graphics.line(x, y, x, y + h - 1)          -- left
    love.graphics.setColor(mb.button_shadow or {0.5, 0.5, 0.5})
    love.graphics.line(x + w - 1, y, x + w - 1, y + h - 1)  -- right
    love.graphics.line(x, y + h - 1, x + w - 1, y + h - 1)  -- bottom
    love.graphics.setColor(mb.button_shadow_outer or {0.35, 0.35, 0.35})
    love.graphics.line(x + w, y, x + w, y + h)      -- outer right
    love.graphics.line(x, y + h, x + w, y + h)      -- outer bottom

    -- Label centered
    love.graphics.setColor(mb.text or {0, 0, 0})
    local font = love.graphics.getFont()
    local tw = font:getWidth(label)
    local th = font:getHeight()
    love.graphics.print(label, x + math.floor((w - tw) / 2), y + math.floor((h - th) / 2))
end

function MessageBoxView:mousemoved(x, y, w, h)
    self.hovered_button = nil
    for i, b in ipairs(self.buttons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            self.hovered_button = i
            break
        end
    end
end

function MessageBoxView:mousepressed(x, y, button, w, h)
    if button ~= 1 then return nil end
    if w and h then self:updateLayout(w, h) end
    for i, b in ipairs(self.buttons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return { name = 'button_clicked', index = i, label = b.label }
        end
    end
    return nil
end

return MessageBoxView
