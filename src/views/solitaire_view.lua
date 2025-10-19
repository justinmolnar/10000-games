local Object = require('class')
local Config = require('src.config')

local SolitaireView = Object:extend('SolitaireView')

-- Win98-style Klondike Solitaire (fully playable)
local SOLCFG = Config.games.solitaire and Config.games.solitaire.view or {}
local CARD_W = (SOLCFG.card and SOLCFG.card.width) or 72
local CARD_H = (SOLCFG.card and SOLCFG.card.height) or 96
local PADDING = (SOLCFG.layout and SOLCFG.layout.padding) or 12
local TOP_MARGIN = (SOLCFG.layout and SOLCFG.layout.top_margin) or 40
local FACEUP_DY = (SOLCFG.layout and SOLCFG.layout.faceup_dy) or 24
local FACEDOWN_DY = (SOLCFG.layout and SOLCFG.layout.facedown_dy) or 14

local RANK_STR = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}
local SolitaireSave = require('src.utils.solitaire_save')

function SolitaireView:init(state)
    self.state = state
    self.viewport = { x = 0, y = 0, width = 800, height = 600 }
    -- Options persist across new games
    self.options = {
        draw_count = 1,          -- 1 or 3
        redeal_limit = nil       -- nil = unlimited, or number (e.g., 3, 1)
    }
    self:resetGame()
end

function SolitaireView:resetGame()
    self.mode = 'play' -- 'play' | 'win'
    self.partyCanvas = nil
    self.partyCards = {}
    self.redeals_used = 0
    -- Build & shuffle deck
    local deck = {}
    local id = 1
    for s=1,4 do
        for r=1,13 do
            local color = (s % 2 == 0) and 'r' or 'b'
            table.insert(deck, { id=id, suit=s, rank=r, color=color, faceup=false })
            id = id + 1
        end
    end
    math.randomseed(os.time())
    for i=#deck,2,-1 do local j=math.random(i); deck[i],deck[j]=deck[j],deck[i] end

    -- Piles
    self.stock = {}
    self.waste = {}
    self.foundations = { {}, {}, {}, {} }
    self.tableau = { {}, {}, {}, {}, {}, {}, {} }

    -- Deal
    local idx = 1
    for col=1,7 do
        for row=1,col do
            local c = deck[idx]; idx=idx+1
            c.faceup = (row==col)
            table.insert(self.tableau[col], c)
        end
    end
    for i=idx,#deck do table.insert(self.stock, deck[i]) end

    -- Drag state
    self.drag = { active=false }
    -- Move history for undo
    self.history = {}
end

function SolitaireView:setViewport(x, y, w, h)
    self.viewport = { x=x, y=y, width=w, height=h }
    -- If in win mode, ensure the party canvas matches new viewport size
    if self.mode == 'win' then
        self:ensurePartyCanvas()
    end
end

function SolitaireView:enter() end

function SolitaireView:update(dt)
    if self.mode == 'win' then
        self:updateWin(dt)
    end
end

-- Persistence helpers
local function serializePile(pile)
    local out = {}
    for i=1,#pile do local c=pile[i]; out[i]={suit=c.suit, rank=c.rank, color=c.color, faceup=c.faceup} end
    return out
end

local function clonePileOfTables(pile)
    local out = {}
    for i=1,#pile do local c=pile[i]; out[i]={suit=c.suit, rank=c.rank, color=c.color, faceup=c.faceup} end
    return out
end

function SolitaireView:getSnapshot()
    -- Serialize tableaus, stock, waste, foundations, options and redeals
    local data = {
        mode = self.mode,
        options = { draw_count = self.options.draw_count, redeal_limit = self.options.redeal_limit },
        redeals_used = self.redeals_used,
        stock = serializePile(self.stock),
        waste = serializePile(self.waste),
        foundations = {
            serializePile(self.foundations[1]),
            serializePile(self.foundations[2]),
            serializePile(self.foundations[3]),
            serializePile(self.foundations[4])
        },
        tableau = {
            serializePile(self.tableau[1]),
            serializePile(self.tableau[2]),
            serializePile(self.tableau[3]),
            serializePile(self.tableau[4]),
            serializePile(self.tableau[5]),
            serializePile(self.tableau[6]),
            serializePile(self.tableau[7])
        }
    }
    return data
