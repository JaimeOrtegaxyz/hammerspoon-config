# Hammerspoon Window Manager

This is a Hammerspoon configuration (`init.lua`) that provides a keyboard-driven window manager for macOS with independent axis control, centered positioning, and multi-monitor overflow.

## Setup

1. Install [Hammerspoon](https://www.hammerspoon.org/)
2. Clone this repo to `~/.hammerspoon/`
3. Reload the Hammerspoon config (menu bar icon → Reload Config)

## Architecture

The window manager tracks two independent axes (horizontal and vertical) per window. Each axis can be in one of two modes: **edge-snap** or **centered**.

### Edge-snap mode

Each axis is a 7-position linear spectrum:

```
1/4 side ← 1/2 side ← 3/4 side ← FULL → 3/4 side → 1/2 side → 1/4 side
```

- Pressing a direction moves along the spectrum in that direction.
- Pressing the opposite direction reverses (e.g., from 1/2 left, pressing right goes back to 3/4 left, then full, then into right positions).
- At the smallest size (1/4), pressing further into that side overflows to the adjacent monitor if one exists (appearing on the opposite edge of the new monitor). If no monitor exists, it wraps to 3/4 on the same side.
- Acting on one axis never affects the other.

### Centered mode

Each axis has a 4-position cycle:

```
full → 3/4 centered → 1/2 centered → 1/4 centered → full → ...
```

- Shrink direction (left/up) increases the index (toward smaller).
- Grow direction (right/down) decreases the index (toward larger).
- Wraps at both ends.

### Mode transitions

- **Edge → Centered**: preserves the current size. A left-half window becomes a centered-half window.
- **Centered → Edge**: preserves the current size. A centered-half window pressed left becomes a left-half window.
- **Reset** (Ctrl+Option+Enter): returns to full screen on both axes, exits centered mode.

## Keybindings

| Shortcut | Action |
|---|---|
| `Ctrl+Option+Left` | Edge-snap: move/cycle left |
| `Ctrl+Option+Right` | Edge-snap: move/cycle right |
| `Ctrl+Option+Up` | Edge-snap: move/cycle up |
| `Ctrl+Option+Down` | Edge-snap: move/cycle down |
| `Ctrl+Option+Enter` | Reset to full screen |
| `Ctrl+Option+Cmd+Left` | Centered: shrink width |
| `Ctrl+Option+Cmd+Right` | Centered: grow width |
| `Ctrl+Option+Cmd+Up` | Centered: shrink height |
| `Ctrl+Option+Cmd+Down` | Centered: grow height |

## State model

Per-window state (keyed by window ID):

```lua
{
    hIdx = 4,           -- edge-snap horizontal index (1-7, 4=full)
    vIdx = 4,           -- edge-snap vertical index (1-7, 4=full)
    hCentered = false,  -- is horizontal axis in centered mode?
    vCentered = false,  -- is vertical axis in centered mode?
    hCenterIdx = 1,     -- centered horizontal index (1-4, 1=full)
    vCenterIdx = 1,     -- centered vertical index (1-4, 1=full)
}
```

## Key data structures

- `hPos` / `vPos`: 7-entry tables mapping edge-snap index to `{x, w}` or `{y, h}` fractions of screen.
- `hCenterPos` / `vCenterPos`: 4-entry tables for centered positions.
- `edgeToCenterH` / `edgeToCenterV`: maps edge index → center index (preserves size on mode entry).
- `centerToEdgeLeft`, `centerToEdgeRight`, `centerToEdgeUp`, `centerToEdgeDown`: maps center index → edge index (preserves size on mode exit, placed on the side matching the key pressed).

## Modifying

- To change keybindings, edit the `mod` and `centerMod` tables and the `hs.hotkey.bind` calls at the bottom of `init.lua`.
- To add more size stops (e.g., 1/3, 2/3), extend the position tables and update the mapping tables and cycling bounds accordingly.
- Multi-monitor overflow is horizontal only. To add vertical overflow, apply the same `toNorth()`/`toSouth()` pattern used in `moveLeft`/`moveRight` to `moveUp`/`moveDown`.
