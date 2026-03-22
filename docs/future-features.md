# Future Feature Ideas

This document captures features discussed for future implementation in our Hammerspoon window manager. These ideas came from a brainstorming session about expanding the tool beyond basic window positioning into a more complete window management system.

## Context: What We Have Today

A keyboard-driven Hammerspoon window manager with:

- **Edge-snap mode** (Ctrl+Option + arrows): independent horizontal/vertical axis cycling through a 7-position spectrum (1/4, 1/2, 3/4, full, 3/4, 1/2, 1/4), with bidirectional navigation (pressing the opposite direction reverses instead of jumping to the other side). Multi-monitor overflow at screen edges.
- **Centered mode** (Ctrl+Option+Cmd + arrows): centered window sizing cycling through full, 3/4, 1/2, 1/4. Size-preserving transitions between edge-snap and centered modes.
- **Accordion stacking**: windows positioned in the same zone are tracked and stacked with peek insets (background windows are taller, peeking above the front window). Cycling through the stack with Ctrl+Option+Tab.

The core design philosophy: the user arranges windows manually using intuitive keybindings, with full freedom over placement. No automatic tiling or forced layouts. The tool should help manage and navigate the windows the user has arranged, not dictate where they go.

## The Problem Space

The user's main pain points beyond basic positioning:

1. **Losing track of windows** — too many open windows leads to forgetting what's where. Multiple browser windows with different tab sets get lost. macOS Cmd+Tab groups all windows per app, making it impossible to reach a specific Chrome window without cycling through all of them.
2. **macOS Cmd+Tab is too limited** — it's per-app, not per-window. You can't distinguish between two Chrome windows or jump to a specific one. It lands on the "main" window and hides siblings.
3. **Want the benefits of tiling WMs without the rigidity** — Aerospace's concepts (accordion, workspaces) are appealing, but its automatic positioning/resizing is too restrictive. The user prefers manual arrangement with smart navigation on top.

---

## Feature 1: Window Switcher (Cmd+Tab Replacement)

### Problem it solves
macOS Cmd+Tab groups by app, not by window. You can't distinguish or jump to a specific window (e.g., "Chrome - Gmail" vs. "Chrome - Jira"). Windows get lost behind the app icon.

### Concept
A per-window switcher that shows individual windows with their titles. Two possible UI approaches were discussed:

- **Searchable text list** (Spotlight/Raycast style): type to filter, shows app name + window title. Fast, keyboard-driven. Could be built with `hs.chooser`.
- **Visual thumbnails**: small window previews, more visual but less searchable. Could use `hs.window.switcher` (built-in).

The decision on which UI to use was deferred until after the accordion feature was tested.

### Hammerspoon APIs available
- `hs.window.switcher` — built-in window-based Cmd+Tab replacement with thumbnail support and UI customization.
- `hs.chooser` — generic searchable list UI, highly customizable, supports dynamic filtering and callback-based selection. Could show app name + window title + screen location.
- `hs.window.allWindows()`, `hs.window.orderedWindows()` — for listing all windows.
- `hs.application:allWindows()`, `hs.application:findWindow(titlePattern)` — for filtering by app.

### Design considerations
- Should integrate with our zone/state tracking — could show which zone a window is in.
- Could group by screen or by zone in the switcher list.
- Should show windows the user might have forgotten about (minimized, on other spaces).

---

## Feature 2: Saved Layouts / Workspaces

### Problem it solves
The user frequently sets up specific window arrangements for different tasks (e.g., "coding" = editor left 3/4 + terminal bottom-right + browser top-right). Recreating these arrangements manually each time is tedious.

### Concept
Save named window arrangements and restore them with a shortcut. A layout would capture:
- Which windows are open (matched by app name + optional title pattern)
- Their positions (our state: hIdx, vIdx, centered mode, etc.)
- Which screen they're on
- Their zone/stack ordering

Possible keybinding: Ctrl+Option+1/2/3 to save/restore layout slots, or a chooser-based approach for named layouts.

### Hammerspoon APIs available
- `hs.spaces` — experimental module for macOS Spaces. Can navigate spaces (`gotoSpace`), move windows between spaces (`moveWindowToSpace`), list spaces (`allSpaces`, `spacesForScreen`), and create/remove spaces. Uses private APIs — functional but could break with macOS updates.
- `hs.window.layout` — built-in module for defining window layouts with rules.
- Window state is already tracked in our `winState` table — could be serialized to JSON and stored on disk.

### Design considerations
- Could tie into macOS Spaces (each workspace = a Space) or be purely virtual (just repositioning windows on the current space).
- Persistence: save layouts to `~/.hammerspoon/layouts/` as JSON files so they survive restarts.
- Matching: when restoring, need to match saved window slots to currently open windows. Could match by app name, title pattern, or let the user assign windows to slots.
- Could support "partial restore" — if not all apps from a layout are open, just position the ones that are.

---

## Feature 3: Window Hints (Jump-to-Window)

### Problem it solves
Quick navigation to any visible window across all screens without cycling. Useful when you know which window you want but it's on another screen or buried behind other windows.

### Concept
Press a keybinding and every visible window across all screens gets a letter/number overlay. Press that letter to instantly focus and raise that window. Like Vimium's link hints but for windows.

### Hammerspoon APIs available
- `hs.hints.windowHints()` — built-in implementation of exactly this. Shows per-window keyboard shortcuts as overlays. Supports filtering and custom styling.
- Could be customized to only show hints for managed windows (those in our zone tracking) or all windows.

### Design considerations
- Very low implementation effort — `hs.hints` does most of the work.
- Could be enhanced to show zone information in the hint overlay.
- Good complement to the window switcher (hints for visible windows, switcher for all windows including hidden/minimized).
- Suggested keybinding: something quick like Ctrl+Option+Space or Ctrl+Option+F.

---

## Feature 4: Enhanced Accordion / Cascade Improvements

### Context
The current accordion stacking works but could be expanded. Ideas for improvement:

- **Visual indicators**: when cycling, briefly show a small overlay with the stack count and current position (e.g., "2/4") and/or the window title. This would help orientation without being always-on.
- **Stack-aware movement**: if you move a window that's in a stack, should the whole stack move? Or just the front window? Currently only the front window moves — this might be the right default but could be configurable.
- **Quick peek**: a keybinding to temporarily "fan out" all windows in a stack so you can see them all at once, then collapse back when released. Like a quick preview of what's in the stack.

---

## Implementation Priority (Suggested)

1. **Window Hints** — lowest effort, highest immediate value. Uses built-in `hs.hints`.
2. **Window Switcher** — medium effort, solves the core "lost windows" problem.
3. **Saved Layouts** — medium-high effort, very useful once the workflow is established.
4. **Enhanced Accordion** — incremental improvements to the existing system.

These priorities were not explicitly agreed upon — they're a suggested order based on effort/value ratio. The user expressed interest in all of them and wanted to see how the accordion feature felt before committing to a next step.
