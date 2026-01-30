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
    self.matched_pairs = {}
    self.match_check_timer = 0
    self.shuffle_timer = p.auto_shuffle_interval
    self.current_combo = 0
    self.chain_progress = 0
    self.chain_target = nil
    self.moves_made = 0
    self.time_remaining = p.time_limit

    -- UI state
    self.match_announcement = nil
    self.match_announcement_timer = 0

    -- Metrics
    self.metrics.matches = 0
    self.metrics.perfect = 0
    self.metrics.combo = 0
    self.metrics.moves = 0
    self.metrics.score = 0

    -- Select initial chain target if chain mode (random value 1 to total_pairs)
    if p.chain_requirement > 0 then
        self.chain_target = math.random(self.total_pairs)
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
    local p = self.params
    local victory_config = {
        victory = {type = "threshold", metric = "metrics.matches", target = self.total_pairs},
        loss = {type = "none"},
        check_loss_first = false,
        bonuses = {}
    }
    if p.time_limit > 0 then
        victory_config.loss = {type = "time_expired", metric = "time_remaining"}
        -- Time bonus for fast completion
        if p.speed_bonus > 0 then
            table.insert(victory_config.bonuses, {
                condition = function(g) return g.time_remaining > 0 end,
                apply = function(g) g.metrics.score = g.metrics.score + math.floor(g.time_remaining * p.speed_bonus) end
            })
        end
    elseif p.move_limit > 0 then
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
        if not self.params.gravity_enabled then
            self.entity_controller:repositionGridEntities("card", {
                start_x = self.start_x,
                start_y = self.start_y,
                cols = self.grid_cols,
                item_width = self.CARD_WIDTH,
                item_height = self.CARD_HEIGHT,
                spacing = self.params.card_spacing
            })
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
    local p = self.params
    local spacing = p.card_spacing
    local card_index = 0

    for i = 1, pairs_count do
        for j = 1, p.match_requirement do
            -- Cards start face up during memorize phase
            local initial_flip_state = self.memorize_phase and "face_up" or "face_down"
            local initial_flip_progress = self.memorize_phase and 1 or 0

            -- Initial position (will be repositioned after shuffle)
            local row = math.floor(card_index / self.grid_cols)
            local col = card_index % self.grid_cols
            local init_x = self.start_x + col * (self.CARD_WIDTH + spacing)
            local init_y = self.start_y + row * (self.CARD_HEIGHT + spacing)

            -- Gravity mode: spawn at top with random physics
            local init_vx, init_vy = 0, 0
            if p.gravity_enabled then
                init_x = init_x + (math.random() - 0.5) * 20
                init_y = -self.CARD_HEIGHT - row * 30
                init_vx = (math.random() - 0.5) * 50
                init_vy = math.random() * 100
            end

            self.entity_controller:spawn("card", init_x, init_y, {
                value = i,
                icon_id = i,
                grid_index = card_index,
                attempts = {},
                flip_state = initial_flip_state,
                flip_progress = initial_flip_progress,
                is_selected = false,
                vx = init_vx,
                vy = init_vy,
                width = self.CARD_WIDTH,
                height = self.CARD_HEIGHT
            })
            card_index = card_index + 1
        end
    end
    self:shuffleCards()
end

function MemoryMatch:shuffleCards()
    self.entity_controller:shuffleGridIndices("card")
    if not self.params.gravity_enabled then
        self.entity_controller:repositionGridEntities("card", {
            start_x = self.start_x,
            start_y = self.start_y,
            cols = self.grid_cols,
            item_width = self.CARD_WIDTH,
            item_height = self.CARD_HEIGHT,
            spacing = self.params.card_spacing
        })
    end
end

--------------------------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------------------------

