# Latest Changes (Post-Release)

This document tracks updates made **after the latest tagged release**.

## Baseline

- Latest release tag: `alpha-v0.8.2`
- Release commit: `8bbf48a`
- Tracking window: `alpha-v0.8.2..HEAD`

## Included Commits

- `aab98d4` - update
- (unreleased) Phase 4: EventBus, Global Edit Mode, Soundpad fixes

---

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

### 7) Soundpad Crossfade & Music State Fixes

- Fixed abrupt audio transitions when switching music states in the Soundpad:
  - Root cause: the `fade_ratio` QPropertyAnimation was calling `deck_volume` setter on every frame (~16ms), which restarted a 1500ms per-player fade animation on each tick — effectively preventing any volume change.
  - Added `apply_volume_direct()` to `MultiTrackDeck`: sets player volumes directly without spawning per-player animations. Used exclusively during crossfade and master volume changes.
  - `update_mix()` / `fade_to(1500ms)` is now reserved for intensity layer transitions only (its intended use case).
  - Crossfade duration increased from 2000ms to 3000ms; easing curve changed to `InOutCubic` for a smoother S-curve blend.
- Fixed active music state button not highlighting on initial theme load:
  - `audio_brain.state_changed` signal is now connected to `_sync_state_buttons()` in `SoundpadPanel`.
  - When a theme loads and the first state begins playing, the corresponding button is automatically marked as checked.

### 8) Phase 4 — EventBus (Architecture Patterns)

- Introduced `core/event_bus.py`: a lightweight publish-subscribe event bus for cross-cutting application events.
  - Events use `{domain}.{action}` naming: `entity.deleted`, `entity.created`, `entity.updated`, `theme.changed`, `language.changed`, `edit_mode.changed`.
  - Error-safe: handler exceptions are logged but do not interrupt other subscribers.
  - Duplicate subscriptions are prevented by default.
- `MainWindow` now creates a single `EventBus` instance (`self.event_bus`) on startup and passes it to components via constructors.
- `DatabaseTab` publishes `entity.deleted` (with `entity_id`) after a confirmed deletion; keeps the existing `entity_deleted` PyQt signal for backward compatibility.
- `EntitySidebar` subscribes to `entity.deleted`, `entity.created`, and `entity.updated` to refresh its list automatically — no longer requires an explicit signal connection wired in `main_root.py`.
- `MainWindow.change_theme()` and `change_language()` publish `theme.changed` / `language.changed` events so future subscribers can react without needing manual wiring.
- Removed the fragile `db_tab.entity_deleted.connect(entity_sidebar.refresh_list)` direct connection from `main_root.py`.

### 9) Global Edit Mode

- `toggle_active_edit_mode()` (`main.py`) is now a true global toggle: flips `MainWindow.global_edit_mode`, updates the toolbar button state, and broadcasts `edit_mode.changed` via EventBus.
- **Database tab (NpcSheets):** All open NpcSheet cards in both left and right panels switch to edit or view mode simultaneously. Auto-save runs for dirty sheets when edit mode is turned off. Newly opened sheets inherit the current global edit mode on creation.
- **Session tab:** `txt_log`, `txt_notes` (MarkdownEditors) are locked to view mode when global edit is off (toggle button disabled); `inp_log_entry` (quick log QTextEdit) is read-only. All unlock when global edit is on.
- **Mind Map:** Note nodes (MarkdownEditor) and entity nodes (NpcSheet) apply the global edit mode on toggle and on creation.
- All components start in **read-only mode** (edit mode OFF) on app launch.

### 10) Edit Mode Button Redesign

- Replaced the "Edit" text label with a `✏️` emoji; button width reduced from 44px to 30px.
- Added `objectName("editModeBtn")` with theme-aware `:checked` highlight styles in all 11 QSS theme files — each theme uses its own `primaryBtn` accent color for the active state.
- Button tooltip still shows the localized `BTN_EDIT` string on hover.

---

## Files Updated in This Window

- `main.py`
- `ui/main_root.py`
- `ui/tabs/database_tab.py`
- `ui/tabs/session_tab.py`
- `ui/tabs/mind_map_tab.py`
- `ui/widgets/entity_sidebar.py`
- `ui/widgets/linked_entity_widget.py`
- `ui/widgets/markdown_editor.py`
- `ui/widgets/npc_sheet.py`
- `core/audio/engine.py`
- `core/event_bus.py` (new)
- `ui/soundpad_panel.py`
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

---

## Validation Notes

- Startup path was validated locally with offscreen boot checks.
- Python syntax compilation passed for touched files:
  - `python3 -m py_compile main.py ui/main_root.py`
- UI transparency change compiled cleanly:
  - `python3 -m py_compile ui/widgets/markdown_editor.py`
- Spell/NPC sheet updates compiled cleanly:
  - `python3 -m py_compile ui/widgets/linked_entity_widget.py ui/widgets/npc_sheet.py`
- Audio crossfade fix compiled cleanly:
  - `python3 -m py_compile core/audio/engine.py ui/soundpad_panel.py`
- EventBus + Global Edit Mode compiled cleanly:
  - `python3 -m py_compile core/event_bus.py main.py ui/main_root.py ui/tabs/database_tab.py ui/tabs/session_tab.py ui/tabs/mind_map_tab.py ui/widgets/entity_sidebar.py`
