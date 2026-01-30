local BaseGame = require('src.games.base_game')
local MemoryMatchView = require('src.games.views.memory_match_view')
local MemoryMatch = BaseGame:extend('MemoryMatch')

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function MemoryMatch:init(game_data, cheats, di, variant_override)
    MemoryMatch.super.init(self, game_data, cheats, di, variant_override)

    local SchemaLoader = self.di.components.SchemaLoader
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.memory_match)
    self.params = SchemaLoader.load(self.variant, "memory_match_schema", runtimeCfg)

    self:setupEntities()
    self:setupComponents()

    self.view = MemoryMatchView:new(self, self.variant)
    self:loadAssets()
    self:calculateGridPosition()
end

--------------------------------------------------------------------------------
-- ENTITY SETUP
--------------------------------------------------------------------------------

function MemoryMatch:setupEntities()
    local p = self.params

    -- Game dimensions
    self.game_width = p.arena_base_width
    self.game_height = p.arena_base_height

    -- Calculate unique icons (pairs/triplets/quads) from card_count or complexity
    local match_req = p.match_requirement
    local total_cards
    if p.card_count > 0 then
        total_cards = p.card_count - (p.card_count % match_req)  -- Ensure divisible by match_requirement
        self.total_pairs = total_cards / match_req
    else
        self.total_pairs = math.floor(6 * self.difficulty_modifiers.complexity * p.difficulty_modifier)
        total_cards = self.total_pairs * match_req
    end
    p.max_icons = self.total_pairs  -- For BaseGame:loadAssets()

    -- Grid layout
    if p.columns == 0 then
        self.grid_cols = math.ceil(math.sqrt(total_cards))
        self.grid_rows = math.ceil(total_cards / self.grid_cols)
    else
        self.grid_cols = p.columns
        self.grid_rows = math.ceil(total_cards / p.columns)
    end

    -- Compute memorize timer with difficulty scaling
    local speed_mod = self.cheats.speed_modifier or 1.0
    local time_bonus_mult = 1.0 + (1.0 - speed_mod)
    self.memorize_timer = p.memorize_time > 0 and
        ((p.memorize_time / self.difficulty_modifiers.time_limit) * time_bonus_mult) / p.difficulty_modifier or 0

    -- Runtime state (changes during gameplay)
    self.memorize_phase = p.memorize_time > 0
    self.selected_indices = {}
    self.matched_pairs = {}
    self.match_check_timer = 0
    self.shuffle_timer = p.auto_shuffle_interval
    self.is_shuffling = false
    self.shuffle_animation_timer = 0
    self.current_combo = 0
    self.chain_progress = 0
    self.chain_target = nil
    self.moves_made = 0
    self.time_remaining = p.time_limit

    -- UI state
    self.match_announcement = nil
    self.match_announcement_timer = 0
    self.mouse_x, self.mouse_y = 0, 0

    -- Metrics
    self.metrics.matches = 0
    self.metrics.perfect = 0
    self.metrics.combo = 0
    self.metrics.moves = 0
    self.metrics.score = 0

    -- Cards array
    self.cards = {}

    -- Select initial chain target if chain mode
    if p.chain_requirement > 0 then
        self:selectNextChainTarget()
    end
end

function MemoryMatch:setupComponents()
    -- Compute derived params for schema resolution
    self.params.fog_of_war_enabled = self.params.fog_of_war > 0

    -- Create fog_controller and hud from schema
    self:createComponentsFromSchema()

    -- EntityController for cards (game-specific config)
    local EntityController = self.di.components.EntityController
    self.entity_controller = EntityController:new({
        entity_types = {
            ["card"] = { flipped = false, matched = false }
        },
        spawning = {mode = "manual"},
        pooling = false,
        max_entities = 100
    })

    -- Victory Condition (dynamic target based on total_pairs)
    local VictoryCondition = self.di.components.VictoryCondition
    local victory_config = {
        victory = {type = "threshold", metric = "metrics.matches", target = self.total_pairs},
        loss = {type = "none"},
        check_loss_first = false
    }
    if self.params.time_limit > 0 then
        victory_config.loss = {type = "time_expired", metric = "time_remaining"}
    elseif self.params.move_limit > 0 then
        victory_config.loss = {type = "move_limit", moves_metric = "moves_made", limit_metric = "move_limit"}
    end
    self.victory_checker = VictoryCondition:new(victory_config)
    self.victory_checker.game = self

    -- Calculate grid layout before creating cards
    self:calculateGridPosition()

    -- Create cards after EntityController is set up
    self:createCards(self.total_pairs)
