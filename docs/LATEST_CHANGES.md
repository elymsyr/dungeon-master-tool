# Latest Changes (Post-Release)

This document tracks updates made **after the latest tagged release**.

## Baseline

- Latest release tag: `alpha-v0.8.2`
- Release commit: `8bbf48a`
- Tracking window: `alpha-v0.8.2..HEAD`

## Included Commits

- `aab98d4` - update

## Delivered Since v0.8.2

### 1) Startup Performance Improvements

- Added lazy loading for the Soundpad panel:
  - The app now starts with a lightweight placeholder instead of constructing the full audio engine panel at boot.
  - The real `SoundpadPanel` is instantiated only when it is first needed (toggle/shortcut/state restore with visibility).
- Deferred map rendering on startup:
  - `map_tab.render_map()` is no longer called during root widget construction.
  - Map rendering now happens when the Map tab is opened for the first time.

### 2) Soundpad Behavior Preserved Under Lazy Loading

- Shortcut handlers (`stop_all`, `stop_ambience`, `play_sfx`) were updated to work with lazy initialization.
- Existing UI state restoration still supports soundpad visibility; if the panel was visible in saved state, it is initialized on restore.

### 3) Root/UI Rebuild Compatibility

- Post-rebuild wiring now reattaches tab-based lazy hooks so behavior remains consistent in dev hot-reload and normal boot flows.

### 4) Transparent Text Background Pass (UI Consistency)

- Applied a global text-input transparency override in all shipped themes:
  - `QLineEdit`, `QTextEdit`, `QPlainTextEdit`, `QTextBrowser`, `QSpinBox`, `QComboBox` and related read-only/disabled/focus states now use transparent backgrounds.
- Updated Markdown editor styling to keep text areas transparent in standard sheet mode as well.
- Goal: remove visible background mismatches across edit/view states in forms (including NPC property/combat-like entry areas).

### 5) Spell Cards & Manual Spell UX Improvements

- Linked Spell entries now render as richer cards:
  - show full spell properties (level, school, casting time, range, duration, components)
  - include description preview on the card.
- Manual Spell flow was expanded:
  - supports filling all core spell properties in addition to title/description
  - keeps property data in `custom_spells[].attributes`
  - view mode shows manual spells in a compact card-style preview (properties + description), edit mode keeps full editable inputs.

### 6) NPC Sheet Layout & Field Rendering Refinements

- Increased Spell list area height for better visibility in the Spells tab.
- Reduced Action item description editor height to make the Actions section denser and easier to scan.
- Added runtime transparent-style enforcement for dynamic property fields (e.g., `Challenge Rating (CR)`, `Attitude`) to improve consistency across theme/state combinations.

## Files Updated in This Window

- `main.py`
- `ui/main_root.py`
- `themes/amethyst.qss`
- `themes/baldur.qss`
- `themes/dark.qss`
- `themes/discord.qss`
- `themes/emerald.qss`
- `themes/frost.qss`
- `themes/grim.qss`
- `themes/light.qss`
- `themes/midnight.qss`
- `themes/ocean.qss`
- `themes/parchment.qss`
- `ui/widgets/linked_entity_widget.py`
- `ui/widgets/markdown_editor.py`
- `ui/widgets/npc_sheet.py`

### 7) Soundpad Crossfade & Music State Fixes

- Fixed abrupt audio transitions when switching music states in the Soundpad:
  - Root cause: the `fade_ratio` QPropertyAnimation was calling `deck_volume` setter on every frame (~16ms), which restarted a 1500ms per-player fade animation on each tick — effectively preventing any volume change.
  - Added `apply_volume_direct()` to `MultiTrackDeck`: sets player volumes directly without spawning per-player animations. Used exclusively during crossfade and master volume changes.
  - `update_mix()` / `fade_to(1500ms)` is now reserved for intensity layer transitions only (its intended use case).
  - Crossfade duration increased from 2000ms to 3000ms; easing curve changed to `InOutCubic` for a smoother S-curve blend.
- Fixed active music state button not highlighting on initial theme load:
  - `audio_brain.state_changed` signal is now connected to `_sync_state_buttons()` in `SoundpadPanel`.
  - When a theme loads and the first state begins playing, the corresponding button is automatically marked as checked.

## Files Updated in This Window

- `main.py`
- `ui/main_root.py`
- `themes/amethyst.qss`
- `themes/baldur.qss`
- `themes/dark.qss`
- `themes/discord.qss`
- `themes/emerald.qss`
- `themes/frost.qss`
- `themes/grim.qss`
- `themes/light.qss`
- `themes/midnight.qss`
- `themes/ocean.qss`
- `themes/parchment.qss`
- `ui/widgets/linked_entity_widget.py`
- `ui/widgets/markdown_editor.py`
- `ui/widgets/npc_sheet.py`
- `core/audio/engine.py`
- `ui/soundpad_panel.py`

## Validation Notes

- Startup path was validated locally with offscreen boot checks.
- Python syntax compilation passed for touched files:
  - `python3 -m py_compile main.py ui/main_root.py`
- Recent UI transparency change compiled cleanly:
  - `python3 -m py_compile ui/widgets/markdown_editor.py`
- Spell/Npc sheet updates compiled cleanly:
  - `python3 -m py_compile ui/widgets/linked_entity_widget.py ui/widgets/npc_sheet.py`
- Audio crossfade fix compiled cleanly:
  - `python3 -m py_compile core/audio/engine.py ui/soundpad_panel.py`
