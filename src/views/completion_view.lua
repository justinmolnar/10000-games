-- src/views/completion_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local CompletionView = Object:extend('CompletionView')

function CompletionView:init(controller)
    self.controller = controller -- completion_state
    self.title = "MVP COMPLETE!"

    self.options = {
        { id = "stats", label = "View Statistics", x = 150, y = 400, w = 200, h = 40 },
        { id = "continue", label = "Continue Playing", x = 450, y = 400, w = 200, h = 40 },
        { id = "quit", label = "Quit Game", x = 300, y = 460, w = 200, h = 40 }
    }
    self.hovered_button_id = nil
end

function CompletionView:update(dt)
    local mx, my = love.mouse.getPosition()
    self.hovered_button_id = nil
    for _, opt in ipairs(self.options) do
        if mx >= opt.x and mx <= opt.x + opt.w and my >= opt.y and my <= opt.y + opt.h then
            self.hovered_button_id = opt.id
            break
        end
    end
end

function CompletionView:draw(stats_data)
    -- Background overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Title
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf(self.title, 0, 80, love.graphics.getWidth(), "center", 0, 2, 2)

    -- Message
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Congratulations! You've completed the MVP content.", 0, 150, love.graphics.getWidth(), "center")
    love.graphics.printf("Thank you for playing!", 0, 180, love.graphics.getWidth(), "center")

    -- Stats Summary
    love.graphics.setColor(0.8, 0.8, 0.8)
    local y_pos = 250
    local line_height = 20
    local playtime = stats_data.total_playtime or 0
    local hours = math.floor(playtime / 3600)
    local minutes = math.floor((playtime % 3600) / 60)
    local playtime_str = string.format("%dh %02dm", hours, minutes)

    love.graphics.printf("Final Playtime: " .. playtime_str, 0, y_pos, love.graphics.getWidth(), "center"); y_pos = y_pos + line_height
    love.graphics.printf("Games Unlocked: " .. (stats_data.total_games_unlocked or 0), 0, y_pos, love.graphics.getWidth(), "center"); y_pos = y_pos + line_height
    love.graphics.printf("Tokens Earned: " .. math.floor(stats_data.total_tokens_earned or 0), 0, y_pos, love.graphics.getWidth(), "center"); y_pos = y_pos + line_height

    -- Buttons
    for _, opt in ipairs(self.options) do
        local is_hovered = (opt.id == self.hovered_button_id)
        UIComponents.drawButton(opt.x, opt.y, opt.w, opt.h, opt.label, true, is_hovered)
    end
end

function CompletionView:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    for _, opt in ipairs(self.options) do
        if x >= opt.x and x <= opt.x + opt.w and y >= opt.y and y <= opt.y + opt.h then
            return { name = "button_click", id = opt.id }
        end
    end
    return nil
end

return CompletionView