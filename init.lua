-- Window Manager: Independent axis cycling with accordion stacking
--
-- Edge-snap mode (Ctrl+Option + arrows):
--   Each axis is a 7-position spectrum:
--   1/4 side ← 1/2 side ← 3/4 side ← FULL → 3/4 side → 1/2 side → 1/4 side
--   At the extremes, overflows to adjacent monitor or wraps.
--
-- Centered mode (Ctrl+Option+Cmd + arrows):
--   Cycles centered sizes: full → 3/4 → 1/2 → 1/4
--   Each axis is independent. Regular arrows break back to edge-snap for that axis.
--
-- Accordion stacking:
--   Windows positioned in the same zone (same state + screen) are stacked.
--   Background windows peek with a small offset. Cycle with Ctrl+Option+Tab.

-- ============================================================
-- Position tables
-- ============================================================

local hPos = {
    { x = 0,   w = 1/4 },  -- 1: left quarter
    { x = 0,   w = 1/2 },  -- 2: left half
    { x = 0,   w = 3/4 },  -- 3: left three quarters
    { x = 0,   w = 1   },  -- 4: full width
    { x = 1/4, w = 3/4 },  -- 5: right three quarters
    { x = 1/2, w = 1/2 },  -- 6: right half
    { x = 3/4, w = 1/4 },  -- 7: right quarter
}

local vPos = {
    { y = 0,   h = 1/4 },  -- 1: top quarter
    { y = 0,   h = 1/2 },  -- 2: top half
    { y = 0,   h = 3/4 },  -- 3: top three quarters
    { y = 0,   h = 1   },  -- 4: full height
    { y = 1/4, h = 3/4 },  -- 5: bottom three quarters
    { y = 1/2, h = 1/2 },  -- 6: bottom half
    { y = 3/4, h = 1/4 },  -- 7: bottom quarter
}

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

-- ============================================================
-- Mapping tables
-- ============================================================

local edgeToCenterH = { [1]=4, [2]=3, [3]=2, [4]=1, [5]=2, [6]=3, [7]=4 }
local edgeToCenterV = edgeToCenterH

local centerToEdgeLeft  = { [1]=4, [2]=3, [3]=2, [4]=1 }
local centerToEdgeRight = { [1]=4, [2]=5, [3]=6, [4]=7 }
local centerToEdgeUp    = { [1]=4, [2]=3, [3]=2, [4]=1 }
local centerToEdgeDown  = { [1]=4, [2]=5, [3]=6, [4]=7 }

-- ============================================================
-- Per-window state
-- ============================================================

local winState = {}

local function getState(win)
    local id = win:id()
    if not winState[id] then
        winState[id] = {
            hIdx = 4, vIdx = 4,
            hCentered = false, vCentered = false,
            hCenterIdx = 1, vCenterIdx = 1,
            currentZone = nil,  -- zone key this window is registered in
        }
    end
    return winState[id]
end

-- ============================================================
-- Zone tracking (accordion stacking)
-- ============================================================

local PEEK_PX = 8  -- pixels of peek visible per background window

-- Registry: zoneKey → ordered list of window IDs (index 1 = front)
local zoneWindows = {}

-- Build a unique key from window state + screen
local function getZoneKey(state, screenID)
    local hPart, vPart
    if state.hCentered then
        hPart = "ch" .. state.hCenterIdx
    else
        hPart = "h" .. state.hIdx
    end
    if state.vCentered then
        vPart = "cv" .. state.vCenterIdx
    else
        vPart = "v" .. state.vIdx
    end
    return screenID .. "_" .. hPart .. "_" .. vPart
end

local function removeFromZone(winId, zoneKey)
    if not zoneKey or not zoneWindows[zoneKey] then return end
    for i, id in ipairs(zoneWindows[zoneKey]) do
        if id == winId then
            table.remove(zoneWindows[zoneKey], i)
            break
        end
    end
    if #zoneWindows[zoneKey] == 0 then
        zoneWindows[zoneKey] = nil
    end
end

local function addToZone(winId, zoneKey)
    if not zoneWindows[zoneKey] then
        zoneWindows[zoneKey] = {}
    end
    -- Add to front of the stack
    table.insert(zoneWindows[zoneKey], 1, winId)
end

-- ============================================================
-- Frame application
-- ============================================================

