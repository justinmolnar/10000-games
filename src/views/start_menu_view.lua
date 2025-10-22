-- src/views/start_menu_view.lua
local Object = require('class')
local Strings = require('src.utils.strings')
local Constants = require('src.constants')

local StartMenuView = Object:extend('StartMenuView')

function StartMenuView:init(program_registry, file_system, di)
    self.program_registry = program_registry
    self.file_system = file_system
    self.di = di or {}
    self.config = (self.di and self.di.config) or {}
    self.sprite_loader = (self.di and self.di.spriteLoader) or nil
    -- Ensure any invalid persisted Start Menu state is cleaned immediately (e.g., moves into Documents)
    if self.program_registry and self.program_registry.sanitizeStartMenuState then
        pcall(self.program_registry.sanitizeStartMenuState, self.program_registry)
    end
    -- Ensure a unified Start Menu Programs folder exists and is seeded
    if self.file_system and self.file_system.ensureStartMenuProgramsFolder then
        pcall(self.file_system.ensureStartMenuProgramsFolder, self.file_system, self.program_registry)
    end

    local desktop_cfg = (self.config and self.config.ui and self.config.ui.desktop) or {}
    local start_cfg = (desktop_cfg.start_menu or {})
    local taskbar_cfg = (self.config and self.config.ui and self.config.ui.taskbar) or {}
    self.taskbar_height = taskbar_cfg.height or 40

    -- Geometry (presentation config only)
    self.start_menu_w = start_cfg.width or 200
    self.start_menu_h = start_cfg.height or 300 -- recomputed when open
    self.start_menu_x = 0
    self.start_menu_y = love.graphics.getHeight() - self.taskbar_height - self.start_menu_h

    -- Timing configuration
    self.cascade_hover_delay = start_cfg.hover_delay or 0.2
    self.cascade_close_delay = start_cfg.hover_leave_delay or self.cascade_hover_delay or 0.2
    self.start_menu_close_grace = start_cfg.close_grace or 0.5
    self.dnd_threshold = 4
end

-- External helpers used by DesktopState when toggling the menu via keyboard/mouse
-- NOTE: These are now deprecated - state management moved to StartMenuState
function StartMenuView:clearStartMenuPress()
    -- Deprecated: state now managed by StartMenuState
end

function StartMenuView:setStartMenuKeyboardSelection(id)
    -- Deprecated: state now managed by StartMenuState
end

function StartMenuView:update(dt, start_menu_open, state)
    if not start_menu_open then
        -- Reset all menu state when closed
        state.submenu_open_id = nil
        state.open_panes = {}
        state._cascade_root_id = nil
        state._start_menu_keepalive_t = 0
        state.hovered_main_id = nil
        state.hovered_sub_id = nil
        return
    end

    -- Mouse
    local mx, my = love.mouse.getPosition()
    -- Recompute geometry Y against current screen height
    self.start_menu_y = love.graphics.getHeight() - self.taskbar_height - self.start_menu_h

    -- Hover main row
    state.hovered_main_id = self:getStartMenuMainAtPosition(mx, my)

    -- Inside legacy submenu
    local sub_bounds = self:getSubmenuBounds(state)
    local inside_sub = sub_bounds and (mx >= sub_bounds.x and mx <= sub_bounds.x + sub_bounds.w and my >= sub_bounds.y and my <= sub_bounds.y + sub_bounds.h)
    -- Inside any cascading pane
    local inside_panes = false
    for _, p in ipairs(state.open_panes or {}) do
        local b = p.bounds
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then inside_panes = true; break end
    end

    -- Open/keep submenu (with grace)
    if state.hovered_main_id == 'programs' or state.hovered_main_id == 'documents' or state.hovered_main_id == 'settings' then
        state.submenu_open_id = state.hovered_main_id
        state._start_menu_keepalive_t = 0
    elseif inside_sub or inside_panes then
        state._start_menu_keepalive_t = 0
    else
        state._start_menu_keepalive_t = (state._start_menu_keepalive_t or 0) + dt
        if state._start_menu_keepalive_t >= (self.start_menu_close_grace or 0.5) then
            state.submenu_open_id = nil
            state.open_panes = {}
            state._cascade_root_id = nil
            state._start_menu_keepalive_t = 0
            state._pane_close = {}
        end
    end

    -- Update hovered item in legacy submenu
    state.hovered_sub_id = self:getStartMenuSubItemAtPosition(mx, my, state)
    -- Always update cascading panes
    self:updateCascade(mx, my, dt, state)

    -- Auto-size menu height for 6 rows
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local main_h = start_cfg.main_item_height or (item_h * 2)
    local padding = start_cfg.padding or 10
    local sep_space = start_cfg.separator_space or 10
    local main_rows = 3
    local bottom_rows = 3
    local desired_h = padding + (main_rows * main_h) + sep_space + (bottom_rows * main_h)
    local screen_h = love.graphics.getHeight()
    local max_h = math.min(desired_h, screen_h - self.taskbar_height - 10)
    self.start_menu_h = max_h
    self.start_menu_y = love.graphics.getHeight() - self.taskbar_height - self.start_menu_h
end

