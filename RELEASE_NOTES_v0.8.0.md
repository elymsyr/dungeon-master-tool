# Release Notes — alpha-v0.8.0

## Battle Map Overhaul

### Tools Overview

The battle map toolbar is now organized into four groups:

| Group | Tools |
|---|---|
| **Navigate** | Pan the map; click a measurement to delete it |
| **Measure** | Ruler (line distance), Circle (radius area) |
| **Draw** | Free-hand annotation brush |
| **Fog** | Fog of War brush (left = add, right = erase) |
| **Actions** | Fill Fog, Clear Fog, Clear Draw, Clear Rulers |

The active tool is highlighted in blue. Groups are separated by visual dividers.

---

### Ruler Tool
Draw a straight line between any two points. The ruler displays the distance in **grid cells** and **feet** (configurable via the grid spinboxes in the toolbar). Rulers are **persistent** — they stay on the map after you release the mouse and survive tool switches. You can place as many rulers as you want simultaneously.

To remove a ruler: switch to **Navigate** mode and click on it. To remove all at once: use **Clear Rulers** in the actions group.

### Circle Tool
Draw a circle from a center point. Like rulers, circles display the radius in feet and remain on the map permanently. Useful for spell radius indicators, burst areas, or movement ranges.

To remove a circle: switch to **Navigate** mode and click on it. **Clear Rulers** removes all circles and rulers together.

### Draw Tool
Free-hand brush for annotating the map directly — mark paths, circle areas of interest, or sketch on the fly. Drawings are also persistent and sync to the player screen.

To erase everything: use **Clear Draw** in the actions group.

### Measurement & Drawing Sync
All persistent rulers, circles, and drawings are rendered and sent to the **player screen (second monitor) in real time**. The player sees exactly what the GM annotates, as it happens. Clearing via the action buttons also clears the player view immediately.

Previously, "Clear Draw" and fog changes would only update the GM screen — this is now fixed.

### Fog of War Unified
Left click adds fog, right click erases it — no more switching between two separate buttons. The old "Erase Fog" button has been removed.

### Navigate Mode
Navigate mode pans the map with an open-hand cursor. Clicking directly on any persistent ruler or circle in this mode deletes it.

### Large Battle Map Images
Images that decompress to over 256 MB (e.g. high-resolution battle maps) can now be loaded without the Qt allocation limit rejection error. The new limit is 1 GB.

### Toolbar Polish
Grid size and feet-per-cell spinboxes are now the same height as the toolbar buttons.

---

## Mind Map — Level of Detail (LOD)

Performance when zoomed out has been significantly improved via a three-zone LOD system:

| Zoom | Rendering |
|---|---|
| ≥ 0.4 | Full quality — drop shadow, no cache |
| 0.1 – 0.4 | Reduced quality — shadow disabled, GPU pixmap cache active |
| < 0.1 | Template mode — widget hidden, simple colored block with label |

In template mode, each node displays a readable label (entity name, note's first line, or image filename). The label is inverse-scaled so it remains the same apparent size on screen regardless of how far you zoom out, and it can overflow the node boundary to stay legible.

The grid is also optimized: dots are skipped entirely below zoom 0.15, and grid spacing widens adaptively between 0.15–0.4 to reduce the number of drawn points.

---

## Player Window

### Unified Battle Map + Player Screen
The battle map and the player screen now live in a single player window instead of two separate windows.

### Splitter Sync
Adjusting the splitter in the Player Screen tab now reflects immediately on the second screen.

---

## Combat Tracker — Auto Event Log

Combat events (damage, healing, condition changes, round advances) are now automatically appended to the session event log. No manual logging required.

---

## UI Theming

Palette-based theming has been applied across all remaining hardcoded-color components: entity sidebar, database tab bars, entity cards, action buttons, bulk downloader, and HP/condition buttons. Switching themes now refreshes every visible widget correctly.

---

## Edit Mode

A global edit mode toggle (toolbar button + `Ctrl+E` shortcut) was added. It activates inline editing on the currently focused entity card.

---

## Bug Fixes

- Battle map "Erase" tool now correctly removes drawings
- Fog changes were not syncing to player window — fixed
- Player screen splitter changes were not reflected on second screen — fixed
- `QGraphicsDropShadowEffect` RuntimeError when cycling LOD zones — fixed by recreating the effect on re-entry