end

function SolitaireView:loadSnapshot(data)
    if type(data) ~= 'table' then return end
    self.mode = data.mode or 'play'
    if data.options then
        self.options.draw_count = data.options.draw_count or 1
        self.options.redeal_limit = data.options.redeal_limit
    end
    self.redeals_used = data.redeals_used or 0
    local function rebuildPile(src)
        local out = {}
        if src then for i=1,#src do local c=src[i]; out[i]={ suit=c.suit, rank=c.rank, color=c.color or ((c.suit%2==0) and 'r' or 'b'), faceup=not not c.faceup } end end
        return out
    end
    self.stock = rebuildPile(data.stock)
    self.waste = rebuildPile(data.waste)
    self.foundations = {
        rebuildPile(data.foundations and data.foundations[1] or {}),
        rebuildPile(data.foundations and data.foundations[2] or {}),
        rebuildPile(data.foundations and data.foundations[3] or {}),
        rebuildPile(data.foundations and data.foundations[4] or {})
    }
    self.tableau = {
        rebuildPile(data.tableau and data.tableau[1] or {}),
        rebuildPile(data.tableau and data.tableau[2] or {}),
        rebuildPile(data.tableau and data.tableau[3] or {}),
        rebuildPile(data.tableau and data.tableau[4] or {}),
        rebuildPile(data.tableau and data.tableau[5] or {}),
        rebuildPile(data.tableau and data.tableau[6] or {}),
        rebuildPile(data.tableau and data.tableau[7] or {})
    }
    -- reset transient state
    self.drag = { active=false }
    self.history = {}
end

-- Layout helpers
function SolitaireView:getTopRowPositions()
    local vp = self.viewport
    local y = TOP_MARGIN
    local stock = { x=PADDING, y=y, w=CARD_W, h=CARD_H }
    local waste = { x=PADDING + CARD_W + PADDING, y=y, w=CARD_W, h=CARD_H }
    local fx = vp.width - (CARD_W + PADDING) * 4
    local foundations = {}
    for i=1,4 do
        foundations[i] = { x = fx + (i-1)*(CARD_W+PADDING), y=y, w=CARD_W, h=CARD_H }
    end
    return stock, waste, foundations
end

function SolitaireView:getTableauColumnRect(col)
    local y0 = TOP_MARGIN + CARD_H + PADDING*2
    local x = PADDING + (col-1) * (CARD_W + PADDING)
    return x, y0
end

-- Rules
local function canPlaceOnTableau(card, destTop)
    -- Empty column accepts any card (easier mode)
    if not destTop then return true end
    return destTop.faceup and (card.color ~= destTop.color) and (card.rank == destTop.rank - 1)
end

local function canPlaceOnFoundation(card, destTop)
    if not destTop then return card.rank == 1 end -- Ace
    return (card.suit == destTop.suit) and (card.rank == destTop.rank + 1)
end

function SolitaireView:isWin()
    for i=1,4 do if #(self.foundations[i]) < 13 then return false end end
    return true
end

