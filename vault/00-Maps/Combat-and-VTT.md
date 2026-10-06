---
type: moc
domain: combat-vtt
updated: 2026-10-06
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
- [[turn_control_provider]] — online oyuncu kendi turunda kendi token'ını oynatır ("Sıra sende" + tur başına geri al). İzin `world_turn_control` (105), hareket `move_turn_token` RPC → DM → yayın.
- [[dice_physics]] — 3D dice roller: bottom-right dice button on world + character screens, results decided before the throw.
- [[dice_log]] — landed rolls (free, skill check, saving throw) into the session log under username + character; players' via `log_dice_roll` (106).

## Data Flow
DM edits initiative/HP → [[combat_provider]] → [[combat_dao]] (Drift) → [[Sync-and-Realtime]]. Map edits → [[world_map_data_dao]] + [[map_pins_dao]]. Snapshot built for [[Projection-Second-Screen]] with [[fog_externalizer]].

## Related Domains
- [[Character-System]] (effective stats) · [[Projection-Second-Screen]] (output) · [[Data-Layer]] (encounter tables) · [[Sync-and-Realtime]].

## VTT Upgrade — Phase 1 (shipped 2026-06-02)
Token HUD (DM + player views), `hidden` flag end-to-end (DM sets → fog-filtered before projection), damage/heal/hide context menu on token long-press. Token context menu drives [[combat_provider]] state. See [[Fog-of-War-and-Visibility]] for hidden-flag filtering.

## Source Docs
- `vtt_upgrade_initiative` memory; design docs removed after Phase 1 shipped.