-- peekInset: how many pixels to shave off the top of this window.
-- The window gets shorter and pushed down, revealing background windows peeking above.
local function applyFrame(win, state, targetScreen, peekInset)
    local screen = (targetScreen or win:screen()):frame()
    peekInset = peekInset or 0

    local hx, hw
    if state.hCentered then
        local c = hCenterPos[state.hCenterIdx]
        hx, hw = c.x, c.w
    else
        local h = hPos[state.hIdx]
        hx, hw = h.x, h.w
    end

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
        y = screen.y + screen.h * vy + peekInset,
        w = screen.w * hw,
        h = screen.h * vh - peekInset,
    })
end

-- Reposition all windows in a zone with peek insets.
-- Back windows are full zone height. Front window is shortened so back windows peek above.
local function applyPeekOffsets(zoneKey)
    if not zoneWindows[zoneKey] then return end
    local windows = zoneWindows[zoneKey]
    local count = #windows

    -- 1. Set all frames (back windows are taller, front is shortest)
    for i, winId in ipairs(windows) do
        local win = hs.window.get(winId)
        local state = winState[winId]
        if win and state then
            local layer = i - 1
            local inset = (count - 1 - layer) * PEEK_PX
            applyFrame(win, state, nil, inset)
        end
    end

    -- 2. Raise background windows back-to-front for correct z-ordering.
    --    raise() orders windows within the same app without triggering
    --    macOS app-level activation (which would group same-app windows).
    for i = count, 2, -1 do
        local win = hs.window.get(windows[i])
        if win then
            win:raise()
        end
    end

    -- 3. Focus only the front window (activates it and puts it on top).
    local frontWin = hs.window.get(windows[1])
    if frontWin then
        frontWin:focus()
    end
end

-- Handle zone transition after state change. Call this instead of applyFrame directly.
-- targetScreen is only needed for monitor overflow (to move window before zone calc).
local function finishMove(win, state, oldZone, targetScreen)
    -- For monitor overflow, move window to target screen first
    if targetScreen then
        applyFrame(win, state, targetScreen)
    end

    -- Compute new zone using the screen the window is now on
    local screen = targetScreen or win:screen()
    local screenID = screen:id()
    local newZone = getZoneKey(state, screenID)

    -- Update zone registry
    removeFromZone(win:id(), oldZone)
    addToZone(win:id(), newZone)
    state.currentZone = newZone

    -- Reapply peek offsets for affected zones
    if oldZone and oldZone ~= newZone then
        applyPeekOffsets(oldZone)
    end
    applyPeekOffsets(newZone)
end

-- ============================================================
-- Edge-snap movement
-- ============================================================

local function moveLeft()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)
    local oldZone = state.currentZone

    if state.hCentered then
        state.hCentered = false
        state.hIdx = centerToEdgeLeft[state.hCenterIdx]
        finishMove(win, state, oldZone)
        return
    end

    if state.hIdx == 1 then
        local target = win:screen():toWest()
        if target then
            state.hIdx = 5
            finishMove(win, state, oldZone, target)
        else
            state.hIdx = 3
            finishMove(win, state, oldZone)
        end
    else
        state.hIdx = state.hIdx - 1
        finishMove(win, state, oldZone)
    end
end

local function moveRight()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)
    local oldZone = state.currentZone

    if state.hCentered then
        state.hCentered = false
        state.hIdx = centerToEdgeRight[state.hCenterIdx]
        finishMove(win, state, oldZone)
        return
    end

    if state.hIdx == 7 then
        local target = win:screen():toEast()
        if target then
            state.hIdx = 3
            finishMove(win, state, oldZone, target)
        else
            state.hIdx = 5
            finishMove(win, state, oldZone)
        end
    else
        state.hIdx = state.hIdx + 1
        finishMove(win, state, oldZone)
    end
end

local function moveUp()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)
    local oldZone = state.currentZone

    if state.vCentered then
        state.vCentered = false
        state.vIdx = centerToEdgeUp[state.vCenterIdx]
        finishMove(win, state, oldZone)
        return
    end

    if state.vIdx == 1 then
        state.vIdx = 3
    else
        state.vIdx = state.vIdx - 1
    end

    finishMove(win, state, oldZone)
end