function StartMenuView:draw(state)
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    if not sprite_loader then
        error("StartMenuView: sprite_loader not available in DI")
    end
    local theme = (self.config and self.config.ui and self.config.ui.colors and self.config.ui.colors.start_menu) or {}
    if state.open_panes and #state.open_panes > 0 then self:reflowOpenPanesBounds(state) end
    love.graphics.setColor(theme.bg or {0.75, 0.75, 0.75})
    love.graphics.rectangle('fill', self.start_menu_x, self.start_menu_y, self.start_menu_w, self.start_menu_h)
    love.graphics.setColor(theme.border_light or {1, 1, 1})
    love.graphics.line(self.start_menu_x, self.start_menu_y, self.start_menu_x + self.start_menu_w, self.start_menu_y)
    love.graphics.line(self.start_menu_x, self.start_menu_y, self.start_menu_x, self.start_menu_y + self.start_menu_h)
    love.graphics.setColor(theme.border_dark or {0.2, 0.2, 0.2})
    love.graphics.line(self.start_menu_x + self.start_menu_w, self.start_menu_y, self.start_menu_x + self.start_menu_w, self.start_menu_y + self.start_menu_h)
    love.graphics.line(self.start_menu_x, self.start_menu_y + self.start_menu_h, self.start_menu_x + self.start_menu_w, self.start_menu_y + self.start_menu_h)

    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_y = self.start_menu_y + (start_cfg.padding or 10)
    local item_h = start_cfg.item_height or 25
    local main_h = start_cfg.main_item_height or (item_h * 2)
    local main_icon_size = start_cfg.main_icon_size or math.floor(main_h * 0.7)

    local function resolveMainMenuIcon(id)
        local function firstExisting(candidates)
            for _, name in ipairs(candidates) do
                if sprite_loader:hasSprite(name) then return name end
            end
            return candidates[#candidates]
        end
        if id == 'programs' then
            return firstExisting({'window_program-0','window_blank-0','executable-0'})
        elseif id == 'documents' then
            return firstExisting({'directory_open_file_mydocs_small-0','document-0'})
        elseif id == 'settings' then
            return firstExisting({'settings_gear-0','gears_tweakui_a-0','executable-0'})
        elseif id == 'help' then
            return firstExisting({'help_book-0','help-0','question_mark-0','document-0'})
        end
        return 'executable-0'
    end

    local function draw_main_item(id, label, icon_sprite)
        local is_hovered = (state.hovered_main_id == id) or (state.keyboard_start_selected_id == id) or (state.submenu_open_id == id)
        if is_hovered then
            local inset = start_cfg.highlight_inset or 2
            love.graphics.setColor(theme.highlight or {0, 0, 0.5})
            love.graphics.rectangle('fill', self.start_menu_x + inset, item_y, self.start_menu_w - 2 * inset, main_h)
        end
        local icon_x = self.start_menu_x + 5
        local icon_y_centered = item_y + (main_h - main_icon_size) / 2
        if icon_sprite then sprite_loader:drawSprite(icon_sprite, icon_x, icon_y_centered, main_icon_size, main_icon_size, is_hovered and {1.2,1.2,1.2} or {1,1,1}) end
        love.graphics.setColor(is_hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0,0,0}))
        love.graphics.print(label, self.start_menu_x + main_icon_size + 10, item_y + (main_h - love.graphics.getFont():getHeight())/2)
        if id == 'programs' or id == 'documents' or id == 'settings' then
            love.graphics.setColor(theme.text or {0,0,0})
            love.graphics.print('>', self.start_menu_x + self.start_menu_w - 15, item_y + (main_h - love.graphics.getFont():getHeight())/2)
        end
        item_y = item_y + main_h
    end

    draw_main_item('programs', Strings.get('start.programs','Programs'), resolveMainMenuIcon('programs'))
    draw_main_item('documents', Strings.get('start.documents','Documents'), resolveMainMenuIcon('documents'))
    draw_main_item('settings', Strings.get('start.settings','Settings'), resolveMainMenuIcon('settings'))

    -- Separator
    item_y = item_y + 5
    love.graphics.setColor(theme.separator or {0.5, 0.5, 0.5})
    love.graphics.line(self.start_menu_x + 5, item_y, self.start_menu_x + self.start_menu_w - 5, item_y)
    item_y = item_y + 5

    -- Help (no-op)
    draw_main_item('help', Strings.get('start.help','Help'), resolveMainMenuIcon('help'))

    -- Run
    local run_hovered = (state.hovered_main_id or state.keyboard_start_selected_id) == 'run'
    if run_hovered then
        local inset = start_cfg.highlight_inset or 2
        love.graphics.setColor(theme.highlight or {0, 0, 0.5})
        love.graphics.rectangle('fill', self.start_menu_x + inset, item_y, self.start_menu_w - 2 * inset, main_h)
    end
    local icon_x = self.start_menu_x + 5
    local icon_y_centered = item_y + (main_h - main_icon_size) / 2
    sprite_loader:drawSprite('console_prompt-0', icon_x, icon_y_centered, main_icon_size, main_icon_size, run_hovered and {1.2,1.2,1.2} or {1,1,1})
    love.graphics.setColor(run_hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0,0,0}))
    love.graphics.print(Strings.get('start.run','Run...'), self.start_menu_x + main_icon_size + 10, item_y + (main_h - love.graphics.getFont():getHeight())/2)
    love.graphics.setColor(theme.shortcut or {0.4, 0.4, 0.4})
    love.graphics.print('Ctrl+R', self.start_menu_x + self.start_menu_w - (start_cfg.run_shortcut_offset or 60), item_y + (main_h - love.graphics.getFont():getHeight())/2, 0, 0.8, 0.8)

    -- Shutdown
    item_y = item_y + main_h
    local shut_hovered = (state.hovered_main_id or state.keyboard_start_selected_id) == 'shutdown'
    if shut_hovered then
        local inset = start_cfg.highlight_inset or 2
        love.graphics.setColor(theme.highlight or {0, 0, 0.5})
        love.graphics.rectangle('fill', self.start_menu_x + inset, item_y, self.start_menu_w - 2 * inset, main_h)
    end
    local icon_x2 = self.start_menu_x + 5
    local icon_y_centered2 = item_y + (main_h - main_icon_size) / 2
    sprite_loader:drawSprite('conn_pcs_off_off', icon_x2, icon_y_centered2, main_icon_size, main_icon_size, shut_hovered and {1.2,1.2,1.2} or {1,1,1})
    love.graphics.setColor(shut_hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0,0,0}))
    love.graphics.print(Strings.get('start.shutdown','Shut down...'), self.start_menu_x + main_icon_size + 10, item_y + (main_h - love.graphics.getFont():getHeight())/2)

    -- Draw cascading panes; fallback to legacy submenu when none
    if state.open_panes and #state.open_panes > 0 then
        for _, pane in ipairs(state.open_panes) do self:drawPane(pane, state) end
        -- Draw insertion indicator when dragging in the active pane, unless we're dropping INTO a folder
        if state.dnd_active and state.open_panes[state.dnd_pane_index or 1] and not (state.dnd_drop_mode == 'into' and state.dnd_target_folder_path) then
            local pane = state.open_panes[state.dnd_pane_index or 1]
            local start_cfg2 = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
            local item_h2 = start_cfg2.item_height or 25
            local padding2 = start_cfg2.padding or 10
            local idx2 = math.max(1, state.dnd_hover_index or state.dnd_source_index or 1)
            local y2 = pane.bounds.y + padding2 + (idx2 - 1) * item_h2
            local theme2 = (self.config and self.config.ui and self.config.ui.colors and self.config.ui.colors.start_menu) or {}
            love.graphics.setColor(theme2.highlight or {0,0,0.5})
            love.graphics.rectangle('fill', pane.bounds.x + 2, y2 - 2, pane.bounds.w - 4, 3)
        end
    else
        if state.submenu_open_id == 'programs' then self:drawProgramsSubmenu(state)
        elseif state.submenu_open_id == 'documents' then self:drawDocumentsSubmenu(state)
        elseif state.submenu_open_id == 'settings' then self:drawSettingsSubmenu(state) end
    end
end

