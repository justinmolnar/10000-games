local Object = require('class')
local GameContext = Object:extend('GameContext')

function GameContext:init()
    self.player_data = nil
    self.game_data = nil
    self.save_manager = nil
    self.vm_manager = nil
    self.state_machine = nil
end

function GameContext:setPlayerData(player_data)
    self.player_data = player_data
end

function GameContext:setGameData(game_data)
    self.game_data = game_data
end

function GameContext:setSaveManager(save_manager)
    self.save_manager = save_manager
end

function GameContext:setVMManager(vm_manager)
    self.vm_manager = vm_manager
end

function GameContext:setStateMachine(state_machine)
    self.state_machine = state_machine
end

return GameContext