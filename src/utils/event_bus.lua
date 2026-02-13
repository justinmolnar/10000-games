-- src/utils/event_bus.lua
-- Simple publish/subscribe event bus

local Object = require('class')
local EventBus = Object:extend('EventBus')

function EventBus:init()
    self.listeners = {}
    self._next_id = 1
    self._id_map = {}  -- id -> {event_name, callback}
end

-- Subscribe a callback function to an event
-- Returns a subscription ID that can be passed to unsubscribe()
function EventBus:subscribe(event_name, callback)
    if not event_name or not callback then return nil end
    self.listeners[event_name] = self.listeners[event_name] or {}
    table.insert(self.listeners[event_name], callback)

    local id = self._next_id
    self._next_id = id + 1
    self._id_map[id] = {event_name = event_name, callback = callback}
    return id
end

-- Remove a subscription by the ID returned from subscribe()
function EventBus:unsubscribe(id)
    local entry = self._id_map[id]
    if not entry then return false end

    local list = self.listeners[entry.event_name]
    if list then
        for i, cb in ipairs(list) do
            if cb == entry.callback then
                table.remove(list, i)
                break
            end
        end
    end

    self._id_map[id] = nil
    return true
end

-- Publish an event to all subscribers
function EventBus:publish(event_name, ...)
    if not event_name or not self.listeners[event_name] then return end

    -- Iterate over a copy in case a callback unsubscribes
    local subscribers = {}
    for _, cb in ipairs(self.listeners[event_name]) do
        table.insert(subscribers, cb)
    end

    for _, callback in ipairs(subscribers) do
        local ok, err = pcall(callback, ...)
        if not ok then
            print("ERROR in EventBus subscriber for '" .. event_name .. "': " .. tostring(err))
        end
    end
end

return EventBus