local Object = require('class')
local ScreensaverView = require('src.views.screensaver_view')
local SettingsManager = require('src.utils.settings_manager')

local ScreensaverState = Object:extend('ScreensaverState')

function ScreensaverState:init(state_machine)
    self.state_machine = state_machine
    self.view = nil
end

function ScreensaverState:enter()
    -- Hide cursor for screensaver
    love.mouse.setVisible(false)
    -- Choose view based on settings
    local t = SettingsManager.get('screensaver_type') or 'starfield'
    if t == 'pipes' then
        local ok, PipesView = pcall(require, 'src.views.screensaver_pipes_view')
        if ok and PipesView then
            local s = SettingsManager.getAll()
            self.view = PipesView:new({
                spawn_min_z = s.screensaver_pipes_spawn_min_z,
                spawn_max_z = s.screensaver_pipes_spawn_max_z,
                radius = s.screensaver_pipes_radius,
                speed = s.screensaver_pipes_speed,
                turn_chance = s.screensaver_pipes_turn_chance,
                avoid_cells = s.screensaver_pipes_avoid_cells,
                show_grid = s.screensaver_pipes_show_grid,
                camera_roll = s.screensaver_pipes_camera_roll,
                camera_drift = s.screensaver_pipes_camera_drift,
                pipe_count = s.screensaver_pipes_pipe_count,
                near = s.screensaver_pipes_near,
                fov = s.screensaver_pipes_fov,
                grid_step = s.screensaver_pipes_grid_step,
                max_segments = s.screensaver_pipes_max_segments,
                show_hud = s.screensaver_pipes_show_hud,
            })
        else
            self.view = ScreensaverView:new()
        end
    elseif t == 'model3d' then
        local ok, ModelView = pcall(require, 'src.views.screensaver_model_view')
        if ok and ModelView then
            local s = SettingsManager.getAll()
            self.view = ModelView:new({
                path = s.screensaver_model_path,
                scale = s.screensaver_model_scale,
                fov = s.screensaver_model_fov,
                rot_speed_x = s.screensaver_model_rot_speed_x,
                rot_speed_y = s.screensaver_model_rot_speed_y,
                rot_speed_z = s.screensaver_model_rot_speed_z,
                mode = 'cube_sphere',
                grid_lat = s.screensaver_model_grid_lat,
                grid_lon = s.screensaver_model_grid_lon,
                morph_speed = s.screensaver_model_morph_speed,
                two_sided = s.screensaver_model_two_sided,
            })
        else
            self.view = ScreensaverView:new()
        end
    else
        local s = SettingsManager.getAll()
        self.view = ScreensaverView:new({
            count = s.screensaver_starfield_count,
            speed = s.screensaver_starfield_speed,
            fov = s.screensaver_starfield_fov,
            tail = s.screensaver_starfield_tail,
        })
    end
end

function ScreensaverState:update(dt)
    if self.view and self.view.update then self.view:update(dt) end
end

function ScreensaverState:draw()
    if self.view and self.view.draw then self.view:draw() end
end

local function exitToDesktop(self)
    -- Restore cursor
    love.mouse.setVisible(true)
    if self.state_machine and self.state_machine.states['desktop'] then
        self.state_machine:switch('desktop')
    end
end

function ScreensaverState:keypressed(key)
    exitToDesktop(self)
    return true
end

function ScreensaverState:mousepressed(x, y, button)
    exitToDesktop(self)
    return true
end

function ScreensaverState:mousereleased(x, y, button)
    exitToDesktop(self)
    return true
end

function ScreensaverState:mousemoved(x, y, dx, dy)
    exitToDesktop(self)
    return true
end

function ScreensaverState:textinput(text)
    exitToDesktop(self)
    return true
end

function ScreensaverState:wheelmoved(x, y)
    exitToDesktop(self)
    return true
end

return ScreensaverState