-- Rendering
function SolitaireView:drawCard(x, y, card)
    local g = love.graphics
    if card.faceup then
        g.setColor(1,1,1)
        g.rectangle('fill', x, y, CARD_W, CARD_H, (SOLCFG.card and SOLCFG.card.corner_radius) or 6, (SOLCFG.card and SOLCFG.card.corner_radius) or 6)
        g.setColor(0,0,0)
        g.rectangle('line', x, y, CARD_W, CARD_H, (SOLCFG.card and SOLCFG.card.corner_radius) or 6, (SOLCFG.card and SOLCFG.card.corner_radius) or 6)
        local rank = RANK_STR[card.rank]
        if card.color == 'r' then g.setColor(0.8,0,0) else g.setColor(0,0,0) end
        g.print(rank, x + 6, y + 5)
    else
        local back = (SOLCFG.card and SOLCFG.card.back_color) or {0.3,0.5,0.8}
        g.setColor(back[1], back[2], back[3])
        g.rectangle('fill', x, y, CARD_W, CARD_H, (SOLCFG.card and SOLCFG.card.corner_radius) or 6, (SOLCFG.card and SOLCFG.card.corner_radius) or 6)
        g.setColor(1,1,1)
        g.rectangle('line', x, y, CARD_W, CARD_H, (SOLCFG.card and SOLCFG.card.corner_radius) or 6, (SOLCFG.card and SOLCFG.card.corner_radius) or 6)
    end
end

function SolitaireView:drawBoard()
    local g = love.graphics
    local vp = self.viewport
    -- Background felt
    local bg = (SOLCFG.bg_color) or {0.05, 0.25, 0.05}
    g.setColor(bg[1], bg[2], bg[3])
    g.rectangle('fill', 0, 0, vp.width, vp.height)

    local stockRect, wasteRect, foundationRects = self:getTopRowPositions()

    -- Stock
    if #self.stock > 0 then self:drawCard(stockRect.x, stockRect.y, {faceup=false})
    else local ec=(SOLCFG.empty_slot_color or {0.2,0.4,0.2}); g.setColor(ec[1],ec[2],ec[3]); g.rectangle('line', stockRect.x, stockRect.y, CARD_W, CARD_H, (SOLCFG.card and SOLCFG.card.corner_radius) or 6, (SOLCFG.card and SOLCFG.card.corner_radius) or 6) end

    -- Waste (draw top only for simplicity)
    if #self.waste > 0 then self:drawCard(wasteRect.x, wasteRect.y, self.waste[#self.waste])
    else local ec=(SOLCFG.empty_slot_color or {0.2,0.4,0.2}); g.setColor(ec[1],ec[2],ec[3]); g.rectangle('line', wasteRect.x, wasteRect.y, CARD_W, CARD_H, (SOLCFG.card and SOLCFG.card.corner_radius) or 6, (SOLCFG.card and SOLCFG.card.corner_radius) or 6) end

    -- Foundations
    for i=1,4 do
        local r = foundationRects[i]
    if #self.foundations[i] > 0 then self:drawCard(r.x, r.y, self.foundations[i][#self.foundations[i]])
    else local ec=(SOLCFG.empty_slot_color or {0.2,0.4,0.2}); g.setColor(ec[1],ec[2],ec[3]); g.rectangle('line', r.x, r.y, CARD_W, CARD_H, (SOLCFG.card and SOLCFG.card.corner_radius) or 6, (SOLCFG.card and SOLCFG.card.corner_radius) or 6) end
    end

    -- Tableau
    for c=1,7 do
        local x, y = self:getTableauColumnRect(c)
        local pile = self.tableau[c]
        for i=1,#pile do
            local card = pile[i]
            -- Skip drawing cards currently dragged
            if not (self.drag.active and self.drag.from.type=='tableau' and self.drag.from.col==c and i>=self.drag.from.index) then
                self:drawCard(x, y, card)
            end
            y = y + (card.faceup and FACEUP_DY or FACEDOWN_DY)
        end
    end

    -- Drag overlay
    if self.drag.active then
        local x, y = self.drag.x - self.drag.offset_x, self.drag.y - self.drag.offset_y
        for _, card in ipairs(self.drag.cards) do
            self:drawCard(x, y, card)
            y = y + (card.faceup and FACEUP_DY or FACEDOWN_DY)
        end
    end

    -- HUD: options
    love.graphics.setColor(1,1,1)
    local hud = string.format("Draw:%d  Redeals:%s%s", self.options.draw_count,
        (self.options.redeal_limit and tostring(self.options.redeal_limit) or "∞"),
        (self.options.redeal_limit and string.format(" (%d used)", self.redeals_used) or ""))
    local hud_pos = SOLCFG.hud or { x1 = PADDING, x2 = PADDING + 200, y = 8 }
    love.graphics.print(hud, hud_pos.x1 or PADDING, hud_pos.y or 8)
    love.graphics.print("N:New  D:Draw1/3  L:Redeal limit  Z:Undo", hud_pos.x2 or (PADDING + 200), hud_pos.y or 8)
