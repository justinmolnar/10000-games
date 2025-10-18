function love.conf(t)
    t.identity = "10000games"        -- Save directory name
    t.version = "11.4"              -- LÖVE version
    t.console = true                -- Enable console for debugging
    
    t.window.title = "10,000 Games"
    t.window.width = 800
    t.window.height = 600
    t.window.resizable = false
    
    -- We don't need these modules yet
    t.modules.physics = false
    t.modules.joystick = false
    t.modules.video = false
end
