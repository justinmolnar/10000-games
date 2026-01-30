--[[
    GameBaseView - Base class for minigame views

    Provides common functionality:
    - DI container access (sprite_loader, sprite_manager, palette_manager)
    - Lazy loading of sprite systems via ensureLoaded()
    - Palette and tint helpers
    - draw() orchestration

    Game views extend this and override drawContent() for game-specific rendering.
]]

local Object = require('class')
local GameBaseView = Object:extend('GameBaseView')

function GameBaseView:init(game_state, variant, config)
    self.game = game_state
    self.variant = variant
    self.config = config or {}

    -- DI container access
    self.di = game_state and game_state.di

    -- Lazy-loaded sprite systems (populated by ensureLoaded)
    self.sprite_loader = nil
    self.sprite_manager = nil
    self.palette_manager = nil
end

function GameBaseView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error(tostring(self) .. ": spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error(tostring(self) .. ": spriteManager not available in DI")
    end

    if not self.palette_manager then
        self.palette_manager = self.di and self.di.paletteManager
    end
end

function GameBaseView:getPaletteId()
    return (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(self.game.data)
end

function GameBaseView:getTint(game_type, config_path)
    if not self.palette_manager then
        return {1, 1, 1}
    end

    -- Get config from DI if config_path provided
    local config = nil
    if config_path and self.di and self.di.config then
        config = self.di.config
        for part in config_path:gmatch("[^.]+") do
            config = config and config[part]
        end
    end

    if config then
        return self.palette_manager:getTintForVariant(self.variant, game_type, config)
    end

    return {1, 1, 1}
end

function GameBaseView:draw()
    self:ensureLoaded()
    self:drawContent()
end

function GameBaseView:drawContent()
    -- Override in subclasses
end

return GameBaseView