end

function MemoryMatch:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height

    if self.CARD_WIDTH and self.CARD_HEIGHT then
        self:calculateGridPosition()

        -- Update card positions for non-gravity mode
        if self.cards and not self.params.gravity_enabled then
            for i, card in ipairs(self.cards) do
                local row = math.floor((i-1) / self.grid_cols)
                local col = (i-1) % self.grid_cols
                card.x = self.start_x + col * (self.CARD_WIDTH + self.params.card_spacing)
                card.y = self.start_y + row * (self.CARD_HEIGHT + self.params.card_spacing)
            end
        end
    end
end

function MemoryMatch:calculateGridPosition()
    if not self.grid_cols or not self.grid_rows then return end

    local layout = self.entity_controller:calculateGridLayout({
        cols = self.grid_cols,
        rows = self.grid_rows,
        container_width = self.game_width,
        container_height = self.game_height,
        item_width = self.base_sprite_width or 60,
        item_height = self.base_sprite_height or 80,
        spacing = self.params.card_spacing,
        padding = self.params.grid_padding,
        reserved_top = self.hud and self.hud:getHeight() or 60
    })

    self.CARD_WIDTH = layout.item_width
    self.CARD_HEIGHT = layout.item_height
    self.start_x = layout.start_x
    self.start_y = layout.start_y
end

--------------------------------------------------------------------------------
-- CARD MANAGEMENT
--------------------------------------------------------------------------------

function MemoryMatch:createCards(pairs_count)
    local spacing = self.params.card_spacing

    for i = 1, pairs_count do
        for j = 1, self.params.match_requirement do
            local card_index = #self.cards + 1
            local row = math.floor((card_index-1) / self.grid_cols)
            local col = (card_index-1) % self.grid_cols

            -- Cards start face up during memorize phase
            local initial_flip_state = self.memorize_phase and "face_up" or "face_down"
            local initial_flip_progress = self.memorize_phase and 1 or 0

            -- In gravity mode, spawn cards at top with random X spread
            local init_x, init_y, init_vx, init_vy
            if self.params.gravity_enabled then
                init_x = self.start_x + col * (self.CARD_WIDTH + spacing) + (math.random() - 0.5) * 20
                init_y = -self.CARD_HEIGHT - row * 30
                init_vx = (math.random() - 0.5) * 50
                init_vy = math.random() * 100
            else
                init_x = self.start_x + col * (self.CARD_WIDTH + spacing)
                init_y = self.start_y + row * (self.CARD_HEIGHT + spacing)
                init_vx = 0
                init_vy = 0
            end

            local card = self.entity_controller:spawn("card", init_x, init_y, {
                value = i,
                attempts = {},
                flip_state = initial_flip_state,
                flip_progress = initial_flip_progress,
                vx = init_vx,
                vy = init_vy,
                grid_row = row,
                grid_col = col,
                icon_id = i,
                width = self.CARD_WIDTH,
                height = self.CARD_HEIGHT
            })

            if card then
                table.insert(self.cards, card)
            end
        end
    end
    self:shuffleCards()
end

