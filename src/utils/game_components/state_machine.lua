local Object = require('class')
local StateMachine = Object:extend('StateMachine')

--[[
    Generic State Machine Component

    Manages state transitions with tic-based timing. Completely agnostic to
    what states mean - games define behavior via callbacks.

    Usage:
        local sm = StateMachine:new({
            states = {
                stand = { duration = 0 },                    -- 0 = infinite
                pain = { duration = 10, next = "chase" },    -- auto-transition after 10 tics
                shoot = { duration = 30, next = "chase", interruptible = false },
                dead = { duration = 0 },                     -- terminal state
            },
            initial = "stand",
            on_enter = function(new_state, old_state) end,
            on_exit = function(old_state, new_state) end,
            on_update = function(state, tics_in_state) end,
        })

        -- In fixed update (1 tic per call at 60fps):
        sm:update(1)

        -- Force transitions:
        sm:setState("pain")      -- respects interruptible
        sm:forceState("die")     -- ignores interruptible

        -- Query:
        sm:getState()            -- current state name
        sm:getTics()             -- tics in current state
]]

function StateMachine:new(config)
    local instance = StateMachine.super.new(self)

    instance.states = config.states or {}
    instance.state = config.initial or next(instance.states)
    instance.tics = 0

    instance.on_enter = config.on_enter
    instance.on_exit = config.on_exit
    instance.on_update = config.on_update

    return instance
end

function StateMachine:update(tics)
    tics = tics or 1
    self.tics = self.tics + tics

    local state_def = self.states[self.state]
    if not state_def then return false end

    -- Check for auto-transition
    local changed = false
    if state_def.duration and state_def.duration > 0 and self.tics >= state_def.duration then
        if state_def.next then
            changed = self:_transition(state_def.next)
        end
    end

    -- Call update callback
    if self.on_update then
        self.on_update(self.state, self.tics)
    end

    return changed
end

function StateMachine:setState(new_state)
    if new_state == self.state then return false end
    if not self.states[new_state] then return false end

    local current_def = self.states[self.state]
    if current_def and current_def.interruptible == false then
        return false
    end

    return self:_transition(new_state)
end

function StateMachine:forceState(new_state)
    if new_state == self.state then return false end
    if not self.states[new_state] then return false end

    return self:_transition(new_state)
end

function StateMachine:_transition(new_state)
    local old_state = self.state

    if self.on_exit then
        self.on_exit(old_state, new_state)
    end

    self.state = new_state
    self.tics = 0

    if self.on_enter then
        self.on_enter(new_state, old_state)
    end

    return true
end

function StateMachine:getState()
    return self.state
end

function StateMachine:getTics()
    return self.tics
end

function StateMachine:getStateDef()
    return self.states[self.state]
end

return StateMachine
