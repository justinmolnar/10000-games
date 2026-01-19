local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local MemoryMatchView = require('src.games.views.memory_match_view')
local FogOfWar = require('src.utils.game_components.fog_of_war')
local SchemaLoader = require('src.utils.game_components.schema_loader')
local HUDRenderer = require('src.utils.game_components.hud_renderer')
local VictoryCondition = require('src.utils.game_components.victory_condition')
local EntityController = require('src.utils.game_components.entity_controller')
local MemoryMatch = BaseGame:extend('MemoryMatch')

function MemoryMatch:init(game_data, cheats, di, variant_override)
    MemoryMatch.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    self.cheats = cheats or {}

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.memory_match)
    self.params = SchemaLoader.load(self.variant, "memory_match_schema", runtimeCfg)

    if self.variant and self.variant.name then
        self.data.display_name = self.variant.name
    end

    self:applyModifiers()
    self:setupGameState()
    self:setupComponents()

    self.view = MemoryMatchView:new(self, self.variant)
end

function MemoryMatch:applyModifiers()
    self.speed_modifier_value = self.cheats.speed_modifier or 1.0
    self.time_bonus_multiplier = 1.0 + (1.0 - self.speed_modifier_value)
    self.variant_difficulty = self.params.difficulty_modifier
end

function MemoryMatch:setupGameState()
    -- Card dimensions (set after loading sprites)
    self.CARD_WIDTH = nil
    self.CARD_HEIGHT = nil
    self.base_sprite_width = nil
    self.base_sprite_height = nil
    self.CARD_SPACING = 10
    self.CARD_ICON_PADDING = 10
    self.grid_padding = 10

    self.game_width = 800
    self.game_height = 600

    -- Calculate pairs from card_count or complexity
    local card_count_override = self.params.card_count
    local per_complexity = 6
    local pairs_count
    local total_cards

    if card_count_override > 0 then
        total_cards = card_count_override
        if total_cards % 2 ~= 0 then total_cards = total_cards - 1 end
        pairs_count = total_cards / 2
    else
        pairs_count = math.floor(per_complexity * self.difficulty_modifiers.complexity * self.variant_difficulty)
        total_cards = pairs_count * 2
    end

    self.total_pairs = pairs_count
    self.pairs_count_for_sprites = pairs_count

    -- Grid layout
    if self.params.columns == 0 then
        self.grid_cols = math.ceil(math.sqrt(total_cards))
        self.grid_rows = math.ceil(total_cards / self.grid_cols)
    else
        self.grid_cols = self.params.columns
        self.grid_rows = math.ceil(total_cards / self.params.columns)
    end
    self.grid_size = math.max(self.grid_cols, self.grid_rows)

    -- Card selection state
    self.selected_indices = {}
    self.matched_pairs = {}

    -- Timing state
    local memorize_time_var = self.params.memorize_time
    self.memorize_phase = memorize_time_var > 0
    self.memorize_timer = ((memorize_time_var / self.difficulty_modifiers.time_limit) * self.time_bonus_multiplier) / self.variant_difficulty
    self.match_check_timer = 0
    self.memorize_time_initial = self.memorize_timer

    self.shuffle_timer = self.params.auto_shuffle_interval
    self.is_shuffling = false
    self.shuffle_animation_timer = 0
    self.shuffle_animation_duration = 1.0

    -- Constraint state
    self.time_remaining = self.params.time_limit
    self.moves_made = 0

    -- Combo state
    self.current_combo = 0

    -- Challenge mode state
    self.chain_target = nil
    self.chain_progress = 0
    if self.params.chain_requirement > 0 then
        self:selectNextChainTarget()
    end

    -- Distraction particles
    self.distraction_particles = {}

    -- Metrics
    self.metrics.matches = 0
    self.metrics.perfect = 0
    self.metrics.time = 0
    self.metrics.combo = 0
    self.metrics.moves = 0
    self.metrics.score = 0

    -- Match announcement
    self.match_announcement = nil
    self.match_announcement_timer = 0
    self.icon_filenames = {}

    -- Mouse tracking for fog of war
    self.mouse_x = 0
    self.mouse_y = 0

    -- Physics constants for gravity mode
    self.GRAVITY_ACCEL = 600
    self.FLOOR_BOUNCE = 0.3
    self.CARD_MASS = 1.0

    -- Load sprite assets to determine card dimensions
    self:loadAssets()

    -- Set default card dimensions if sprites didn't provide them
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.memory_match)
    if not self.CARD_WIDTH or not self.CARD_HEIGHT then
        self.CARD_WIDTH = (runtimeCfg and runtimeCfg.cards and runtimeCfg.cards.width) or 60
        self.CARD_HEIGHT = (runtimeCfg and runtimeCfg.cards and runtimeCfg.cards.height) or 80
        self.base_sprite_width = self.CARD_WIDTH
        self.base_sprite_height = self.CARD_HEIGHT
    end

    self:calculateGridPosition()

    -- EntityController must be created before cards
    self.entity_controller = EntityController:new({
        entity_types = {
            ["card"] = {
                flipped = false,
                matched = false
            }
        },
        spawning = {mode = "manual"},
        pooling = false,
        max_entities = 100
    })

    -- Create cards
    self.cards = {}
    self:createCards(self.total_pairs)
