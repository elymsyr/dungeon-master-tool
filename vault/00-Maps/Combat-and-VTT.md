---
type: moc
domain: combat-vtt
updated: 2026-06-09
tags: [moc]
---

# Combat & VTT — Map of Content

> [!summary] Scope
> Initiative/turn tracking, HP/condition management, and the grid-based battle map (tokens, pins, fog regions). Combat state syncs for multiplayer and feeds the projection target.

## Key Files
- [[combat_provider]] — combat state notifier (initiative, turn order, HP, conditions).
- [[battlemap_marks_protocol]] — protocol for battle-map marks/condition ops (`bm_mark_ops`).
- [[combat_dao]] — encounters / combatants / conditions persistence.
- [[fog_externalizer]] — fog-of-war serialization for projection. See [[Fog-of-War-and-Visibility]].
- [[map_data]] — grid, grid size, background image entity.
- [[world_map_data_dao]] — save/load map grids.
- [[map_pins_dao]] — pinned markers/labels.
- [[grid_canvas]] — grid render + token placement widget.

## Data Flow
DM edits initiative/HP → [[combat_provider]] → [[combat_dao]] (Drift) → [[Sync-and-Realtime]]. Map edits → [[world_map_data_dao]] + [[map_pins_dao]]. Snapshot built for [[Projection-Second-Screen]] with [[fog_externalizer]].

## Related Domains
- [[Character-System]] (effective stats) · [[Projection-Second-Screen]] (output) · [[Data-Layer]] (encounter tables) · [[Sync-and-Realtime]].

## Source Docs
- `flutter_app/docs/` VTT-upgrade + battlemap notes; `vtt_upgrade_initiative` memory.
