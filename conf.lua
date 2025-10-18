function love.conf(t)
    t.identity = "10000games"
    t.version = "11.4"
    t.console = true
    
    t.window.title = "10,000 Games"
    t.window.width = 1920
    t.window.height = 1080
    t.window.resizable = false
    t.window.fullscreen = true
    t.window.fullscreentype = "desktop"
    
    t.modules.physics = false
    t.modules.joystick = false
    t.modules.video = false
end