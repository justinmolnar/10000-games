local Object = require('class')
local LauncherState = Object:extend('LauncherState')

function LauncherState:init()
    self.games = {
        {
            id = 'space_shooter',
            name = 'Space Shooter',
            class_name = 'SpaceShooter',
            description = 'Shoot enemies, don\'t die',
            difficulty = 1,
            variant = 1,
            metrics_tracked = {'kills', 'deaths'},
            difficulty_modifiers = {
                speed = 1,
                count = 1,
                complexity = 1
            },
            variant_multiplier = 1
        },
        {
            id = 'snake_game',
            name = 'Snake',
            class_name = 'SnakeGame',
            description = 'Eat food, grow longer',
            difficulty = 1,
            variant = 1,
            metrics_tracked = {'snake_length', 'survival_time'},
            difficulty_modifiers = {
                speed = 1,
                count = 1,
                complexity = 1
            },
            variant_multiplier = 1
        },
        {
            id = 'memory_match',
            name = 'Memory Match',
            class_name = 'MemoryMatch',
            description = 'Match pairs of cards',
            difficulty = 1,
            variant = 1,
            metrics_tracked = {'matches_found', 'time_taken', 'perfect_matches'},
            difficulty_modifiers = {
                speed = 1,
                count = 1,
                complexity = 1
            },
            variant_multiplier = 1
        },
        {
            id = 'dodge_game',
            name = 'Dodge',
            class_name = 'DodgeGame',
            description = 'Dodge incoming objects',
            difficulty = 1,
            variant = 1,
            metrics_tracked = {'objects_dodged', 'collisions', 'perfect_dodges'},
            difficulty_modifiers = {
                speed = 1,
                count = 1,
                complexity = 1
            },
            variant_multiplier = 1
        },
        {
            id = 'hidden_object',
            name = 'Hidden Object',
            class_name = 'HiddenObject',
            description = 'Find hidden objects quickly',
            difficulty = 1,
            variant = 1,
            metrics_tracked = {'objects_found', 'time_bonus'},
            difficulty_modifiers = {
                speed = 1,
                count = 1,
                complexity = 1
            },
            variant_multiplier = 1
        }
    }
    
    self.selected_index = 1
    self.button_height = 50
    self.button_padding = 10
end

function LauncherState:update(dt)
    -- No update logic needed yet
end

function LauncherState:draw()
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Game Launcher', 10, 10, 0, 2, 2)
    
    -- Draw game buttons
    for i, game in ipairs(self.games) do
        local y = 60 + (i-1) * (self.button_height + self.button_padding)
        
        -- Button background
        if i == self.selected_index then
            love.graphics.setColor(0.3, 0.3, 0.8)
        else
            love.graphics.setColor(0.2, 0.2, 0.2)
        end
        love.graphics.rectangle('fill', 10, y, 300, self.button_height)
        
        -- Button text
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(game.name, 20, y + 10)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(game.description, 20, y + 30, 0, 0.8, 0.8)
    end
    
    -- Draw instructions
    love.graphics.setColor(0.7, 0.7, 0.7)
    local instructions = {
        "Up/Down: Select game",
        "Enter/Space: Start game",
        "ESC: Quit"
    }
    local base_y = 60 + #self.games * (self.button_height + self.button_padding)
    for i, instruction in ipairs(instructions) do
        love.graphics.print(instruction, 10, base_y + i * 20)
    end
end

function LauncherState:keypressed(key)
    if key == 'up' then
        self.selected_index = math.max(1, self.selected_index - 1)
    elseif key == 'down' then
        self.selected_index = math.min(#self.games, self.selected_index + 1)
    elseif key == 'return' or key == 'space' then
        local selected_game = self.games[self.selected_index]
        if selected_game then
            -- Switch to minigame state with ALL game data
            self.state_machine:switch('minigame', selected_game)
        end
    end
end

function LauncherState:mousepressed(x, y, button)
    -- Check if click is within any game button
    for i, game in ipairs(self.games) do
        local button_y = 60 + (i-1) * (self.button_height + self.button_padding)
        if x >= 10 and x <= 310 and y >= button_y and y <= button_y + self.button_height then
            self.selected_index = i
            -- If it's a left click, launch the game
            if button == 1 then
                self.state_machine:switch('minigame', game)
            end
            break
        end
    end
end

return LauncherState