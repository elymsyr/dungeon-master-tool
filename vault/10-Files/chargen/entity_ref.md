---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/entity_ref.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
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
- Public API: `String? resolveEntityRef(Object? raw, Map<String,Entity> byId)`; `String? findEntityIdByName(Map<String,Entity> byId, String slug, String name)`.

## Dependencies & Links
- Depends on: `entity.dart` (reads `Entity.categorySlug`, `.name`, `.id`).
- Used by: [[character_resolver]] (as `_resolveRef`/`_findEntityIdByName`), and the chargen wizard / level-up selection UI.
- Domain map: [[Character-System]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: see `tool/open5e_import/refgraph.dart` + [[mapper_chargen]] for how the envelopes are emitted at pack-build time.

## Key Logic / Variables
- Three envelope shapes: (1) plain entity-id `String` (`ref()` resolved at build, or a `_lookup` that became a Tier-0 UUID at load); (2) `{_ref: <id>, name}`; (3) `softRef` `{slug, name}` left intact for runtime name-resolution against installed content (subclass→base class, background→origin feat, species→innate spell).
- `resolveEntityRef`: bare String returns it only if present in `byId` (else null); Map reads `_ref` **or** `slug` plus `name` and delegates to `findEntityIdByName`.
- `findEntityIdByName`: O(1) via a per-map `(slug,name)→id` index built lazily into an `Expando<Map<String,String>>` keyed weakly on the `byId` instance. Safe because the maps are unmodifiable and rebuilt as a *new* instance whenever contents change (`wizardEntitiesProvider`), so a cached index can never go stale. Key format is `"$slug $name"`; first-writer-wins matches the old linear "first match".
- Qualifier-tolerant: on a miss it strips a trailing parenthetical (`"Magic Initiate (Cleric)"` → `"Magic Initiate"`) and retries, so a softRef naming a specific variant lands on the generic entity the pack ships.
- **Case sensitive.** The index key is the raw `"$slug $name"` — `"thieves' tools"` does not find `"Thieves' Tools"`. Anything *emitting* a softRef must use the target's exact name; [[dupe_census]] lowercases when it audits this surface, so it will report such a ref as resolved while this function drops it.
- **Qualifier tolerance cuts both ways.** [[srd_core_pack]] ships both `Amphibious` and `Amphibious (Dragon)`; a softRef to `"Amphibious (Aboleth)"` therefore resolves *successfully* onto the generic row and puts the wrong text on the sheet. It is a fallback, never a naming strategy — a wrong-but-resolvable name is worse than a dangling one, because nothing warns.

## Notes
- Performance note in source: `CharacterResolver` resolves 20+ refs against the *same* `entitiesById` per character — without the Expando cache each was an O(n) scan (twice on a qualifier miss) over the whole merged map.
- ⚠️ **Adoption is incomplete on the chargen side (2026-07-30).** [[character_resolver]] routes every `_ref` through here (`_readRefList`/`_resolveRef`), but several wizard/level-up filters still compare raw id strings and so cannot see a softRef Map at all: `wizard/steps/spells_step.dart` `_classRefs`, `wizard/character_creation_wizard_screen.dart` (the `spellCount` check that decides **whether the spells step is shown**), `wizard/steps/feats_step.dart`, and `pending_choice_resolver_dialog.dart` (×2) — all on `spell.class_refs`. Packaged spells reach those lists only via a parallel bare-name `tags` fallback. Consequence: filling `class_refs` with softRefs (audit phase L3) while retiring `tags` would remove every bundled spell from character creation with no test failing. Audit doc §2.3.1 / phase **U1** puts these readers on `resolveEntityRef` first.
