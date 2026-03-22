-- Window Manager: Independent axis cycling with bidirectional navigation
--
-- Edge-snap mode (Ctrl+Option + arrows):
--   Each axis is a 7-position spectrum:
--   1/4 side ← 1/2 side ← 3/4 side ← FULL → 3/4 side → 1/2 side → 1/4 side
--   At the extremes, overflows to adjacent monitor or wraps.
--
-- Centered mode (Ctrl+Option+Cmd + arrows):
--   Cycles centered sizes: 3/4 → 1/2 → 1/4 (left/up = shrink, right/down = grow)
--   Each axis is independent. Regular arrows break back to edge-snap for that axis.

-- Edge-snap positions: horizontal (index 1-7, starting at 4 = full)
local hPos = {
    { x = 0,   w = 1/4 },  -- 1: left quarter
    { x = 0,   w = 1/2 },  -- 2: left half
    { x = 0,   w = 3/4 },  -- 3: left three quarters
    { x = 0,   w = 1   },  -- 4: full width
    { x = 1/4, w = 3/4 },  -- 5: right three quarters
    { x = 1/2, w = 1/2 },  -- 6: right half
    { x = 3/4, w = 1/4 },  -- 7: right quarter
}

-- Edge-snap positions: vertical (index 1-7, starting at 4 = full)
local vPos = {
    { y = 0,   h = 1/4 },  -- 1: top quarter
    { y = 0,   h = 1/2 },  -- 2: top half
    { y = 0,   h = 3/4 },  -- 3: top three quarters
    { y = 0,   h = 1   },  -- 4: full height
    { y = 1/4, h = 3/4 },  -- 5: bottom three quarters
    { y = 1/2, h = 1/2 },  -- 6: bottom half
    { y = 3/4, h = 1/4 },  -- 7: bottom quarter
}

-- Centered positions (index 1-4)
local hCenterPos = {
    { x = 0,    w = 1   },  -- 1: full width
    { x = 1/8,  w = 3/4 },  -- 2: centered 3/4
    { x = 1/4,  w = 1/2 },  -- 3: centered 1/2
    { x = 3/8,  w = 1/4 },  -- 4: centered 1/4
}

local vCenterPos = {
    { y = 0,    h = 1   },  -- 1: full height
    { y = 1/8,  h = 3/4 },  -- 2: centered 3/4
    { y = 1/4,  h = 1/2 },  -- 3: centered 1/2
    { y = 3/8,  h = 1/4 },  -- 4: centered 1/4
}

-- State per window ID
-- hIdx/vIdx = edge-snap index (1-7), hCenterIdx/vCenterIdx = centered index (1-3)
-- hCentered/vCentered = boolean, whether that axis is in centered mode
-- Map edge-snap index to centered index (preserve size on entry)
-- hIdx: 1,7=quarter(3) 2,6=half(2) 3,5=three-quarters(1) 4=full(1)
local edgeToCenterH = { [1]=4, [2]=3, [3]=2, [4]=1, [5]=2, [6]=3, [7]=4 }
local edgeToCenterV = edgeToCenterH  -- same mapping

-- Map centered index to edge-snap index (preserve size on exit)
-- centerIdx: 1=full, 2=three-quarters, 3=half, 4=quarter
local centerToEdgeLeft  = { [1]=4, [2]=3, [3]=2, [4]=1 }  -- left side
local centerToEdgeRight = { [1]=4, [2]=5, [3]=6, [4]=7 }  -- right side
local centerToEdgeUp    = { [1]=4, [2]=3, [3]=2, [4]=1 }  -- top side
local centerToEdgeDown  = { [1]=4, [2]=5, [3]=6, [4]=7 }  -- bottom side

local winState = {}

local function getState(win)
    local id = win:id()
    if not winState[id] then
        winState[id] = {
            hIdx = 4, vIdx = 4,
            hCentered = false, vCentered = false,
            hCenterIdx = 1, vCenterIdx = 1,
        }
    end
    return winState[id]
end

local function applyFrame(win, state, targetScreen)
    local screen = (targetScreen or win:screen()):frame()

    -- Resolve horizontal
    local hx, hw
    if state.hCentered then
        local c = hCenterPos[state.hCenterIdx]
        hx, hw = c.x, c.w
    else
        local h = hPos[state.hIdx]
        hx, hw = h.x, h.w
    end

    -- Resolve vertical
    local vy, vh
    if state.vCentered then
        local c = vCenterPos[state.vCenterIdx]
        vy, vh = c.y, c.h
    else
        local v = vPos[state.vIdx]
        vy, vh = v.y, v.h
    end

    win:setFrame({
        x = screen.x + screen.w * hx,
        y = screen.y + screen.h * vy,
        w = screen.w * hw,
        h = screen.h * vh,
    })