function MemoryMatch:shuffleCards()
    local spacing = self.params.card_spacing

    for i = #self.cards, 2, -1 do
        local j = math.random(i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end

    for i, card in ipairs(self.cards) do
        local row = math.floor((i-1) / self.grid_cols)
        local col = (i-1) % self.grid_cols
        card.grid_row = row
        card.grid_col = col

        if not self.params.gravity_enabled then
            card.x = self.start_x + col * (self.CARD_WIDTH + spacing)
            card.y = self.start_y + row * (self.CARD_HEIGHT + spacing)
            card.vx = 0
            card.vy = 0
        end
    end
end

function MemoryMatch:isSelected(index)
    for _, selected_index in ipairs(self.selected_indices) do
        if selected_index == index then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------------------------

function MemoryMatch:updateGameLogic(dt)
    if self.memorize_phase then
        self.memorize_timer = self.memorize_timer - dt
        if self.memorize_timer <= 0 then
            self.memorize_phase = false
            self.time_elapsed = 0

            for _, card in ipairs(self.cards) do
                card.flip_state = "flipping_down"
                card.flip_progress = 1
            end
        end
    else
        self.metrics.time = self.time_elapsed

        -- Update match announcement timer
        if self.match_announcement_timer > 0 then
            self.match_announcement_timer = self.match_announcement_timer - dt
            if self.match_announcement_timer <= 0 then
                self.match_announcement = nil
            end
        end

        -- Time limit countdown
        if self.params.time_limit > 0 then
            self.time_remaining = math.max(0, self.time_remaining - dt)
            if self.time_remaining <= 0 then
                self.is_failed = true
            end
        end

        -- Auto-shuffle timer
        if self.params.auto_shuffle_interval > 0 and not self.is_shuffling then
            self.shuffle_timer = self.shuffle_timer - dt
            if self.shuffle_timer <= 0 then
                self:startShuffle()
                self.shuffle_timer = self.params.auto_shuffle_interval
            end
        end

        -- Shuffle animation
        if self.is_shuffling then
            self.shuffle_animation_timer = self.shuffle_animation_timer + dt
            if self.shuffle_animation_timer >= self.params.shuffle_animation_duration then
                self:completeShuffle()
            end
        end

        -- Update flip animations for all cards
        for i, card in ipairs(self.cards) do
            if card.flip_state == "flipping_up" then
                card.flip_progress = math.min(1, card.flip_progress + dt / self.params.flip_speed)
                if card.flip_progress >= 1 then
                    card.flip_state = "face_up"
                    card.flip_progress = 1
                end
            elseif card.flip_state == "flipping_down" then
                card.flip_progress = math.max(0, card.flip_progress - dt / self.params.flip_speed)
                if card.flip_progress <= 0 then
                    card.flip_state = "face_down"
                    card.flip_progress = 0
                end
            end
        end

        -- Gravity physics
        if self.params.gravity_enabled then
            local gravity = self.params.gravity_accel
            local bounce = self.params.floor_bounce

            for i, card in ipairs(self.cards) do
                if not self.matched_pairs[card.value] then
                    card.vy = card.vy + gravity * dt
                    card.x = card.x + card.vx * dt
                    card.y = card.y + card.vy * dt

                    local floor_y = self.game_height - self.CARD_HEIGHT
                    if card.y >= floor_y then
                        card.y = floor_y
                        card.vy = card.vy * -bounce
                        if math.abs(card.vy) < 10 then
                            card.vy = 0
                        end
                    end

                    if card.x < 0 then
                        card.x = 0
                        card.vx = card.vx * -0.5
                    elseif card.x + self.CARD_WIDTH > self.game_width then
                        card.x = self.game_width - self.CARD_WIDTH
                        card.vx = card.vx * -0.5
                    end
                end
            end
        end

        if self.match_check_timer > 0 then
            self.match_check_timer = self.match_check_timer - dt
            if self.match_check_timer <= 0 then
                self:checkMatch()
            end
        end
    end
end

function MemoryMatch:checkMatch()
    local all_match = true
    local first_value = self.cards[self.selected_indices[1]].value

    for i = 2, #self.selected_indices do
        if self.cards[self.selected_indices[i]].value ~= first_value then
            all_match = false
            break
        end
    end

    if all_match then
        local chain_valid = true
        if self.params.chain_requirement > 0 and self.chain_target then
            chain_valid = (first_value == self.chain_target)
        end

        if chain_valid then
            self:onMatchSuccess(first_value)
        else
            self:onMatchFailure()
        end
    else
        self:onMatchFailure()
    end
    self.selected_indices = {}
end

function MemoryMatch:onMatchSuccess(matched_value)
    self.matched_pairs[matched_value] = true
    self.metrics.matches = self.metrics.matches + 1

    -- Show match announcement with sprite name
    if self.icon_filenames and self.icon_filenames[matched_value] then
        local filename = self.icon_filenames[matched_value]
        self.match_announcement = filename:upper() .. "!"
        self.match_announcement_timer = 2.0

        -- Speak the match via TTS
        if self.di and self.di.ttsManager then
            local tts = self.di.ttsManager
            local weirdness = (self.di.config and self.di.config.tts and self.di.config.tts.weirdness) or 1
            tts:speakWeird(filename, weirdness)
        end
    end

    -- Check for perfect match and apply bonus
    local is_perfect = true
    for _, idx in ipairs(self.selected_indices) do
        if #self.cards[idx].attempts > 1 then
            is_perfect = false
            break
        end
    end

    if is_perfect then
        self.metrics.perfect = self.metrics.perfect + 1
        if self.params.perfect_bonus > 0 then
            self.metrics.score = self.metrics.score + self.params.perfect_bonus
        end
    end

    -- Combo system
    self.current_combo = self.current_combo + 1
    self.metrics.combo = math.max(self.metrics.combo, self.current_combo)

    if self.params.combo_multiplier > 0 then
        local combo_bonus = math.floor(10 * self.params.combo_multiplier * self.current_combo)
        self.metrics.score = self.metrics.score + combo_bonus
    end

    -- Base match points
    self.metrics.score = self.metrics.score + 10

    -- Chain requirement progress
    if self.params.chain_requirement > 0 then
        self.chain_progress = self.chain_progress + 1
        if self.chain_progress >= self.params.chain_requirement then
            self.chain_progress = 0
        end
        self:selectNextChainTarget()
    end

    self:playSound("match", 1.0)
end

function MemoryMatch:onMatchFailure()
    self.current_combo = 0
    if self.params.mismatch_penalty > 0 then
        self:applyMismatchPenalty()
    end
    for _, idx in ipairs(self.selected_indices) do
        self.cards[idx].flip_state = "flipping_down"
    end
    self:playSound("mismatch", 0.8)
end

function MemoryMatch:draw()
    if self.view then
        self.view:draw()
    end
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

function MemoryMatch:mousemoved(x, y, dx, dy)
    self.mouse_x = x
    self.mouse_y = y
end

function MemoryMatch:mousepressed(x, y, button)
    self.mouse_x = x
    self.mouse_y = y

    if self.memorize_phase or self.match_check_timer > 0 or #self.selected_indices >= self.params.match_requirement then return end

    if self.params.move_limit > 0 and self.moves_made >= self.params.move_limit then
        self.is_failed = true
        return
    end

    local spacing = self.params.card_spacing

    for i, card in ipairs(self.cards) do
        local card_x, card_y
        if self.params.gravity_enabled then
            card_x = card.x
            card_y = card.y
        else
            local row = math.floor((i-1) / self.grid_cols)
            local col = (i-1) % self.grid_cols
            card_x = self.start_x + col * (self.CARD_WIDTH + spacing)
            card_y = self.start_y + row * (self.CARD_HEIGHT + spacing)
        end

        if x >= card_x and x <= card_x + self.CARD_WIDTH and y >= card_y and y <= card_y + self.CARD_HEIGHT then
            if not self.matched_pairs[card.value] and not self:isSelected(i) and card.flip_state ~= "flipping_up" then
                table.insert(card.attempts, self.time_elapsed)
                table.insert(self.selected_indices, i)
                self.moves_made = self.moves_made + 1
                self.metrics.moves = self.moves_made

                card.flip_state = "flipping_up"
                card.flip_progress = 0

                self:playSound("flip_card", 0.7)

                if #self.selected_indices == self.params.match_requirement then
                    self.match_check_timer = self.params.reveal_duration
                end
                break
            end
        end
    end
end

--------------------------------------------------------------------------------
-- GAME STATE / VICTORY
--------------------------------------------------------------------------------

function MemoryMatch:checkComplete()
    if self.memorize_phase then return false end

    if self.is_failed then
        self.victory = false
        self.game_over = true
        return true
    end

    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

function MemoryMatch:onComplete()
    if self.params.time_limit > 0 and self.params.speed_bonus > 0 then
        local time_bonus = math.floor(self.time_remaining * self.params.speed_bonus)
        self.metrics.score = self.metrics.score + time_bonus
    end

    self:playSound("success", 1.0)
    self:stopMusic()

    MemoryMatch.super.onComplete(self)
end

--------------------------------------------------------------------------------
-- SHUFFLE ANIMATION
--------------------------------------------------------------------------------

function MemoryMatch:startShuffle()
    local face_down_indices = {}

    for i, card in ipairs(self.cards) do
        local is_face_down = (card.flip_state == "face_down")
        local not_matched = not self.matched_pairs[card.value]
        local not_selected = not self:isSelected(i)
        local not_flipping = (card.flip_state ~= "flipping_up" and card.flip_state ~= "flipping_down")

        if is_face_down and not_matched and not_selected and not_flipping then
            table.insert(face_down_indices, i)
        end
    end

    if #face_down_indices < 2 then return end

    local shuffle_count = self.params.auto_shuffle_count
    if shuffle_count == 0 or shuffle_count > #face_down_indices then
        shuffle_count = #face_down_indices
    end

    if shuffle_count < 2 then return end

    local selected_indices = {}
    local available = {}
    for _, idx in ipairs(face_down_indices) do
        table.insert(available, idx)
    end

    for i = 1, shuffle_count do
        local pick = math.random(#available)
        table.insert(selected_indices, available[pick])
        table.remove(available, pick)
    end

    local spacing = self.params.card_spacing
    self.shuffle_start_positions = {}
    for i, card in ipairs(self.cards) do
        local row = math.floor((i-1) / self.grid_cols)
        local col = (i-1) % self.grid_cols
        local x = self.start_x + col * (self.CARD_WIDTH + spacing)
        local y = self.start_y + row * (self.CARD_HEIGHT + spacing)
        self.shuffle_start_positions[i] = {x = x, y = y}
    end

    for i = #selected_indices, 2, -1 do
        local j = math.random(i - 1)
        local idx1 = selected_indices[i]
        local idx2 = selected_indices[j]
        self.cards[idx1], self.cards[idx2] = self.cards[idx2], self.cards[idx1]
        self.shuffle_start_positions[idx1], self.shuffle_start_positions[idx2] =
            self.shuffle_start_positions[idx2], self.shuffle_start_positions[idx1]
    end

    self.is_shuffling = true
    self.shuffle_animation_timer = 0
end

function MemoryMatch:completeShuffle()
    self.is_shuffling = false
    self.shuffle_start_positions = nil
end

--------------------------------------------------------------------------------
-- CHALLENGE MODE
--------------------------------------------------------------------------------

function MemoryMatch:selectNextChainTarget()
    if self.params.chain_requirement == 0 then return end

    local unmatched = {}
    for i = 1, self.total_pairs do
        if not self.matched_pairs[i] then
            table.insert(unmatched, i)
        end
    end

    if #unmatched > 0 then
        self.chain_target = unmatched[math.random(#unmatched)]
    else
        self.chain_target = nil
    end
end

function MemoryMatch:applyMismatchPenalty()
    if self.params.time_limit > 0 then
        self.time_remaining = math.max(0, self.time_remaining - self.params.mismatch_penalty)
        if self.time_remaining <= 0 then
            self.is_failed = true
        end
    elseif self.params.mismatch_penalty > 0 then
        self.is_failed = true
    end
end

return MemoryMatch
