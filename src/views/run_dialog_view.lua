-- src/views/run_dialog_view.lua
local BaseView = require('src.views.base_view')
local UIComponents = require('src.views.ui_components')
local Strings = require('src.utils.strings')

local RunDialogView = BaseView:extend('RunDialogView')

function RunDialogView:init(di)
    -- Note: controller not available at init, will be set by state
    RunDialogView.super.init(self, nil)
    self.di = di
    if di and UIComponents and UIComponents.inject then UIComponents.inject(di) end
    -- Default layout; will be updated by updateLayout
    self.w, self.h = 400, 150
    -- Defaults are generic; callers can override via setParams
    self.title = Strings.get('dialog.input', 'Input')
    self.prompt = Strings.get('dialog.enter_value','Enter a value:')
    self.ok_label = Strings.get('buttons.ok','OK')
    self.cancel_label = Strings.get('buttons.cancel','Cancel')
end

function RunDialogView:updateLayout(w, h)
    self.w, self.h = w, h
end

function RunDialogView:update(dt, text)
    -- no dynamic behavior yet
end

function RunDialogView:setParams(params)
    if not params then return end
    if params.title then self.title = params.title end
    if params.prompt then self.prompt = params.prompt end
    if params.ok_label then self.ok_label = params.ok_label end
    if params.cancel_label then self.cancel_label = params.cancel_label end
end

-- Override BaseView's drawWindowed to pass extra parameters
function RunDialogView:drawWindowed(text, w, h)
    self.draw_params = { text = text }
    RunDialogView.super.drawWindowed(self, w, h)
end

-- Implements BaseView's abstract drawContent method
function RunDialogView:drawContent(w, h)
    local text = self.draw_params.text
    local desktop_cfg = (self.di and self.di.config and self.di.config.ui and self.di.config.ui.desktop) or {}
    local run_cfg = desktop_cfg.run_dialog or {}
    local pad = run_cfg.padding or 10
    local input_y = run_cfg.input_y or 40
    local input_h = run_cfg.input_h or 25
    local btns = run_cfg.buttons or {}
    local colors = (self.di and self.di.config and self.di.config.ui and self.di.config.ui.colors and self.di.config.ui.colors.run_dialog) or {}

    -- Content background
    love.graphics.setColor(colors.bg or {0.8, 0.8, 0.8})
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Content
    love.graphics.setColor(colors.label_text or {0, 0, 0})
    love.graphics.print(self.prompt, pad, 12)

    love.graphics.setColor(colors.input_bg or {1, 1, 1})
    love.graphics.rectangle('fill', pad, input_y, w - 2 * pad, input_h)
    love.graphics.setColor(colors.input_border or {0, 0, 0})
    love.graphics.rectangle('line', pad, input_y, w - 2 * pad, input_h)
    love.graphics.setColor(colors.input_text or {0, 0, 0})
    love.graphics.print(text or "", pad + 5, input_y + 5)

    UIComponents.drawButton(w - (btns.ok_offset_x or 180), h - (btns.bottom_margin or 40), btns.ok_w or 80, btns.ok_h or 30, self.ok_label or Strings.get('buttons.ok','OK'), true, false)
    UIComponents.drawButton(w - (btns.cancel_offset_x or 90), h - (btns.bottom_margin or 40), btns.cancel_w or 80, btns.cancel_h or 30, self.cancel_label or Strings.get('buttons.cancel','Cancel'), true, false)
end

function RunDialogView:mousepressed(x, y, button, w, h)
    if button ~= 1 then return nil end
    local desktop_cfg = (self.di and self.di.config and self.di.config.ui and self.di.config.ui.desktop) or {}
    local run_cfg = desktop_cfg.run_dialog or {}
    local buttons = run_cfg.buttons or {}
    local ok_x = w - (buttons.ok_offset_x or 180)
    local ok_y = h - (buttons.bottom_margin or 40)
    if x >= ok_x and x <= ok_x + (buttons.ok_w or 80) and y >= ok_y and y <= ok_y + (buttons.ok_h or 30) then return {name = 'submit'} end

    local cancel_x = w - (buttons.cancel_offset_x or 90)
    local cancel_y = h - (buttons.bottom_margin or 40)
    if x >= cancel_x and x <= cancel_x + (buttons.cancel_w or 80) and y >= cancel_y and y <= cancel_y + (buttons.cancel_h or 30) then return {name = 'cancel'} end

    return nil
end

return RunDialogView