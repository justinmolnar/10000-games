-- src/states/run_dialog_state.lua
local Object = require('class')
local Strings = require('src.utils.strings')
local RunDialogView = require('src.views.run_dialog_view')

local RunDialogState = Object:extend('RunDialogState')

function RunDialogState:init(di)
    self.di = di
    self.view = RunDialogView:new(di)
    self.viewport = { x = 0, y = 0, width = 400, height = 150 }
    self.text = ""
    -- Parametric behavior
    self.params = {
        -- Make this a generic input dialog by default; callers can override
        title = Strings.get('dialog.input', 'Input'),
        prompt = Strings.get('dialog.enter_value','Enter a value:'),
        ok_label = Strings.get('buttons.ok','OK'),
        cancel_label = Strings.get('buttons.cancel','Cancel'),
        submit_event = 'run_execute',
        context = nil,
    }
    self.view:setParams({ title = self.params.title, prompt = self.params.prompt, ok_label = self.params.ok_label, cancel_label = self.params.cancel_label })
end

function RunDialogState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function RunDialogState:setViewport(x, y, w, h)
    self.viewport = { x = x, y = y, width = w, height = h }
    if self.view and self.view.updateLayout then self.view:updateLayout(w, h) end
end

function RunDialogState:enter(params)
    -- Apply overrides if provided
    if type(params) == 'table' then
        self:setParams(params)
    end
end

-- Allow callers to override title/prompt/buttons/submit_event/context dynamically
function RunDialogState:setParams(params)
    if not params then return end
    -- Merge params
    for k, v in pairs(params) do self.params[k] = v end
    -- Update the view labels
    if self.view and self.view.setParams then
        self.view:setParams({
            title = self.params.title,
            prompt = self.params.prompt,
            ok_label = self.params.ok_label,
            cancel_label = self.params.cancel_label,
        })
    end
    -- Update the window title bar if available
    if self.window_manager and self.window_id and self.params.title then
        pcall(self.window_manager.updateWindowTitle, self.window_manager, self.window_id, self.params.title)
    end
end

function RunDialogState:update(dt)
    if self.view and self.view.update then self.view:update(dt, self.text) end
end

function RunDialogState:draw()
    self.view:drawWindowed(self.text, self.viewport.width, self.viewport.height)
end

function RunDialogState:keypressed(key)
    if key == 'escape' then
        return { type = 'close_window' }
    elseif key == 'return' or key == 'kpenter' then
        return { type = 'event', name = self.params.submit_event or 'run_execute', text = self.text, command = self.text, context = self.params.context }
    elseif key == 'backspace' then
        if self.text and #self.text > 0 then
            self.text = self.text:sub(1, -2)
        end
        return { type = 'content_interaction' }
    end
end

function RunDialogState:textinput(t)
    -- Append character
    self.text = (self.text or "") .. t
    return { type = 'content_interaction' }
end

function RunDialogState:keyreleased(key)
    -- Support backspace deletion in keypressed path (LOVE usually uses keypressed with backspace)
end

function RunDialogState:mousepressed(x, y, button)
    local ev = self.view:mousepressed(x, y, button, self.viewport.width, self.viewport.height)
    if not ev then return { type = 'content_interaction' } end
    if ev.name == 'submit' then
        return { type = 'event', name = self.params.submit_event or 'run_execute', text = self.text, command = self.text, context = self.params.context }
    elseif ev.name == 'cancel' or ev.name == 'run_cancel' then
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

function RunDialogState:handleBackspace()
    if self.text and #self.text > 0 then
        self.text = self.text:sub(1, -2)
    end
end

return RunDialogState