end

function SolitaireView:draw()
    if self.mode == 'win' then
        self:drawWin()
        return
    end
    self:drawBoard()
end

-- Hit testing
function SolitaireView:hitTestTableau(x, y)
    for c=7,1,-1 do -- rightmost priority
        local cx, cy = self:getTableauColumnRect(c)
        local pile = self.tableau[c]
        -- Precompute y for each card
        local ys = {}
        local py = cy
        for i=1,#pile do ys[i]=py; py = py + (pile[i].faceup and FACEUP_DY or FACEDOWN_DY) end
        -- Test from topmost down so covered cards don't swallow clicks
        for i=#pile,1,-1 do
            local nextOffset = (i < #pile) and (pile[i+1].faceup and FACEUP_DY or FACEDOWN_DY) or CARD_H
            local rect_h = (i < #pile) and nextOffset or CARD_H
            if x >= cx and x <= cx + CARD_W and y >= ys[i] and y <= ys[i] + rect_h then
                return c, i
            end
        end
        -- empty column box
        if #pile == 0 and x >= cx and x <= cx + CARD_W and y >= cy and y <= cy + CARD_H then
            return c, 0
        end
    end
    return nil
end

function SolitaireView:hitInRect(x, y, r)
    return x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h
end

-- Dragging and moves
function SolitaireView:startDragFromTableau(col, index, mx, my)
    local pile = self.tableau[col]
    if index == 0 then return end
    local card = pile[index]
    if not card or not card.faceup then return end
    -- collect sequence (must be face-up chain)
    local seq = {}
    for i=index,#pile do table.insert(seq, pile[i]) end
    self.drag = {
        active = true,
        cards = seq,
        from = { type='tableau', col=col, index=index },
        x = mx, y = my, offset_x = (mx - (PADDING + (col-1)*(CARD_W+PADDING))),
        offset_y = 0
    }
    -- compute offset_y to top of clicked card
    local _, base_y = self:getTableauColumnRect(col)
    for i=1,index-1 do base_y = base_y + (pile[i].faceup and FACEUP_DY or FACEDOWN_DY) end
    self.drag.offset_y = mx*0 -- dummy to keep structure
    self.drag.offset_y = (my - base_y)
end

function SolitaireView:startDragFromWaste(mx, my)
    if #self.waste == 0 then return end
    local stockRect, wasteRect = self:getTopRowPositions()
    if not self:hitInRect(mx, my, wasteRect) then return end
    local card = self.waste[#self.waste]
    self.drag = { active=true, cards={card}, from={type='waste'}, x=mx, y=my, offset_x=mx - wasteRect.x, offset_y=my - wasteRect.y }
end

function SolitaireView:startDragFromFoundation(mx, my)
    local _, _, fRects = self:getTopRowPositions()
    for i=1,4 do
        if self:hitInRect(mx, my, fRects[i]) and #self.foundations[i] > 0 then
            local card = self.foundations[i][#self.foundations[i]]
            self.drag = { active=true, cards={card}, from={type='foundation', idx=i}, x=mx, y=my, offset_x=mx - fRects[i].x, offset_y=my - fRects[i].y }
            return
        end
    end
end

function SolitaireView:mousepressed(x, y, button)
    if self.mode == 'win' then return { type = 'content_interaction' } end
    if button ~= 1 then return false end

    local stockRect, wasteRect = self:getTopRowPositions()
    -- Click stock: flip 1 to waste, else recycle
    if self:hitInRect(x, y, stockRect) then
        if #self.stock > 0 then
            local take = math.min(self.options.draw_count, #self.stock)
            for i=1,take do local card = table.remove(self.stock); card.faceup=true; table.insert(self.waste, card) end
        else
            -- Recycle only if under redeal limit (or unlimited) and waste has cards
            local can_redeal = (self.options.redeal_limit == nil) or (self.redeals_used < self.options.redeal_limit)
            if can_redeal and #self.waste > 0 then
                for i=#self.waste,1,-1 do local c=table.remove(self.waste, i); c.faceup=false; table.insert(self.stock, 1, c) end
                self.redeals_used = self.redeals_used + 1
            end
        end
        return { type='content_interaction' }
    end

    -- Try start dragging from waste, then foundation, then tableau
    self:startDragFromWaste(x, y)
    if not self.drag.active then self:startDragFromFoundation(x, y) end
    if not self.drag.active then
        local col, index = self:hitTestTableau(x, y)
        if col then
            if index == 0 then
                -- empty column clicked - no drag
            else
                local card = self.tableau[col][index]
                if card and not card.faceup then
                    -- Flip only if it is the top card
                    if index == #self.tableau[col] then card.faceup = true end
                else
                    self:startDragFromTableau(col, index, x, y)
                end
            end
        end
    end
    return { type='content_interaction' }
end

-- Simple double-click to auto-move to foundation if legal
function SolitaireView:mousereleased(x, y, button)
    if button ~= 1 then return false end
    if self.drag.active then
        if not self:tryDrop(x, y) then self.drag = { active=false } end
        return { type='content_interaction' }
    end
    -- Detect quick second click by time (basic)
    local t = love.timer.getTime()
    self._last_click = self._last_click or { t=0, x=0, y=0 }
    local dc = SOLCFG.double_click or { time = 0.35, jitter = 8 }
    if t - self._last_click.t < (dc.time or 0.35) and math.abs(x - self._last_click.x) < (dc.jitter or 8) and math.abs(y - self._last_click.y) < (dc.jitter or 8) then
        -- Try waste first
        local moved = false
        local stockRect, wasteRect = self:getTopRowPositions()
        if self:hitInRect(x, y, wasteRect) and #self.waste>0 then
            local c = self.waste[#self.waste]
            for i=1,4 do local top=self.foundations[i][#(self.foundations[i])]; if canPlaceOnFoundation(c, top) then table.remove(self.waste); table.insert(self.foundations[i], c); table.insert(self.history, { from={type='waste'}, to={type='foundation', idx=i}, cards={c} }); moved=true; break end end
        end
        -- Try tableau top at clicked column
        if not moved then
            local col, index = self:hitTestTableau(x, y)
            if col and index>0 then
                local pile=self.tableau[col]; local c=pile[#pile]
                if c then
                    local flipped=nil
                    if #pile>1 and pile[#pile-1].faceup==false then flipped={col=col, card=pile[#pile-1]} end
                    for i=1,4 do local top=self.foundations[i][#(self.foundations[i])]; if canPlaceOnFoundation(c, top) then table.remove(pile); table.insert(self.foundations[i], c); table.insert(self.history, { from={type='tableau', col=col, index=#pile+1}, to={type='foundation', idx=i}, cards={c}, flipped=flipped }); moved=true; break end end
                end
            end
        end
        if moved then self:postMoveCleanup(); return { type='content_interaction' } end
    end
    self._last_click = { t=t, x=x, y=y }
    return false
end

function SolitaireView:mousemoved(x, y, dx, dy)
    if self.drag.active then self.drag.x = x; self.drag.y = y end
end

function SolitaireView:tryDrop(x, y)
    local _, _, fRects = self:getTopRowPositions()
    -- Foundations first (single card only)
    for i=1,4 do
        if self:hitInRect(x, y, fRects[i]) then
            local destTop = self.foundations[i][#(self.foundations[i])]
            local card = self.drag.cards[#self.drag.cards]
            if #self.drag.cards == 1 and canPlaceOnFoundation(card, destTop) then
                -- capture possible flip under origin
                local flipped=nil
                if self.drag.from.type=='tableau' and self.drag.from.index>1 then
                    local pile=self.tableau[self.drag.from.col]
                    local under=pile[self.drag.from.index-1]
                    if under and under.faceup==false then flipped={col=self.drag.from.col, card=under} end
                end
                local from=self.drag.from
                self:removeDraggedFromOrigin()
                table.insert(self.foundations[i], card)
                self:postMoveCleanup()
                table.insert(self.history, { from=from, to={type='foundation', idx=i}, cards={card}, flipped=flipped })
                return true
            end
        end
    end
    -- Tableau columns
    for c=1,7 do
        local cx, cy = self:getTableauColumnRect(c)
        local rect = { x=cx, y=cy, w=CARD_W, h= self.viewport.height - cy }
        if self:hitInRect(x, y, rect) then
            local destTop = self.tableau[c][#(self.tableau[c])]
            local first = self.drag.cards[1]
            if canPlaceOnTableau(first, destTop) then
                -- capture possible flip under origin
                local flipped=nil
                if self.drag.from.type=='tableau' and self.drag.from.index>1 then
                    local pile=self.tableau[self.drag.from.col]
                    local under=pile[self.drag.from.index-1]
                    if under and under.faceup==false then flipped={col=self.drag.from.col, card=under} end
                end
                local moved={}
                for _,cc in ipairs(self.drag.cards) do table.insert(moved, cc) end
                local from=self.drag.from
                self:removeDraggedFromOrigin()
                for _,card in ipairs(moved) do table.insert(self.tableau[c], card) end
                self:postMoveCleanup()
                table.insert(self.history, { from=from, to={type='tableau', col=c}, cards=moved, flipped=flipped })
                return true
            end
        end
    end
    return false
end

function SolitaireView:removeDraggedFromOrigin()
    local from = self.drag.from
    if from.type=='tableau' then
        local pile = self.tableau[from.col]
        for i=#pile, from.index, -1 do table.remove(pile, i) end
    elseif from.type=='waste' then
        table.remove(self.waste) -- last
    elseif from.type=='foundation' then
        table.remove(self.foundations[from.idx])
    end
end

function SolitaireView:postMoveCleanup()
    -- Flip newly exposed tableau card if needed
    for col=1,7 do
        local pile = self.tableau[col]
        if #pile > 0 and not pile[#pile].faceup then pile[#pile].faceup = true end
    end
    -- Win check
    if self:isWin() then self:startWinAnimation() end
    -- Clear drag
    self.drag = { active=false }
    -- Autosave after a completed move
    if self.getSnapshot then
        local ok, snap = pcall(self.getSnapshot, self)
        if ok and snap then SolitaireSave.save(snap) end
    end
end

function SolitaireView:keypressed(key)
    if key == 'space' then
        -- Draw based on difficulty option
        local n = math.min(self.options.draw_count, #self.stock)
        for i=1,n do local c=table.remove(self.stock); if c then c.faceup=true; table.insert(self.waste, c) end end
        return { type='content_interaction' }
    elseif key == 'n' then
        -- New game keeps options
        self:resetGame()
        return { type='content_interaction' }
    elseif key == 'd' then
        -- Toggle draw 1/3
        self.options.draw_count = (self.options.draw_count == 1) and 3 or 1
        return { type='content_interaction' }
    elseif key == 'l' then
        -- Cycle redeal limit: ∞ -> 3 -> 1 -> ∞
        local v = self.options.redeal_limit
        if v == nil then self.options.redeal_limit = 3
        elseif v == 3 then self.options.redeal_limit = 1
        else self.options.redeal_limit = nil end
        self.redeals_used = 0
        return { type='content_interaction' }
    elseif key == 'z' then
        -- Undo last placement
        if self.history and #self.history>0 then
            local m = table.remove(self.history)
            -- remove from destination
            if m.to.type=='foundation' then
                for i=1,#m.cards do table.remove(self.foundations[m.to.idx]) end
            elseif m.to.type=='tableau' then
                for i=1,#m.cards do table.remove(self.tableau[m.to.col]) end
            end
            -- restore to origin
            if m.from.type=='tableau' then
                for _,card in ipairs(m.cards) do table.insert(self.tableau[m.from.col], card) end
            elseif m.from.type=='waste' then
                for _,card in ipairs(m.cards) do table.insert(self.waste, card) end
            elseif m.from.type=='foundation' then
                for _,card in ipairs(m.cards) do table.insert(self.foundations[m.from.idx], card) end
            end
            -- restore flipped state if any
            if m.flipped and m.flipped.card then m.flipped.card.faceup = false end
            self.drag = { active=false }
        end
        return { type='content_interaction' }
    elseif key == 'a' then
        -- Auto-move top waste/tableau to foundations when legal (repeat while possible)
        local moved = true
        while moved do
            moved = false
            -- waste
            if #self.waste > 0 then
                for i=1,4 do
                    local top = self.foundations[i][#(self.foundations[i])]
                    local c = self.waste[#self.waste]
                    if canPlaceOnFoundation(c, top) then table.remove(self.waste); table.insert(self.foundations[i], c); table.insert(self.history, { from={type='waste'}, to={type='foundation', idx=i}, cards={c} }); moved=true; break end
                end
            end
            -- tableau tops
            for col=1,7 do
                local pile = self.tableau[col]
                local c = pile[#pile]
                if c then
                    local flipped=nil
                    if #pile>1 and pile[#pile-1].faceup==false then flipped={col=col, card=pile[#pile-1]} end
                    for i=1,4 do local top=self.foundations[i][#(self.foundations[i])]; if canPlaceOnFoundation(c, top) then table.remove(pile); table.insert(self.foundations[i], c); table.insert(self.history, { from={type='tableau', col=col, index=#pile+1}, to={type='foundation', idx=i}, cards={c}, flipped=flipped }); moved=true; break end end
                    if moved then break end
                end
            end
        end
        self:postMoveCleanup()
        return { type='content_interaction' }
    end
    return false
end

-- Win animation (bouncing cards that leave artifacts)
function SolitaireView:startWinAnimation()
    self.mode = 'win'
    local vp = self.viewport
    self.partyCanvas = love.graphics.newCanvas(vp.width, vp.height)
    -- Prime canvas with the current board rendering
    love.graphics.push()
    love.graphics.setCanvas(self.partyCanvas)
    self:drawBoard()
    love.graphics.setCanvas()
    love.graphics.pop()
    -- seed some bouncing cards
    self.partyCards = {}
    local win = SOLCFG.win or { party_count = 40 }
    for i=1,(win.party_count or 40) do
        local x = math.random(0, vp.width - CARD_W)
        local y = math.random(0, vp.height/3)
        local vx = ((SOLCFG.win and SOLCFG.win.init_vx_min) or 80) + math.random()*(((SOLCFG.win and SOLCFG.win.init_vx_max) or 240) - ((SOLCFG.win and SOLCFG.win.init_vx_min) or 80))
        if math.random()<0.5 then vx = -vx end
        local vy = - (((SOLCFG.win and SOLCFG.win.init_vy_min) or 120) + math.random()*(((SOLCFG.win and SOLCFG.win.init_vy_max) or 300) - ((SOLCFG.win and SOLCFG.win.init_vy_min) or 120)))
        table.insert(self.partyCards, { x=x, y=y, vx=vx, vy=vy })
    end
end

-- Ensure the win-mode canvas exists and matches viewport size
function SolitaireView:ensurePartyCanvas()
    local vp = self.viewport
    local needs_new = (not self.partyCanvas)
    if not needs_new then
        local cw, ch = self.partyCanvas:getDimensions()
        if cw ~= vp.width or ch ~= vp.height then
            needs_new = true
        end
    end
    if needs_new then
        self.partyCanvas = love.graphics.newCanvas(vp.width, vp.height)
        -- Prime the canvas with current board if possible
        love.graphics.push()
        love.graphics.setCanvas(self.partyCanvas)
        self:drawBoard()
        love.graphics.setCanvas()
        love.graphics.pop()
        -- If we just created a new canvas, also (re)seed some cards if none exist
        if not self.partyCards or #self.partyCards == 0 then
            self.partyCards = {}
            local win = SOLCFG.win or { party_count = 40 }
            for i=1,(win.party_count or 40) do
                local x = math.random(0, math.max(0, vp.width - CARD_W))
                local y = math.random(0, math.max(0, math.floor(vp.height/3)))
                local vx = ((SOLCFG.win and SOLCFG.win.init_vx_min) or 80) + math.random()*(((SOLCFG.win and SOLCFG.win.init_vx_max) or 240) - ((SOLCFG.win and SOLCFG.win.init_vx_min) or 80))
                if math.random()<0.5 then vx = -vx end
                local vy = - (((SOLCFG.win and SOLCFG.win.init_vy_min) or 120) + math.random()*(((SOLCFG.win and SOLCFG.win.init_vy_max) or 300) - ((SOLCFG.win and SOLCFG.win.init_vy_min) or 120)))
                table.insert(self.partyCards, { x=x, y=y, vx=vx, vy=vy })
            end
        end
    end
end

function SolitaireView:updateWin(dt)
    local vp = self.viewport
    -- Make sure canvas exists
    self:ensurePartyCanvas()
    love.graphics.push()
    love.graphics.setCanvas(self.partyCanvas)
    -- Do NOT clear canvas to preserve artifacts
    for _,c in ipairs(self.partyCards) do
        -- integrate
    c.vy = c.vy + ((SOLCFG.win and SOLCFG.win.gravity) or 420)*dt
        c.x = c.x + c.vx * dt
        c.y = c.y + c.vy * dt
        -- bounce
    if c.x < 0 then c.x=0; c.vx = -c.vx*((SOLCFG.win and SOLCFG.win.bounce_x_friction) or 0.98) end
    if c.x + CARD_W > vp.width then c.x = vp.width - CARD_W; c.vx = -c.vx*((SOLCFG.win and SOLCFG.win.bounce_x_friction) or 0.98) end
    if c.y + CARD_H > vp.height then c.y = vp.height - CARD_H; c.vy = -math.abs(c.vy)*((SOLCFG.win and SOLCFG.win.bounce_y_coeff) or 0.92) end
        -- draw card back at new pos (leaves trail)
        love.graphics.setColor(1,1,1)
    love.graphics.rectangle('line', c.x, c.y, CARD_W, CARD_H)
        love.graphics.setColor(0.95,0.95,0.95)
    love.graphics.rectangle('fill', c.x+1, c.y+1, CARD_W-2, CARD_H-2)
    end
    love.graphics.setCanvas()
    love.graphics.pop()
end

function SolitaireView:drawWin()
    love.graphics.setColor(1,1,1)
    if self.partyCanvas then
        love.graphics.draw(self.partyCanvas, 0, 0)
    else
        -- Fallback safeguard: if canvas is missing, just draw the board until canvas is ready
        self:drawBoard()
    end
    love.graphics.setColor(0,0,0)
    love.graphics.print("You Win! Press ESC to close", 12, 12, 0, 1.2, 1.2)
end

return SolitaireView