function StartMenuView:mousepressedStartMenu(x, y, button, state)
    if button ~= 1 then return nil end
    local in_main = (x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and y >= self.start_menu_y and y <= self.start_menu_y + self.start_menu_h)
    local sub = self:getSubmenuBounds(state)
    local in_sub = sub and (x >= sub.x and x <= sub.x + sub.w and y >= sub.y and y <= sub.y + sub.h)
    local in_pane = false
    local hit_pane = nil
    local hit_pane_level = nil
    for i, p in ipairs(state.open_panes or {}) do local b = p.bounds; if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then in_pane=true; hit_pane=p; hit_pane_level=i; break end end
    if in_main or in_sub or in_pane then
        state._start_menu_pressed_id = true
        -- Start drag if pressed on a reorder-eligible item in the hit pane (supports nested panes)
        if hit_pane then
            local idx = self:getPaneIndexAtPosition(hit_pane, x, y)
            local it = idx and hit_pane.items and hit_pane.items[idx]
            local function isFsRootRestricted(path)
                return path == '/My Computer/C:/Documents' or path == '/Control Panel'
            end
            if idx and it then
                if hit_pane.kind == 'programs' and it.program_id then
                    state.dnd_pending = { pane_index=hit_pane_level, source_index=idx, hover_index=idx, item_id=it.program_id, entry_key=nil, scope='programs' }
                    state.dnd_start_x, state.dnd_start_y = x, y
                elseif hit_pane.kind == 'fs' and hit_pane.parent_path and not isFsRootRestricted(hit_pane.parent_path) then
                    if it.type == 'program' and it.program_id then
                        -- Program inside a folder: keep program_id; use name as entry key for same-folder reordering
                        state.dnd_pending = { pane_index=hit_pane_level, source_index=idx, hover_index=idx, item_id=it.program_id, entry_key=it.name, scope=hit_pane.parent_path }
                        state.dnd_start_x, state.dnd_start_y = x, y
                    elseif it.type == 'executable' and it.program_id then
                        -- Executable node with a program_id: treat similarly to a program entry
                        local key = it.path or it.name
                        state.dnd_pending = { pane_index=hit_pane_level, source_index=idx, hover_index=idx, item_id=it.program_id, entry_key=key, scope=hit_pane.parent_path }
                        state.dnd_start_x, state.dnd_start_y = x, y
                    else
                        local key = it.path or it.name
                        if key then
                            state.dnd_pending = { pane_index=hit_pane_level, source_index=idx, hover_index=idx, item_id=nil, entry_key=key, scope=hit_pane.parent_path }
                            state.dnd_start_x, state.dnd_start_y = x, y
                        end
                    end
                end
            end
        end
        return { name = 'start_menu_pressed' }
    end
    return { name = 'close_start_menu' }
end

