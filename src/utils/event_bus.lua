-- src/utils/event_bus.lua
-- Simple publish/subscribe event bus

local Object = require('class')
local EventBus = Object:extend('EventBus')

function EventBus:init()
    self.listeners = {}
end

-- Subscribe a callback function to an event
function EventBus:subscribe(event_name, callback)
    if not event_name or not callback then return false end
    self.listeners[event_name] = self.listeners[event_name] or {}
    table.insert(self.listeners[event_name], callback)
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