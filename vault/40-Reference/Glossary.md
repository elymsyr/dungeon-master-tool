---
type: reference
domain: cross-cutting
updated: 2026-06-09
tags: [reference, glossary]
---

# Glossary

> [!summary] Project vocabulary
> Terms that recur across notes. Link here from any note using a term for the first time.

- **CDC** — Change Data Capture. Postgres → client realtime stream. Artık yalnızca DM'in paylaşım kanalındaki beş tabloyu taşır. See [[Share-Broadcast-Flow]].
- **MoC** — Map of Content. A domain index note in `00-Maps/` linking its file notes.
- **Outbox** — *tarihsel.* Bekleyen mutasyonların yerel kuyruğuydu, `(table, pk, op)` başına birleştirilirdi. Bulut sync ile birlikte kaldırıldı (2026-08-24); yazmalar artık doğrudan, last-write-wins.
- **Share payload** — `entity_shares.payload_json`: DM'in paylaştığı kartın gövdesi. `world_entities` aynası olmadığı için oyuncunun tek içerik kaynağı. NULL = linked kart, gövdesi kurulu paketten gelir. Bkz. [[Share-Broadcast-Flow]].
- **Coalescing** — overwriting an existing pending write for the same row instead of queuing a duplicate.
- **Echo suppression** — skipping inbound CDC events that echo the client's own recent push (3 s window).
- **SyncTier** — fast (realtime) vs slow (10 s batched) routing of writes. See `sync_tier.dart` (kaldırıldı).
- **Tier-0 / Tier-1** — Tier-0 = enum lookups (size, alignment, damage-type…); Tier-1 = content categories (monster, spell, class…). 73-category schema.
- **EffectiveCharacter** — computed character view after [[character_resolver]] folds all effects. See [[effective_character]].
- **Grant block** — the shared set of plainly named fields a card uses to declare what it grants (`granted_skill_proficiencies`, `ac_bonus`, `resource_pool_grants`, `mechanical_notes`, …). Emitted by `_FB.grantBlock`, read by `CharacterResolver.applyGrantsFrom`. See [[Grant-Resolution]].
- **Effect DSL** *(retired 2026-07-28)* — the former `effect/predicate/scalesWith/activation` row language on content, plus the parallel `granted_modifiers` DSL. Replaced by the grant block; existing data is converted by [[rule_effects_migration]].
- **Hard ref / Soft ref** — uuid `_ref` (intra-pack, build-resolved) vs slug+name (cross-pack, runtime). See [[Ref-Resolution-Hard-vs-Soft]].
- **Drift** — the local SQLite ORM (schema v12). See [[Data-Layer]].
- **Free / Counted / Transient** — the three media tiers. See [[Media-Storage-Tiers]].
- **Projection / Second-screen** — DM→player output (4th output type). See [[Projection-Second-Screen]].
- **Pack / Package** — installable content bundle (`.pkg.json`). Built by [[Content-Pipeline]].
