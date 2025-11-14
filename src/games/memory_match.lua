local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local MemoryMatchView = require('src.games.views.memory_match_view')
local FogOfWar = require('src.utils.game_components.fog_of_war')
local VariantLoader = require('src.utils.game_components.variant_loader')
local HUDRenderer = require('src.utils.game_components.hud_renderer')
local VictoryCondition = require('src.utils.game_components.victory_condition')
local EntityController = require('src.utils.game_components.entity_controller')
local MemoryMatch = BaseGame:extend('MemoryMatch')

-- Config-driven defaults with safe fallbacks
local MMCfg = (Config and Config.games and Config.games.memory_match) or {}
local CARD_WIDTH = (MMCfg.cards and MMCfg.cards.width) or 60
local CARD_HEIGHT = (MMCfg.cards and MMCfg.cards.height) or 80
local CARD_SPACING = (MMCfg.cards and MMCfg.cards.spacing) or 10
local CARD_ICON_PADDING = (MMCfg.cards and MMCfg.cards.icon_padding) or 10
local MEMORIZE_TIME_BASE = (MMCfg.timings and MMCfg.timings.memorize_time_base) or 5
local MATCH_VIEW_TIME = (MMCfg.timings and MMCfg.timings.match_view_time) or 1

function MemoryMatch:init(game_data, cheats, di, variant_override)
    MemoryMatch.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.memory_match) or MMCfg

    -- Phase 7: Initialize VariantLoader for simplified parameter loading
    local loader = VariantLoader:new(self.variant, runtimeCfg, {
        -- Card dimensions
        card_width = CARD_WIDTH,
        card_height = CARD_HEIGHT,
        card_spacing = CARD_SPACING,
        card_icon_padding = CARD_ICON_PADDING,
        -- Arena
        arena_width = (MMCfg.arena and MMCfg.arena.width) or 800,
        arena_height = (MMCfg.arena and MMCfg.arena.height) or 600,
        -- Timings
        flip_speed = 0.3,
        reveal_duration = 1.0,
        memorize_time_base = MEMORIZE_TIME_BASE,
        -- Scoring
        mismatch_penalty = 0,
        combo_multiplier = 0.0,
        speed_bonus = 0,
        perfect_bonus = 0,
        -- Constraints
        time_limit = 0,
        move_limit = 0,
        -- Auto shuffle
        auto_shuffle_interval = 0,
        auto_shuffle_count = 0,
        -- Visual effects
        gravity_enabled = false,
        card_rotation = false,
        spinning_cards = false,
        fog_of_war = 0
    })

    -- Update display name from variant (so window title shows correct name)
    if self.variant and self.variant.name then
        self.data.display_name = self.variant.name
        print("[MemoryMatch:init] Updated display name to: " .. self.variant.name)
    end

    -- Apply variant difficulty modifier (from Phase 1.1-1.2)
    local variant_difficulty = loader:getNumber('difficulty_modifier', 1.0)

    local speed_modifier_value = self.cheats.speed_modifier or 1.0
    local time_bonus_multiplier = 1.0 + (1.0 - speed_modifier_value)

    -- Card dimensions will be set after loading sprites (to match sprite size)
    self.CARD_WIDTH = nil
    self.CARD_HEIGHT = nil
    self.base_sprite_width = nil   -- Store original sprite dimensions for scaling
    self.base_sprite_height = nil
    -- Phase 7: Use VariantLoader for all parameter loading
    self.CARD_SPACING = loader:get('cards.spacing', CARD_SPACING)
    self.CARD_ICON_PADDING = loader:get('cards.icon_padding', CARD_ICON_PADDING)
    self.grid_padding = 10  -- Padding around the grid edges (reduced to maximize card space)

    self.game_width = loader:get('arena.width', loader.defaults.arena_width)
    self.game_height = loader:get('arena.height', loader.defaults.arena_height)

    -- Grid & Layout parameters
    local card_count_override = loader:getNumber('card_count', 0)

    local per_complexity = (MMCfg.pairs and MMCfg.pairs.per_complexity) or 6
    local pairs_count
    local total_cards

    if card_count_override > 0 then
        total_cards = card_count_override
        if total_cards % 2 ~= 0 then total_cards = total_cards - 1 end
        pairs_count = total_cards / 2
    else
        pairs_count = math.floor(per_complexity * self.difficulty_modifiers.complexity * variant_difficulty)
        total_cards = pairs_count * 2
    end

    self.total_pairs = pairs_count

    -- Grid columns (0 = auto-calculate square, non-zero = explicit)
    self.columns = loader:getNumber('columns', 0)

    -- Always calculate grid_cols and grid_rows for proper rectangular layouts
    if self.columns == 0 then
        -- Auto-calculate square-ish grid
        self.grid_cols = math.ceil(math.sqrt(total_cards))
        self.grid_rows = math.ceil(total_cards / self.grid_cols)
    else
        -- Use explicit columns
        self.grid_cols = self.columns
        self.grid_rows = math.ceil(total_cards / self.columns)
    end

    -- Keep grid_size for backward compatibility (use the larger dimension)
    self.grid_size = math.max(self.grid_cols, self.grid_rows)

    print("============ MEMORY MATCH INIT ============")
    print("Total cards: " .. total_cards)
    print("Grid: " .. self.grid_cols .. " cols x " .. self.grid_rows .. " rows")
    print("Grid positions: " .. (self.grid_cols * self.grid_rows))
    print("===========================================")

    -- Match requirement (2-4 cards)
    self.match_requirement = loader:getNumber('match_requirement', 2)

    -- Store pairs_count for later use
    self.pairs_count_for_sprites = pairs_count

    self.selected_indices = {}
    self.matched_pairs = {}

    -- Timing parameters
    self.flip_speed = loader:get('timings.flip_speed', loader.defaults.flip_speed)
    self.reveal_duration = loader:get('timings.reveal_duration', loader.defaults.reveal_duration)

    local memorize_time_var = loader:get('memorize_time', loader:get('timings.memorize_time_base', MEMORIZE_TIME_BASE))

    self.memorize_phase = memorize_time_var > 0
    self.memorize_timer = ((memorize_time_var / self.difficulty_modifiers.time_limit) * time_bonus_multiplier) / variant_difficulty
    self.match_check_timer = 0
    self.memorize_time_initial = self.memorize_timer  -- Store for later use

    self.auto_shuffle_interval = loader:getNumber('auto_shuffle_interval', 0)
    self.shuffle_timer = self.auto_shuffle_interval

    -- 0 = shuffle all face-down cards, N = shuffle only N random face-down cards
    self.auto_shuffle_count = loader:getNumber('auto_shuffle_count', 0)

    self.is_shuffling = false
    self.shuffle_animation_timer = 0
    self.shuffle_animation_duration = 1.0

    print(string.format("[MemoryMatch:init] Shuffle config: interval=%d seconds, count=%d cards",
        self.auto_shuffle_interval, self.auto_shuffle_count))

    -- Constraints parameters
    self.time_limit = loader:getNumber('time_limit', 0)
    self.time_remaining = self.time_limit

    self.move_limit = loader:getNumber('move_limit', 0)
    self.moves_made = 0

    -- Scoring parameters
    self.mismatch_penalty = loader:getNumber('mismatch_penalty', 0)
    self.combo_multiplier = loader:getNumber('combo_multiplier', 0.0)
    self.current_combo = 0
    self.speed_bonus = loader:getNumber('speed_bonus', 0)
    self.perfect_bonus = loader:getNumber('perfect_bonus', 0)

    -- Visual Effects parameters
    self.gravity_enabled = loader:getBoolean('gravity_enabled', false)
    self.card_rotation = loader:getBoolean('card_rotation', false)
    self.spinning_cards = loader:getBoolean('spinning_cards', false)
    self.fog_of_war = loader:getNumber('fog_of_war', 0)

    -- Fog spotlight size: 0.0-1.0, percentage of radius that's fully lit (0.6 = 60% inner clear, 40% gradient)
    self.fog_inner_radius = loader:getNumber('fog_inner_radius', 0.6)

    -- Fog darkness: 0.0-1.0, how dark the obscured area is (0.0 = pitch black, 1.0 = no obscuring)
    self.fog_darkness = loader:getNumber('fog_darkness', 0.1)

    -- Initialize FogOfWar component (alpha mode for per-card fog)
    self.fog_controller = FogOfWar:new({
        enabled = self.fog_of_war > 0,
        mode = "alpha",
        opacity = self.fog_darkness,
        inner_radius_multiplier = self.fog_inner_radius,
        outer_radius = self.fog_of_war
    })

    self.distraction_elements = loader:getBoolean('distraction_elements', false)
    self.distraction_particles = {}

    -- Challenge Mode parameters
    self.chain_requirement = loader:getNumber('chain_requirement', 0)
    self.chain_target = nil
    self.chain_progress = 0

    if self.chain_requirement > 0 then
        self:selectNextChainTarget()
    end

    -- Initialize metrics
    self.metrics.matches = 0
    self.metrics.perfect = 0
    self.metrics.time = 0
    self.metrics.combo = 0  -- Track highest combo
    self.metrics.moves = 0
    self.metrics.score = 0  -- Total score including bonuses

    -- Match announcement
    self.match_announcement = nil  -- Name to show
    self.match_announcement_timer = 0  -- How long to show it
    self.icon_filenames = {}  -- Map icon_id to filename

    -- Mouse tracking for fog of war (in game viewport coordinates)
    self.mouse_x = 0
    self.mouse_y = 0

    -- Physics constants for gravity mode
    self.GRAVITY_ACCEL = 600  -- Pixels per second squared
    self.FLOOR_BOUNCE = 0.3   -- Bounce damping
    self.CARD_MASS = 1.0

    -- Phase 2.3: Load sprite assets FIRST to determine card dimensions
    self:loadAssets()

    -- Set default card dimensions if sprites didn't provide them
    if not self.CARD_WIDTH or not self.CARD_HEIGHT then
        self.CARD_WIDTH = (runtimeCfg and runtimeCfg.cards and runtimeCfg.cards.width) or CARD_WIDTH
        self.CARD_HEIGHT = (runtimeCfg and runtimeCfg.cards and runtimeCfg.cards.height) or CARD_HEIGHT
        self.base_sprite_width = self.CARD_WIDTH
        self.base_sprite_height = self.CARD_HEIGHT
        print("[MemoryMatch:init] Using fallback card dimensions:", self.CARD_WIDTH, self.CARD_HEIGHT)
    end

    -- NOW calculate grid position (needs CARD_WIDTH and CARD_HEIGHT)
    self:calculateGridPosition()

    -- Phase 11: EntityController for cards
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

    -- Create cards after sprites are loaded and dimensions are set
    self.cards = {}
    self:createCards(pairs_count)

    -- Standard HUD (Phase 8)
    self.hud = HUDRenderer:new({
        primary = {label = "Matches", key = "matches"},
        secondary = {label = "Moves", key = "moves"},
        timer = {label = "Time", key = "time_elapsed", format = "float"}
    })
    self.hud.game = self

    -- Victory Condition System (Phase 9)
    local victory_config = {
        victory = {type = "threshold", metric = "metrics.matches", target = self.total_pairs},
        loss = {type = "none"},
        check_loss_first = false
    }

    -- Add loss conditions if applicable
    if self.time_limit > 0 then
        victory_config.loss = {type = "time_expired", metric = "time_remaining"}
    elseif self.move_limit > 0 then
        victory_config.loss = {type = "move_limit", moves_metric = "moves_made", limit_metric = "move_limit"}
    end

    self.victory_checker = VictoryCondition:new(victory_config)
    self.victory_checker.game = self

    -- Audio/visual variant data (Phase 1.3)
    self.view = MemoryMatchView:new(self, self.variant)
    print("[MemoryMatch:init] Initialized with card dimensions:", self.CARD_WIDTH, self.CARD_HEIGHT)
    print("[MemoryMatch:init] Variant:", self.variant and self.variant.name or "Default")
