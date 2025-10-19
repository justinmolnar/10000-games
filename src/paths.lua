-- src/paths.lua: Centralized paths for assets and data

local Paths = {}

Paths.assets = {
    base = 'assets/',
    data = 'assets/data/',
    sprites = 'assets/sprites/',
    fonts = 'assets/fonts/',
    shaders = 'assets/shaders/',
    sounds = 'assets/sounds/'
}

Paths.data = {
    control_panels = 'assets/data/control_panels/',
    models = 'assets/data/models/',
    programs = 'assets/data/programs.json'
}

return Paths
