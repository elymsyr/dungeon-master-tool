# Project Progress Report (progress.md)

## [10.06.2026 - 19:12] - Last Update Status
- **Current Phase:** Infrastructure (Roadmap Phase 1 — UI Cleanup)
- **Last Completed Task:** **PR-1.1 — Removed all rule-authoring UI from entity cards.** Deleted the `DerivedRulesPanel` mount + import from `entity_card.dart` and the `PrereqWarningsBanner` mount + import from `character_editor_screen.dart`; deleted the files `derived_rules_panel.dart` and `prereq_warnings_banner.dart`. Routed the five rule-DSL `FieldType` branches (`spellEffectList`, `grantedModifiers`, `featEffectList`, `autoGrantSources`, `prereqClauses`) in `field_widget_factory.dart` to `const SizedBox.shrink()`. Deleted the now-dead authoring widgets and their private helpers from `structured_list_field_widgets.dart` (`SpellEffectListFieldWidget`, `GrantedModifiersFieldWidget`, `FeatEffectListFieldWidget`+`_FeatEffectRow`, `_PredicateEditor`, `_ScalesWithEditor`, `_ActivationEditor`, `AutoGrantSourcesFieldWidget`, `PrereqClausesFieldWidget`+`_PrereqClauseRow`+`_ClauseOptionListField`, plus the orphaned `_miniEnum`/`_miniBool` helpers and their section consts) — file shrank 3400→1337 lines. Removed the three now-unused imports (`rule_catalog_provider`, `rule_definition`, `rule_validator`). The **resolver is untouched** — data fields still parse and resolve; only the authoring/display UI is gone. Verified: zero remaining references to any deleted symbol across `lib/` + `test/`; brace/paren balance intact on the trimmed file.
- **Next Task for Next Run:** **PR-1.2 — Template model v3 (inert).** Add `typeConfig: Map<String,dynamic>?` and `rules: List<Map<String,dynamic>>` to `FieldSchema`; add `formatVersion` (int, default 2) and `seedRows` to `WorldSchema`; add the new `FieldType` enum values (`abilityScoreTable`, `combatStatsTable`, `intPouch`, `checkboxPouch`, `pouchMatrix`, `skillTree`, `recordList`, `levelMatrix`, `levelUpTable`, `actionButton`); extend `computeWorldSchemaContentHash` to fold in `seedRows` + the new per-field keys. Nothing consumes these yet (inert). Keep JSON round-trip backward-compatible (absent keys default cleanly on old assets).

## Todo List
- [x] Clean up legacy rule panels from the old UI *(PR-1.1 — done)*
- [ ] Implement the core Template System infrastructure *(PR-1.2 model v3 inert → PR-1.3 builtin JSON export → PR-1.4 template library/copy)*
- [ ] **Develop the mobile and desktop responsive Template Editor UI for dynamic template modification** *(PR-1.5 shell + Phase 2 components)*
- [ ] Write the Built-in SRD Template as JSON (without advanced rule fields initially, preserving static text/descriptions) *(PR-1.3, RULE RESET: `rules: []` everywhere)*
- [ ] Migrate the Built-in DnD Package (Cards/Entities), enrich descriptions using Markdown, and evolve the template dynamically with rules (Just-In-Time) *(Phase 3 waves)*
- [ ] Clean up redundant template fields, run **UI responsive layout tests**, and conduct final integration testing *(Phase 4)*

## Notes / Constraints
- Working on branch **`new-rules`**; commit every change here.
- `flutter`/`dart` toolchain is **not installed** in this remote environment, so `flutter analyze` cannot be executed here — changes are verified by static grep sweeps, brace/paren balance, and dependency-graph analysis. The analyze gate must be re-run in a Flutter-capable environment before release.
- Per the master roadmap, this roadmap wins over the two detail docs (notably: rule text goes into the card `description`, not a `rules_text` side-field; JIT evolution replaces a bulk ruleset drop).
- Vault is intentionally **not** updated until the whole roadmap + tests are finished (per run instructions).