end

-- Phase 2.3: Asset loading with fallback - SCANS DIRECTORY FOR ALL IMAGES
function MemoryMatch:loadAssets()
    self.sprites = {}

    -- Default to "flags" if no sprite_set specified
    local sprite_set = (self.variant and self.variant.sprite_set) or "flags"

    local game_type = "memory_match"
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
        if filename:match("%.png$") and filename ~= "card_back.png" and filename ~= "launcher_icon.png" then
            table.insert(icon_files, filename)
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

    -- Phase 3.3: Load audio - using BaseGame helper
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
        if self.cards and not self.gravity_enabled then
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
    if self.chain_requirement > 0 then hud_height = hud_height + 20 end
    if self.perfect_bonus > 0 then hud_height = hud_height + 20 end
    if self.time_limit > 0 then hud_height = hud_height + 20 end
    if self.move_limit > 0 then hud_height = hud_height + 20 end
    if self.combo_multiplier > 1 then hud_height = hud_height + 20 end
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
    -- Phase 11: Sync cards array with EntityController
    self.cards = self.entity_controller:getEntities()

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
        if self.time_limit > 0 then
            self.time_remaining = math.max(0, self.time_remaining - dt)
            if self.time_remaining <= 0 then
                self.is_failed = true  -- Time's up
            end
        end

        -- Auto-shuffle timer
        if self.auto_shuffle_interval > 0 and not self.is_shuffling then
            self.shuffle_timer = self.shuffle_timer - dt
            if self.shuffle_timer <= 0 then
                print(string.format("[MemoryMatch] Shuffle timer triggered! (interval: %d, count: %d)",
                    self.auto_shuffle_interval, self.auto_shuffle_count))
                self:startShuffle()
                self.shuffle_timer = self.auto_shuffle_interval
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
                card.flip_progress = math.min(1, card.flip_progress + dt / self.flip_speed)
                if card.flip_progress >= 1 then
                    card.flip_state = "face_up"
                    card.flip_progress = 1
                end
            elseif card.flip_state == "flipping_down" then
                card.flip_progress = math.max(0, card.flip_progress - dt / self.flip_speed)
                if card.flip_progress <= 0 then
                    card.flip_state = "face_down"
                    card.flip_progress = 0
                end
            end
        end

        -- Gravity physics
        if self.gravity_enabled then
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
                    if self.chain_requirement > 0 and self.chain_target then
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
                            self.match_announcement_timer = 2.0  -- Show for 2 seconds

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
                            -- Apply perfect bonus to score
                            if self.perfect_bonus > 0 then
                                self.metrics.score = self.metrics.score + self.perfect_bonus
                            end
                        end

                        -- Combo system - ALWAYS track combo for power formula
                        self.current_combo = self.current_combo + 1
                        self.metrics.combo = math.max(self.metrics.combo, self.current_combo)

                        -- Apply combo bonus to score (only if combo_multiplier is set)
                        if self.combo_multiplier > 0 then
                            local combo_bonus = math.floor(10 * self.combo_multiplier * self.current_combo)
                            self.metrics.score = self.metrics.score + combo_bonus
                        end

                        -- Base match points
                        self.metrics.score = self.metrics.score + 10

                        -- Chain requirement progress
                        if self.chain_requirement > 0 then
                            self.chain_progress = self.chain_progress + 1
                            if self.chain_progress >= self.chain_requirement then
                                self.chain_progress = 0
                            end
                            self:selectNextChainTarget()
                        end

                        self:playSound("match", 1.0)
                    else
                        -- Wrong chain target - flip cards back down
                        self.current_combo = 0
                        if self.mismatch_penalty > 0 then
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
                    if self.mismatch_penalty > 0 then
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

    if self.memorize_phase or self.match_check_timer > 0 or #self.selected_indices >= self.match_requirement then return end

    -- Check move limit
    if self.move_limit > 0 and self.moves_made >= self.move_limit then
        self.is_failed = true
        print("[MemoryMatch] Game over: Move limit exceeded (" .. self.moves_made .. "/" .. self.move_limit .. ")")
        return
    end

    for i, card in ipairs(self.cards) do
        -- Use physics position if gravity enabled, grid position otherwise
        local card_x, card_y
        if self.gravity_enabled then
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

                -- Phase 3.3: Play flip sound
                self:playSound("flip_card", 0.7)

                if #self.selected_indices == self.match_requirement then
                    self.match_check_timer = self.reveal_duration
                end
                break
            end
        end
    end
