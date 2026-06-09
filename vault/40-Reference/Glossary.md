---
type: reference
domain: cross-cutting
updated: 2026-06-09
tags: [reference, glossary]
---

# Glossary

> [!summary] Project vocabulary
> Terms that recur across notes. Link here from any note using a term for the first time.

- **CDC** — Change Data Capture. Postgres → client realtime stream that drives inbound sync. See [[CDC-Sync-Flow]].
- **MoC** — Map of Content. A domain index note in `00-Maps/` linking its file notes.
- **Outbox** — local queue of pending mutations; coalesced per `(table, pk, op)`. See [[sync_outbox_dao]].
- **Coalescing** — overwriting an existing pending write for the same row instead of queuing a duplicate.
- **Echo suppression** — skipping inbound CDC events that echo the client's own recent push (3 s window).
- **SyncTier** — fast (realtime) vs slow (10 s batched) routing of writes. See [[sync_tier]].
- **Tier-0 / Tier-1** — Tier-0 = enum lookups (size, alignment, damage-type…); Tier-1 = content categories (monster, spell, class…). 73-category schema.
- **EffectiveCharacter** — computed character view after [[character_resolver]] folds all effects. See [[effective_character]].
- **Effect DSL** — declarative effect entries on content (`effect/predicate/scalesWith/activation`). See [[Effect-DSL-Resolution]].
- **Hard ref / Soft ref** — uuid `_ref` (intra-pack, build-resolved) vs slug+name (cross-pack, runtime). See [[Ref-Resolution-Hard-vs-Soft]].
- **Drift** — the local SQLite ORM (schema v12). See [[Data-Layer]].
- **Free / Counted / Transient** — the three media tiers. See [[Media-Storage-Tiers]].
- **Projection / Second-screen** — DM→player output (4th output type). See [[Projection-Second-Screen]].
- **Pack / Package** — installable content bundle (`.pkg.json`). Built by [[Content-Pipeline]].