end

function MemoryMatch:setupComponents()
    -- FogOfWar component
    self.fog_controller = FogOfWar:new({
        enabled = self.params.fog_of_war > 0,
        mode = "alpha",
        opacity = self.params.fog_darkness,
        inner_radius_multiplier = self.params.fog_inner_radius,
        outer_radius = self.params.fog_of_war
    })

    -- Note: entity_controller created in setupGameState() before createCards()

    -- HUD
    self.hud = HUDRenderer:new({
        primary = {label = "Matches", key = "metrics.matches"},
        secondary = {label = "Moves", key = "metrics.moves"},
        timer = {label = "Time", key = "time_elapsed", format = "float"}
    })
    self.hud.game = self

    -- Victory Condition
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
end

function MemoryMatch:loadAssets()
    self.sprites = {}

    -- Default to "flags" if no sprite_set specified
    local sprite_set = (self.variant and self.variant.sprite_set) or "flags"

    local game_type = "memory"
    local base_path = "assets/sprites/games/" .. game_type .. "/" .. sprite_set

    -- Try to load card back
    local card_back_path = base_path .. "/card_back.png"
    local success, card_back = pcall(function()
        return love.graphics.newImage(card_back_path)
    end)

    if success then
        self.sprites.card_back = card_back
        print("[MemoryMatch:loadAssets] Loaded card_back: " .. card_back_path)
    else
        print("[MemoryMatch:loadAssets] No card_back.png found, using fallback")
    end

    -- Scan directory for all .png files (excluding card_back.png)
    local icon_files = {}
    local files = love.filesystem.getDirectoryItems(base_path)

    for _, filename in ipairs(files) do
        if filename:lower():match("%.png$") and filename:lower() ~= "card_back.png" and filename:lower() ~= "launcher_icon.png" then
            table.insert(icon_files, filename)
        end
    end

    -- Failsafe: If no icons found, try forcing the memory/flags path
    if #icon_files == 0 then
        print("[MemoryMatch:loadAssets] No icons found in " .. base_path .. ", trying fallback to assets/sprites/games/memory/flags")
        base_path = "assets/sprites/games/memory/flags"
        
        -- Try loading card back again from fallback path
        local fallback_card_back = base_path .. "/card_back.png"
        local cb_success, cb_img = pcall(function() return love.graphics.newImage(fallback_card_back) end)
        if cb_success then
            self.sprites.card_back = cb_img
        end

        files = love.filesystem.getDirectoryItems(base_path)
        for _, filename in ipairs(files) do
            if filename:lower():match("%.png$") and filename:lower() ~= "card_back.png" and filename:lower() ~= "launcher_icon.png" then
                table.insert(icon_files, filename)
            end
        end
    end

    if #icon_files == 0 then
        print("[MemoryMatch:loadAssets] No icon sprites found in " .. base_path .. ", using fallback")
        self:loadAudio()
        return
    end

    -- Shuffle icon files for randomness
    -- Re-seed with current time to ensure different selection each game
    math.randomseed(os.time() + love.timer.getTime() * 1000)
    -- Discard first few random values (Lua RNG warmup)
    for _ = 1, 3 do math.random() end

    for i = #icon_files, 2, -1 do
        local j = math.random(i)
        icon_files[i], icon_files[j] = icon_files[j], icon_files[i]
    end

    -- Load as many as we need (up to total available)
    local needed_icons = self.total_pairs
    local icons_to_load = math.min(needed_icons, #icon_files)

    print(string.format("[MemoryMatch:loadAssets] Found %d sprites, need %d pairs, loading %d random icons",
        #icon_files, needed_icons, icons_to_load))

    local first_sprite_loaded = false
    for i = 1, icons_to_load do
        local filename = icon_files[i]
        local filepath = base_path .. "/" .. filename
        local load_success, sprite = pcall(function()
            return love.graphics.newImage(filepath)
        end)

        if load_success then
            self.sprites["icon_" .. i] = sprite

            -- Store filename for match announcements (remove .png extension)
            local display_name = filename:gsub("%.png$", ""):gsub("%.PNG$", "")
            self.icon_filenames[i] = display_name

            print("[MemoryMatch:loadAssets] Loaded icon " .. i .. ": " .. filename)

            -- Use first loaded sprite to determine base card dimensions
            if not first_sprite_loaded then
                self.base_sprite_width = sprite:getWidth()
                self.base_sprite_height = sprite:getHeight()
                -- Initial card size = sprite size (will be scaled in calculateGridPosition)
                self.CARD_WIDTH = self.base_sprite_width
                self.CARD_HEIGHT = self.base_sprite_height
                print(string.format("[MemoryMatch:loadAssets] Base sprite dimensions: %dx%d",
                    self.base_sprite_width, self.base_sprite_height))
                first_sprite_loaded = true
            end
        else
            print("[MemoryMatch:loadAssets] Failed to load: " .. filepath)
        end
    end

    print(string.format("[MemoryMatch:loadAssets] Loaded %d sprites for variant: %s",
        self:countLoadedSprites(), self.variant.name or "Unknown"))

    self:loadAudio()
end

function MemoryMatch:countLoadedSprites()
    local count = 0
    for _ in pairs(self.sprites) do
        count = count + 1
    end
    return count
end

function MemoryMatch:hasSprite(sprite_key)
    return self.sprites and self.sprites[sprite_key] ~= nil
end

function MemoryMatch:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height

    -- Only recalculate if we have the required constants
    if self.CARD_WIDTH and self.CARD_HEIGHT and self.CARD_SPACING and self.grid_size then
        -- Recalculate grid position and card scaling
        self:calculateGridPosition()

        -- Update card positions for non-gravity mode
        if self.cards and not self.params.gravity_enabled then
            for i, card in ipairs(self.cards) do
                local row = math.floor((i-1) / self.grid_cols)
                local col = (i-1) % self.grid_cols
                card.x = self.start_x + col * (self.CARD_WIDTH + self.CARD_SPACING)
                card.y = self.start_y + row * (self.CARD_HEIGHT + self.CARD_SPACING)
            end
        end

        print("[MemoryMatch] Play area updated to:", width, height)
    else
        print("[MemoryMatch] setPlayArea called before init completed, dimensions stored for later")
    end
end

function MemoryMatch:calculateGridPosition()
    -- If we don't have base sprite dimensions yet, use current card dimensions
    local base_width = self.base_sprite_width or self.CARD_WIDTH
    local base_height = self.base_sprite_height or self.CARD_HEIGHT

    if not base_width or not base_height then
        print("[MemoryMatch:calculateGridPosition] No dimensions available, skipping")
        return
    end

    -- Calculate HUD height (reserve space at top for HUD)
    -- HUD has variable height based on active features, estimate conservatively
    local hud_height = 10  -- Top margin
    hud_height = hud_height + 20  -- Matches row (always shown)
    hud_height = hud_height + 20  -- Time row (always shown)
    if self.params.chain_requirement > 0 then hud_height = hud_height + 20 end
    if self.params.perfect_bonus > 0 then hud_height = hud_height + 20 end
    if self.params.time_limit > 0 then hud_height = hud_height + 20 end
    if self.params.move_limit > 0 then hud_height = hud_height + 20 end
    if self.params.combo_multiplier > 1 then hud_height = hud_height + 20 end
    hud_height = hud_height + 20  -- Bottom margin for HUD

    -- Calculate available space (minus padding and HUD)
    local available_width = self.game_width - (self.grid_padding * 2)
    local available_height = self.game_height - hud_height - (self.grid_padding * 2)

    -- Determine grid dimensions (rows and columns)
    if not self.grid_cols or not self.grid_rows then
        print("[MemoryMatch:calculateGridPosition] Grid dimensions not initialized yet")
        return
    end

    local cols = self.grid_cols
    local rows = self.grid_rows

    -- Calculate maximum card dimensions that would fit
    -- Account for spacing between cards
    local total_spacing_width = self.CARD_SPACING * (cols - 1)
    local total_spacing_height = self.CARD_SPACING * (rows - 1)

    local max_card_width = (available_width - total_spacing_width) / cols
    local max_card_height = (available_height - total_spacing_height) / rows

    -- Calculate scale factors for each dimension
    local scale_for_width = max_card_width / base_width
    local scale_for_height = max_card_height / base_height

    -- Use the smaller scale factor (whichever hits limit first)
    local scale = math.min(scale_for_width, scale_for_height)

    -- Apply scale to get final card dimensions (maintain aspect ratio)
    self.CARD_WIDTH = base_width * scale
    self.CARD_HEIGHT = base_height * scale

    -- Calculate total grid dimensions with scaled cards
    local total_grid_width = (self.CARD_WIDTH + self.CARD_SPACING) * cols - self.CARD_SPACING
    local total_grid_height = (self.CARD_HEIGHT + self.CARD_SPACING) * rows - self.CARD_SPACING

    -- Ensure grid fits (shouldn't happen with correct math, but safety check)
    if total_grid_height > available_height then
        print(string.format("[MemoryMatch] ERROR: Grid doesn't fit! grid_height=%.1f > available_height=%.1f",
            total_grid_height, available_height))
        print(string.format("  cols=%d, rows=%d, card_size=%.1fx%.1f, spacing=%d",
            cols, rows, self.CARD_WIDTH, self.CARD_HEIGHT, self.CARD_SPACING))
    end

    -- Center the grid in available space (horizontally centered, vertically below HUD)
    self.start_x = (self.game_width - total_grid_width) / 2
    -- Don't center vertically if grid is too tall - align to top instead
    if total_grid_height <= available_height then
        self.start_y = hud_height + ((available_height - total_grid_height) / 2)
    else
        self.start_y = hud_height + self.grid_padding
    end
end

function MemoryMatch:updateGameLogic(dt)
    -- Note: self.cards is already populated by createCards() and shuffled by shuffleCards()
    -- Do NOT sync with entity_controller:getEntities() as it returns spawn order, not shuffled order

    if self.memorize_phase then
        self.memorize_timer = self.memorize_timer - dt
        if self.memorize_timer <= 0 then
            self.memorize_phase = false
            self.time_elapsed = 0

            -- Flip all cards down when memorize phase ends
            for _, card in ipairs(self.cards) do
                card.flip_state = "flipping_down"
                card.flip_progress = 1  -- Start from face_up
            end

            -- DO NOT shuffle after memorize - that defeats the purpose!
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
                self.is_failed = true  -- Time's up
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
            if self.shuffle_animation_timer >= self.shuffle_animation_duration then
                print(string.format("[MemoryMatch] Shuffle animation finished (%.2f >= %.2f)",
                    self.shuffle_animation_timer, self.shuffle_animation_duration))
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
            for i, card in ipairs(self.cards) do
                if not self.matched_pairs[card.value] then
                    -- Apply gravity
                    card.vy = card.vy + self.GRAVITY_ACCEL * dt

                    -- Update position
                    card.x = card.x + card.vx * dt
                    card.y = card.y + card.vy * dt

                    -- Floor collision
                    local floor_y = self.game_height - self.CARD_HEIGHT
                    if card.y >= floor_y then
                        card.y = floor_y
                        card.vy = card.vy * -self.FLOOR_BOUNCE
                        if math.abs(card.vy) < 10 then
                            card.vy = 0  -- Stop bouncing when velocity is low
                        end
                    end

                    -- Side wall collision
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
                -- Check if all selected cards match
                local all_match = true
                local first_value = self.cards[self.selected_indices[1]].value

                for i = 2, #self.selected_indices do
                    if self.cards[self.selected_indices[i]].value ~= first_value then
                        all_match = false
                        break
                    end
                end

                if all_match then
                    -- Check chain requirement
                    local chain_valid = true
                    if self.params.chain_requirement > 0 and self.chain_target then
                        chain_valid = (first_value == self.chain_target)
                    end

                    if chain_valid then
                        -- Cards match!
                        self.matched_pairs[first_value] = true
                        self.metrics.matches = self.metrics.matches + 1

                        -- Show match announcement with sprite name
                        if self.icon_filenames[first_value] then
                            local filename = self.icon_filenames[first_value]
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
                    else
                        -- Wrong chain target - flip cards back down
                        self.current_combo = 0
                        if self.params.mismatch_penalty > 0 then
                            self:applyMismatchPenalty()
                        end
                        -- Start flip down animation
                        for _, idx in ipairs(self.selected_indices) do
                            self.cards[idx].flip_state = "flipping_down"
                        end
                        self:playSound("mismatch", 0.8)
                    end
                else
                    -- Cards don't match - flip back down
                    self.current_combo = 0
                    if self.params.mismatch_penalty > 0 then
                        self:applyMismatchPenalty()
                    end
                    -- Start flip down animation
                    for _, idx in ipairs(self.selected_indices) do
                        self.cards[idx].flip_state = "flipping_down"
                    end
                    self:playSound("mismatch", 0.8)
                end
                self.selected_indices = {}
            end
        end
    end
end

function MemoryMatch:draw()
    if self.view then
        self.view:draw()
    end
end

function MemoryMatch:mousemoved(x, y, dx, dy)
    -- Track mouse position for fog of war
    self.mouse_x = x
    self.mouse_y = y
end

function MemoryMatch:mousepressed(x, y, button)
    -- Update mouse position
    self.mouse_x = x
    self.mouse_y = y

    if self.memorize_phase or self.match_check_timer > 0 or #self.selected_indices >= self.params.match_requirement then return end

    -- Check move limit
    if self.params.move_limit > 0 and self.moves_made >= self.params.move_limit then
        self.is_failed = true
        return
    end

    for i, card in ipairs(self.cards) do
        -- Use physics position if gravity enabled, grid position otherwise
        local card_x, card_y
        if self.params.gravity_enabled then
            card_x = card.x
            card_y = card.y
        else
            local row = math.floor((i-1) / self.grid_cols)
            local col = (i-1) % self.grid_cols
            card_x = self.start_x + col * (self.CARD_WIDTH + self.CARD_SPACING)
            card_y = self.start_y + row * (self.CARD_HEIGHT + self.CARD_SPACING)
        end

        if x >= card_x and x <= card_x + self.CARD_WIDTH and y >= card_y and y <= card_y + self.CARD_HEIGHT then
            if not self.matched_pairs[card.value] and not self:isSelected(i) and card.flip_state ~= "flipping_up" then
                table.insert(card.attempts, self.time_elapsed)
                table.insert(self.selected_indices, i)
                self.moves_made = self.moves_made + 1
                self.metrics.moves = self.moves_made

                -- Start flip animation
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

function MemoryMatch:createCards(pairs_count)
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
                init_x = self.start_x + col * (self.CARD_WIDTH + self.CARD_SPACING) + (math.random() - 0.5) * 20
                init_y = -self.CARD_HEIGHT - row * 30  -- Start above screen
                init_vx = (math.random() - 0.5) * 50
                init_vy = math.random() * 100
            else
                init_x = self.start_x + col * (self.CARD_WIDTH + self.CARD_SPACING)
                init_y = self.start_y + row * (self.CARD_HEIGHT + self.CARD_SPACING)
                init_vx = 0
                init_vy = 0
            end

            local card = self.entity_controller:spawn("card", init_x, init_y, {
                value = i,
                attempts = {},
                -- Flip animation state
                flip_state = initial_flip_state,  -- "face_down", "flipping_up", "face_up", "flipping_down"
                flip_progress = initial_flip_progress,  -- 0-1 animation progress
                -- Physics for gravity mode
                vx = init_vx,
                vy = init_vy,
                grid_row = row,
                grid_col = col,
                icon_id = i,  -- Icon identifier for sprite lookup
                width = self.CARD_WIDTH,
                height = self.CARD_HEIGHT
            })
            
            -- Also add to local cards list for initial shuffle
            if card then
                table.insert(self.cards, card)
            else
                print("[MemoryMatch:createCards] Failed to spawn card entity!")
            end
        end
    end
    self:shuffleCards()
end

function MemoryMatch:shuffleCards()
    -- Shuffle card values and icon assignments
    for i = #self.cards, 2, -1 do
        local j = math.random(i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end

    -- Update grid positions and physics positions after shuffle
    for i, card in ipairs(self.cards) do
        local row = math.floor((i-1) / self.grid_cols)
        local col = (i-1) % self.grid_cols
        card.grid_row = row
        card.grid_col = col

        -- Reset to grid position if not in gravity mode
        if not self.params.gravity_enabled then
            card.x = self.start_x + col * (self.CARD_WIDTH + self.CARD_SPACING)
            card.y = self.start_y + row * (self.CARD_HEIGHT + self.CARD_SPACING)
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
    -- Calculate speed bonus if time limit exists
    if self.params.time_limit > 0 and self.params.speed_bonus > 0 then
        local time_bonus = math.floor(self.time_remaining * self.params.speed_bonus)
        self.metrics.score = self.metrics.score + time_bonus
    end

    -- All matches found = win
    self:playSound("success", 1.0)

    -- Stop music
    self:stopMusic()

    -- Call parent onComplete
    MemoryMatch.super.onComplete(self)
end

function MemoryMatch:keypressed(key)
    -- Call parent to handle virtual key tracking for demo playback
    MemoryMatch.super.keypressed(self, key)
    return false
end

-- Helper function: Start shuffle animation
function MemoryMatch:startShuffle()
    print("[MemoryMatch:startShuffle] Starting shuffle check...")

    -- Find all face-down cards (not matched, not selected, not flipping)
    local face_down_indices = {}
    local debug_counts = {face_down = 0, matched = 0, selected = 0, flipping = 0}

    for i, card in ipairs(self.cards) do
        local is_face_down = (card.flip_state == "face_down")
        local not_matched = not self.matched_pairs[card.value]
        local not_selected = not self:isSelected(i)
        local not_flipping = (card.flip_state ~= "flipping_up" and card.flip_state ~= "flipping_down")

        -- Debug counts
        if card.flip_state == "face_down" then debug_counts.face_down = debug_counts.face_down + 1 end
        if card.flip_state == "flipping_up" or card.flip_state == "flipping_down" or card.flip_state == "face_up" then
            debug_counts.flipping = debug_counts.flipping + 1
        end
        if self.matched_pairs[card.value] then debug_counts.matched = debug_counts.matched + 1 end
        if self:isSelected(i) then debug_counts.selected = debug_counts.selected + 1 end

        if is_face_down and not_matched and not_selected and not_flipping then
            table.insert(face_down_indices, i)
        end
    end

    print(string.format("[MemoryMatch:startShuffle] Card states: face_down=%d, flipping/up=%d, matched=%d, selected=%d, eligible=%d",
        debug_counts.face_down, debug_counts.flipping, debug_counts.matched, debug_counts.selected, #face_down_indices))

    -- Edge case: Need at least 2 cards to shuffle
    if #face_down_indices < 2 then
        print("[MemoryMatch:startShuffle] Not enough face-down cards to shuffle (" .. #face_down_indices .. " available)")
        return
    end

    -- Determine how many cards to shuffle
    local shuffle_count = self.params.auto_shuffle_count
    if shuffle_count == 0 or shuffle_count > #face_down_indices then
        shuffle_count = #face_down_indices  -- Shuffle all
    end

    -- Edge case: If only shuffling 1 card, there's nothing to shuffle with
    if shuffle_count < 2 then
        print("[MemoryMatch:startShuffle] Shuffle count too low (" .. shuffle_count .. "), need at least 2")
        return
    end

    -- Randomly select which cards to shuffle
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

    -- Store current visual positions for ALL cards (for animation)
    self.shuffle_start_positions = {}
    for i, card in ipairs(self.cards) do
        local row = math.floor((i-1) / self.grid_cols)
        local col = (i-1) % self.grid_cols
        local x = self.start_x + col * (self.CARD_WIDTH + self.CARD_SPACING)
        local y = self.start_y + row * (self.CARD_HEIGHT + self.CARD_SPACING)
        self.shuffle_start_positions[i] = {x = x, y = y}
    end

    -- Shuffle the selected card OBJECTS in the array
    -- This makes them actually swap positions in the grid
    -- IMPORTANT: We need to ensure cards swap with DIFFERENT indices for visual movement
    for i = #selected_indices, 2, -1 do
        local j = math.random(i - 1)  -- Pick from 1 to i-1, never i itself!
        local idx1 = selected_indices[i]
        local idx2 = selected_indices[j]
        print(string.format("[MemoryMatch:startShuffle] Swapping cards at indices %d ↔ %d", idx1, idx2))
        -- Swap the card objects AND their start positions
        -- This ensures cards animate FROM where they were TO where they're going
        self.cards[idx1], self.cards[idx2] = self.cards[idx2], self.cards[idx1]
        self.shuffle_start_positions[idx1], self.shuffle_start_positions[idx2] =
            self.shuffle_start_positions[idx2], self.shuffle_start_positions[idx1]
    end

    -- Start animation
    self.is_shuffling = true
    self.shuffle_animation_timer = 0

    print(string.format("[MemoryMatch:startShuffle] Shuffling %d of %d face-down cards. Animation started, is_shuffling=%s",
        shuffle_count, #face_down_indices, tostring(self.is_shuffling)))
end

-- Helper function: Complete shuffle
function MemoryMatch:completeShuffle()
    print("[MemoryMatch:completeShuffle] Animation complete, clearing is_shuffling flag")
    self.is_shuffling = false
    self.shuffle_start_positions = nil
end

function MemoryMatch:selectNextChainTarget()
    if self.params.chain_requirement == 0 then return end

    -- Find unmatched card values
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