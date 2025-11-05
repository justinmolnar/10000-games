local Object = require('class')
local ScreensaverView = require('src.views.screensaver_view')
local SettingsManager = require('src.utils.settings_manager')

local ScreensaverState = Object:extend('ScreensaverState')

local Constants = require('src.constants')

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
            -- Build shapes array from up to three saved choices (ignore 'none' or empty)
            local shapes = {}
            local function addShape(v)
                if v and v ~= '' and v ~= 'none' then table.insert(shapes, v) end
            end
            addShape(s.screensaver_model_shape1)
            addShape(s.screensaver_model_shape2)
            addShape(s.screensaver_model_shape3)

            -- Build tint color (default white)
            local tint = {
                s.screensaver_model_tint_r or 1.0,
                s.screensaver_model_tint_g or 1.0,
                s.screensaver_model_tint_b or 1.0,
            }

            self.view = ModelView:new({
                path = s.screensaver_model_path,
                scale = s.screensaver_model_scale,
                fov = s.screensaver_model_fov,
                rot_speed_x = s.screensaver_model_rot_speed_x,
                rot_speed_y = s.screensaver_model_rot_speed_y,
                rot_speed_z = s.screensaver_model_rot_speed_z,
                grid_lat = s.screensaver_model_grid_lat,
                grid_lon = s.screensaver_model_grid_lon,
                morph_speed = s.screensaver_model_morph_speed,
                two_sided = s.screensaver_model_two_sided,
                -- New model settings
                shapes = (#shapes > 0) and shapes or nil,
                hold_time = s.screensaver_model_hold_time or 0.0,
                tint = tint,
            })
        else
            self.view = ScreensaverView:new()
        end
    elseif t == 'text3d' then
        local ok, Text3DView = pcall(require, 'src.views.screensaver_text3d_view')
        if ok and Text3DView then
            local s = SettingsManager.getAll()
            -- Use current background color so preview and full-screen match
            local br,bg,bb = love.graphics.getBackgroundColor()
            -- Derive size fallback from legacy fields if new size missing
            local size_val = s.screensaver_text3d_size
            if size_val == nil then
                local fs = s.screensaver_text3d_font_size or 96
                local fov = s.screensaver_text3d_fov or 350
                local dist = s.screensaver_text3d_distance or 18
                size_val = math.max(0.2, math.min(3.0, (fs / 96) * (350 / math.max(1, fov)) * (dist / 18)))
            end
            self.view = Text3DView:new({
                size = size_val,
                -- Keep fov/distance for internal fallback only
                fov = s.screensaver_text3d_fov,
                distance = s.screensaver_text3d_distance,
                bg_color = { br or 0, bg or 0, bb or 0 },
                color = { s.screensaver_text3d_color_r, s.screensaver_text3d_color_g, s.screensaver_text3d_color_b },
                color_mode = s.screensaver_text3d_color_mode,
                use_hsv = s.screensaver_text3d_use_hsv,
                color_h = s.screensaver_text3d_color_h,
                color_s = s.screensaver_text3d_color_s,
                color_v = s.screensaver_text3d_color_v,
                font_size = s.screensaver_text3d_font_size,
                extrude_layers = s.screensaver_text3d_extrude_layers,
                spin_x = s.screensaver_text3d_spin_x,
                spin_y = s.screensaver_text3d_spin_y,
                spin_z = s.screensaver_text3d_spin_z,
                rotation_mode_x = s.screensaver_text3d_rotation_mode_x,
                rotation_mode_y = s.screensaver_text3d_rotation_mode_y,
                rotation_mode_z = s.screensaver_text3d_rotation_mode_z,
                rotation_range_x = s.screensaver_text3d_rotation_range_x,
                rotation_range_y = s.screensaver_text3d_rotation_range_y,
                rotation_range_z = s.screensaver_text3d_rotation_range_z,
                move_enabled = s.screensaver_text3d_move_enabled,
                move_mode = s.screensaver_text3d_move_mode,
                move_speed = s.screensaver_text3d_move_speed,
                move_radius = s.screensaver_text3d_move_radius,
                bounce_speed_x = s.screensaver_text3d_bounce_speed_x,
                bounce_speed_y = s.screensaver_text3d_bounce_speed_y,
                depth_oscillate = s.screensaver_text3d_depth_oscillate,
                depth_speed = s.screensaver_text3d_depth_speed,
                depth_min = s.screensaver_text3d_depth_min,
                depth_max = s.screensaver_text3d_depth_max,
                pulse_enabled = s.screensaver_text3d_pulse_enabled,
                pulse_speed = s.screensaver_text3d_pulse_speed,
                pulse_amp = s.screensaver_text3d_pulse_amp,
                use_time = s.screensaver_text3d_use_time,
                text = s.screensaver_text3d_text,
            })
        else
            self.view = ScreensaverView:new()
        end
    else
        -- Starfield screensaver (default)
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
    if self.state_machine and self.state_machine.states[Constants.state.DESKTOP] then
        self.state_machine:switch(Constants.state.DESKTOP)
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
