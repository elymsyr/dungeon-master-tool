# Content Conversion — Old Packages/Content → Template v3

> Instructions only. Design context in [the-template-system.md](the-template-system.md). Runs in PR-T9.

## Tooling

1. Put the core logic in one shared library: `flutter_app/lib/domain/services/template_migration/legacy_content_converter.dart`. The **same code** runs everywhere.
2. Wrap it in a CLI for offline use: `flutter_app/tool/convert_packs_v3.dart` (sibling of the Open5e import tooling) — converts the bundled packs at build time.
3. Compile it into the app as an **on-open shim** — converts user personal packages and existing world entities when first opened on a v3 build.
4. Do NOT convert the SRD Core package from JSON — regenerate it: update the `builtin/srd_core/*.dart` generators to emit v3 fields directly (highest-fidelity path).

## Per-entity transformation (deterministic, idempotent, driven by the pack's embedded old schema)

1. Wire-identical type renames are value-preserving no-ops: `slot` → `checkboxPouch`, `spellSlotGrid` → `pouchMatrix`, `proficiencyTable` → `skillTree`, `statBlock` → `abilityScoreTable`, `combatStats` → `combatStatsTable`, `spellSlotProgression` → `levelMatrix`. Leave values untouched.
2. Convert integer pip fields to pouch values where the v3 template declares a pouch (death saves, heroic inspiration): int `n` → `{count, states}` with `n` states true.
3. `classFeatures` rows → `levelUpTable` rows: copy `{level, description}`; map legacy tolerated keys (`granted_feat_refs`, `choice_count`, inline `effects`) into `grants[]` / `choices[]` rows.
4. `auto_granted_by` (autoGrantSources) → **invert** each edge into the named source entity's `levelUpTable.grants` row at `at_level` (`choice_required` → a `choices` row). Drop the field afterward.
5. `prereq_clauses` → `prerequisites` recordList rows (clause vocabulary unchanged; read by the template's `check_clauses` rule).
6. `rule_effects` / `effects` / `granted_modifiers` rows — map by kind:
   - ~25 parametric kinds (ability_score_bonus, ac_bonus, speed_bonus, hp_bonus_*, initiative_bonus, proficiency_grant, expertise_grant, language_grant, spell/cantrip_grant, damage_resistance/immunity/vulnerability, condition_immunity_grant, sense/truesight/blindsight_grant, unarmored_ac_formula, resource_pool_grant, recovery_grant, slot_recovery_short_rest, granted_action/bonus_action/reaction_grant, choice_group, class_level_grant) → write into the corresponding v3 data fields covered by the template's standing field rules.
   - Everything else (~40 combat/VTT kinds: advantage_on, reroll_*, crit_range_extend, extra_attack_*, ignore_cover, …) → render to `rules_text` markdown via per-kind human-readable templates (the `note` escape hatch). **Nothing is deleted silently.**
7. `spellEffectList` → recordList `spell-effects` data, unchanged (display-only in v3).
8. Stamp pack metadata: `"format": 3` + v3 template lineage hashes. Emit a per-pack `conversion_report.json` with counts: mapped / noted / dropped (follow the existing `unmapped_report.json` pattern).

## Scope order

1. SRD Core — regenerate from Dart sources (step 4 above).
2. 19 bundled packs (`assets/open5e_packs/*.pkg.json`) — CLI, commit converted assets.
3. User personal packages — on-open shim, with pre-conversion backup via the existing trash machinery.
4. World entities — same shim, during the world v3 migration prompt.

## Verification

- Idempotency: re-running the converter on converted content is a no-op (byte-identical output).
- Check each pack's `conversion_report.json` counts; every `noted` row must be visible as rules text on its card.
- Spot-check per pack: one class (levelUpTable + resources), one feat (ASI options + prereqs), one magic item (noted combat effects), one subspecies (choose rule data).
- Gate: `flutter analyze` clean; converted SRD character resolves with identical sheet values on the new runtime.