end

-- Edge-snap: left/right (breaks out of centered mode for horizontal)
local function moveLeft()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)

    if state.hCentered then
        state.hCentered = false
        state.hIdx = centerToEdgeLeft[state.hCenterIdx]
        applyFrame(win, state)
        return
    end

    if state.hIdx == 1 then
        local target = win:screen():toWest()
        if target then
            state.hIdx = 5
            applyFrame(win, state, target)
        else
            state.hIdx = 3
            applyFrame(win, state)
        end
    else
        state.hIdx = state.hIdx - 1
        applyFrame(win, state)
    end
end

local function moveRight()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)

    if state.hCentered then
        state.hCentered = false
        state.hIdx = centerToEdgeRight[state.hCenterIdx]
        applyFrame(win, state)
        return
    end

    if state.hIdx == 7 then
        local target = win:screen():toEast()
        if target then
            state.hIdx = 3
            applyFrame(win, state, target)
        else
            state.hIdx = 5
            applyFrame(win, state)
        end
    else
        state.hIdx = state.hIdx + 1
        applyFrame(win, state)
    end
end

-- Edge-snap: up/down (breaks out of centered mode for vertical)
local function moveUp()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)

    if state.vCentered then
        state.vCentered = false
        state.vIdx = centerToEdgeUp[state.vCenterIdx]
        applyFrame(win, state)
        return
    end

    if state.vIdx == 1 then
        state.vIdx = 3
    else
        state.vIdx = state.vIdx - 1
    end

    applyFrame(win, state)
end

local function moveDown()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)

    if state.vCentered then
        state.vCentered = false
        state.vIdx = centerToEdgeDown[state.vCenterIdx]
        applyFrame(win, state)
        return
    end

    if state.vIdx == 7 then
        state.vIdx = 5
    else
        state.vIdx = state.vIdx + 1
    end

    applyFrame(win, state)
end

-- Centered mode: horizontal (left = shrink, right = grow)
local function centerH(direction)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end
        local state = getState(win)

        if not state.hCentered then
            -- Enter centered mode, preserving current size
            state.hCentered = true
            state.hCenterIdx = edgeToCenterH[state.hIdx]
        else
            if direction == "shrink" then
                if state.hCenterIdx == 4 then
                    state.hCenterIdx = 1  -- wrap: 1/4 → full
                else
                    state.hCenterIdx = state.hCenterIdx + 1
                end
            else
                if state.hCenterIdx == 1 then
                    state.hCenterIdx = 4  -- wrap: full → 1/4
                else
                    state.hCenterIdx = state.hCenterIdx - 1
                end
            end
        end

        applyFrame(win, state)
    end
end

-- Centered mode: vertical (up = shrink, down = grow)
local function centerV(direction)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end
        local state = getState(win)

        if not state.vCentered then
            state.vCentered = true
            state.vCenterIdx = edgeToCenterV[state.vIdx]
        else
            if direction == "shrink" then
                if state.vCenterIdx == 4 then
                    state.vCenterIdx = 1  -- wrap: 1/4 → full
                else
                    state.vCenterIdx = state.vCenterIdx + 1
                end
            else
                if state.vCenterIdx == 1 then
                    state.vCenterIdx = 4  -- wrap: full → 1/4
                else
                    state.vCenterIdx = state.vCenterIdx - 1
                end
            end
        end

        applyFrame(win, state)
    end
end

-- Reset: full screen, clear centered mode
local function resetWindow()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)
    state.hIdx = 4
    state.vIdx = 4
    state.hCentered = false
    state.vCentered = false
    applyFrame(win, state)
end

-- Keybindings: Ctrl+Option + arrows = edge-snap
local mod = { "ctrl", "option" }
hs.hotkey.bind(mod, "left",   moveLeft)
hs.hotkey.bind(mod, "right",  moveRight)
hs.hotkey.bind(mod, "up",     moveUp)
hs.hotkey.bind(mod, "down",   moveDown)
hs.hotkey.bind(mod, "return", resetWindow)

-- Keybindings: Ctrl+Option+Cmd + arrows = centered mode
local centerMod = { "ctrl", "option", "cmd" }
hs.hotkey.bind(centerMod, "left",  centerH("shrink"))
hs.hotkey.bind(centerMod, "right", centerH("grow"))
hs.hotkey.bind(centerMod, "up",    centerV("shrink"))
hs.hotkey.bind(centerMod, "down",  centerV("grow"))
