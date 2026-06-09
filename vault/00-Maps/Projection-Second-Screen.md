---
type: moc
domain: projection
updated: 2026-06-09
tags: [moc]
---

# Projection & Second-Screen — Map of Content

> [!summary] Scope
> DM→player output abstraction. One content stream (battle map, images, text) delivered over three transports: desktop sub-window, OS screencast (Presentation API), or online (Supabase-mediated). Applies visibility/fog filtering before output.

## Key Files
- [[projection_output]] — abstract delivery interface (the 4th output type).
- [[projection_output_window]] — `desktop_multi_window` backend. See [[Multi-Window-IPC]].
- [[projection_output_screencast]] — OS Presentation API. See [[Screencast-Presentation-API]].
- [[projection_output_online]] — online second-screen via Supabase.
- [[projection_ipc]] — DM ↔ player sub-window IPC bridge.
- [[battle_map_snapshot_builder]] — serialize battle-map state for projection.
- [[entity_snapshot_builder]] — visible-entity computation (fog rules). See [[Fog-of-War-and-Visibility]].
- [[projection_state]] — render state (items, blackout, active index).
- [[battle_map_snapshot]] — map + tokens + fog snapshot model.
- [[player_window_main]] · [[screencast_main]] — sub-window entrypoints.

## Data Flow
[[Combat-and-VTT]] / [[World-and-Content]] state → [[battle_map_snapshot_builder]] + [[entity_snapshot_builder]] (fog filter) → [[projection_state]] → chosen [[projection_output]] transport.

## Related Domains
- [[Combat-and-VTT]] · [[Media-and-Assets]] (images) · [[Multiplayer-and-Online]] (online output) · [[Platform-Targets]].

## Source Docs
- `flutter_app/docs/online_second_screen_architecture_may21.md`, `second_screen_dm_player_view_spec_may21.md`.
