-- src/states/solitaire_settings_state.lua
local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')
local View = require('src.views.solitaire_settings_view')

local State = Object:extend('SolitaireSettingsState')

function State:init(window_controller, di)
    self.window_controller = window_controller
    self.di = di
    self.view = View:new(self, di)
    self.viewport = nil
    self.pending = {}
    self.current = {}
end

function State:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
    if self.view.updateLayout then self.view:updateLayout(w, h) end
end

function State:enter()
    -- Pull current settings into local map (with defaults derived from game options)
    local s = SettingsManager.getAll()
    self.current = {
        solitaire_draw_count = s.solitaire_draw_count or 1,
        solitaire_redeal_limit = s.solitaire_redeal_limit or 'infinite',
        solitaire_empty_any = (s.solitaire_empty_any ~= false) and (s.solitaire_empty_any == true or s.solitaire_empty_any == 1),
        solitaire_card_back = s.solitaire_card_back
    }
    self.pending = {}
end

function State:update(dt)
    -- If another window updated the card back (picker), reflect it live
    local s = SettingsManager.getAll()
    if s.solitaire_card_back ~= self.current.solitaire_card_back then
        self.current.solitaire_card_back = s.solitaire_card_back
    end
    if self.view.update then self.view:update(dt) end
end

function State:draw()
    if not self.viewport then return end
    self.view:drawWindowed(self.viewport.width, self.viewport.height)
end

function State:keypressed(key)
    if key == 'escape' then return { type = 'close_window' } end
    return false
end

function State:mousepressed(x, y, button)
    local ev = self.view:mousepressed(x, y, button)
    return self:_handleEvent(ev)
end

function State:mousereleased(x, y, button)
    local ev = self.view:mousereleased(x, y, button)
    return self:_handleEvent(ev)
end

function State:mousemoved(x, y, dx, dy)
    if self.view.mousemoved then self.view:mousemoved(x, y, dx, dy) end
end

function State:handle_event(ev)
    return self:_handleEvent(ev)
end

function State:_handleEvent(ev)
    if not ev then return false end
    if ev.name == 'set_pending' then
        self.pending[ev.id] = ev.value
        return { type = 'content_interaction' }
    elseif ev.name == 'open_back_picker' then
        -- Launch a small modal to pick a back; use program registry if present, else ad-hoc
        return { type = 'event', name = 'launch_program', program_id = 'solitaire_back_picker' }
    elseif ev.name == 'apply' then
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.current[k] = v end
        SettingsManager.save()
        self.pending = {}
        -- Notify solitaire state (if provided) that options changed
        if self.on_applied then pcall(self.on_applied, self.current) end
        return { type = 'content_interaction' }
    elseif ev.name == 'ok' then
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.current[k] = v end
        SettingsManager.save()
        self.pending = {}
        if self.on_applied then pcall(self.on_applied, self.current) end
        return { type = 'close_window' }
    elseif ev.name == 'cancel' then
        self.pending = {}
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

-- Interface required by view
function State:get_value(id)
    local v = self.pending[id]; if v == nil then v = self.current[id] end; return v
end

function State:has_pending()
    return next(self.pending) ~= nil
end

return State
