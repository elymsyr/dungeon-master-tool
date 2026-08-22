---
type: platform
domain: projection
updated: 2026-08-22
tags: [platform]
---

# Multi-Window IPC

> [!summary] What this is
> Desktop second-screen via `desktop_multi_window`: a DM main window spawns a player sub-window; the two communicate over an IPC bridge. The "hardware integration" path for a physically separate player display on desktop.

## Participants
- [[projection_output_window]] — window-backed projection transport.
- [[projection_ipc]] — DM ↔ player-window message bridge.
- [[player_window_main]] — sub-window entrypoint.

## Notes
- Initialized in `main.dart` multi-window bootstrap (DM + player window).
- Master mirror shape must match player expectations (see B8a fix in `online_second_screen_design` history).
- Alternative transports: [[Screencast-Presentation-API]] (OS cast), online ([[projection_output_online]]).

## Linux sub-window close crash (fixed 2026-08-22)
- `desktop_multi_window` 0.2.1 is **vendored + patched** under `flutter_app/packages/desktop_multi_window/` (wired via `dependency_overrides` in [[pubspec]]).
- **Root cause**: the plugin spawns each sub-window with `fl_view_new()` — a legacy "separate Flutter engine + implicit view per window" pattern that predates Flutter's multi-view embedder. On Flutter 3.44.6, destroying that window routes `fl_view_dispose` → `fl_engine_remove_view(view_id=0)` into `FlutterEngineRemoveView` on the *implicit* view, which the embedder rejects (`kInvalidArguments`, "The implicit view cannot be removed"), leaving the shell in an inconsistent state that then segfaults during `FlutterEngineShutdown` (`eglMakeCurrent failed` + "Lost connection to device"). This is inside the engine reacting to the plugin's pattern — **no teardown-ordering patch can fix it** (verified: the same crash is reported on `desktop_multi_window` 0.3.0 too, and 0.3.0's `ObserveWindowClose` reorder does not help).
- **Fix — never destroy the sub-window, only hide it**:
  1. `flutter_window.cc`: `on_close_clicked` (the `delete-event` handler) now `gtk_widget_hide`s the window instead of `gtk_widget_destroy`ing it, so neither the DM-side `close()` nor the native X button ever tears the FlView/engine down.
  2. `flutter_window.cc`: disconnect the engine shell's own `delete-event` handler (`fl_view.cc` → `window_delete_event_cb`, flutter/engine PR #40033) so hiding a sub-window never calls `fl_engine_request_app_exit` → `g_application_quit` on the whole app.
  3. [[projection_output_window]] keeps a static `_persistedWindowId` and `show()`s the hidden window on the next `activate()` instead of recreating it; `deactivate()` and the external-close path both `hide()` instead of `close()`. `main.dart`'s `playerClosed` handler and stale-window cleanup likewise `hide()`.
  4. [[player_window_app]] clears its `playerProjectionStateProvider` (new `clear()`) on the `close` IPC and hides itself on the X button, so a re-shown window never flashes stale content.

## Related
- MoCs: [[Projection-Second-Screen]] · [[Platform-Targets]]