function StartMenuView:mousereleasedStartMenu(x, y, button, state)
    if button ~= 1 then return nil end
    local in_main = (x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and y >= self.start_menu_y and y <= self.start_menu_y + self.start_menu_h)
    local sub = self:getSubmenuBounds(state)
    local in_sub = sub and (x >= sub.x and x <= sub.x + sub.w and y >= sub.y and y <= sub.y + sub.h)
    -- Cascading pane click
    local in_pane = false; local pane_ref=nil; local row_idx=nil; local pane_level=nil
    for i, p in ipairs(state.open_panes or {}) do local b=p.bounds; if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then in_pane=true; pane_ref=p; pane_level=i; row_idx=self:getPaneIndexAtPosition(p,x,y); break end end
    if not in_main and not in_sub and not in_pane then
        state._start_menu_pressed_id=nil
        -- Always clear drag state on mouse release, even if dropping outside
        state.dnd_active=false; state.dnd_source_index=nil; state.dnd_hover_index=nil; state.dnd_pane_index=nil; state.dnd_item_id=nil; state.dnd_entry_key=nil; state.dnd_scope=nil; state.dnd_pending=nil; state.dnd_start_x=nil; state.dnd_start_y=nil
        return { name = 'close_start_menu' }
    end
    -- Finish drag reorder first if active, even if not exactly over a row
    if in_pane and pane_ref then
        if state.dnd_active then
            state._start_menu_pressed_id = nil
            local fs = self.file_system
            local function isFsRootRestricted(path)
                -- Only allow operations inside dynamic roots
                return not (fs and fs.isPathInDynamicRoot and fs:isPathInDynamicRoot(path))
            end
            -- Preferred branch: dropping directly INTO a hovered folder
            if state.dnd_drop_mode == 'into' and state.dnd_target_folder_path then
                local dst_path = state.dnd_target_folder_path
                -- Guard against relocating a folder into itself/descendant
                if state.dnd_entry_key and (state.dnd_entry_key == dst_path or (dst_path:sub(1, #state.dnd_entry_key) == state.dnd_entry_key and (dst_path == state.dnd_entry_key or dst_path:sub(#state.dnd_entry_key+1, #state.dnd_entry_key+1) == '/'))) then
                    -- Cancel and consume
                    state.dnd_active=false; state.dnd_source_index=nil; state.dnd_hover_index=nil; state.dnd_pane_index=nil; state.dnd_item_id=nil; state.dnd_entry_key=nil; state.dnd_scope=nil; state.dnd_drop_mode=nil; state.dnd_target_folder_path=nil
                    return { name = 'start_menu_pressed' }
                end
                -- FS entry being dragged into folder: move using FileSystem
                local src_path = state.dnd_scope
                if fs and src_path and state.dnd_entry_key and not isFsRootRestricted(src_path) and not isFsRootRestricted(dst_path) then
                    pcall(fs.moveEntry, fs, state.dnd_entry_key, dst_path)
                end
                -- Refresh panes and clear drag state
                for _, p in ipairs(state.open_panes or {}) do
                    if p.kind == 'fs' and p.parent_path then p.items = self:buildPaneItems('fs', p.parent_path) end
                end
                if state.open_panes and #state.open_panes > 0 then self:reflowOpenPanesBounds(state) end
                state.dnd_active=false; state.dnd_source_index=nil; state.dnd_hover_index=nil; state.dnd_pane_index=nil; state.dnd_item_id=nil; state.dnd_entry_key=nil; state.dnd_scope=nil; state.dnd_drop_mode=nil; state.dnd_target_folder_path=nil
                return { name = 'start_menu_pressed' }
            end
            -- Compute insertion index from y position
            local b = pane_ref.bounds
            local cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
            local item_h = cfg.item_height or 25
            local padding = cfg.padding or 10
            local idx_calc
            if y < b.y + padding then idx_calc = 1
            elseif y > b.y + b.h then idx_calc = (#(pane_ref.items or {}) ) + 1
            else idx_calc = math.floor((y - (b.y + padding)) / item_h) + 1 end
            local target_idx = math.max(1, idx_calc or state.dnd_hover_index or 1)
            -- Ignore program drag paths; Start is FS-only now
            -- Ignore moving FS entries into 'programs' pane; FS-only editing occurs within FS panes
            -- Ignore program drag cases
            -- Folder reorder or relocate (includes program entries living in folder panes) (insert-line behavior)
            if state.dnd_scope and pane_ref.kind == 'fs' and state.dnd_entry_key then
                local dst_path = pane_ref.parent_path
                local src_path = state.dnd_scope
                if dst_path and not isFsRootRestricted(dst_path) then
                    -- Prevent relocating a folder into itself or its descendant
                    if state.dnd_entry_key == dst_path or (dst_path:sub(1, #state.dnd_entry_key) == state.dnd_entry_key and (dst_path == state.dnd_entry_key or dst_path:sub(#state.dnd_entry_key+1, #state.dnd_entry_key+1) == '/')) then
                        -- Cancel move, consume event
                        state.dnd_active=false; state.dnd_source_index=nil; state.dnd_hover_index=nil; state.dnd_pane_index=nil; state.dnd_item_id=nil; state.dnd_entry_key=nil; state.dnd_scope=nil
                        return { name = 'start_menu_pressed' }
                    end
                    -- Cross-folder relocate for FS entry (append order)
                    if fs and src_path ~= dst_path then pcall(fs.moveEntry, fs, state.dnd_entry_key, dst_path) end
                    -- Refresh all panes so updates are immediate
                    for _, p in ipairs(state.open_panes or {}) do
                        if p.kind == 'fs' and p.parent_path then p.items = self:buildPaneItems('fs', p.parent_path) end
                    end
                    state.dnd_active=false; state.dnd_source_index=nil; state.dnd_hover_index=nil; state.dnd_pane_index=nil; state.dnd_item_id=nil; state.dnd_entry_key=nil; state.dnd_scope=nil
                    return { name = 'start_menu_pressed' }
                end
            end
            -- Could not drop (invalid target); cancel drag without activating items
            state.dnd_active=false; state.dnd_source_index=nil; state.dnd_hover_index=nil; state.dnd_pane_index=nil; state.dnd_item_id=nil; state.dnd_entry_key=nil; state.dnd_scope=nil; state.dnd_pending=nil; state.dnd_start_x=nil; state.dnd_start_y=nil; state.dnd_drop_mode=nil; state.dnd_target_folder_path=nil
            return { name = 'start_menu_pressed' }
        end
    end
    -- If not dragging, process item activation when directly on a row
    if in_pane and pane_ref and row_idx and pane_ref.items and pane_ref.items[row_idx] then
        local item = pane_ref.items[row_idx]
        state._start_menu_pressed_id = nil
        -- Check for programs (type='program') or executables (type='executable' with program_id)
        if item.type == 'program' then
            return { name = 'launch_program', program_id = item.program_id }
        elseif item.type == 'executable' and item.program_id then
            return { name = 'launch_program', program_id = item.program_id }
        elseif item.type ~= 'folder' then
            return { name = 'open_path', path = item.path }
        else
            return nil
        end
    end
    -- Legacy submenu activation
    if in_sub then
        local sub_item = self:getStartMenuSubItemAtPosition(x, y, state)
        state._start_menu_pressed_id = nil
        if sub_item then
            if state.submenu_open_id == 'programs' then return { name='launch_program', program_id=sub_item }
            else return { name='open_path', path=sub_item } end
        end
        return nil
    end
    -- Main items: only Run/Shutdown/Help activate on click here
    local main = self:getStartMenuMainAtPosition(x, y)
    state._start_menu_pressed_id = nil
    state.dnd_active=false; state.dnd_source_index=nil; state.dnd_hover_index=nil; state.dnd_pane_index=nil; state.dnd_item_id=nil; state.dnd_entry_key=nil; state.dnd_scope=nil; state.dnd_pending=nil; state.dnd_start_x=nil; state.dnd_start_y=nil; state.dnd_drop_mode=nil; state.dnd_target_folder_path=nil
    if main == 'run' then return { name='open_run' }
    elseif main=='shutdown' then return { name='open_shutdown' }
    elseif main=='help' then return { name='close_start_menu' } end
    return nil
end

function StartMenuView:mousemovedStartMenu(x, y, dx, dy, state)
    -- Activate pending drag after threshold
    if state.dnd_pending and (math.abs((x or 0) - (state.dnd_start_x or 0)) + math.abs((y or 0) - (state.dnd_start_y or 0)) >= (self.dnd_threshold or 4)) then
        local p = state.dnd_pending
        state.dnd_active = true
        state.dnd_source_index = p.source_index
        state.dnd_hover_index = p.hover_index
        state.dnd_pane_index = p.pane_index
        state.dnd_item_id = p.item_id
        state.dnd_entry_key = p.entry_key
        state.dnd_scope = p.scope
        state.dnd_pending = nil
    end
    if not state.dnd_active then return end
    -- Choose the pane under the cursor vertically to support cross-pane targeting
    local pane = nil
    local pane_idx = state.dnd_pane_index or 1
    for i, p in ipairs(state.open_panes or {}) do
        local btest = p.bounds
        if btest and y >= btest.y and y <= btest.y + btest.h then pane = p; pane_idx = i; break end
    end
    pane = pane or ((state.open_panes and state.open_panes[state.dnd_pane_index or 1]) or nil)
    if not pane or not pane.bounds then return end
    state.dnd_pane_index = pane_idx
    local b = pane.bounds
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local padding = start_cfg.padding or 10
    local idx
    -- Compute index from vertical position even if cursor is horizontally outside the pane
    if y < b.y + padding then
        idx = 1
    elseif y > b.y + b.h then
        idx = (#pane.items or 0) + 1
    else
        idx = math.floor((y - (b.y + padding)) / item_h) + 1
    end
    if idx and idx >= 1 then state.dnd_hover_index = idx end
    -- Determine if we are directly hovering a folder row (x within pane bounds) to enable drop-into-folder behavior
    local direct_idx = self:getPaneIndexAtPosition(pane, x, y)
    local direct_item = (direct_idx and pane.items and pane.items[direct_idx]) or nil
    if direct_item and direct_item.type == 'folder' then
        state.dnd_drop_mode = 'into'
        state.dnd_target_folder_path = direct_item.path
        -- For visual accuracy, snap hover index to the folder row
        state.dnd_hover_index = direct_idx or state.dnd_hover_index
    else
        state.dnd_drop_mode = nil
        state.dnd_target_folder_path = nil
    end
end

-- Hit-testing helpers
function StartMenuView:isPointInStartMenu(x, y)
    return x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and y >= self.start_menu_y and y <= self.start_menu_y + self.start_menu_h
end

function StartMenuView:isPointInStartMenuOrSubmenu(x, y, state)
    if self:isPointInStartMenu(x, y) then return true end
    local bounds = self.getSubmenuBounds and self:getSubmenuBounds(state) or nil
    if bounds and x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then return true end
    for _, pane in ipairs(state.open_panes or {}) do local b=pane.bounds; if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then return true end end
    return false
end

-- Context hit-test for right-clicks: returns { area='pane'|'submenu'|'main', ... }
function StartMenuView:hitTestStartMenuContext(x, y, state)
    -- Check panes first
    for i, pane in ipairs(state.open_panes or {}) do
        local b = pane.bounds
        if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then
            local idx = self:getPaneIndexAtPosition(pane, x, y)
            local item = (idx and pane.items and pane.items[idx]) or nil
            return { area='pane', pane_index=i, kind=pane.kind, parent_path=pane.parent_path, index=idx, item=item }
        end
    end
    -- Legacy submenu
    local sub_bounds = self:getSubmenuBounds(state)
    if sub_bounds and x>=sub_bounds.x and x<=sub_bounds.x+sub_bounds.w and y>=sub_bounds.y and y<=sub_bounds.y+sub_bounds.h then
        local sub_id = self:getStartMenuSubItemAtPosition(x, y, state)
        return { area='submenu', submenu=state.submenu_open_id, id=sub_id }
    end
    -- Main area
    if self:isPointInStartMenu(x, y) then
        local main = self:getStartMenuMainAtPosition(x, y)
        return { area='main', main=main }
    end
    return nil
end

function StartMenuView:getStartMenuProgramAtPosition(x, y)
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local padding = start_cfg.padding or 10
    local item_h = start_cfg.item_height or 25
    local main_h = start_cfg.main_item_height or (item_h * 2)
    local y0 = self.start_menu_y + padding
    local sep_top = y0 + main_h * 3
    local sep_bottom = sep_top + (start_cfg.separator_space or 10)
    local run_top = sep_bottom + main_h
    local shut_top = sep_bottom + main_h * 2
    if x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and y >= run_top and y <= run_top + main_h then return 'run' end
    if x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and y >= shut_top and y <= shut_top + main_h then return 'shutdown' end
    return nil
end

-- Main item hit-test
function StartMenuView:getStartMenuMainAtPosition(x, y)
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local main_h = start_cfg.main_item_height or (item_h * 2)
    local padding = start_cfg.padding or 10
    if x < self.start_menu_x or x > self.start_menu_x + self.start_menu_w then return nil end
    if y < self.start_menu_y + padding or y > self.start_menu_y + self.start_menu_h then return nil end
    local y0 = self.start_menu_y + padding
    if y >= y0 and y < y0 + main_h then return 'programs' end
    if y >= y0 + main_h and y < y0 + main_h * 2 then return 'documents' end
    if y >= y0 + main_h * 2 and y < y0 + main_h * 3 then return 'settings' end
    local sep_top = y0 + main_h * 3
    local sep_bottom = sep_top + (start_cfg.separator_space or 10)
    if y >= sep_top and y < sep_bottom then return nil end
    if y >= sep_bottom and y < sep_bottom + main_h then return 'help' end
    if y >= sep_bottom + main_h and y < sep_bottom + main_h * 2 then return 'run' end
    if y >= sep_bottom + main_h * 2 and y < sep_bottom + main_h * 3 then return 'shutdown' end
    return nil
end

function StartMenuView:getSubmenuBounds(state)
    if state.submenu_open_id ~= 'programs' and state.submenu_open_id ~= 'documents' and state.submenu_open_id ~= 'settings' then return nil end
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local main_h = start_cfg.main_item_height or (item_h * 2)
    local padding = start_cfg.padding or 10
    local count = 0
    if state.submenu_open_id == 'programs' then local items = self.program_registry:getStartMenuPrograms() or {}; count = #items
    elseif state.submenu_open_id == 'documents' then local fs=self.file_system; local docs=fs and fs:getContents('/My Computer/C:/Documents') or {}; count=#docs
    else local fs=self.file_system; local items=fs and fs:getContents('/Control Panel') or {}; count=#items end
    local h = padding + count * item_h + 10
    local w = self.start_menu_w + (start_cfg.submenu_extra_width or 40)
    local x = self.start_menu_x + self.start_menu_w - (start_cfg.submenu_overlap or 2)
    local rowIndex = (state.submenu_open_id == 'programs') and 0 or ((state.submenu_open_id == 'documents') and 1 or 2)
    local y = self.start_menu_y + padding + rowIndex * main_h
    local screen_h = love.graphics.getHeight()
    -- Clamp inside screen (minY) and above taskbar (maxY)
    local minY = 10
    local maxY = screen_h - self.taskbar_height - 2
    local maxH = math.max(0, maxY - minY)
    if h > maxH then h = maxH end
    if y < minY then y = minY end
    if y + h > maxY then y = math.max(minY, maxY - h) end
    return {x=x, y=y, w=w, h=h}
end

function StartMenuView:getStartMenuSubItemAtPosition(x, y, state)
    local bounds = self:getSubmenuBounds(state); if not bounds then return nil end
    if x < bounds.x or x > bounds.x + bounds.w or y < bounds.y or y > bounds.y + bounds.h then return nil end
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local padding = start_cfg.padding or 10
    local index = math.floor((y - (bounds.y + padding)) / item_h) + 1
    if state.submenu_open_id == 'programs' then local fs=self.file_system; local items=fs and fs:getContents(Constants.paths.START_MENU_PROGRAMS) or {}; local e=items[index]; return e and e.path or nil
    elseif state.submenu_open_id == 'documents' then local fs=self.file_system; local docs=fs and fs:getContents('/My Computer/C:/Documents') or {}; local e=docs[index]; return e and e.path or nil
    elseif state.submenu_open_id == 'settings' then local fs=self.file_system; local items=fs and fs:getContents('/Control Panel') or {}; local e=items[index]; return e and e.path or nil end
    return nil
end

-- Legacy submenus drawing
function StartMenuView:drawProgramsSubmenu(state)
    local bounds = self:getSubmenuBounds(state); if not bounds then return end
    local theme = (self.config and self.config.ui and self.config.ui.colors and self.config.ui.colors.start_menu) or {}
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25; local icon_size = start_cfg.icon_size or 20
    local prev_sx, prev_sy, prev_sw, prev_sh = love.graphics.getScissor()
    love.graphics.setScissor(bounds.x, bounds.y, bounds.w, bounds.h)
    love.graphics.setColor(theme.bg or {0.75, 0.75, 0.75}); love.graphics.rectangle('fill', bounds.x, bounds.y, bounds.w, bounds.h)
    love.graphics.setColor(theme.border_dark or {0.2, 0.2, 0.2}); love.graphics.rectangle('line', bounds.x, bounds.y, bounds.w, bounds.h)
    -- Read from FS path for Programs to keep parity with cascading panes
    local fs = self.file_system; local items = fs and fs:getContents(Constants.paths.START_MENU_PROGRAMS) or {}
    -- Reuse FE icon resolver when available for consistent icons
    local okFE, FileExplorerView = pcall(require, 'src.views.file_explorer_view')
    local fe_resolve = nil
    if okFE and FileExplorerView and FileExplorerView.resolveItemSprite then
        fe_resolve = function(item)
            local controller = { program_registry = self.program_registry, file_system = self.file_system }
            local dummy = { controller = controller, resolveItemSprite = FileExplorerView.resolveItemSprite, getControlPanelIconSprite = function() return nil end }
            return FileExplorerView.resolveItemSprite(dummy, item)
        end
    end
    local y = bounds.y + (start_cfg.padding or 10)
    for _, entry in ipairs(items) do
        local is_hovered = state.hovered_sub_id == entry.path
        if is_hovered then love.graphics.setColor(theme.highlight or {0,0,0.5}); love.graphics.rectangle('fill', bounds.x + 2, y, bounds.w - 4, item_h) end
        local sprite
        if fe_resolve then sprite = fe_resolve(entry) else
            local icon = (fs and fs.getItemIcon and fs:getItemIcon(entry)) or 'file'
            sprite = (icon == 'folder' and 'directory_open_file_mydocs_small-0') or (icon == 'exe' and 'executable-0') or (entry.name and entry.name:match('%.txt$') and 'notepad_file-0') or 'document-0'
        end
        love.graphics.setColor(1,1,1); sprite_loader:drawSprite(sprite, bounds.x + 5, y + (item_h - icon_size)/2, icon_size, icon_size, is_hovered and {1.2,1.2,1.2} or {1,1,1})
        love.graphics.setColor(is_hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0,0,0})); love.graphics.print(entry.name, bounds.x + icon_size + 10, y + 5)
        y = y + item_h
    end
    love.graphics.setScissor(prev_sx, prev_sy, prev_sw, prev_sh)
end

function StartMenuView:drawDocumentsSubmenu(state)
    local bounds = self:getSubmenuBounds(state); if not bounds then return end
    local theme = (self.config and self.config.ui and self.config.ui.colors and self.config.ui.colors.start_menu) or {}
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25; local icon_size = start_cfg.icon_size or 20
    local prev_sx, prev_sy, prev_sw, prev_sh = love.graphics.getScissor()
    love.graphics.setScissor(bounds.x, bounds.y, bounds.w, bounds.h)
    love.graphics.setColor(theme.bg or {0.75, 0.75, 0.75}); love.graphics.rectangle('fill', bounds.x, bounds.y, bounds.w, bounds.h)
    love.graphics.setColor(theme.border_dark or {0.2, 0.2, 0.2}); love.graphics.rectangle('line', bounds.x, bounds.y, bounds.w, bounds.h)
    local fs = self.file_system; local docs = fs and fs:getContents('/My Computer/C:/Documents') or {}
    local okFE, FileExplorerView = pcall(require, 'src.views.file_explorer_view')
    local fe_resolve = nil
    if okFE and FileExplorerView and FileExplorerView.resolveItemSprite then
        fe_resolve = function(item)
            local controller = { program_registry = self.program_registry, file_system = self.file_system }
            local dummy = { controller = controller, resolveItemSprite = FileExplorerView.resolveItemSprite, getControlPanelIconSprite = function() return nil end }
            return FileExplorerView.resolveItemSprite(dummy, item)
        end
    end
    local y = bounds.y + (start_cfg.padding or 10)
    for _, entry in ipairs(docs) do
        local is_hovered = state.hovered_sub_id == entry.path
        if is_hovered then love.graphics.setColor(theme.highlight or {0,0,0.5}); love.graphics.rectangle('fill', bounds.x + 2, y, bounds.w - 4, item_h) end
        local sprite
        if fe_resolve then sprite = fe_resolve(entry) else
            local icon = (fs and fs.getItemIcon and fs:getItemIcon(entry)) or 'file'
            sprite = (icon == 'folder' and 'directory_open_file_mydocs_small-0') or (icon == 'exe' and 'executable-0') or (entry.name and entry.name:match('%.txt$') and 'notepad_file-0') or 'document-0'
        end
        love.graphics.setColor(1,1,1); sprite_loader:drawSprite(sprite, bounds.x + 5, y + (item_h - icon_size)/2, icon_size, icon_size, is_hovered and {1.2,1.2,1.2} or {1,1,1})
        love.graphics.setColor(is_hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0,0,0})); love.graphics.print(entry.name, bounds.x + icon_size + 10, y + 5)
        y = y + item_h
    end
    love.graphics.setScissor(prev_sx, prev_sy, prev_sw, prev_sh)
end

function StartMenuView:drawSettingsSubmenu(state)
    local bounds = self:getSubmenuBounds(state); if not bounds then return end
    local theme = (self.config and self.config.ui and self.config.ui.colors and self.config.ui.colors.start_menu) or {}
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25; local icon_size = start_cfg.icon_size or 20
    local prev_sx, prev_sy, prev_sw, prev_sh = love.graphics.getScissor()
    love.graphics.setScissor(bounds.x, bounds.y, bounds.w, bounds.h)
    love.graphics.setColor(theme.bg or {0.75, 0.75, 0.75}); love.graphics.rectangle('fill', bounds.x, bounds.y, bounds.w, bounds.h)
    love.graphics.setColor(theme.border_dark or {0.2, 0.2, 0.2}); love.graphics.rectangle('line', bounds.x, bounds.y, bounds.w, bounds.h)
    local fs = self.file_system; local items = fs and fs:getContents('/Control Panel') or {}
    local okFE, FileExplorerView = pcall(require, 'src.views.file_explorer_view')
    local fe_resolve = nil; local cp_resolve = nil
    if okFE and FileExplorerView then
        fe_resolve = FileExplorerView.resolveItemSprite and function(item)
            local controller = { program_registry = self.program_registry, file_system = self.file_system }
            local dummy = { controller = controller, resolveItemSprite = FileExplorerView.resolveItemSprite, getControlPanelIconSprite = FileExplorerView.getControlPanelIconSprite }
            return FileExplorerView.resolveItemSprite(dummy, item)
        end or nil
        cp_resolve = FileExplorerView.getControlPanelIconSprite and function(panel_key)
            local dummy = { _cp_icons_cache = {} }
            return FileExplorerView.getControlPanelIconSprite(dummy, panel_key)
        end or nil
    end
    local y = bounds.y + (start_cfg.padding or 10)
    for _, entry in ipairs(items) do
        local is_hovered = state.hovered_sub_id == entry.path
        if is_hovered then love.graphics.setColor(theme.highlight or {0,0,0.5}); love.graphics.rectangle('fill', bounds.x + 2, y, bounds.w - 4, item_h) end
        local sprite = 'executable-0'
        if fe_resolve then sprite = fe_resolve(entry) or sprite else
            if entry.path and entry.path:match('^/Control Panel/') and cp_resolve then
                local panel_key = entry.name and entry.name:lower():gsub('%s+', '') or nil
                sprite = (panel_key and cp_resolve(panel_key)) or sprite
            elseif entry.program_id then
                local prog = self.program_registry and self.program_registry:getProgram(entry.program_id)
                if prog and prog.icon_sprite then sprite = prog.icon_sprite end
            else sprite = 'settings_gear-0' end
        end
        love.graphics.setColor(1,1,1); sprite_loader:drawSprite(sprite, bounds.x + 5, y + (item_h - icon_size)/2, icon_size, icon_size, is_hovered and {1.2,1.2,1.2} or {1,1,1})
        love.graphics.setColor(is_hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0,0,0})); love.graphics.print(entry.name, bounds.x + icon_size + 10, y + 5)
        y = y + item_h
    end
    love.graphics.setScissor(prev_sx, prev_sy, prev_sw, prev_sh)
end

-- Cascading panes
function StartMenuView:updateCascade(mx, my, dt, state)
    dt = dt or 0
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local padding = start_cfg.padding or 10
    local extra_w = start_cfg.submenu_extra_width or 40
    local overlap = start_cfg.submenu_overlap or 2
    local main_h = start_cfg.main_item_height or (item_h * 2)
    if not state.open_panes then state.open_panes = {} end

    local root_kind, root_path, base_row = nil, nil, nil
    if state.hovered_main_id == 'documents' then root_kind='fs'; root_path='/My Computer/C:/Documents'; base_row=1
    elseif state.hovered_main_id == 'settings' then root_kind='fs'; root_path='/Control Panel'; base_row=2
    elseif state.hovered_main_id == 'programs' then root_kind='fs'; root_path=Constants.paths.START_MENU_PROGRAMS; base_row=0 end

    local inside_pane=false
    for _, p in ipairs(state.open_panes) do local b=p.bounds; if mx>=b.x and mx<=b.x+b.w and my>=b.y and my<=b.y+b.h then inside_pane=true; break end end
    -- Don't clear panes here; allow StartMenuView:update to handle grace close.
    -- We still process close timers even if not inside any pane/root.
    -- If not inside any pane and no root hovered, we will only advance close timers and potentially close panes after delay.

    local desired_root_id = root_kind and (root_kind .. '|' .. tostring(root_path or '')) or nil
    -- Create or re-create the root pane when hovering a root section. If the root id changed OR the
    -- root pane was previously closed (e.g., by leave-close timer), rebuild it.
    if desired_root_id and (state._cascade_root_id ~= desired_root_id or not (state.open_panes[1] and state.open_panes[1].kind)) then
        local base_x = self.start_menu_x + self.start_menu_w - overlap
        local base_y = self.start_menu_y + padding + (base_row or 0) * main_h
        local items = self:buildPaneItems(root_kind, root_path)
        local h = padding + (#items) * item_h + 10
        local w = self.start_menu_w + extra_w
        -- Clamp within screen top and above taskbar
        local minY = 10
        local maxY = love.graphics.getHeight() - self.taskbar_height - 2
        local maxH = math.max(0, maxY - minY)
        if h > maxH then h = maxH end
        if base_y < minY then base_y = minY end
        if base_y + h > maxY then base_y = math.max(minY, maxY - h) end
        state.open_panes[1] = { kind = root_kind, items = items, bounds = { x = base_x, y = base_y, w = w, h = h }, parent_path = root_path }
        state.cascade_hover = { level = nil, index = nil, t = 0 }
        for i=2,#state.open_panes do state.open_panes[i]=nil end
        state._cascade_root_id = desired_root_id
        -- Reset close timers beyond root
        state._pane_close = {}
        -- Immediately reflow to avoid a frame of incorrect size/position
        if state.open_panes and #state.open_panes > 0 then self:reflowOpenPanesBounds(state) end
    end

    -- active pane under cursor
    local level, idx = nil, nil
    for i,p in ipairs(state.open_panes) do local b=p.bounds; if mx>=b.x and mx<=b.x+b.w and my>=b.y and my<=b.y+b.h then level=i; idx=self:getPaneIndexAtPosition(p,mx,my); break end end

    -- Manage delayed closing for panes deeper than the active level (or all if mouse not over any pane)
    local function close_deeper_from(from_level)
        -- Never auto-close the root pane via leave timers; allow global grace to close it.
        local start_i = math.max(2, from_level)
        for i=start_i,#state.open_panes do state.open_panes[i]=nil; state._pane_close[i]=nil end
    end
    local active_level = level or 0
    -- Cancel pending close for panes up to the active level; advance timers for deeper ones
    for i=1,active_level do state._pane_close[i] = nil end
    for i=math.max(2, active_level+1), #state.open_panes do
        state._pane_close[i] = (state._pane_close[i] or 0) + (dt or 0)
        if (state._pane_close[i] or 0) >= (self.cascade_close_delay or 0.2) then
            close_deeper_from(i)
            -- Reflow right away to prevent a frame of stale bounds
            if state.open_panes and #state.open_panes > 0 then self:reflowOpenPanesBounds(state) end
            break
        end
    end

    if not level then state.cascade_hover.t = 0; return end
    -- Hover delay accumulation
    if state.cascade_hover.level ~= level or state.cascade_hover.index ~= idx then state.cascade_hover = { level=level, index=idx, t=0 } else state.cascade_hover.t=(state.cascade_hover.t or 0)+dt end
    local pane = state.open_panes[level]; if not pane or not idx or not pane.items or not pane.items[idx] then return end
    local item = pane.items[idx]; if item.type ~= 'folder' then return end
    -- If dragging this folder, do not open its child pane (avoids trapping drop target on the folder's own child pane)
    if state.dnd_active and state.dnd_entry_key and item.path == state.dnd_entry_key then return end
    if (state.cascade_hover.t or 0) < (self.cascade_hover_delay or 0.2) then return end
    local child_items = self:buildPaneItems('fs', item.path); if #child_items == 0 then return end
    local child_x = pane.bounds.x + pane.bounds.w - overlap
    local child_y = pane.bounds.y + padding + (idx - 1) * item_h
    local child_h = padding + (#child_items) * item_h + 10
    local child_w = self.start_menu_w + extra_w
    -- Clamp child pane
    local minY = 10
    local maxY = love.graphics.getHeight() - self.taskbar_height - 2
    local maxH = math.max(0, maxY - minY)
    if child_h > maxH then child_h = maxH end
    if child_y < minY then child_y = minY end
    if child_y + child_h > maxY then child_y = math.max(minY, maxY - child_h) end
    state.open_panes[level + 1] = { kind='fs', items=child_items, bounds={ x=child_x, y=child_y, w=child_w, h=child_h }, parent_path=item.path }
    -- When opening a new child, immediately discard panes deeper than it and reset close timer for this one
    for i=level+2, #state.open_panes do state.open_panes[i]=nil end
    state._pane_close[level + 1] = nil
    -- Reflow after opening child to clamp size
    if state.open_panes and #state.open_panes > 0 then self:reflowOpenPanesBounds(state) end
end

function StartMenuView:getPaneIndexAtPosition(pane, mx, my)
    if not pane or not pane.bounds then return nil end
    local b = pane.bounds
    if mx < b.x or mx > b.x + b.w or my < b.y or my > b.y + b.h then return nil end
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local padding = start_cfg.padding or 10
    local idx = math.floor((my - (b.y + padding)) / item_h) + 1
    return idx
end

function StartMenuView:buildPaneItems(kind, path)
    local items = {}
    if kind == 'programs' then
        local fs = self.file_system
        local progs = self.program_registry:getStartMenuPrograms() or {}
        local moves = self.program_registry and self.program_registry.getStartMenuMoves and self.program_registry:getStartMenuMoves() or {}
        for _, p in ipairs(progs) do
            -- Skip programs that have been moved to a folder or hidden to tomb
            local mv = moves['program:' .. p.id]
            if not mv or mv == 'PROGRAMS_ROOT' then
                if p.shortcut_type == 'folder' and p.shortcut_target and fs and fs:pathExists(p.shortcut_target) then
                    table.insert(items, { type = 'folder', name = p.name or p.shortcut_target, path = p.shortcut_target, program_id = p.id, icon_sprite = p.icon_sprite })
                else
                    table.insert(items, { type = 'program', name = p.name, program_id = p.id, icon_sprite = p.icon_sprite })
                end
            end
        end
    elseif kind == 'fs' then
        local fs = self.file_system
        local entries = fs and fs:getContents(path) or {}
        -- Pure FS view: no program registry overlays, no virtual injection, no custom ordering
        for _, e in ipairs(entries or {}) do
            local ty = e.type
            if ty == 'directory' then ty = 'folder' end
            table.insert(items, { type = ty, name = e.name, path = e.path, program_id = e.program_id, icon_sprite = e.icon_sprite })
        end
    end
    return items
end

function StartMenuView:drawPane(pane, state)
    if not pane or not pane.bounds then return end
    local theme = (self.config and self.config.ui and self.config.ui.colors and self.config.ui.colors.start_menu) or {}
    local sprite_loader = self.sprite_loader or (self.di and self.di.spriteLoader)
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local icon_size = start_cfg.icon_size or 20
    local padding = start_cfg.padding or 10
    local prev_sx, prev_sy, prev_sw, prev_sh = love.graphics.getScissor()
    love.graphics.setScissor(pane.bounds.x, pane.bounds.y, pane.bounds.w, pane.bounds.h)
    love.graphics.setColor(theme.bg or {0.75, 0.75, 0.75})
    love.graphics.rectangle('fill', pane.bounds.x, pane.bounds.y, pane.bounds.w, pane.bounds.h)
    love.graphics.setColor(theme.border_dark or {0.2, 0.2, 0.2})
    love.graphics.rectangle('line', pane.bounds.x, pane.bounds.y, pane.bounds.w, pane.bounds.h)
    local okFE, FileExplorerView = pcall(require, 'src.views.file_explorer_view')
    local fe_resolve = nil
    if okFE and FileExplorerView and FileExplorerView.resolveItemSprite then
        fe_resolve = function(item)
            local controller = { program_registry = self.program_registry, file_system = self.file_system }
            local dummy = { controller = controller, resolveItemSprite = FileExplorerView.resolveItemSprite, getControlPanelIconSprite = FileExplorerView.getControlPanelIconSprite }
            return FileExplorerView.resolveItemSprite(dummy, item)
        end
    end
    local y = pane.bounds.y + padding
    for i, entry in ipairs(pane.items) do
        local hovered = false
        local idx = self:getPaneIndexAtPosition(pane, love.mouse.getX(), love.mouse.getY())
        if not state.dnd_active and idx == i then love.graphics.setColor(theme.highlight or {0,0,0.5}); love.graphics.rectangle('fill', pane.bounds.x + 2, y, pane.bounds.w - 4, item_h); hovered = true end
        -- While dragging: highlight the folder row under the cursor when dropping INTO it
        if state.dnd_active and state.dnd_drop_mode == 'into' and entry.type == 'folder' and state.dnd_target_folder_path == entry.path then
            love.graphics.setColor(theme.highlight or {0,0,0.5})
            love.graphics.rectangle('fill', pane.bounds.x + 2, y, pane.bounds.w - 4, item_h)
        end
        local sprite
        if fe_resolve and entry.type ~= 'program' then
            sprite = fe_resolve(entry) or ((entry.type == 'folder') and 'directory_open_file_mydocs_small-0') or 'document-0'
        else
            if entry.icon_sprite then
                sprite = entry.icon_sprite
            elseif entry.type == 'folder' then
                sprite = 'directory_open_file_mydocs_small-0'
            elseif entry.type == 'executable' or entry.type == 'exe' then
                sprite = 'executable-0'
            else
                sprite = 'document-0'
            end
        end
        love.graphics.setColor(1,1,1); sprite_loader:drawSprite(sprite, pane.bounds.x + 5, y + (item_h - icon_size)/2, icon_size, icon_size, hovered and {1.2,1.2,1.2} or {1,1,1})
        love.graphics.setColor(hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0,0,0}))
        love.graphics.print(entry.name or '', pane.bounds.x + icon_size + 10, y + 5)
        if entry.type == 'folder' then love.graphics.setColor(theme.text or {0,0,0}); local chevron_x = pane.bounds.x + pane.bounds.w - 12; local chevron_y = y + (item_h - love.graphics.getFont():getHeight())/2; love.graphics.print('>', chevron_x, chevron_y) end
        y = y + item_h
    end
    love.graphics.setScissor(prev_sx, prev_sy, prev_sw, prev_sh)
end

-- Recompute bounds (height and position) for all currently open panes based on their items
function StartMenuView:reflowOpenPanesBounds(state)
    if not (state.open_panes and #state.open_panes > 0) then return end
    local start_cfg = (((self.config and self.config.ui and self.config.ui.desktop) or {}).start_menu) or {}
    local item_h = start_cfg.item_height or 25
    local padding = start_cfg.padding or 10
    local extra_w = start_cfg.submenu_extra_width or 40
    local overlap = start_cfg.submenu_overlap or 2
    local minY = 10
    local maxY = love.graphics.getHeight() - self.taskbar_height - 2
    local maxH = math.max(0, maxY - minY)
    for i, pane in ipairs(state.open_panes) do
        local count = #(pane.items or {})
        local h = padding + count * item_h + 10
        if h > maxH then h = maxH end
        local w = self.start_menu_w + extra_w
        local x = pane.bounds.x
        local y = pane.bounds.y
        -- For the root pane, recompute y from its anchor rows if needed
        if i == 1 then
            local main_h = start_cfg.main_item_height or (item_h * 2)
            local base_row = 0
            if pane.kind == 'fs' and pane.parent_path == '/My Computer/C:/Documents' then base_row = 1
            elseif pane.kind == 'fs' and pane.parent_path == '/Control Panel' then base_row = 2
            else base_row = 0 end
            y = self.start_menu_y + padding + base_row * main_h
            x = self.start_menu_x + self.start_menu_w - overlap
        else
            -- Child panes hang off the previous pane's hovered index approximate position; keep current x
            -- but clamp y within screen
        end
        if y < minY then y = minY end
        if y + h > maxY then y = math.max(minY, maxY - h) end
        pane.bounds.x, pane.bounds.y, pane.bounds.w, pane.bounds.h = x, y, w, h
    end
end

return StartMenuView
