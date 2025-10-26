-- config.lua: Central configuration for game tuning parameters

local Config = {
    -- Player Data
    start_tokens = 500,
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

        -- Which parameters should be hidden/locked
        -- For testing: empty (show everything)
        -- In production, might hide: clone_index, name, sprite_set, etc.
        hidden_parameters = {
            -- "clone_index", -- Don't allow editing clone_index
            -- "name", -- Don't allow editing display name
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
            arena = { width = 800, height = 600 },
            cards = { width = 60, height = 80, spacing = 10, icon_padding = 10 },
            timings = { memorize_time_base = 5, match_view_time = 1 },
            pairs = { per_complexity = 6 },
            view = {
                bg_color = {0.05, 0.08, 0.12},
                hud = { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 70, text_x = 90, row_y = {10, 30, 50, 70} }
            }
        },
    snake = {
            arena = { width = 800, height = 600 },
            grid_size = 20,
            base_speed = 8,
            base_target_length = 20,
            base_obstacle_count = 5,
            view = {
                bg_color = {0.05, 0.1, 0.05},
                hud = { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50} }
            }
        },
        space_shooter = {
            arena = { width = 800, height = 600 },
            player = {
                width = 30,
                height = 30,
                speed = 200,
                start_y_offset = 50,
                max_deaths_base = 5,
                fire_cooldown = 0.2
            },
            bullet = { width = 4, height = 8, speed = 400 },
            enemy = {
                width = 30,
                height = 30,
                base_speed = 100,
                start_y_offset = -30,
                base_shoot_rate_min = 1.0,
                base_shoot_rate_max = 3.0,
                shoot_rate_complexity_factor = 0.5
            },
            spawn = { base_rate = 1.0 },
            goals = { base_target_kills = 20 },
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
                hp = 5000,
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
    }
}

return Config