end

function MemoryMatch:createCards(pairs_count)
    for i = 1, pairs_count do
        for j = 1, self.match_requirement do
            local card_index = #self.cards + 1
            local row = math.floor((card_index-1) / self.grid_cols)
            local col = (card_index-1) % self.grid_cols

            -- Cards start face up during memorize phase
            local initial_flip_state = self.memorize_phase and "face_up" or "face_down"
            local initial_flip_progress = self.memorize_phase and 1 or 0

            -- In gravity mode, spawn cards at top with random X spread
            local init_x, init_y, init_vx, init_vy
            if self.gravity_enabled then
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

            table.insert(self.cards, {
                value = i,
                attempts = {},
                -- Flip animation state
                flip_state = initial_flip_state,  -- "face_down", "flipping_up", "face_up", "flipping_down"
                flip_progress = initial_flip_progress,  -- 0-1 animation progress
                -- Physics for gravity mode
                x = init_x,
                y = init_y,
                vx = init_vx,  -- Velocity X
                vy = init_vy,  -- Velocity Y
                grid_row = row,
                grid_col = col,
                icon_id = i  -- Icon identifier for sprite lookup
            })
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
        if not self.gravity_enabled then
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

    -- Phase 9: Check penalty failure first
    if self.is_failed then
        self.victory = false
        self.game_over = true
        return true
    end

    -- Phase 9: Use VictoryCondition component
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

