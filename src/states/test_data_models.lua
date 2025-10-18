local PlayerData = require('src.models.player_data')
local GameData = require('src.models.game_data')
local SaveManager = require('src.utils.save_manager')

local Object = require('class')
local TestState = Object:extend('TestState')

function TestState:init()
    print("Initializing TestState...")
    self.player_data = PlayerData:new()
    print("PlayerData created")
    self.game_data = GameData:new()
    print("GameData created")
    self.test_results = {}
    print("Running tests...")
    self:runTests()
    print("Tests completed")
end

function TestState:runTests()
    print("\n=== Running Data Model Tests ===\n")
    
    -- Test PlayerData
    print("Testing PlayerData:")
    self.player_data:addTokens(1000)
    assert(self.player_data.tokens == 1000, "addTokens failed")
    assert(self.player_data:hasTokens(500), "hasTokens failed")
    assert(self.player_data:spendTokens(500), "spendTokens failed")
    assert(self.player_data.tokens == 500, "token balance incorrect")
    print("✓ Basic token operations")
    
    -- Test GameData
    print("\nTesting GameData:")
    local games = self.game_data:getAllGames()
    assert(#games > 0, "No games loaded")
    local space_shooter = self.game_data:getGame("space_shooter_1")
    assert(space_shooter, "Could not find base game")
    assert(space_shooter.variant_multiplier == 1, "Base game multiplier incorrect")
    print("✓ Game data loading")
    
    -- Test game unlocking
    print("\nTesting game unlocking:")
    assert(self.player_data:unlockGame("space_shooter_1"), "Game unlock failed")
    assert(self.player_data:isGameUnlocked("space_shooter_1"), "Game not showing as unlocked")
    print("✓ Game unlocking")
    
    -- Test performance tracking
    print("\nTesting performance tracking:")
    local metrics = {kills = 50, deaths = 2}
    local formula_result = self.game_data:calculatePower("space_shooter_1", metrics)
    assert(formula_result == 48, "Formula calculation incorrect")
    assert(self.player_data:updateGamePerformance("space_shooter_1", metrics, formula_result), "Performance update failed")
    local stored_perf = self.player_data:getGamePerformance("space_shooter_1")
    assert(stored_perf.best_score == 48, "Best score not stored correctly")
    print("✓ Performance tracking")
    
    -- Test save/load
    print("\nTesting save/load:")
    assert(SaveManager.save(self.player_data), "Save failed")
    local loaded_data = SaveManager.load()
    assert(loaded_data, "Load failed")
    assert(loaded_data.tokens == 500, "Loaded data incorrect")
    print("✓ Save/load system")
    
    print("\n=== All tests passed! ===\n")
end

function TestState:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Check console for test results", 10, 10)
    love.graphics.print("Press ESC to return to menu", 10, 30)
end

return TestState