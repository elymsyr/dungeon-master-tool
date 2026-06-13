# Static-Field Preservation Checklist — Built-in Template v2 → v3

> **Roadmap:** PR-2.3 (Phase 2) STATIC-FIELD PRESERVATION CHECKPOINT · **Prompt §4** retention policy · **Roadmap §1.4** "Static fields are sacred".
>
> This is the explicit per-category audit of every player-facing **narrative / static-text** field in the built-in D&D 5e template, asserting each is **present and unchanged** in the v3 template that `generateBuiltinDnd5eTemplateV3()` produces from the frozen v2 schema.

## 1. Policy

Story, biography, notes, description, benefits, appearance, ideals/bonds/flaws, GM notes, glossary prose — **any narrative text/markdown field that does not trigger a mechanic is never deleted, retyped, or value-mutated** by the rule migration. The rule reset (roadmap §1.1) strips *rule* semantics, not prose. During the Just-In-Time waves (Phase 3) the per-card `description` is *enriched*, never truncated; the redundant-field cleanup (prompt §4) removes only empty/deprecated **mechanical** fields, explicitly sparing static text.

A field is **protected** iff its `FieldType` is one of `text`, `textarea`, or `markdown` (`staticNarrativeFieldTypes`). This is a deliberate **superset** — an allow-list of *types*, not of names — so any future category's prose field is covered automatically.

## 2. Enforcement (binding source of truth)

The checklist below is documentation; the **binding** check is code:

- `auditStaticFieldPreservation(v2, v3)` in
  [`builtin/builtin_dnd5e_template_v3.dart`](../../flutter_app/lib/domain/entities/schema/builtin/builtin_dnd5e_template_v3.dart)
  walks every `text`/`textarea`/`markdown` field of the **v2 source schema** and asserts the same
  `(categorySlug, fieldKey)` exists in the **v3 template** with an identical `fieldType` *and* a
  deep-equal `defaultValue`. A dropped, retyped, or value-mutated prose field throws `StateError`
  naming the offender.
- It is wired into `generateBuiltinDnd5eTemplateV3()` under an `assert(() { … }())`, so it gates
  every debug/test build (the same discipline as the editor's `typeConfig` validator) at zero
  release cost.
- Because it is computed over the **live schema**, this audit can never silently drift from the
  source — adding a category or renaming a field updates the result automatically.

**Why it holds by construction today:** the only edits the v3 transform makes are on the
*Player Character* category's **mechanical** fields — the six wire-identical parity renames
(`pcFieldTypeSwaps`: `statBlock`/`combatStats`/`proficiencyTable`/`spellSlotGrid` → v3 types),
the three `integer` → `checkboxPouch` pip swaps (`pcPipFieldKeys`), and three appended
`actionButton` header fields. **None of these is a `text`/`textarea`/`markdown` field**, so every
protected field is returned untouched.

## 3. The audit list

Verified preserved (`[x]` = type & value identical in v3). Grouped by tier; `md` = markdown,
`ta` = textarea, `t` = text.

### Tier 0 — Lookups (`lookups.dart`)

Every Tier-0 lookup category shares the glossary prose pair, plus a few carry one extra prose field. All preserved:

- [x] **all lookups** — `summary` (ta), `effects` (md)
- [x] `skill` — + `examples` (ta)
- [x] `damage-type` — + `example_sources` (ta)
- [x] `condition` — + `ends_on` (ta)
- [x] `creature-type` — + `default_skills_note` (ta)
- [x] `language` — + `typical_speakers` (ta)

> The `summary`/`effects` pair is the glossary body for every lookup (`ability`, `skill`,
> `condition`, `damage-type`, `sense`, `language`, `weapon-property`, `weapon-mastery`,
> `spell-school`, `size`, `rarity`, `alignment`, `action`, `plane`, … — the full Tier-0 set).

### Tier 1 — Content shapes (`content.dart`)

- [x] `class` — `multiclass_requirements` (md), `multiclass_granted_proficiencies` (md)
- [x] `subclass` — `flavor_description` (md)
- [x] `species` — `age` (t, "Typical Lifespan")
- [x] `feat` — `prerequisite` (md), `benefits` (md) *(benefits merges into `description` Effects at Phase-3 Wave 5; until then it is preserved verbatim)*
- [x] `spell` — `description` (md), `material_description` (t), `reaction_trigger` (t)
- [x] `tool` — `utilize_description` (ta)
- [x] `adventuring-gear` — `utilize_description` (md)
- [x] `ammunition` — `storage_container` (t)
- [x] `pack` — `contents` (md)
- [x] `trinket` — `description` (md)
- [x] `magic-item` — `attunement_prereq` (md), `effects` (md), `charge_regain` (t), `command_word` (t), `sentient_communication` (t), `sentient_senses` (t), `sentient_special_purpose` (t)
- [x] `trait` — `source` (t), `description` (md), `benefits` (md)
- [x] `creature-action` — `source` (t), `recharge` (t), `description` (md)
- [x] `monster` / `animal` — `tags_line` (t), `ac_note` (t)
- [x] `starter-bundle` — `notes` (md)

> Categories with no prose field (`subspecies`, `background`, `weapon`, `armor`, `mount`,
> `vehicle`) carry nothing to preserve — confirmed empty, not a gap.

### Tier 2 — DM / Campaign (`dm.dart`)

- [x] `npc` — `faction` (t), `goals` (md), `appearance` (md), `mannerisms` (md), `secrets` (md, DM-only)
- [x] **`player-character`** — `trinket` (md), `personality_traits` (md), `ideals` (md), `bonds` (md), `flaws` (md), `appearance` (md), `backstory` (md), `allies_organizations` (md), `age`/`height`/`weight`/`eyes`/`skin`/`hair` (t)
- [x] `applied-condition` — `notes` (ta)
- [x] `location` — `environment` (t), `description_long` (md), `secrets` (md, DM-only)
- [x] `scene` — `beats` (md)
- [x] `quest` — `reward` (md), `objective` (md), `secrets` (md, DM-only)
- [x] `encounter` — `setup` (md), `tactics` (md, DM-only)
- [x] `trap` — `trigger` (md), `countermeasures` (md)
- [x] `poison` — `effect` (md)
- [x] `curse` — `trigger` (md), `effect` (md), `removed_by` (md)
- [x] `environmental-effect` — `effect` (md)
- [x] `service` — `availability` (t)

> **`player-character` is the safety-critical row:** it is the *only* category the v3 transform
> edits, and it is the one with the most narrative fields (8 markdown + 6 identity text). All 14
> sit outside `pcFieldTypeSwaps` / `pcPipFieldKeys`, so `_swapPcField` returns each untouched. The
> assertion proves it on every build.

## 4. Re-audit hook (Phase 4)

Roadmap Phase 4 (PR-4.x) re-runs this same checkpoint after the JIT waves complete, to confirm
description enrichment never displaced a static field. Because the check is the live
`auditStaticFieldPreservation` assertion — not a frozen snapshot — the Phase-4 pass is automatic:
any wave that drops a prose field fails the debug build immediately.
