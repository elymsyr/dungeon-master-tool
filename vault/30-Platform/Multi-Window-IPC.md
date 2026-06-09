---
type: platform
domain: projection
updated: 2026-06-09
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

## Related
- MoCs: [[Projection-Second-Screen]] · [[Platform-Targets]]
