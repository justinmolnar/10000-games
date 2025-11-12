-- src/views/statistics_view.lua
local BaseView = require('src.views.base_view')
local UIComponents = require('src.views.ui_components')
local StatisticsView = BaseView:extend('StatisticsView')

function StatisticsView:init(controller)
    StatisticsView.super.init(self, controller)
    self.controller = controller -- statistics_state
    self.title = "Game Statistics"

    -- Initial button position, updated by updateLayout
    self.back_button = { x = 50, y = 330, w = 200, h = 40, label = "Close" }
    self.hovered = false
end

function StatisticsView:updateLayout(viewport_width, viewport_height)
    -- Update back button position based on viewport height
    self.back_button.y = viewport_height - 50 -- Position near bottom
    -- Center button horizontally?
    self.back_button.x = (viewport_width - self.back_button.w) / 2
end

function StatisticsView:update(dt)
    local mx, my = love.mouse.getPosition()
    -- Get window position from controller's viewport
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    self.hovered = local_mx >= self.back_button.x and local_mx <= self.back_button.x + self.back_button.w and
                   local_my >= self.back_button.y and local_my <= self.back_button.y + self.back_button.h
end

-- Override BaseView's drawWindowed to pass extra parameters
function StatisticsView:drawWindowed(stats_data, viewport_width, viewport_height)
    self.draw_params = { stats_data = stats_data }
    StatisticsView.super.drawWindowed(self, viewport_width, viewport_height)
end

-- Implements BaseView's abstract drawContent method
function StatisticsView:drawContent(viewport_width, viewport_height)
    local stats_data = self.draw_params.stats_data

    -- Draw background
    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.title, 0, 20, viewport_width, "center")

    -- Stats layout uses relative positioning, should adapt okay
    local x_pos = 50
    local y_pos = 60
    local line_height = 25
    local value_x_pos = x_pos + 230 -- Align values

    -- Format Playtime
    local playtime = stats_data.total_playtime or 0
    local hours = math.floor(playtime / 3600)
    local minutes = math.floor((playtime % 3600) / 60)
    local seconds = math.floor(playtime % 60)
    local playtime_str = string.format("%02d:%02d:%02d", hours, minutes, seconds)

    -- Display Stats
    love.graphics.print("Total Playtime: ", x_pos, y_pos); love.graphics.print(playtime_str, value_x_pos, y_pos); y_pos = y_pos + line_height
    love.graphics.print("Total Games Unlocked: ", x_pos, y_pos); love.graphics.print(stats_data.total_games_unlocked or 0, value_x_pos, y_pos); y_pos = y_pos + line_height
    love.graphics.print("Total Tokens Earned: ", x_pos, y_pos); love.graphics.print(math.floor(stats_data.total_tokens_earned or 0), value_x_pos, y_pos); y_pos = y_pos + line_height
    love.graphics.print("Total Bullets Fired: ", x_pos, y_pos); love.graphics.print(math.floor(stats_data.total_bullets_fired or 0), value_x_pos, y_pos); y_pos = y_pos + line_height
    love.graphics.print("Highest Single Hit Damage: ", x_pos, y_pos); love.graphics.print(math.floor(stats_data.highest_damage_dealt or 0), value_x_pos, y_pos); y_pos = y_pos + line_height

    -- Back Button (Uses updated position, label changed)
    UIComponents.drawButton(self.back_button.x, self.back_button.y, self.back_button.w, self.back_button.h, self.back_button.label, true, self.hovered)
end


function StatisticsView:mousepressed(x, y, button)
    -- x, y are LOCAL coords relative to content area (0,0)
    if button ~= 1 then return nil end

    -- Use relative button coordinates calculated in updateLayout
    -- Check using LOCAL x, y
    if x >= self.back_button.x and x <= self.back_button.x + self.back_button.w and
       y >= self.back_button.y and y <= self.back_button.y + self.back_button.h then
        return { name = "back" } -- State interprets this as close_window
    end
    return nil -- Clicked empty space within the view
end

return StatisticsView