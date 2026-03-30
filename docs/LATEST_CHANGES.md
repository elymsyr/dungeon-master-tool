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

## Files Updated in This Window

- `main.py`
- `ui/main_root.py`

## Validation Notes

- Startup path was validated locally with offscreen boot checks.
- Python syntax compilation passed for touched files:
  - `python3 -m py_compile main.py ui/main_root.py`
