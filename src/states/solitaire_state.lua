-- src/states/solitaire_state.lua
local Object = require('class')
local SolitaireView = require('src.views.solitaire_view')
local SolitaireSave = require('src.utils.solitaire_save')

local SolitaireState = Object:extend('SolitaireState')

function SolitaireState:init(di)
    self.di = di
    self.view = SolitaireView:new(self)
    self.viewport = nil
end

function SolitaireState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function SolitaireState:setViewport(x, y, w, h)
    self.viewport = { x = x, y = y, width = w, height = h }
    if self.view and self.view.setViewport then
        self.view:setViewport(x, y, w, h)
    end
end

function SolitaireState:enter()
    -- No dependencies, no tokens; this is a standalone app
    if self.view and self.view.enter then self.view:enter() end
    -- Try loading persisted state
    if self.view and self.view.loadSnapshot then
        local data = SolitaireSave.load()
        if data then pcall(self.view.loadSnapshot, self.view, data) end
    end
end

function SolitaireState:update(dt)
    if self.view and self.view.update then self.view:update(dt) end
end

function SolitaireState:draw()
    if self.view and self.view.draw then self.view:draw() end
end

function SolitaireState:keypressed(key)
    if self.view and self.view.keypressed then return self.view:keypressed(key) end
    return false
end

function SolitaireState:mousepressed(x, y, button)
    if self.view and self.view.mousepressed then return self.view:mousepressed(x, y, button) end
    return { type = "content_interaction" }
end

function SolitaireState:mousemoved(x, y, dx, dy)
    if self.view and self.view.mousemoved then self.view:mousemoved(x, y, dx, dy) end
end

function SolitaireState:mousereleased(x, y, button)
    if self.view and self.view.mousereleased then return self.view:mousereleased(x, y, button) end
    return false
end

function SolitaireState:leave()
    -- Persist state on leave
    if self.view and self.view.getSnapshot then
        local ok, snapshot = pcall(self.view.getSnapshot, self.view)
        if ok and snapshot then SolitaireSave.save(snapshot) end
    end
end

return SolitaireState
