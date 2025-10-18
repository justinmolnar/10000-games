-- src/views/statistics_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local StatisticsView = Object:extend('StatisticsView')

function StatisticsView:init(controller)
    self.controller = controller -- statistics_state
    self.title = "Game Statistics"

    self.back_button = { x = 50, y = love.graphics.getHeight() - 70, w = 200, h = 40, label = "Back" }
    self.hovered = false
end

function StatisticsView:update(dt)
    local mx, my = love.mouse.getPosition()
    self.hovered = mx >= self.back_button.x and mx <= self.back_button.x + self.back_button.w and
                   my >= self.back_button.y and my <= self.back_button.y + self.back_button.h
end

function StatisticsView:draw(stats_data)
    UIComponents.drawWindow(0, 0, love.graphics.getWidth(), love.graphics.getHeight(), self.title)

    local x_pos = 50
    local y_pos = 80
    local line_height = 25

    love.graphics.setColor(1, 1, 1)

    -- Format Playtime
    local playtime = stats_data.total_playtime or 0
    local hours = math.floor(playtime / 3600)
    local minutes = math.floor((playtime % 3600) / 60)
    local seconds = math.floor(playtime % 60)
    local playtime_str = string.format("%02d:%02d:%02d", hours, minutes, seconds)

    -- Display Stats
    love.graphics.print("Total Playtime: ", x_pos, y_pos); love.graphics.print(playtime_str, x_pos + 250, y_pos); y_pos = y_pos + line_height
    love.graphics.print("Total Games Unlocked: ", x_pos, y_pos); love.graphics.print(stats_data.total_games_unlocked or 0, x_pos + 250, y_pos); y_pos = y_pos + line_height
    love.graphics.print("Total Tokens Earned: ", x_pos, y_pos); love.graphics.print(math.floor(stats_data.total_tokens_earned or 0), x_pos + 250, y_pos); y_pos = y_pos + line_height
    love.graphics.print("Total Bullets Fired: ", x_pos, y_pos); love.graphics.print(math.floor(stats_data.total_bullets_fired or 0), x_pos + 250, y_pos); y_pos = y_pos + line_height
    love.graphics.print("Highest Single Hit Damage: ", x_pos, y_pos); love.graphics.print(math.floor(stats_data.highest_damage_dealt or 0), x_pos + 250, y_pos); y_pos = y_pos + line_height

    -- Back Button
    UIComponents.drawButton(self.back_button.x, self.back_button.y, self.back_button.w, self.back_button.h, self.back_button.label, true, self.hovered)
end

function StatisticsView:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    if x >= self.back_button.x and x <= self.back_button.x + self.back_button.w and
       y >= self.back_button.y and y <= self.back_button.y + self.back_button.h then
        return { name = "back" }
    end
    return nil
end

return StatisticsView