-- Phase 3.3: Override onComplete to play success sound
function MemoryMatch:onComplete()
    -- Calculate speed bonus if time limit exists
    if self.time_limit > 0 and self.speed_bonus > 0 then
        local time_bonus = math.floor(self.time_remaining * self.speed_bonus)
        self.metrics.score = self.metrics.score + time_bonus
        print(string.format("[MemoryMatch] Speed bonus: %d points (%d seconds * %d)",
            time_bonus, math.floor(self.time_remaining), self.speed_bonus))
    end

    print(string.format("[MemoryMatch] Final score: %d points", self.metrics.score))

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
    local shuffle_count = self.auto_shuffle_count
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

-- Helper function: Select next chain target
function MemoryMatch:selectNextChainTarget()
    if self.chain_requirement == 0 then return end

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

-- Helper function: Apply mismatch penalty
function MemoryMatch:applyMismatchPenalty()
    if self.time_limit > 0 then
        -- Reduce time remaining
        self.time_remaining = math.max(0, self.time_remaining - self.mismatch_penalty)
        -- Check if time ran out due to penalty
        if self.time_remaining <= 0 then
            self.is_failed = true
            print("[MemoryMatch] Game over: Time penalty exceeded time limit")
        end
    elseif self.mismatch_penalty > 0 then
        -- No time limit, but penalty exists - treat any penalty as instant fail
        self.is_failed = true
        print("[MemoryMatch] Game over: Mismatch penalty with no time limit (instant fail)")
    end
    -- Could also apply score penalty here if scoring system is added
end

return MemoryMatch