local function moveDown()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)
    local oldZone = state.currentZone

    if state.vCentered then
        state.vCentered = false
        state.vIdx = centerToEdgeDown[state.vCenterIdx]
        finishMove(win, state, oldZone)
        return
    end

    if state.vIdx == 7 then
        state.vIdx = 5
    else
        state.vIdx = state.vIdx + 1
    end

    finishMove(win, state, oldZone)
end

-- ============================================================
-- Centered mode
-- ============================================================

local function centerH(direction)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end
        local state = getState(win)
        local oldZone = state.currentZone

        if not state.hCentered then
            state.hCentered = true
            state.hCenterIdx = edgeToCenterH[state.hIdx]
        else
            if direction == "shrink" then
                if state.hCenterIdx == 4 then
                    state.hCenterIdx = 1
                else
                    state.hCenterIdx = state.hCenterIdx + 1
                end
            else
                if state.hCenterIdx == 1 then
                    state.hCenterIdx = 4
                else
                    state.hCenterIdx = state.hCenterIdx - 1
                end
            end
        end

        finishMove(win, state, oldZone)
    end
end

local function centerV(direction)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end
        local state = getState(win)
        local oldZone = state.currentZone

        if not state.vCentered then
            state.vCentered = true
            state.vCenterIdx = edgeToCenterV[state.vIdx]
        else
            if direction == "shrink" then
                if state.vCenterIdx == 4 then
                    state.vCenterIdx = 1
                else
                    state.vCenterIdx = state.vCenterIdx + 1
                end
            else
                if state.vCenterIdx == 1 then
                    state.vCenterIdx = 4
                else
                    state.vCenterIdx = state.vCenterIdx - 1
                end
            end
        end

        finishMove(win, state, oldZone)
    end
end

-- ============================================================
-- Reset
-- ============================================================

local function resetWindow()
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = getState(win)
    local oldZone = state.currentZone

    state.hIdx = 4
    state.vIdx = 4
    state.hCentered = false
    state.vCentered = false

    finishMove(win, state, oldZone)
end

-- ============================================================
-- Accordion cycling
-- ============================================================

local function cycleZone(direction)
    local win = hs.window.focusedWindow()
    if not win then return end
    local state = winState[win:id()]
    if not state or not state.currentZone then return end

    local zoneKey = state.currentZone
    local windows = zoneWindows[zoneKey]
    if not windows or #windows <= 1 then return end

    if direction == "forward" then
        -- Move front to back
        local front = table.remove(windows, 1)
        table.insert(windows, front)
    else
        -- Move back to front
        local back = table.remove(windows, #windows)
        table.insert(windows, 1, back)
    end

    -- Focus the new front window and reapply offsets
    local frontWin = hs.window.get(windows[1])
    if frontWin then
        frontWin:focus()
    end
    applyPeekOffsets(zoneKey)
end

-- ============================================================
-- Cleanup: remove closed windows from zones
-- ============================================================

local wf = hs.window.filter.new()
wf:subscribe(hs.window.filter.windowDestroyed, function(win)
    local id = win:id()
    local state = winState[id]
    if state and state.currentZone then
        local zoneKey = state.currentZone
        removeFromZone(id, zoneKey)
        if zoneWindows[zoneKey] then
            applyPeekOffsets(zoneKey)
        end
    end
    winState[id] = nil
end)

-- ============================================================
-- Keybindings
-- ============================================================

local mod = { "ctrl", "option" }
hs.hotkey.bind(mod, "left",   moveLeft)
hs.hotkey.bind(mod, "right",  moveRight)
hs.hotkey.bind(mod, "up",     moveUp)
hs.hotkey.bind(mod, "down",   moveDown)
hs.hotkey.bind(mod, "return", resetWindow)
hs.hotkey.bind(mod, "tab",    function() cycleZone("forward") end)
hs.hotkey.bind({ "ctrl", "option", "shift" }, "tab", function() cycleZone("backward") end)

local centerMod = { "ctrl", "option", "cmd" }
hs.hotkey.bind(centerMod, "left",  centerH("shrink"))
hs.hotkey.bind(centerMod, "right", centerH("grow"))
hs.hotkey.bind(centerMod, "up",    centerV("shrink"))
hs.hotkey.bind(centerMod, "down",  centerV("grow"))