function MemoryMatch:updateGameLogic(dt)
    local cards = self.entity_controller:getEntitiesByType("card")

    if self.memorize_phase then
        self.memorize_timer = self.memorize_timer - dt
        if self.memorize_timer <= 0 then
            self.memorize_phase = false
            self.time_elapsed = 0

            for _, card in ipairs(cards) do
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

        -- Time limit countdown (VictoryCondition handles loss check)
        if self.params.time_limit > 0 then
            self.time_remaining = math.max(0, self.time_remaining - dt)
        end

        -- Auto-shuffle timer
        if self.params.auto_shuffle_interval > 0 and not self.entity_controller:isGridShuffling() then
            self.shuffle_timer = self.shuffle_timer - dt
            if self.shuffle_timer <= 0 then
                self:startShuffle()
                self.shuffle_timer = self.params.auto_shuffle_interval
            end
        end

        -- Shuffle animation update
        if self.entity_controller:updateGridShuffle(dt) then
            self:completeShuffle()
        end

        -- Update flip animations for all cards
        for _, card in ipairs(cards) do
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

            for _, card in ipairs(cards) do
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
    local selected = self.entity_controller:getEntitiesByFilter(function(e) return e.is_selected end)
    if #selected == 0 then return end

    local all_match = true
    local first_value = selected[1].value

    for i = 2, #selected do
        if selected[i].value ~= first_value then
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
            self:onMatchSuccess(first_value, selected)
        else
            self:onMatchFailure(selected)
        end
    else
        self:onMatchFailure(selected)
    end

    -- Clear selection
    for _, card in ipairs(selected) do
        card.is_selected = false
    end
end

function MemoryMatch:onMatchSuccess(matched_value, selected)
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
    for _, card in ipairs(selected) do
        if #card.attempts > 1 then
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

    -- Chain requirement progress - pick random unmatched value as next target
    if self.params.chain_requirement > 0 then
        self.chain_progress = self.chain_progress + 1
        if self.chain_progress >= self.params.chain_requirement then
            self.chain_progress = 0
        end
        -- Select next chain target (random unmatched)
        local unmatched = {}
        for i = 1, self.total_pairs do
            if not self.matched_pairs[i] then table.insert(unmatched, i) end
        end
        self.chain_target = #unmatched > 0 and unmatched[math.random(#unmatched)] or nil
    end

    self:playSound("match", 1.0)
end

function MemoryMatch:onMatchFailure(selected)
    self.current_combo = 0

    -- Apply mismatch penalty (inline from applyMismatchPenalty)
    local p = self.params
    if p.mismatch_penalty > 0 then
        if p.time_limit > 0 then
            self.time_remaining = math.max(0, self.time_remaining - p.mismatch_penalty)
        end
    end

    for _, card in ipairs(selected) do
        card.flip_state = "flipping_down"
    end
    self:playSound("mismatch", 0.8)
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

function MemoryMatch:mousemoved(x, y)
    if self.fog_controller then
        self.fog_controller:updateMousePosition(x, y)
    end
end

function MemoryMatch:mousepressed(x, y, button)
    local selected_count = #self.entity_controller:getEntitiesByFilter(function(e) return e.is_selected end)
    if self.memorize_phase or self.match_check_timer > 0 or selected_count >= self.params.match_requirement then return end

    -- Move limit check (VictoryCondition handles loss, just block input)
    if self.params.move_limit > 0 and self.moves_made >= self.params.move_limit then return end

    -- Find clicked card using EntityController hit testing
    local card = self.entity_controller:getEntityAtPoint(x, y, "card")

    if card and not self.matched_pairs[card.value] and not card.is_selected and card.flip_state ~= "flipping_up" then
        table.insert(card.attempts, self.time_elapsed)
        card.is_selected = true
        self.moves_made = self.moves_made + 1
        self.metrics.moves = self.moves_made

        card.flip_state = "flipping_up"
        card.flip_progress = 0

        self:playSound("flip_card", 0.7)

        if selected_count + 1 == self.params.match_requirement then
            self.match_check_timer = self.params.reveal_duration
        end
    end
end

--------------------------------------------------------------------------------
-- GAME STATE / VICTORY
--------------------------------------------------------------------------------

function MemoryMatch:checkComplete()
    if self.memorize_phase then return false end
    return MemoryMatch.super.checkComplete(self)
end

--------------------------------------------------------------------------------
-- SHUFFLE ANIMATION
--------------------------------------------------------------------------------

function MemoryMatch:startShuffle()
    local matched_pairs = self.matched_pairs
    local shuffleable = self.entity_controller:getEntitiesByFilter(function(card)
        return card.flip_state == "face_down"
            and not matched_pairs[card.value]
            and not card.is_selected
    end)

    if #shuffleable < 2 then return end

    local p = self.params
    self.entity_controller:animateGridShuffle(shuffleable, p.auto_shuffle_count, {
        start_x = self.start_x,
        start_y = self.start_y,
        cols = self.grid_cols,
        item_width = self.CARD_WIDTH,
        item_height = self.CARD_HEIGHT,
        spacing = p.card_spacing
    }, p.shuffle_animation_duration)
end

function MemoryMatch:completeShuffle()
    self.entity_controller:completeGridShuffle()
end

return MemoryMatch
