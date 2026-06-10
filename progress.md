# Project Progress Report (progress.md)

## [10.06.2026 - 20:30] - Last Update Status
- **Current Phase:** Infrastructure (Roadmap Phase 1 — Template model v3)
- **Last Completed Task:** **PR-1.2 — Template model v3 (inert).** Evolved the schema model in place (no replacement) per roadmap §1.2 / the-template-system §2.
  - **`field_schema.dart`** — added **10 new `FieldType` enum values** (`abilityScoreTable`, `combatStatsTable`, `intPouch`, `checkboxPouch`, `pouchMatrix`, `skillTree`, `recordList`, `levelMatrix`, `levelUpTable`, `actionButton`), each documented inline with its wire-shape + `typeConfig` contract (the parity types — `checkboxPouch`/`pouchMatrix`/`skillTree` — explicitly note byte-identical wire to `slot`/`spellSlotGrid`/`proficiencyTable`). Added two new `FieldSchema` fields: **`typeConfig: Map<String,dynamic>?`** and **`rules: List<Map<String,dynamic>>?`**, both raw-map (lazily validated, no freezed explosion) and both `@JsonKey(includeIfNull: false)` so a rule-free field serializes byte-identically to today.
  - **`world_schema.dart`** — added **`formatVersion` (int, default 2)** and **`seedRows: Map<String,dynamic>?`** (`includeIfNull: false`, `Map<slug, List<rowMap>>`, dynamic for JSON robustness like `metadata`).
  - **`world_schema_hash.dart`** — extended `computeWorldSchemaContentHash`: per-field `typeConfig`/`rules` fold in for free via `categories`; `seedRows` folded in **only when present** so pre-v3 schemas hash byte-identically; `formatVersion` deliberately **excluded** (structural marker, like `version`).
  - **Inertness verified:** all four `FieldType` switch-expressions (`field_widget_factory.dart`, `entity_provider.dart`, `package_import_service.dart`, `character_provider.dart`) carry a wildcard `_` default → new values fall through with zero behavior change; no hand-written `FieldType` wire-parser exists (json_serializable generates `_$FieldTypeEnumMap`); generated `.g.dart`/`.freezed.dart` are gitignored and rebuilt by build_runner, so only hand-written source was touched. No existing constructor call sites break (all additions defaulted). **Decision logged:** `rules`/`typeConfig`/`seedRows` made *nullable with `includeIfNull:false`* (vs. the planning note's non-nullable `rules`) precisely to keep serialization — and therefore the content hash — inert for every existing v2 world; consumers read `rules ?? const []`.
- **Next Task for Next Run:** **PR-1.3 — Built-in template → JSON asset (RULE RESET).** Write one-shot exporter `flutter_app/tool/export_builtin_template.dart` that serializes `generateBuiltinDnd5eV2Schema()` to `flutter_app/assets/templates/dnd5e_srd.template.json` with `formatVersion: 3`, **`rules: []` everywhere (zero rule-assigned fields)**, and `seedRows` lifted out of `lookups.dart`. Add `BuiltinTemplateLoader` (cached asset load) + a debug assert that loaded-asset content hash == generator hash; register the asset in `pubspec.yaml`. Keep old FieldTypes in place (type swap is PR-2.3). Do NOT yet swap call sites beyond the loader scaffold. (Toolchain is absent here — the exporter is a dev/CI script; if it can't be run in-env, generate the asset deterministically and document that the assert must be confirmed in a Flutter-capable env.)

## Todo List
- [x] Clean up legacy rule panels from the old UI *(PR-1.1 — done)*
- [ ] Implement the core Template System infrastructure *(PR-1.2 model v3 inert ✅ → PR-1.3 builtin JSON export → PR-1.4 template library/copy)*
- [ ] **Develop the mobile and desktop responsive Template Editor UI for dynamic template modification** *(PR-1.5 shell + Phase 2 components)*
- [ ] Write the Built-in SRD Template as JSON (without advanced rule fields initially, preserving static text/descriptions) *(PR-1.3, RULE RESET: `rules: []` everywhere)*
- [ ] Migrate the Built-in DnD Package (Cards/Entities), enrich descriptions using Markdown, and evolve the template dynamically with rules (Just-In-Time) *(Phase 3 waves)*
- [ ] Clean up redundant template fields, run **UI responsive layout tests**, and conduct final integration testing *(Phase 4)*

## Notes / Constraints
- Working on branch **`new-rules`**; commit every change here.
- `flutter`/`dart` toolchain is **not installed** in this remote environment, so `flutter analyze` cannot be executed here — changes are verified by static grep sweeps, brace/paren balance, and dependency-graph analysis. The analyze gate must be re-run in a Flutter-capable environment before release.
- Per the master roadmap, this roadmap wins over the two detail docs (notably: rule text goes into the card `description`, not a `rules_text` side-field; JIT evolution replaces a bulk ruleset drop).
- Vault is intentionally **not** updated until the whole roadmap + tests are finished (per run instructions).
