---
type: file-note
domain: content-pipeline
path: flutter_app/lib/domain/entities/schema/builtin/srd_core/srd_core_pack.dart
layer: domain
language: dart
status: stable
updated: 2026-08-20
tags: [file]
---

# `srd_core_pack.dart`

> [!abstract] Primary Purpose
> Assembles the hand-authored built-in "SRD 5.2.1 Core" content pack in memory at runtime. Walks every per-slug authoring function (weapons, spells, monsters, classes, …), mints deterministic UUIDv5 ids in stable order (Pass 1), then resolves every `_ref` placeholder against the freshly minted UUIDs (Pass 2). This is the canonical two-pass build that [[refgraph]] clones for Open5e packs. Tier-0 `_lookup` placeholders are left intact for the bootstrap to resolve at import time.

## Inputs / Outputs
**Inputs**
- Per-slug raw row lists from the sibling content files (see [[srd-pack-content]]): `srdWeapons()`, `srdSpells()`, `srdMonsters()`, `srdClasses()`, `srdFeats()` + `srdClassFeats()` + `srdSubclassFeats()`, etc.

**Outputs**
- `SrdCorePack buildSrdCorePack()` — `{entities: <uuid → wire-format entity>, metadata}`.
- `srdStableEntityId(slug, name)` — `uuid.v5(_srdNamespaceUuid, 'slug:name')`, shared with `SrdCorePackageBootstrap`.
- Constants: `srdAttribution`, `srdLicense = 'CC-BY-4.0'`, `srdSourceTag = 'SRD 5.2.1'`, `srdCorePackVersion = '1.1.0'`.

## Dependencies & Links
- Depends on: [[srd-pack-content]] (all 20+ content files), [[srd_helpers]] (`packEntity`, `lookup`, `ref`), `package:uuid`.
- Used by: `bundled_packs_bootstrap` / `SrdCorePackageBootstrap`, [[package_payload_importer]], [[package_import_service]], `package_sync_service`.
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]], [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: [[SRD-5.2.1]], [[Content-Licenses]]

## Key Logic / Variables
- `_srdNamespaceUuid = '6e7d2a4a-2c2d-4d2c-8a3a-7f0c1b2c3d4e'` — fixed namespace so ids are byte-stable across app starts. **Critical invariant**: ids are persisted as `package_entity_id` foreign keys in installed campaigns; if they changed per session, `package_sync_service` would treat every campaign row as orphaned, delete it in the remove sweep, then re-insert with new ids — stranding open EntityCard tabs.
- `srdRawRowsBySlug()` — defines the build ORDER (matters for deterministic id assignment): independent slugs (weapon/armor/tool/gear/ammunition/mount/vehicle) first, then `pack` (refs gear), then identity content. The `feat` slug folds `srdFeats()` + `srdClassFeats()` + `srdSubclassFeats()` together so `wireFeatureGrants` can hang each class feature off its Class/Subclass level row and the `featureOption` dialog finds option feats. Public so content tests can inspect the authored rows before ids are minted.
- **`wireFeatureGrants(raw)` (Pass 0)** — moves each class-feature feat's build-time `_feature_grant` marker onto the granting card's `features` row as `granted_feat_refs`, then strips it. This is what makes the Class card the single statement of *when* a feature arrives; the feat carries no notion of who grants it. Returns a list of rows it had to move or synthesize, pinned by `feature_grant_edge_test`.
- **Duplicate-id guard (Pass 1)** — ids are `slug:name` derived, so two rows sharing a name silently overwrote each other. `Uncanny Dodge` (Rogue L5 vs a Hunter option) and `Fiendish Vigor` (Fiend Patron L3 vs a Warlock invocation) both shipped that way; the builder now throws.
- `srdCorePackVersion` is hoisted top-level so `SrdCorePackageBootstrap` can compare against the stored DB version WITHOUT building the full ~2000-entity pack first; bump it on any content change to force re-seed.
- Pass 2 `_resolveRefs`: unknown `_ref` becomes `''` (caught by the integrity test `srd_core_pack_test.dart`).
- `trinket` slug intentionally unpopulated (SRD 5.2.1 omits the d100 trinket table).

## Notes
- Every value authored into a row must be **JSON-encodable with String keys** — `jsonEncode` rejects a Map with int keys, and [[srd_core_package_bootstrap]] encodes each row's `attributes` verbatim. Level tables (`count_by_level`, `extra_attack_count_by_level`) therefore use `{'1': 2}`, not `{1: 2}`; `test/domain/srd_core_json_encodable_test.dart` guards this.
- v1.0.6 authored the SRD spellcasting tables onto the built-in casters (audit **T2-2**), v1.0.7 put `skill.ability_ref` on the standard `_lookup` placeholder (**T2-1**), v1.0.8 lifted the spell area / Reaction trigger / upcast fields and `pack.content_quantities` out of the rows' own prose (**T2-3**), v1.1.0 transcribed the SRD MOD/SAVE columns and "Skills" lines onto the creature cards (**R7**, `save_bonuses` on 123 cards, `skill_bonuses` on 220) — see [[srd-pack-content]].
- v1.0.3 added 14 magic-items + 7 spells ported from the dropped Open5e SRD packs (see Open5e Pack Consolidation memory). Subspecies became a first-class category in Jun 2026 (pack v1.0.2).
