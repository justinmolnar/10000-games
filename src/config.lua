-- config.lua: Central configuration for game tuning parameters

local Config = {
    -- Player Data
    start_tokens = 20,
    upgrade_costs = {
        cpu_speed = 500, -- Base cost for level 1
        overclock = 1000,
        auto_dodge = 2000 
        -- Cost multiplier per level: base_cost * (current_level + 1)
    },

    -- VM Manager
    vm_base_cost = 1000, -- Base cost for the first additional VM slot (slot #2)
    vm_cost_exponent = 2, -- Cost scales as base_cost * (exponent ^ (current_slots - 1))
    vm_max_slots = 10,
    vm_base_cycle_time = 60, -- Seconds per cycle before upgrades
    vm_cpu_speed_bonus_per_level = 0.1, -- 10% faster per level
    vm_overclock_bonus_per_level = 0.05, -- 5% more power per level

    -- Game Data
    -- Game Cloning
    clone_cost_exponent = 0.8,            -- Cost scales as base_cost * (multiplier ^ cost_exponent)
    clone_difficulty_step = 5, -- Every 5 clones, the difficulty level increases by 1
    scaling_constant = 1, -- Global scaling modifier applied to ALL game formulas (separate from clone_index multiplier)
    
    -- Auto-Play Performance Scaling (relative to base auto-play performance)
    auto_play_scaling = {
        -- Metrics that should decrease with higher difficulty (harder to achieve)
        performance_reduction_factor = 0.08, -- e.g., kills = base * (1 - diff * factor)
        -- Metrics that should increase with higher difficulty (more penalties)
        penalty_increase_factor = 0.15, -- e.g., deaths = base * (1 + diff * factor)
        -- Time-based metrics that worsen
        time_penalty_factor = 0.05, -- e.g., time = base * (1 - diff*factor) makes sense.
        -- Bonus metrics that decrease
        bonus_reduction_factor = 0.10 -- e.g., perfect = base * (1 - diff * factor)
    },

    -- Save Manager
    save_file_name = "save.json",
    save_version = "1.0",

    -- Cheat Engine (Legacy - old system)
    cheat_costs = {
        speed = 500,       -- Speed Modifiers
        advantage = 1000,  -- Advantage Modifiers
        performance = 2000,  -- Performance Boosters
        aim = 5000,        -- Aim Assist (Fake)
        god = 10000        -- God Mode (Fake)
    },

    -- CheatEngine (New System - Dynamic Parameter Modification)
    cheat_engine = {
        -- Starting budget for testing (set VERY high for testing)
        -- In production, this would start lower and be upgraded
        default_budget = 999999999, -- Nearly infinite for testing

        -- Budget upgrades (costs to increase budget cap)
        -- Not used initially - just for future expansion
        budget_upgrades = {
            { cost = 2500, new_cap = 1000 },
            { cost = 10000, new_cap = 5000 },
            { cost = 50000, new_cap = 25000 },
            { cost = 250000, new_cap = 100000 },
            { cost = 1000000, new_cap = 500000 }
        },

        -- Parameter modification pricing
        -- Base cost multipliers by parameter type
        parameter_costs = {
            -- Numeric parameters (lives, movement_speed, victory_limit, etc.)
            numeric = {
                base_cost = 10,  -- Very cheap for testing (production: 100)
                exponential_scale = 1.0, -- No scaling for testing (production: 1.5)
                -- Cost multiplier per step size
                step_costs = {
                    [1] = 1.0,    -- +/- 1: normal cost
                    [5] = 1.0,    -- +/- 5: testing - same cost (production: 0.9)
                    [10] = 1.0,   -- +/- 10: testing - same cost (production: 0.8)
                    [100] = 1.0,  -- +/- 100: testing - same cost (production: 0.6)
                    ["max"] = 1.0 -- Set to max/min: testing - same cost (production: 2.0)
                }
            },

            -- Boolean parameters (leaving_area_ends_game, etc.)
            boolean = {
                base_cost = 10,  -- Very cheap for testing (production: 500)
                exponential_scale = 1.0 -- Flat cost
            },

            -- String/enum parameters (victory_condition, movement_type, etc.)
            enum = {
                base_cost = 10,  -- Very cheap for testing (production: 5000)
                exponential_scale = 1.0 -- Flat cost
            },

            -- Array parameters (enemies, holes)
            array = {
                base_cost = 10,  -- Very cheap for testing (production: 1000)
                exponential_scale = 1.0  -- Flat for testing (production: 1.3)
            }
        },

        -- Parameter-specific overrides (optional)
        -- Use this to make specific params more/less expensive
        -- Empty for testing - all use default costs
        parameter_overrides = {
            -- Example overrides (commented out for testing):
            -- victory_condition = { base_cost = 5000 }, -- Expensive to change
            -- lives = { base_cost = 100 },
            -- victory_limit = { base_cost = 150 },
        },

        -- Parameter ranges for validation
        -- Defines min/max values for numeric parameters to prevent breaking games
        parameter_ranges = {
            -- Snake Game Parameters
            snake_speed = { min = 1, max = 20 },
            speed_increase_per_food = { min = 0, max = 5 },
            max_speed_cap = { min = 0, max = 50 },
            growth_per_food = { min = 0, max = 10 },
            shrink_over_time = { min = 0, max = 5 },
            max_length_cap = { min = 1, max = 9999 },
            girth = { min = 1, max = 10 },
            girth_growth = { min = 0, max = 50 },
            arena_size = { min = 0.3, max = 3.0 },
            food_count = { min = 1, max = 20 },
            food_lifetime = { min = 0, max = 60 },
            food_size_variance = { min = 0, max = 1.0 },
            bad_food_chance = { min = 0, max = 1.0 },
            golden_food_spawn_rate = { min = 0, max = 1.0 },
            obstacle_count = { min = 0, max = 50 },
            obstacle_spawn_over_time = { min = 0, max = 5 },
            ai_snake_count = { min = 0, max = 10 },
            ai_speed = { min = 1, max = 20 },
            snake_count = { min = 1, max = 5 },
            victory_limit = { min = 1, max = 200 },
            camera_zoom = { min = 0.5, max = 2.0 },
            difficulty_modifier = { min = 0.5, max = 3.0 },
            turn_speed = { min = 1, max = 360 },

            -- Dodge Game Parameters
            rotation_speed = { min = 0.5, max = 20 },
            movement_speed = { min = 50, max = 600 },
            jump_distance = { min = 20, max = 200 },
            jump_cooldown = { min = 0.1, max = 2.0 },
            jump_speed = { min = 200, max = 9999 },
            accel_friction = { min = 0.0, max = 1.0 },
            decel_friction = { min = 0.0, max = 1.0 },
            bounce_damping = { min = 0.0, max = 1.0 },
            area_size = { min = 0.3, max = 3.0 },
            area_morph_speed = { min = 0.0, max = 5.0 },
            area_movement_speed = { min = 0.0, max = 3.0 },
            area_friction = { min = 0.8, max = 1.0 },
            holes_count = { min = 0, max = 15 },
            player_size = { min = 0.3, max = 3.0 },
            max_speed = { min = 0, max = 1200 },
            lives = { min = 1, max = 50 },
            shield = { min = 0, max = 10 },
            shield_recharge_time = { min = 0, max = 60 },
            obstacle_tracking = { min = 0.0, max = 1.0 },
            obstacle_speed_variance = { min = 0.0, max = 1.0 },
            obstacle_spawn_rate = { min = 0.1, max = 5.0 },
            obstacle_size_variance = { min = 0.0, max = 1.0 },
            obstacle_trails = { min = 0, max = 50 },
            area_gravity = { min = -500, max = 500 },
            wind_direction = { min = 0, max = 360 },
            wind_strength = { min = 0, max = 500 },

            -- Memory Match Parameters
            card_count = { min = 4, max = 48 },
            columns = { min = 0, max = 8 },
            match_requirement = { min = 2, max = 4 },
            flip_speed = { min = 0.1, max = 2.0 },
            reveal_duration = { min = 0.2, max = 5.0 },
            memorize_time = { min = 0, max = 30 },
            auto_shuffle_interval = { min = 0, max = 60 },
            auto_shuffle_count = { min = 0, max = 48 },
            time_limit = { min = 0, max = 300 },
            move_limit = { min = 0, max = 200 },
            mismatch_penalty = { min = 0, max = 50 },
            combo_multiplier = { min = 0.0, max = 5.0 },
            speed_bonus = { min = 0, max = 100 },
            perfect_bonus = { min = 0, max = 50 },
            fog_of_war = { min = 0, max = 500 },
            fog_inner_radius = { min = 0.0, max = 1.0 },
            fog_darkness = { min = 0.0, max = 1.0 },
            chain_requirement = { min = 0, max = 10 },

            -- Space Shooter Parameters
            -- Player Movement
            player_speed = { min = 50, max = 600 },
            player_rotation_speed = { min = 0.5, max = 20.0 },
            player_accel_friction = { min = 0.0, max = 1.0 },
            player_decel_friction = { min = 0.0, max = 1.0 },
            player_jump_distance = { min = 20, max = 300 },
            player_jump_cooldown = { min = 0.1, max = 3.0 },
            player_jump_speed = { min = 100, max = 1000 },
            player_size_multiplier = { min = 0.3, max = 3.0 },
            -- Lives & Shield
            lives_count = { min = 1, max = 50 },
            shield_hits = { min = 0, max = 10 },
            shield_regen_time = { min = 0, max = 60 },
            -- Weapon System
            fire_rate = { min = 0.1, max = 20.0 },
            bullet_speed = { min = 50, max = 1000 },
            bullet_gravity = { min = -500, max = 500 },
            bullet_lifetime = { min = 1, max = 30 },
            bullet_damage_multiplier = { min = 0.1, max = 10.0 },
            homing_strength = { min = 0.0, max = 1.0 },
            burst_count = { min = 1, max = 10 },
            burst_delay = { min = 0.05, max = 1.0 },
            charge_time = { min = 0.1, max = 5.0 },
            spread_angle = { min = 5, max = 180 },
            overheat_threshold = { min = 3, max = 100 },
            overheat_cooldown = { min = 0.5, max = 10.0 },
            overheat_heat_dissipation = { min = 0.1, max = 10.0 },
            ammo_capacity = { min = 5, max = 500 },
            ammo_reload_time = { min = 0.5, max = 10.0 },
            -- Enemy System
            enemy_spawn_rate = { min = 0.1, max = 10.0 },
            enemy_speed_multiplier = { min = 0.1, max = 5.0 },
            enemy_bullet_speed = { min = 50, max = 800 },
            powerup_spawn_rate = { min = 1, max = 60 },
            powerup_duration = { min = 1, max = 30 },
            -- Environment
            scroll_speed = { min = 0, max = 500 },
            asteroid_density = { min = 0, max = 10 },
            meteor_frequency = { min = 0, max = 10 },
            gravity_wells = { min = 0, max = 10 },
            gravity_well_strength = { min = 50, max = 1000 },
            -- Arena
            arena_width = { min = 400, max = 1200 },
            blackout_zones = { min = 0, max = 5 },
        },

        -- Which parameters should be hidden/locked
        -- Hide metadata and non-gameplay parameters
        hidden_parameters = {
            "clone_index",      -- Internal identifier
            "name",             -- Display name
            "sprite_set",       -- Visual only
            "palette",          -- Visual only
            "music_track",      -- Audio only
            "sfx_pack",         -- Audio only
            "background",       -- Visual only
            "flavor_text",      -- Text only
            "intro_cutscene",   -- Cutscene data
            "enemies",          -- Complex array structure
            "movement_type",    -- String enum - would need dropdown (dodge/snake/space_shooter)
            "wall_mode",        -- String enum - snake wall behavior
            "arena_shape",      -- String enum - snake arena shape
            "food_spawn_pattern",  -- String enum - snake food spawning
            "food_movement",    -- String enum - snake food behavior
            "obstacle_type",    -- String enum - snake obstacle type
            "ai_behavior",      -- String enum - snake AI behavior
            "snake_collision_mode",  -- String enum - snake collision handling
            "victory_condition", -- String enum - win condition type
            "camera_mode",      -- String enum - camera follow mode
            "fog_of_war",       -- String enum - fog type (could be boolean but treated as enum)
            "sprite_style",     -- String enum - uniform vs segmented sprites
            -- Space Shooter enum parameters
            "fire_mode",        -- String enum - manual, auto, charge, burst
            "bullet_pattern",   -- String enum - single, double, triple, spread, spiral, wave
            "enemy_pattern",    -- String enum - spawn pattern type
            "enemy_formation",  -- String enum - scattered, v_formation, wall, spiral
            "difficulty_curve", -- String enum - linear, exponential, wave
            "powerup_types",    -- Array - available power-up types
        },

        -- Special unlocks (gate certain modifications behind progression)
        -- NOTE: Not implemented initially - using existing game unlock system
        -- Only unlocked games appear in CheatEngine (player_data:isGameUnlocked)
        unlockable_modifications = {
            -- Example structure (not used yet):
            -- {
            --     id = "dodge_count_multiplier",
            --     unlock_cost = 50000,
            --     applies_to = { "dodge" },
            --     unlocked = true  -- All unlocked for testing
            -- }
        },

        -- Refund policy when resetting parameters
        refund = {
            percentage = 100,  -- 100% refund for testing (production: 50-75%)
            min_refund = 0     -- Minimum refund amount
        }
    },

    -- Window/Display
    window = {
        windowed = {
            width = 1280,
            height = 720,
            resizable = false
        },
        fullscreen = {
            width = 1920,
            height = 1080,
            type = "desktop", -- 'desktop' uses native desktop resolution
            resizable = false
        },
        -- Global default window size/title if a program does not specify window_defaults
        defaults = {
            width = 800,
            height = 600,
            resizable = true,
            title_prefix = "" -- Optional prefix to apply to window titles
        },
        -- Minimum window size
        min_size = { w = 200, h = 150 },
        -- New window cascade behavior
        cascade = {
            offset_x = 25,
            offset_y = 25,
            reset_anchor = { x = 50, y = 50 }
        }
    },

    -- UI settings
    ui = {
        -- Taskbar metrics
        taskbar = {
            height = 40,
            start_button_width = 60,
            sys_tray_width = 150,
            button_max_width = 160,
            button_min_width = 80,
            button_padding = 4,
            -- Gap between start button and first taskbar button area
            button_area_gap = 10,
            -- Horizontal margin from the left edge for start button
            left_margin = 10,
            -- Vertical padding inside taskbar (top/bottom)
            vertical_padding = 5,
            -- Vertical margin for taskbar buttons (top+bottom combined)
            button_vertical_margin = 3
        },
            scrollbar = {
                width = 10,          -- track width in pixels
                margin_right = 2,    -- right margin in pixels (lane = width + margin)
                arrow_height = 12,   -- up/down arrow region height in pixels
                arrow_step_px = 20,  -- arrow click step in pixels
                min_thumb_h = 20,    -- minimum thumb height in pixels
            },
        -- Double-click timing threshold (seconds)
        double_click_time = 0.5,
        -- Window chrome metrics and colors
        window = {
            chrome = {
                title_bar_height = 25,
                border_width = 2,
                button = {
                    width = 16,
                    height = 14,
                    padding = 2,
                    right_margin = 4,
                    y_offset = 4
                },
                icon_size = 16,
                resize_edge_size = 8,
                -- Extra space used when excluding buttons from titlebar dragging
                buttons_area_extra = 8,
                -- Padding inside title bar for icon/text placement and title text scale
                content_padding = 5,
                title_text_scale = 0.9,
                colors = {
                    titlebar_focused   = {0, 0, 0.5},
                    titlebar_unfocused = {0.5, 0.5, 0.5},
                    border_outer       = {1, 1, 1},
                    border_inner_focused   = {0.8, 0.8, 0.8},
                    border_inner_unfocused = {0.5, 0.5, 0.5},
                    button_bg          = {0.75, 0.75, 0.75},
                    button_border_light= {1, 1, 1},
                    button_border_dark = {0.3, 0.3, 0.3},
                    button_icon        = {0, 0, 0},
                    button_disabled_bg   = {0.6, 0.6, 0.6},
                    button_disabled_icon = {0.4, 0.4, 0.4}
                }
            },
            interaction = {
                drag_deadzone = 4,
                snap = {
                    enabled = false,
                    padding = 10,
                    to_edges = true,
                    top_maximize = false
                }
            },
            error = {
                text_color = {1, 0, 0},
                text_pad = { x = 5, y = 5 },
                width_pad = 10
            }
        },
        -- Theme colors for desktop UI elements
        colors = {
            desktop = {
                wallpaper = {0, 0.5, 0.5}
            },
            taskbar = {
                bg = {0.75, 0.75, 0.75},
                top_line = {1, 1, 1}
            },
            start_button = {
                bg = {0.75, 0.75, 0.75},
                bg_hover = {0.85, 0.85, 0.85},
                border_light = {1, 1, 1},
                border_dark = {0.2, 0.2, 0.2},
                text = {0, 0, 0}
            },
            system_tray = {
                bg = {0.6, 0.6, 0.6},
                border_light = {1, 1, 1},
                border_dark = {0.2, 0.2, 0.2},
                text = {0, 0, 0}
            },
            start_menu = {
                bg = {0.75, 0.75, 0.75},
                border_light = {1, 1, 1},
                border_dark = {0.2, 0.2, 0.2},
                highlight = {0, 0, 0.5},
                text = {0, 0, 0},
                text_disabled = {0.5, 0.5, 0.5},
                text_hover = {1, 1, 1},
                separator = {0.5, 0.5, 0.5},
                shortcut = {0.4, 0.4, 0.4}
            },
            run_dialog = {
                bg = {0.75, 0.75, 0.75},
                title_bg = {0, 0, 0.5},
                title_text = {1, 1, 1},
                label_text = {0, 0, 0},
                input_bg = {1, 1, 1},
                input_border = {0, 0, 0},
                input_text = {0, 0, 0}
            }
        },
        -- Desktop-specific layout metrics
        desktop = {
            grid = {
                icon_padding = 20,
                start_x = 20,
                start_y = 20
            },
            icons = {
                sprite_size = 48,
                sprite_offset_y = 10,
                label_margin_top = 5,
                label_padding_x = 2,
                label_padding_y = 1,
                hover_tint = 1.2,
                disabled_overlay_alpha = 0.5,
                recycle_indicator = { radius = 4, offset_x = 5, offset_y = 5 }
            },
            start_menu = {
                width = 200,
                height = 300,
                padding = 10,
                item_height = 25,
                icon_size = 20,
                separator_space = 10,
                highlight_inset = 2,
                -- Distance from right edge where the shortcut text (e.g., Ctrl+R) starts
                run_shortcut_offset = 60
            },
            run_dialog = {
                width = 400,
                height = 150,
                title_bar_height = 25,
                padding = 10,
                input_y = 65,
                input_h = 25,
                buttons = {
                    ok_offset_x = 180, ok_w = 80, ok_h = 30,
                    cancel_offset_x = 90, cancel_w = 80, cancel_h = 30,
                    bottom_margin = 40
                }
            },
            system_tray = {
                clock_right_offset = 50,
                clock_text_scale = 1.2,
                token_offset = { x = 5, y = 3 }
            },
            screensaver = { default_timeout = 10 }
        },
        -- Taskbar start button text metrics
        taskbar_text = {
            start_text_offset = { x = 5, y = 5 },
            start_text_scale = 0.9
        },
        -- Per-view layout/theming constants to eliminate magic numbers from views
        views = {
            file_explorer = {
                toolbar_height = 35,
                address_bar_height = 25,
                status_bar_height = 20,
                item_height = 25,
                scrollbar_width = 15,
                colors = {
                    bg = {1,1,1},
                    toolbar_bg = {0.9, 0.9, 0.9},
                    toolbar_sep = {0.7, 0.7, 0.7},
                    status_bg = {0.9, 0.9, 0.9},
                    status_sep = {0.7, 0.7, 0.7},
                    item_selected = {0.6, 0.6, 0.9},
                    item_hover = {0.9, 0.9, 0.95},
                    item_bg = {1,1,1},
                    text = {0,0,0},
                    text_muted = {0.5,0.5,0.5},
                    type_file = {0.5,0.5,0.5},
                    type_exec = {0, 0.5, 0},
                    type_deleted = {0.7, 0.0, 0.0},
                    scrollbar_track = {0.9,0.9,0.9},
                    scrollbar_thumb = {0.6,0.6,0.6}
                },
                toolbar = {
                    margin = 5,
                    button_w = 25,
                    button_h = 25,
                    spacing = 5,
                    gap_after_nav = 10,
                    empty_bin_w = 120
                },
                address_bar = {
                    inset_x = 5,
                    inset_y = 2,
                    border = {0.5,0.5,0.5},
                    text_scale = 0.9,
                    text_pad_x = 10
                },
                item = {
                    icon_pad_x = 5,
                    icon_pad_y = 2,
                    name_pad_x = 5,
                    name_pad_y = 5,
                    name_scale = 0.9,
                    type_scale = 0.8
                },
                deleted_overlay = { color = {1,0,0,0.7}, line_width = 2 }
            },
            control_panel_legacy = {
                padding = { x = 10, y = 10 },
                row_gap = 26,
                slider = { w = 280, h = 14, handle_w = 12, value_gap = 12 },
                checkbox = { w = 20, h = 20, check_line_width = 3, label_gap = 10 },
                screensavers = {
                    label_x = 10,
                    section_gap = 30,
                    checkbox = { x = 20, y = 0, w = 22, h = 22 },
                    slider = { x = 20, w = 300, h = 14 }
                }
            },
            control_panel_general = {
                form = { label_x = 16, slider_x = 126, value_col_w = 60, start_y = 60 }
            },
            control_panel_screensavers = {
                tab = { x = 8, y = 28, w = 110, h = 18 },
                padding = { x = 16, y = 60 },
                label_col_w = 110,
                dropdown = { w = 160, h = 22 },
                preview = { frame_pad = 4, w = 320, h = 200 },
                row_gap = 34,
                slider_h = 12,
                checkbox = { w = 18, h = 18 },
                section_rule_h = 2,
                colors = {
                    panel_bg = {0.9, 0.9, 0.9},
                    panel_border = {0.6, 0.6, 0.6},
                    text = {0, 0, 0},
                    tab_bg = {0, 0, 0},
                    frame_fill = {0.9, 0.9, 0.95},
                    frame_line = {0.2, 0.2, 0.2},
                    label = {0, 0, 0},
                    slider_track = {0.85, 0.85, 0.85},
                    slider_fill = {0.1, 0.7, 0.1},
                    slider_handle = {0.9, 0.9, 0.9},
                    checkbox_fill = {1,1,1},
                    checkbox_border = {0,0,0},
                    checkbox_check = {0, 0.7, 0},
                    section_rule = {0.8, 0.8, 0.8}
                }
            },
            vm_manager = {
                colors = {
                    bg = {0.15, 0.15, 0.15},
                    upgrade_button = {
                        disabled_bg = {0.3, 0.3, 0.3},
                        hover_bg = {0.35, 0.6, 0.35},
                        enabled_bg = {0, 0.5, 0},
                        border = {0.5, 0.5, 0.5},
                        text_enabled = {1, 1, 1},
                        text_disabled = {0.5, 0.5, 0.5},
                        cost_enabled = {1, 1, 0},
                        cost_disabled = {0.5, 0.5, 0}
                    },
                    slot = {
                        selected_bg = {0.3, 0.3, 0.7},
                        hovered_bg = {0.35, 0.35, 0.35},
                        normal_bg = {0.25, 0.25, 0.25},
                        border = {0.5, 0.5, 0.5},
                        header_text = {0.7, 0.7, 0.7},
                        name_text = {1,1,1},
                        power_label = {0, 1, 1},
                        progress_bg = {0.3, 0.3, 0.3},
                        time_text = {1,1,1},
                        auto_badge = {0.5, 0.5, 1},
                        error_text = {1, 0, 0},
                        empty_text = {0.5, 0.5, 0.5},
                        empty_subtext = {0.5, 0.5, 0.5}
                    },
                    modal = {
                        panel_bg = {0.2, 0.2, 0.2},
                        overlay_alpha = 0.7, -- fallback if not provided in modal block
                        item_bg = {0.25, 0.25, 0.25},
                        item_bg_assigned = {0.15, 0.15, 0.15},
                        item_text = {1,1,1},
                        item_text_assigned = {0.5, 0.5, 0.5},
                        power_label = {0, 1, 1},
                        status_text = {0.7, 0.7, 0.7},
                        status_in_use = {1, 0, 0},
                        scrollbar = {0.5, 0.5, 0.5}
                    }
                },
                grid = { slot_w = 180, slot_h = 120, padding = 10, start_y = 50, left_margin = 10, bottom_reserved = 70 },
                purchase_button = { x = 10, w = 200, h = 40, bottom_margin = 60 },
                upgrade = { x = 230, w = 180, h = 40, spacing = 10, bottom_margin = 60 },
                modal = { min_w = 400, max_h = 500, side_margin = 20, top_y = 60, item_h = 40, overlay_alpha = 0.7, scrollbar_w = 8 },
                tokens = { right_offset = 200 },
                instructions = { bottom_offset = 25 }
            },
            settings = {
                base_x = 50,
                title_y = 40,
                slider = { w = 300, h = 20, handle_w = 10 },
                toggle = { w = 30, h = 30 },
                row_gap = 50,
                section_gap = 60,
                int_slider = { min_seconds = 5, max_seconds = 600 }
            },
            cheat_engine = {
                list = { x = 10, y = 50, max_w = 300, min_w = 150, item_h = 30, scrollbar_w = 6 },
                detail = { x_gap = 10 },
                spacing = { panel_gap = 10, header_h = 70, footer_h = 50, cheat_item_extra_h = 20 },
                buttons = { wide_h = 40, small_w = 110, small_h = 30 }
            },
            screensaver_starfield = {
                overlay = { color = {0.8, 0.8, 1, 0.5}, x = 12, y = 10, scale = 1.5 },
                bg_color = {0,0,0}
            },
            screensaver_pipes_draw = {
                bg_color = {0, 0.15, 0.2},
                grid = {
                    color = {0.0, 0.3, 0.35, 0.35},
                    x_extents = { -10, 10 },
                    y_extents = { -8, 8 },
                    z1 = 600, z2 = 900,
                    step_mul = 6
                },
                pipes = {
                    colors = {
                        {0.9,0.2,0.2}, {0.2,0.9,0.2}, {0.2,0.6,1.0}, {0.9,0.8,0.2}, {0.9,0.4,0.8}
                    },
                    shadow_factor = 0.35,
                    shadow_alpha = 0.6,
                    main_factor = 0.85,
                    highlight_scale = 1.2,
                    highlight_alpha = 0.85,
                    joint_radius_scale = 0.12
                },
                hud = { label = "3D Pipes", color = {0.7, 0.9, 1, 0.5} }
            },
            screensaver_model_draw = {
                bg_color = {0,0,0},
                ambient = { min = 0.3, max = 1.0 },
                z_push = 6,
                near_min = 0.1,
                edge_color = {0,0,0}
            }
        }
    },

    -- Systems configuration (shared mechanics)
    systems = {
        bullets = {
            width = 4,
            height = 8,
            speed_y = -400,
            despawn_margin = 0,      -- extra px above screen before despawn
            spawn_offset_y = 0,      -- extra px above player's top edge
            sprite_scale = 2.0       -- scale factor for sprite rendering
        }
    },

    -- UI: Token counter thresholds/colors
    tokens = {
        thresholds = {
            low = 100,
            medium = 500
        },
        colors = {
            low = {1, 0, 0},      -- red
            medium = {1, 1, 0},   -- yellow
            high = {0, 1, 0}      -- green
        }
    },

    -- Screensavers defaults
    screensavers = {
        defaults = {
            starfield = {
                count = 500,
                speed = 120,
                fov = 300,
                tail = 12
            },
            pipes = {
                fov = 420,
                near = 80,
                radius = 4.5,
                grid_step = 24,
                max_segments = 800,
                turn_chance = 0.45,
                speed = 60,
                spawn_min_z = 200,
                spawn_max_z = 600,
                avoid_cells = true,
                show_grid = false,
                camera_drift = 40,
                camera_roll = 0.05,
                pipe_count = 5,
                show_hud = true
            },
            model = {
                fov = 350,
                grid_lat = 24,
                grid_lon = 48,
                morph_speed = 0.3,
                two_sided = false
            }
        }
    },

    -- Games configuration
    games = {
        dodge = {
            -- Tinting Configuration
            tinting = {
                enabled = true,  -- Enable random tinting by default
                sprites = {"player"},  -- Only tint player, not obstacles
            },

            base_target = 30,
            player = {
                size = 20,
                speed = 300,
                rotation_speed = 2.0,  -- radians per second (2 rad/s ≈ 114°/s, fast but smooth)
                -- Asteroids mode physics
                thrust_acceleration = 600,  -- Acceleration when thrusting (pixels/sec²)
                friction = 0.98,  -- Velocity multiplier per second (0.98 = slight friction, 1.0 = no friction)
                -- Jump mode physics
                jump_distance = 80,  -- How far each jump goes (pixels)
                jump_cooldown = 0.5,  -- Time between jumps (seconds)
                jump_speed = 800,  -- Speed of the jump movement (pixels/sec, 9999 = instant teleport)
                -- New variant parameters
                player_size = 1.0,  -- Multiplier on player hitbox (0.5 = tiny, 2.0 = big target)
                max_speed = 600,  -- Hard cap on velocity (prevents runaway speed in asteroids mode)
                lives = 10,  -- Hit count before game over (replaces collisions.max)
                shield = 0,  -- Number of shield charges (0 = none, integer for charges)
                shield_recharge_time = 0  -- Time in seconds to recharge shield (0 = never recharges)
            },
            objects = {
                size = 15,
                base_speed = 200,
                base_spawn_rate = 1.0,
                warning_time = 0.5,
                -- Per-type speed multipliers relative to base object speed
                type_speed_multipliers = {
                    seeker = 0.9,
                    splitter = 0.8,
                    zigzag = 1.1,
                    sine   = 1.0,
                    linear = 1.0
                },
                -- Zigzag/Sine wobble parameters
                zigzag = {
                    wave_speed_min = 6,
                    wave_speed_range = 4,
                    wave_amp = 30,
                    wave_velocity_factor = 2.0
                },
                -- Object type spawn weighting: base + time_elapsed * growth
                weights = {
                    linear  = { base = 50, growth = 0.0 },
                    zigzag  = { base = 22, growth = 0.30 },
                    sine    = { base = 18, growth = 0.22 },
                    seeker  = { base = 4,  growth = 0.08 },
                    splitter= { base = 7,  growth = 0.18 }
                },
                -- Splitter shard parameters
                splitter = {
                    shards_count = 3,
                    shard_radius_min = 6,
                    shard_radius_factor = 0.6,
                    shard_speed_factor = 0.36,
                    spread_deg = 35
                },
                -- New variant parameters
                tracking = 0.0,  -- Homing strength (0.0 = none, 0.5 = slight, 1.0 = aggressive)
                speed_variance = 0.0,  -- Random speed variation (0.0 = uniform, 1.0 = very chaotic)
                spawn_rate_multiplier = 1.0,  -- Multiplier on spawn frequency (0.5 = sparse, 2.0 = bullet hell)
                spawn_pattern = "random",  -- "random", "waves", "clusters", "spiral", "pulse_with_arena"
                size_variance = 0.0,  -- Mix of tiny/medium/huge (0.0 = uniform, 1.0 = extreme variance)
                trails = 0  -- Trail length in segments (0 = none, 5 = short, 20 = long damaging trail)
            },
            collisions = { max = 10 },  -- DEPRECATED: Use player.lives instead
            arena = {
                width = 400,
                height = 400,
                initial_safe_radius_fraction = 0.48,
                min_safe_radius_fraction = 0.35,
                safe_zone_shrink_sec = 45,
                spawn_inset = 2,
                target_ring = { min_scale = 1.2, max_scale = 1.5 },
                -- Safe zone customization
                area_size = 1.0,  -- Multiplier on safe zone radius (2.0 = double, 0.5 = half)
                area_morph_type = "shrink",  -- "shrink", "pulsing", "shape_shifting", "deformation", "none"
                area_morph_speed = 1.0,  -- Speed multiplier for morphing effects (0 = disabled)
                area_movement_speed = 1.0,  -- Movement speed multiplier (current drift is baseline, 0 = static)
                area_movement_type = "random",  -- "random" (current drift), "cardinal", "none"
                area_friction = 1.0,  -- How quickly safe zone changes direction (1.0 = instant, <1.0 = momentum/drift)
                area_shape = "circle",  -- "circle", "square", "hex"
                -- Game over system
                leaving_area_ends_game = false,  -- If true, leaving safe zone = instant game over
                holes_type = "none",  -- "circle" (on boundary), "background" (static), "none"
                holes_count = 0,  -- Number of hazard holes (0 = disabled)
                -- New environment forces
                gravity = 0.0,  -- Pull toward/away from center in px/sec² (positive = pull in, negative = push out)
                wind_direction = 0,  -- 0-360 degrees (0 = east, 90 = south), or "random"
                wind_strength = 0,  -- Force magnitude in px/sec² (0 = no wind)
                wind_type = "none"  -- "turbulent", "steady", "changing_steady", "changing_turbulent", "none"
            },
            spawn = {
                warning_chance = 0.7,
                accel = { max = 2.0, time = 60 } -- spawn rate speeds up to 2x over 60s
            },
            seeker = {
                base_turn_deg = 6,
                difficulty = { max = 2.0, time = 90 } -- up to 2x turn rate over 90s
            },
            drift = {
                base_speed = 45,
                level_scale_add_per_level = 0.15, -- 15% more drift speed per difficulty level after 1
                accel = { max = 1.0, time = 90 } -- drift velocity scales up to 2x (1+1) over 90s
            },
            warnings = { complexity_threshold = 2 },
            victory = {
                condition = "dodge_count",  -- "dodge_count" (default) or "time" (survive X seconds)
                limit = 30  -- X dodges or X seconds (uses base_target calculation by default)
            },
            view = {
                bg_color = {0.08, 0.05, 0.1},
                starfield = { count = 180, speed_min = 20, speed_max = 100, size_divisor = 60 },
                hud = { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 70, text_x = 90, row_y = {10, 30, 50, 70} },
                -- New visual effects
                fog_origin = "none",  -- "player", "circle_center", or "none"
                fog_radius = 9999,  -- Visibility radius in pixels (100 = tight, 9999 = full vision)
                camera_shake = 0.0,  -- Screen shake intensity (0 = none, 1.0 = moderate, 2.0 = intense)
                player_trail = 0,  -- Player trail length in segments (0 = none, 10 = short, 50 = long)
                score_mode = "none"  -- Score multiplier mode: "center", "edge", "speed", or "none"
            }
        },
    hidden_object = {
            -- Tinting Configuration
            tinting = {
                enabled = false,  -- Disable tinting (objects have specific appearances)
                sprites = {},
            },

            arena = { width = 800, height = 600 },
            time = {
                base_limit = 60,
                bonus_multiplier = 5
            },
            objects = {
                base_count = 5,
                base_size = 20,
                sprite_variant_divisor_base = 5
            },
            background = {
                grid_base = 10,
                position_hash = { x1 = 17, x2 = 47, y1 = 23, y2 = 53 },
                background_hash = { h1 = 17, h2 = 3 }
            },
            view = {
                bg_color = {0.12, 0.1, 0.08},
                hud = { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50, 70} }
            }
        },
    memory_match = {
            -- Tinting Configuration
            tinting = {
                enabled = false,  -- Disable tinting (flags/cards need specific colors for gameplay)
                sprites = {},
            },

            arena = { width = 800, height = 600 },
            cards = { width = 60, height = 80, spacing = 10, icon_padding = 10 },
            timings = { memorize_time_base = 5, match_view_time = 1, flip_speed = 0.3, reveal_duration = 1.0 },
            pairs = { per_complexity = 6 },
            view = {
                bg_color = {0.05, 0.08, 0.12},
                hud = { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 70, text_x = 90, row_y = {10, 30, 50, 70} }
            },

            -- Grid & Layout defaults
            card_count = 0,  -- 0 = auto-calculate (pairs * 2), non-zero = explicit count
            columns = 0,  -- 0 = auto (square grid), non-zero = explicit column count
            match_requirement = 2,  -- Cards to match at once (2 = pairs, 3 = triplets, 4 = quads)

            -- Timing defaults
            auto_shuffle_interval = 0,  -- Seconds between shuffles (0 = disabled)
            auto_shuffle_count = 0,  -- Cards to shuffle per interval (0 = all face-down cards)

            -- Constraints defaults
            time_limit = 0,  -- Total time limit in seconds (0 = no limit)
            move_limit = 0,  -- Maximum flips allowed (0 = unlimited)

            -- Scoring defaults
            mismatch_penalty = 0,  -- Penalty per mismatch
            combo_multiplier = 0.0,  -- Bonus multiplier for consecutive matches (0 = disabled)
            speed_bonus = 0,  -- Bonus points per second remaining (requires time_limit)
            perfect_bonus = 0,  -- Bonus for perfect matches (found on first try)

            -- Visual Effects defaults
            gravity_enabled = false,  -- Cards fall with gravity
            card_rotation = false,  -- Cards rotate while face-down
            spinning_cards = false,  -- Cards spin continuously
            fog_of_war = 0,  -- Visibility radius around cursor (0 = disabled)
            fog_inner_radius = 0.6,  -- Percentage of radius that's fully lit (0.0-1.0)
            fog_darkness = 0.1,  -- How dark obscured areas get (0.0 = pitch black, 1.0 = no obscuring)
            distraction_elements = false,  -- Spawn visual distractions

            -- Challenge Mode defaults
            chain_requirement = 0,  -- Forces matching specific sequence (0 = disabled)
        },
    snake = {
            -- Tinting Configuration
            tinting = {
                enabled = true,  -- Enable random tinting by default
                sprites = "all",  -- Tint all snake segments
            },

            arena = { width = 800, height = 600 },
            grid_size = 20,
            base_speed = 8,
            base_target_length = 20,
            base_obstacle_count = 5,

            -- Movement defaults
            movement_type = "grid",  -- "grid" (classic), "smooth" (analog turning with trail)
            snake_speed = 8,
            turn_speed = 180,  -- Degrees per second for smooth movement (only used in "smooth" mode)
            speed_increase_per_food = 0,  -- Speed increase per food eaten (0 = constant speed)
            max_speed_cap = 20,  -- Maximum speed limit

            -- Growth & Body defaults
            growth_per_food = 1,  -- Segments added per food (1 = classic)
            shrink_over_time = 0,  -- Segments lost per second (0 = no shrinking)
            phase_through_tail = false,  -- Can pass through own body
            max_length_cap = 9999,  -- Maximum snake length
            girth = 1,  -- Snake thickness (1 = normal, 2+ = thicker)
            girth_growth = 0,  -- Segments needed to add 1 girth (0 = no growth)

            -- Arena defaults
            wall_mode = "wrap",  -- "wrap" (Pac-Man), "death", "bounce"
            obstacle_bounce = false,  -- If true, bounce off obstacles (separate from walls)
            arena_size = 1.0,  -- Multiplier on arena size
            arena_shape = "rectangle",  -- "rectangle", "circle", "hexagon"
            shrinking_arena = false,  -- Arena walls close in over time
            moving_walls = false,  -- Walls shift positions

            -- Food defaults
            food_count = 1,  -- Number of simultaneous food items
            food_spawn_pattern = "random",  -- "random", "cluster", "line", "spiral"
            food_lifetime = 0,  -- Food despawns after X seconds (0 = never)
            food_movement = "static",  -- "static", "drift", "flee_from_snake", "chase_snake"
            food_speed = 3,  -- Food movement speed in moves per second (when food_movement is not "static")
            food_spawn_mode = "continuous",  -- "continuous" (spawn immediately) or "batch" (spawn all when batch collected)
            food_size_variance = 0,  -- Size variation affects GROWTH amount only, NOT visual size (0 = uniform, 1 = varied 1-5 segments)
            bad_food_chance = 0,  -- Chance of bad food (shrinks snake)
            golden_food_spawn_rate = 0,  -- Chance of golden food (bonus)

            -- Obstacle defaults
            obstacle_count = 5,  -- Static obstacles in arena
            obstacle_type = "static_blocks",  -- "static_blocks", "walls", "moving_blocks", "rotating_blades", "teleport_pairs"
            obstacle_spawn_over_time = 0,  -- New obstacles per second (0 = none)

            -- AI defaults
            ai_snake_count = 0,  -- Number of AI snakes
            ai_behavior = "food_focused",  -- "aggressive", "defensive", "food_focused"
            snake_collision_mode = "both_die",  -- "both_die", "big_eats_small", "phase_through"
            snake_count = 1,  -- Number of snakes controlled simultaneously

            -- Victory defaults
            victory_condition = "length",  -- "length" (reach target) or "time" (survive X seconds)
            victory_limit = 20,  -- Target length or time in seconds

            -- Visual defaults
            fog_of_war = "none",  -- "player", "center", "none" - limits visibility
            invisible_tail = false,  -- Can't see own body (memory challenge)
            camera_mode = "follow_head",  -- "follow_head", "center_of_mass", "fixed"
            camera_zoom = 1.0,  -- Camera zoom level
            sprite_style = "uniform",  -- "uniform" (same sprite for all segments) or "segmented" (head/body/tail)
            sprite_set = "classic/snake",  -- Path to sprite folder from assets/sprites/games/snake/

            view = {
                bg_color = {0.05, 0.1, 0.05},
                hud = { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50} }
            }
        },
        space_shooter = {
            -- Tinting Configuration
            tinting = {
                enabled = true,  -- Enable random tinting by default
                sprites = "all",  -- "all" or array of sprite names like {"player", "enemy_*"}
            },

            arena = {
                width = 800,
                height = 600,
                aspect_ratio_locked = false,  -- If true, locks window aspect ratio like Snake
                screen_wrap = false,  -- Edges wrap like Asteroids
                reverse_gravity = false,  -- Player at top, enemies at bottom
                blackout_zones = 0  -- Number of vision-blocking zones
            },

            -- Player Movement Defaults
            player = {
                width = 30,
                height = 30,
                speed = 200,  -- Base movement speed (rail/default modes)
                rotation_speed = 5.0,  -- Asteroids mode rotation (degrees/frame)
                accel_friction = 1.0,  -- Asteroids mode acceleration responsiveness
                decel_friction = 1.0,  -- Asteroids mode deceleration
                start_y_offset = 50,  -- Spawn position from bottom
                max_deaths_base = 5,  -- Base lives
                fire_cooldown = 0.2,  -- Seconds between shots
                jump_distance = 0.08,  -- Jump mode dash distance (% of screen width, 0.08 = 8%)
                jump_cooldown = 0.5,  -- Jump mode cooldown
                jump_speed = 400,  -- Jump mode dash speed
                size_multiplier = 1.0,  -- Hitbox size (0.5 = tiny, 2.0 = huge)
            },

            -- Shield Defaults
            shield = {
                enabled = false,
                regen_time = 5.0,  -- Seconds to regenerate
                max_hits = 1,  -- Hits before shield breaks
            },

            -- Bullet Defaults
            bullet = {
                width = 4,
                height = 8,
                speed = 400,
                gravity = 0,  -- Pixels/sec^2 downward pull (0 for none, 500 for strong curve)
                lifetime = 10,  -- Seconds before despawn
                piercing = false,
                homing = false,
                homing_strength = 0.0,  -- 0-1, how aggressively bullets home
                damage_multiplier = 1.0,  -- Damage scaling
            },

            -- Weapon System Defaults
            weapon = {
                fire_mode = "manual",  -- manual, auto, charge, burst
                fire_rate = 1.0,  -- Shots per second (auto mode)
                burst_count = 3,  -- Bullets per burst (burst mode)
                burst_delay = 0.1,  -- Seconds between burst shots
                charge_time = 1.0,  -- Seconds to full charge
                pattern = "single",  -- single, double, triple, spread, spiral, wave
                spread_angle = 30,  -- Degrees for spread pattern
                bullet_arc = 30,  -- Degrees for arc-based patterns (affects spread size, homing count, etc.)
                bullets_per_shot = 1,  -- Number of bullets per shot (multiplier for patterns)
                overheat_enabled = false,
                overheat_threshold = 10,  -- Shots before overheat
                overheat_cooldown = 3.0,  -- Seconds to cool down
                overheat_heat_dissipation = 2.0,  -- Heat dissipated per second
                ammo_enabled = false,
                ammo_capacity = 50,
                ammo_reload_time = 2.0,
            },

            -- Enemy Defaults
            enemy = {
                width = 30,
                height = 30,
                base_speed = 100,
                start_y_offset = -30,
                base_shoot_rate_min = 1.0,
                base_shoot_rate_max = 3.0,
                shoot_rate_complexity_factor = 0.5,
                spawn_base_rate = 1.0,  -- Seconds between spawns
                speed_multiplier = 1.0,
                bullets_enabled = true,
                bullet_speed = 200,
                formation = "scattered",  -- scattered, v_formation, wall, spiral
            },

            -- Power-up Defaults
            powerup = {
                spawn_rate = 10.0,  -- Seconds between spawns
                duration = 5.0,  -- Seconds power-up lasts
                stacking = false,  -- Can stack multiples
                from_enemies = 0.1,  -- 10% chance on enemy kill
                types = {  -- Available types
                    "weapon_upgrade",
                    "shield",
                    "speed",
                }
            },

            -- Environment Defaults
            environment = {
                scroll_speed = 0,  -- Pixels/sec background scroll
                asteroid_density = 0,  -- Asteroids per second
                meteor_frequency = 0,  -- Meteor showers per minute
                gravity_wells = 0,  -- Number of gravity wells
                gravity_well_strength = 200,  -- Pixels/sec^2 pull
            },

            -- Victory/Difficulty Defaults
            goals = {
                base_target_kills = 20,
                victory_condition = "kills",  -- kills, time, survival, boss
                victory_limit = 20,  -- Varies by condition type
                difficulty_curve = "linear",  -- linear, exponential, wave
                bullet_hell_mode = false,  -- Tiny hitbox, massive bullet count
            },

            spawn = { base_rate = 1.0 },
            movement = { zigzag_frequency = 2 },

            view = {
                bg_color = {0.05, 0.05, 0.15},
                hud = { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50} }
            }
        },
        solitaire = {
            view = {
                bg_color = {0.05, 0.25, 0.05},
                card = {
                    width = 72,
                    height = 96,
                    corner_radius = 6,
                    back_color = {0.3, 0.5, 0.8}
                },
                layout = {
                    padding = 12,
                    top_margin = 40,
                    faceup_dy = 24,
                    facedown_dy = 14
                },
                hud = { x1 = 12, x2 = 212, y = 8 },
                empty_slot_color = {0.2, 0.4, 0.2},
                double_click = { time = 0.35, jitter = 8 },
                win = {
                    party_count = 40,
                    gravity = 420,
                    bounce_x_friction = 0.98,
                    bounce_y_coeff = 0.92,
                    init_vx_min = 80,
                    init_vx_max = 240,
                    init_vy_min = 120,
                    init_vy_max = 300
                }
            }
        },
        space_defender = {
            arena = { width = 1024, height = 768 },
            player = {
                width = 30,
                height = 30,
                speed = 250,
                hp = 3,
                bombs = 3,
                start_y_offset = 80
            },
            enemy = {
                width = 30,
                height = 30,
                zigzag = { den = 30, amp = 100 },
                sine   = { den = 50, amp = 80 },
                offscreen_padding = 20
            },
            spawn = { x_inset = 20, y_start = -20 },
            boss = {
                width = 80,
                height = 80,
                vx = 100,
                attack_rate = 2.0,
                orbit = {
                    count = 3,
                    radius_x = 70,
                    radius_y = 30,
                    rotate_per_level = 0.1,
                    spawn_speed_base = 150,
                    spawn_speed_per_level = 5
                }
            },
            scaling = {
                -- Boss HP formula: boss_hp_base * (level ^ boss_hp_exponent)
                boss_hp_base = 5000,
                boss_hp_exponent = 2.0,
                -- Enemy HP formula: enemy_hp_base * (level ^ enemy_hp_exponent)
                enemy_hp_base = 500,
                enemy_hp_exponent = 1.8,
                -- Boss attack spawn HP formula: attack_hp_base * (level ^ attack_hp_exponent)
                attack_hp_base = 50,
                attack_hp_exponent = 1.5,
                -- Wave count formula: wave_count_base + (level * wave_count_per_level)
                wave_count_base = 2,
                wave_count_per_level = 3,
                -- Enemy count per wave formula: enemy_count_base * (level ^ enemy_count_exponent)
                enemy_count_base = 10,
                enemy_count_exponent = 1.3,
                -- Spawn rate (seconds between spawns, decreases with level)
                spawn_rate_base = 0.15,  -- Much faster spawning (was 1.0)
                spawn_rate_min = 0.05,   -- Can get very fast at high levels (was 0.1)
                spawn_rate_level_reduction = 0.01  -- Slower reduction (was 0.05)
            },
            boss_movement = {
                -- Boss moves downward toward player
                move_down_speed = 15,  -- pixels per second downward
                side_speed = 100,      -- horizontal speed
                min_y = 50,            -- Start position
                death_y_threshold = 0.85  -- If boss reaches 85% down screen, player loses a life
            },
            bomb = { enemy_frac = 0.5, enemy_bonus = 50, boss_frac = 0.1, boss_bonus = 500 },
            rewards = { base = 500, per_level_multiplier = 0.5 },
            final_level = 5,
            level_bonuses = {
                thresholds = {
                    { level = 3, damage = 1.5 },
                    { level = 5, damage = 2.0, fire_rate = 1.2 }
                }
            },
            view = {
                bg_color = {0, 0, 0.1},
                starfield = {
                    count = 200,
                    speed_min = 20,
                    speed_max = 100,
                    base_size = { w = 1024, h = 768 }
                },
                hud = { left_x = 10, right_margin_offset = 150, row_y = {10, 30} },
                overlays = { complete_alpha = 0.7, game_over_alpha = 0.7, paused_alpha = 0.5 },
                boss_bar = { width = 200, height = 15, offset_y = 20 }
            }
        }
    },

    -- === Text-to-Speech Configuration ===
    tts = {
        enabled = true,              -- Enable/disable TTS globally
        rate = 0,                    -- Speech rate: -10 (slow) to 10 (fast), 0 = normal
        volume = 80,                 -- Volume: 0-100
        use_audio_effects = false,   -- EXPERIMENTAL: Generate to WAV for pitch shifting (may freeze game briefly)
        voice_name = nil,            -- Specific SAPI voice name (nil = default) e.g., "Microsoft David Desktop"

        -- Voice presets (weirdness parameter):
        -- When use_audio_effects = false: only affects speed (rate)
        -- When use_audio_effects = true: affects speed + pitch
        -- 0 = Normal
        -- 1 = Slightly weird
        -- 2 = Very weird
        -- 3 = Creepy
        -- 4 = Robot
        -- 5 = Demon
        weirdness = 0,
    },

    -- === VM Demo Recording & Playback Configuration ===
    vm_demo = {
        fixed_dt = 1/60,              -- Fixed timestep for recording/playback (60 FPS)
        restart_delay = 5.0,          -- Seconds between runs (show completion screen, upgradeable later)
        max_demo_frames = 18000,      -- Max frames (~5 minutes at 60 FPS)
        min_demo_frames = 60,         -- Min frames (~1 second at 60 FPS)
        stats_update_interval = 1.0,  -- Update UI stats every second
        save_frequency = 30,          -- Save VM state every 30 seconds

        -- Speed upgrade system (levels defined in balance, not here)
        max_visual_speed_multiplier = 100, -- Cap for rendered VMs
        headless_speed_label = "INSTANT",  -- UI label for headless mode
    },
}

return Config