---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/world_blueprint_converter.dart
layer: domain
language: dart
status: stable
updated: 2026-08-31
tags: [file]
---

# `world_blueprint_converter.dart`

> [!abstract] Primary Purpose
> Blueprint (`world-blueprint.json` + `blueprint.json`) → world/package wire-format
> entity map, plus the **validation** that makes a bad blueprint fail loudly. It is the
> single translation point: the offline CLI ([[convert_blueprint]]) and the in-app
> installer ([[bundled_worlds_installer]]) both call it. Before 2026-08-31 the logic
> was hand-duplicated in those two files and had drifted — the installer's copy did not
> know the `trait` / `creature-action` categories, so 25 of 99 Devils' 82 world entities
> were silently dropped at install and every `trait_refs` / `action_refs` pointing at
> them degraded to an unresolvable soft ref.

## Inputs / Outputs
**Inputs**
- `packageName`, `sourceTitle` — id namespace + every entity's `source`.
- `tier0Slugs`, `contentSlugs` — schema-derived (see [[builtin_content_names]]); never hand-listed.
- `knownNames` — `slug → {name}` for everything that exists outside the blueprint (Tier-0 seeds + SRD pack).
- `fieldKeys` — `slug → {field key}` per category; empty disables field checking.
- `mediaResolver` — relative media path → resolved value, `null` = missing file.
- `convert({worldBlueprint, characterBlueprint})`.

**Outputs**
- `BlueprintConversion.entities` — `uuid → wire entity` (`name`, `type`, `source`, `description`, `image_path`, `images`, `tags`, `dm_notes`, `pdfs`, `location_id`, `attributes`).
- `BlueprintConversion.issues` / `errors` / `hasErrors` / `counts`.

## Dependencies & Links
- Depends on: `package:uuid` only (pure domain, no Flutter).
- Used by: [[bundled_worlds_installer]], [[convert_blueprint]]
- Reads name/field catalogues from: [[builtin_content_names]]
- Domain map: [[World-and-Content]], [[Content-Pipeline]]
- Ref semantics: [[Ref-Resolution-Hard-vs-Soft]]
- Authoring rules: `tool/content/README.md`, `tool/content/WORLD_CONTENT_ORDER.md`

## Key Logic / Variables
- **Ref tiers**, in order — this is the whole contract:
  1. Tier-0 slug → `{_lookup, name}`. The value must be a seeded schema value **or** declared under `categories.<slug>` in the same blueprint; otherwise error.
  2. Name declared in this blueprint → `{_ref: slug, name}` (in-pack hard ref).
  3. Name present in `knownNames` (SRD) → `{slug, name}` soft ref — README rule 3, reference rather than recreate.
  4. Neither → **error**. A soft ref is still emitted so nothing crashes, but the caller must fail: a dangling soft ref is dropped silently at read time (`entity_ref.dart`), which is exactly how a missing equipment/trait/spell list becomes invisible.
- Row-side keys on a ref (`equipped`, `quantity`) are copied **into** the envelope, because `_parseItems` / `CharacterResolver` read them off the same map.
- Ids are `uuid.v5(_namespace, '<package>:<slug>:<lowercased name>')` — deterministic across runs. Two rows sharing `(slug, name)` are an error, not a silent overwrite.
- Any string matching `\.(webp|png|jpe?g|gif|svg|pdf|mp3|ogg|wav|gcs)$` goes through `mediaResolver`, wherever it sits in the tree — no per-key allowlist to drift.
- A `mapping` key absent from `fieldKeys[slug]` is an error: it would land in `attributes` where no widget reads it (this is how two PCs' spell lists vanished into `spell_refs` instead of `spells_known`).

## Notes
- Guards: `test/domain/services/world_blueprint_converter_test.dart` (unit) and `bundled_worlds_blueprint_test.dart` (every shipped world converts with zero issues).
