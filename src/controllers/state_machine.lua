-- state_machine.lua: Simple state machine implementation

local function StateMachineBuilder(Object)
    local StateMachine = Object:extend('StateMachine')

    function StateMachine:init()
        self.states = {}
        self.current_state = nil
    end

    function StateMachine:register(state_name, state_object)
        self.states[state_name] = state_object
    end

    function StateMachine:switch(state_name, ...)
        if self.states[state_name] then
            self.current_state = self.states[state_name]
            if self.current_state.enter then
                self.current_state:enter(...)
            end
        end
    end

    function StateMachine:update(dt)
        if self.current_state and self.current_state.update then
            self.current_state:update(dt)
        end
    end

    function StateMachine:draw()
        if self.current_state and self.current_state.draw then
            self.current_state:draw()
        end
    end

    function StateMachine:keypressed(key)
        if self.current_state and self.current_state.keypressed then
            self.current_state:keypressed(key)
        end
    end

    function StateMachine:mousepressed(x, y, button)
        if self.current_state and self.current_state.mousepressed then
            self.current_state:mousepressed(x, y, button)
        end
    end

    -- ADDED: Forward mousemoved event
    function StateMachine:mousemoved(x, y, dx, dy)
        if self.current_state and self.current_state.mousemoved then
            self.current_state:mousemoved(x, y, dx, dy)
        end
    end

    -- ADDED: Forward mousereleased event (Ensuring it exists)
    function StateMachine:mousereleased(x, y, button)
        if self.current_state and self.current_state.mousereleased then
            self.current_state:mousereleased(x, y, button)
        end
    end

    -- ADDED: Forward textinput event (Ensuring it exists)
    function StateMachine:textinput(text)
         if self.current_state and self.current_state.textinput then
            self.current_state:textinput(text)
        end
    end

     -- ADDED: Forward wheelmoved event (Ensuring it exists)
    function StateMachine:wheelmoved(x, y)
        if self.current_state and self.current_state.wheelmoved then
            self.current_state:wheelmoved(x, y)
        end
    end

    return StateMachine
end

return StateMachineBuilder