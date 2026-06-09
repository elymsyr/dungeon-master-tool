---
type: system
domain: projection
updated: 2026-06-09
tags: [system]
---

# Fog of War & Visibility

> [!summary] What this is
> The filtering layer that decides what players see vs what the DM sees before content is projected. Hidden tokens, fogged map regions, and entity visibility are resolved here so the projection transport never leaks DM-only data. Owned by [[Projection-Second-Screen]] / [[Combat-and-VTT]].

## Participants
- [[entity_snapshot_builder]] — computes the player-visible entity set.
- [[fog_externalizer]] — serializes fog regions for projection.
- [[battle_map_snapshot_builder]] — assembles the map + tokens snapshot.
- [[battle_map_snapshot]] / [[projection_state]] — the filtered render models.

## Flow
1. DM state (full) lives in [[Combat-and-VTT]] + [[World-and-Content]].
2. On projection update, [[entity_snapshot_builder]] applies visibility rules (hidden flag, fog regions) → player-safe entity list.
3. [[fog_externalizer]] serializes revealed/concealed map regions.
4. [[battle_map_snapshot_builder]] composes map + visible tokens + fog → [[battle_map_snapshot]].
5. Pushed via the chosen [[projection_output]] transport — DM-only fields never cross.

## Key Constants / Invariants
- Filtering happens **before** transport — the player window/screencast/online stream only ever receives the filtered snapshot.
- Hidden flag is end-to-end (DM + player) per the VTT upgrade.

## Related
- MoCs: [[Projection-Second-Screen]], [[Combat-and-VTT]]
- Source Docs: `flutter_app/docs/second_screen_dm_player_view_spec_may21.md`
