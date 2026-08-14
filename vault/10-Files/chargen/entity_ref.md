---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/entity_ref.dart
layer: domain
language: dart
status: stable
updated: 2026-08-14
tags: [file]
---

# `entity_ref.dart`

> [!abstract] Primary Purpose
> Shared, dependency-light resolution for the three entity-reference envelope shapes that content packages and the built-in SRD store. Lifted out of `CharacterResolver` so the chargen wizard, level-up selection UI, and the resolver all resolve refs identically — instead of the wizard accepting only a bare `String` (which silently dropped packaged content whose cross-pack target arrives as a `softRef` Map).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — top-level functions.
- Reads: a caller-supplied `Map<String, Entity> byId` (the merged entity map).
- Supabase / CDC subscribed: none.
- Events / triggers: none.

**Outputs**
- Public API: `String? resolveEntityRef(Object? raw, Map<String,Entity> byId)`; `List<String> resolveEntityRefList(Object? raw, Map<String,Entity> byId)`; `String? abilityAbbrevFromRef(Object? raw, Map<String,Entity> byId)`; `String? abilityAbbrev(String raw)`; `String? findEntityIdByName(Map<String,Entity> byId, String slug, String name)`.

## Dependencies & Links
- Depends on: `entity.dart` (reads `Entity.categorySlug`, `.name`, `.id`).
- Used by: [[character_resolver]] (as `_resolveRef`/`_findEntityIdByName`, and `abilityAbbrevFromRef` for both ability relation lists), and the chargen wizard / level-up selection UI (`pending_choice_resolver_dialog` reads feat ASI options through it).
- Domain map: [[Character-System]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: see `tool/open5e_import/refgraph.dart` + [[mapper_chargen]] for how the envelopes are emitted at pack-build time.

## Key Logic / Variables
- Three envelope shapes: (1) plain entity-id `String` (`ref()` resolved at build, or a `_lookup` that became a Tier-0 UUID at load); (2) `{_ref: <id>, name}`; (3) `softRef` `{slug, name}` left intact for runtime name-resolution against installed content (subclass→base class, background→origin feat, species→innate spell).
- `resolveEntityRef`: bare String returns it only if present in `byId` (else null); Map reads `_ref` **or** `slug` plus `name` and delegates to `findEntityIdByName`.
- `resolveEntityRefList` (added 2026-08-13, audit **U1**): maps a `*_refs` list through `resolveEntityRef` in order and **drops** what does not resolve — the soft-ref contract, where a missing target is never an error. It exists because the raw idioms it replaces, `(list as List).contains(id)` and `list.whereType<String>()`, both discard every Map envelope silently: a correctly written packaged ref simply became invisible. Every chargen reader of a `*_refs` field goes through it; use it rather than re-deriving the loop.
- `abilityAbbrevFromRef` (added 2026-08-13, audit **M1**): one entry of an **ability relation list** (`asi_ability_options`, `unarmored_ac_abilities`) → `STR`…`CHA`. The same card carries a different shape depending on provenance — an installed package resolved its `{_lookup, name}` envelopes to **ids**, an as-authored card still holds the envelope, and parts of [[srd_core_pack]] ship plain names (`'Strength'`) — and all three mean the same ability. Reading one shape only is exactly how feat ASI stopped applying to every packaged feat (see Notes). Falls through id → `{id}` → `{name}`/`{_lookup,name}` → bare name/abbreviation, null on anything else.
- `findEntityIdByName`: O(1) via a per-map `(slug,name)→id` index built lazily into an `Expando<Map<String,String>>` keyed weakly on the `byId` instance. Safe because the maps are unmodifiable and rebuilt as a *new* instance whenever contents change (`wizardEntitiesProvider`), so a cached index can never go stale. Key format is `"$slug $name"`; first-writer-wins matches the old linear "first match".
- **First-writer-wins makes merge order a content decision.** Ids are uuidv5 of `(pack, slug, name)`, so an SRD card and a pack's restat of the same spell never collide by id — both are in `byId`, and this function returns whichever the map iterates first. Who that is belongs to [[package_source_entities]], which since audit **L1** (2026-08-14) layers packages *ahead* of the built-in on every path, so the pack the user picked wins. Before that fix the wizard and the sheet disagreed on the same ref.
- Qualifier-tolerant: on a miss it strips a trailing parenthetical (`"Magic Initiate (Cleric)"` → `"Magic Initiate"`) and retries, so a softRef naming a specific variant lands on the generic entity the pack ships.
- **Case sensitive.** The index key is the raw `"$slug $name"` — `"thieves' tools"` does not find `"Thieves' Tools"`. Anything *emitting* a softRef must use the target's exact name; [[dupe_census]] lowercases when it audits this surface, so it will report such a ref as resolved while this function drops it.
- **Qualifier tolerance cuts both ways.** [[srd_core_pack]] ships both `Amphibious` and `Amphibious (Dragon)`; a softRef to `"Amphibious (Aboleth)"` therefore resolves *successfully* onto the generic row and puts the wrong text on the sheet. It is a fallback, never a naming strategy — a wrong-but-resolvable name is worse than a dangling one, because nothing warns.

## Notes
- ✅ **Feat ASI was dead on every packaged feat until 2026-08-13 (audit M1).** The resolver's ASI fallback read `asi_ability_options` as a list of maps and took `['name']` — the *unresolved* envelope shape, which no installed card has, because import rewrites it to an id. All 23 a5e-ag + toh feats with `asi_amount > 0` therefore bumped nothing, silently. The fix was to stop having three private readers of one relation list: `abilityAbbrevFromRef` is now the only one, and `pending_choice_resolver_dialog`'s `_asiOptionToAbbrev` / `_abilityNameToAbbrev` copies are deleted. Caught by the data-driven sweep in `test/domain/services/bundled_pack_resolve_test.dart`, not by review.
- Performance note in source: `CharacterResolver` resolves 20+ refs against the *same* `entitiesById` per character — without the Expando cache each was an O(n) scan (twice on a qualifier miss) over the whole merged map.
- ✅ **Chargen adoption closed 2026-08-13 (audit U1).** Six readers previously compared raw id strings and could not see a softRef Map: `wizard/steps/spells_step.dart` `_classRefs`, `wizard/character_creation_wizard_screen.dart` (the `spellCount` check that decides **whether the spells step is shown**, plus the `skillEntityIdSet` that collects background/species granted skills), `wizard/steps/feats_step.dart`, and `pending_choice_resolver_dialog.dart` (×2) — all but one on `spell.class_refs`. All now call `resolveEntityRefList`. Test: `test/domain/services/entity_ref_list_test.dart`.
- ⚠️ The parallel bare-name `tags` fallback is **still live and still load-bearing**: `class_refs` is 0% filled in the packs, so `tags` is what actually makes bundled spells visible today. Retiring it belongs to audit L3, and only after U2's per-family wizard test proves the spell list is non-empty without it. Writing `class_refs` as softRefs and dropping `tags` in one change still removes every bundled spell from character creation.
