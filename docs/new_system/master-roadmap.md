# Master Roadmap — Dynamic Template & Package Architecture

> **Status:** APPROVED PLAN (2026-06-10). This is the single authoritative roadmap for migrating the project from the hardcoded rule system to the dynamic, JSON-based Template & Package architecture.
>
> **Detail layer:** [docs/new_system/the-template-system.md](docs/new_system/the-template-system.md) (Template v3 JSON format, field wire shapes, runtime design) and [docs/new_system/content-convert.md](docs/new_system/content-convert.md) (converter pipeline).
>
> **Override note:** Where this roadmap conflicts with those documents, **this roadmap wins**. Known overrides: the old PR-T8 "bulk SRD ruleset" drop is replaced by **Just-In-Time evolution** (§3, Phase 3); the `rules_text` side-field is rescinded — generated rule text goes **into the card's `description`** (§4.1); template copy infrastructure moves to **Phase 1**.

---

## 1. Executive Summary & Architectural Vision

### 1.1 Current structure

Today the system is rigid in three layers:

1. **Schema is code.** 74 entity categories (39 Tier-0 lookups, 22 Tier-1 content shapes, 13 Tier-2 DM categories) are hardcoded in `flutter_app/lib/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart` and its builders (`lookups.dart`, `content.dart`, `dm.dart`). Changing a field means shipping a new app build.
2. **Rules live on entity cards.** Mechanics are authored as DSL rows on individual cards (`effects`, `rule_effects`, `granted_modifiers`, `prereq_clauses`, `auto_granted_by`, flat ASI fields), compiled per-card by `RuleCompiler` (~67 effect kinds) into `BoundRule`s, and executed by `character_resolver.dart`. Every card is a tiny program; creators must understand the effect DSL to author content.
3. **Template UI is read-only.** `hub/templates_tab.dart` is a browser list; `hub/template_editor.dart` is an inspector. Users cannot create, copy, or edit templates at all.

### 1.2 New dynamic structure

The target architecture inverts the relationship between schema and rules:

- A **Template** is a user-editable JSON document (`formatVersion 3`; `WorldSchema` evolved in place — the existing dual-hash lineage, world binding, and drift-detection machinery are reused verbatim). It defines categories, fields, and — attached to fields — **rule semantics**.
- An **entity card is pure data.** The DM fills values into template-defined fields. Rules fire from field semantics declared once in the template, never from per-card rule rows. Example: the template's `feat` category declares an `asi_options` list field carrying a `when_granted` choose-one rule; each feat card just lists its options; the player who gains the feat gets a picker.
- Every card additionally carries a **complete, player-facing Markdown description**: prerequisites, level-up effects, equip rules, and all other mechanics written so the player fully understands the card from text alone. Mechanical automation is a synchronized bonus layer on top of readable text.
- Templates live in a **hub-level library** (like the packages tab): list, **copy the built-in**, edit your copy. The built-in SRD template ships read-only.

**Three strategic shifts** govern the migration (these supersede the earlier phase plan):

> 1. **Rule reset first.** The built-in template is extracted to JSON with **zero** rule-assigned fields. The whole app runs rule-free on the new infrastructure before a single rule exists.
> 2. **Just-In-Time template evolution.** Built-in DnD pack cards migrate one category at a time. The template gains a rule-assigned field **only at the moment a card actually needs it**. End-state guarantee: every rule-bearing field is used by ≥1 card — zero dead or erroneous fields, enforced by an automated usage audit.
> 3. **Description-first cards.** During conversion, every card's `description` is completed into standalone, standard-format Markdown. The text is the contract with the player; the rule fields keep the sheet in sync with it.

### 1.3 Responsive Editor UI vision

The Template Editor becomes a first-class, fully responsive surface following the app's existing responsive grammar — `ScreenType` (`lib/core/utils/screen_type.dart`: phone < 600 shortest-side, tablet 600–1199, desktop ≥ 1200), `ResizableSplit` dual panes (as in `database_screen.dart`), `isTouchPlatform` for sheet-vs-dialog dispatch:

```
Hub ── Templates tab (library: built-in [View][Copy] · copies [Edit][Rename][Delete])
        └─ /template/edit  →  TemplateEditorScreen (responsive shell)
             desktop ≥1200 ── 3-pane: [Categories 240px] | ResizableSplit( [Fields] | [Field Inspector] )
             tablet 600-1199 ─ 2-pane: [Categories ⇄ Fields drill] | [Field Inspector]
             phone <600 ────── stacked: Categories page → Fields page → Field Edit page
```

Creators add/remove/reorder categories and fields, configure each field's `typeConfig` through dedicated forms, and (from Phase 3 on) attach rules — on any device. Full specification in Phase 1.5 (§3).

### 1.4 Invariants carried over unchanged

- **PC sheet pixel parity** — every new field type keeps its existing renderer; new types reuse old value wire-shapes verbatim (`checkboxPouch` = old `slot` `{count, states[]}`; `pouchMatrix` = old `spellSlotGrid` `{max, remaining}`; `skillTree` = old `proficiencyTable` rows). The 20k-card value migration is therefore near-zero.
- **Dual-hash drift detection** (`originalHash` + `computeWorldSchemaContentHash`) and `applyTemplateUpdate` reused as-is; template copies preserve `originalHash` lineage.
- **Per-world dual-stack authority** during migration: worlds on a v2 embedded schema keep resolving on the frozen old engine until migrated; no character ever breaks mid-transition.
- **Static fields are sacred.** Story, biography, notes, description — any narrative text/markdown field that doesn't trigger a mechanic is **never deleted**; preservation is checklisted (Phase 2.3) and re-audited (Phase 4).
- **Closed rule vocabulary.** The rule kinds and contexts in §2 are closed sets. A mechanic that doesn't fit becomes Markdown in the description — a new kind is never invented mid-migration.

---

## 2. Technical Details of Predefined Field Types and Rule Contexts

Normative summary. Wire formats, `typeConfig` payloads, and worked JSON examples live in [the-template-system.md §2](docs/new_system/the-template-system.md).

### 2.1 Field type catalog

| Type | Value wire | typeConfig essentials | Rule capability |
|---|---|---|---|
| `int`, `float`, `text`, `textarea`, `markdown`, `dice`, `enum`, `date`, `boolean` | scalar | `int` may `publishAspect` (e.g. `prof_bonus`) | aspect source only |
| `intPouch` | `{current, max}` (e.g. 23/40) | `maxSource: fixed / levelTable / formula / manual` | `refill_pouch` / `empty_pouch` / `set_pouch_max` target |
| `checkboxPouch` | `{count, states[bool]}` (= old `slot`) | `countSource` (same kinds), `style: pips/checkboxes` | refill/empty target; count changeable by level-up/triggers |
| `pouchMatrix` | `{max{row:n}, remaining{row:n}}` (= old `spellSlotGrid`) | `rowKeys`, `maxSource` | `set_pouch_max` target; per-row refill |
| `abilityScoreTable` | per-column ints | `columns[{key,label}]`, `modifierBase` (10), `modifierStep` (2), `publishAspects` | publishes `<col>` / `<col>_mod` aspects; modifier = `floor((score−base)/step)` |
| `combatStatsTable` | canonical keys `hp, max_hp, ac, speed, level, initiative, xp` | `visibleKeys` only — **structure fixed, not creator-editable** | publishes `level`, `ac`, `max_hp` aspects |
| `skillTree` | rows `{name, ability, proficient, expertise, misc}` (= old `proficiencyTable`) | `abilityFieldKey`, `proficiencyBonusAspect`, `rowSeed`, `tiers` | `grant_proficiency` target; one type for saving throws AND skills |
| `relation` (+`isList`, `hasEquip`) | refs (hard uuid / soft slug+name) | unchanged | `grant_refs` target; equipped rows fire `when_equipped` |
| `recordList` | typed rows | `columns[]` (text/int/float/dice/bool/enum/ref), optional `preset` (keeps bespoke renderer) | `choose` / `check_clauses` data source |
| `levelMatrix`, `levelTextTable`, `levelTable` | level-keyed data | — | feeds `set_pouch_max` / display |
| `levelUpTable` | rows `{level, description, grants[], choices[]}` | `gate: class / character` | drives level-up grants + pending choices |
| `actionButton` | — | `action: level_up / short_rest / long_rest`; label = field label (editable), **process fixed** | fires `on_button` rules declared on target pouch fields |
| media (`image`, `imagePerEra`, `file`, `pdf`), `tagList`, `crCalculator` | unchanged | unchanged | none |

### 2.2 Rule contexts

The five card-authoring contexts, plus one internal hook:

| Context | Fires | Legal rule kinds | Output surface |
|---|---|---|---|
| `when_granted` | while source entity attached (stateless fold; ≡ always-on) | modify_stat, grant_refs, grant_proficiency, choose, grant_pouch, set_pouch_max, note | sheet overlay; choices → pending-choice dialog |
| `level_up` | gated fold: applies while `gateLevel ≥ row.level` | levelUpTable grants/choices, modify_stat, grant_pouch, note | level-up dialog + sheet overlay |
| `prereq_to_grant` | at grant/pick time | check_clauses | picker filter (block) / sheet warning (warn-keep) |
| `when_equipped` | while inventory row equipped | modify_stat, grant_refs, grant_proficiency, note | sheet overlay |
| `prereq_to_equip` | at equip time | check_clauses | warning / confirm |
| `on_button` *(internal hook, not a card context)* | rest / level-up button pressed | refill_pouch, empty_pouch | patches pouch values; declared **on the target pouch field**, naming its button |

**Rule kinds (closed set of 8 + escape hatch):** `modify_stat` · `grant_refs` · `grant_proficiency` · `choose` (pick-N, `perPick` nested effects) · `set_pouch_max` · `refill_pouch`/`empty_pouch` · `grant_pouch` · `check_clauses` (warn/block) · **`note`** (visible rule text — the escape hatch).

> **Normative:** these sets are closed. A mechanic that does not fit becomes Markdown in the card description — never a new kind, never a new trigger. Combat/VTT automation (advantage, rerolls, reactions, per-attack predicates) is intentionally out of scope and always converts to description text.

---

## 3. Step-by-Step Phase Planning

Gate for **every** PR: `flutter analyze` clean (project rule: no `flutter test`) + manual smoke of the PC sheet. Vault SOP applies (tracking notes for new files, MoC updates, changelog). Estimates in person-days (pd).

### Phase 1 — UI Cleanup, Copy Infrastructure, Responsive Template Editor Design Rules (~10–13 pd)

| PR | Maps to | Scope | Est. |
|---|---|---|---|
| **1.1** | T1 | **Rules UI off entity cards**: remove `DerivedRulesPanel` mount (`entity_card.dart:534`); delete `derived_rules_panel.dart`, `prereq_warnings_banner.dart`; shrink `spellEffectList` / `grantedModifiers` / `featEffectList` / `autoGrantSources` / `prereqClauses` branches in `field_widget_factory.dart`; delete the rule-row editors in `structured_list_field_widgets.dart`. **Resolver untouched** — data still resolves; only authoring UI dies. | 2d |
| **1.2** | T2 | **Template model v3 (inert)**: `FieldSchema.typeConfig` + `rules[]` (raw maps, lazily validated), `WorldSchema.formatVersion` + `seedRows`, new FieldType enum values, content-hash extension. Nothing consumes them yet. | 2–3d |
| **1.3** | T3 (modified) | **Built-in template → JSON asset** (`assets/templates/dnd5e_srd.template.json`) via one-shot exporter `tool/export_builtin_template.dart`. **RULE RESET: the exporter emits `rules: []` everywhere — zero rule-assigned fields.** `BuiltinTemplateLoader` + call-site swap; debug assert loaded-hash == generator-hash; generator deleted once assert holds. | 2–3d |
| **1.4** | T4 (moved up) | **Template library + Copy**: `templates` Drift table (one JSON blob per row) + `TemplateRepository` + provider; `templates_tab.dart` rebuilt on the `packages_tab.dart` pattern — Load / **Copy** / Rename / Delete; `_copyTemplate()` mirrors `_copyPackage()` (`packages_tab.dart:437`: "(Copy)" suggestion, collision suffix, name dialog, provider invalidate). Copy = **fresh `schemaId`, preserved `originalHash`** (lineage survives for drift detection). Built-in tile: read-only affordances. | 2–3d |
| **1.5** | new | **Responsive editor shell + binding design rules** (below) landed read-only — the layout contract every Phase 2 component plugs into. | 2d |

**Phase 1 gate:** analyze clean; PC sheet identical with rules UI removed; copy → load round-trip; built-in read-only.

#### Phase 1.5 — Responsive Template Editor UI design rules (binding)

- **Desktop (≥1200) = 3-pane.** Fixed 240px category pane (existing inspector/database-sidebar convention) | `ResizableSplit` between field list and field inspector. Nothing selected → inspector shows category metadata editors (name/slug/icon/color).
- **Tablet (600–1199) = 2-pane.** Left master drills category list → field list in place (slide + back chevron); right = field inspector via `ResizableSplit`. Mirrors the database screen's tablet layout.
- **Phone (<600) = stacked navigation** via a nested `Navigator` (system back works): `TemplateCategoriesPage` → `TemplateFieldsPage` → `TemplateFieldEditPage` (full screen — typeConfig forms need keyboard room). Quick actions use modal bottom sheets when `isTouchPlatform`, dialogs otherwise.
- **Reorder:** `ReorderableListView.builder` with drag handles for categories and fields (reuse the `_StructuredListShell` row pattern, `structured_list_field_widgets.dart:25`). Trailing CRUD icons on desktop; no swipe-reveal.
- **Add field:** trailing "+ Add field" row (desktop/tablet) / FAB (phone) → **type picker** (bottom sheet on touch, anchored dialog on desktop): grid of §2.1 types with icons + one-line semantics; rule-capable types badge-marked.
- **typeConfig sub-forms:** one form widget per parametric type, mounted in the inspector (desktop/tablet) or the edit page (phone); row-based configs reuse `_StructuredListShell`.
- **Built-in read-only mode:** all CRUD hidden; persistent banner "Built-in template — make a copy to edit" with inline Copy button → reopens the copy.
- **Save / dirty / hash:** Riverpod `templateDraftProvider` Notifier holds draft + dirty flag. **Explicit Save** (no autosave — hash-churn discipline): validation → `computeWorldSchemaContentHash` recompute → `TemplateRepository.save` → invalidate list. `PopScope` discard dialog when dirty. World drift prompt fires later on campaign open (existing machinery, untouched).
- **Validation surfacing:** inline errors (duplicate `fieldKey`/`slug`, empty label, incomplete typeConfig, reserved keys); Save blocked with an error summary; non-blocking amber warnings (Phase 3: rule referencing missing fieldKey).

**Component inventory** (`flutter_app/lib/presentation/`):

| File | Role |
|---|---|
| `screens/templates/template_editor_screen.dart` | exists — becomes the responsive shell (`getScreenType` dispatch, app bar Save + dirty dot) |
| `screens/templates/widgets/template_category_pane.dart` | category list: reorder/add/select, icon/color chips |
| `screens/templates/widgets/template_field_list_pane.dart` | per-category field list: reorder/add, group headers |
| `screens/templates/widgets/template_field_inspector.dart` | label/key/type/required/visibility + typeConfig form mount |
| `screens/templates/widgets/field_type_picker.dart` | sheet/dialog type picker |
| `screens/templates/widgets/type_config_forms/*.dart` | `ability_score_table_form`, `combat_stats_form`, `pouch_config_form` (shared maxSource editor for intPouch/checkboxPouch/pouchMatrix), `skill_tree_form`, `record_list_columns_form`, `level_up_table_form`, `action_button_form` |
| `screens/templates/widgets/category_edit_sheet.dart` | name/slug/icon/color (sheet on touch, dialog on desktop) |
| `screens/templates/widgets/rule_attachment_editor.dart` | **Phase 3 only**: trigger + kind + params forms |
| `application/providers/template_editor_provider.dart` | draft state, dirty, validation, save |

### Phase 2 — Rule-Free Core Template Infrastructure, Static-Field Preservation, Editor Core Components (~16–20 pd)

| PR | Maps to | Scope | Est. |
|---|---|---|---|
| **2.1** | T5 (part) | **Category CRUD live** on the responsive shell: add/rename/archive/reorder, icon/color, group editor. **Slug-first import matching hardening lands here** — before users can rename categories. | 3–4d |
| **2.2** | T5 (part) | **Field CRUD**: type picker, all typeConfig forms (**NO rule UI**), validation, save/hash/dirty flow; drift prompt verified against an edited copy. | 4–5d |
| **2.3** | T6 | **Parity field types live**: widget renames/parameterization (statBlock→abilityScoreTable, slot→checkboxPouch, spellSlotGrid→pouchMatrix, proficiencyTable→skillTree, recordList presets wrap bespoke list widgets, actionButton calls extracted rest/level-up service). Built-in asset regenerated with new types; death-saves int→states value migration; old types parse as aliases. **STATIC-FIELD PRESERVATION CHECKPOINT**: an explicit audit list of every narrative text/markdown field (description, notes, bio, backstory, benefits, GM notes, appearance, ideals/bonds/flaws, …) per category, asserted present in the v3 asset — committed as a PR checklist. | 4–6d |
| **2.4** | T7 | **`TemplateRuleResolver` shadow** at `lib/domain/services/template_rules/` (resolver, formula evaluator, aspect context, generic `PendingChoiceKind.templateChoice`). Built-in still has zero rules — shadow runs only on dev test copies; debug compare panel. Old engine authoritative everywhere. | 4–5d |

**Phase 2 gate:** analyze; **side-by-side PC-sheet screenshot pass** (phone 360×640, tablet 800×1280, desktop 1440×900); template copy → add category → add every field type → save → create world → entity card renders; static-field checklist green.

### Phase 3 — Built-in Pack Conversion, Markdown Description Completion, JIT Template Evolution (~25–30 pd)

| PR | Scope | Est. |
|---|---|---|
| **3.0** | Converter tooling (per [content-convert.md](docs/new_system/content-convert.md)): `legacy_content_converter.dart` shared lib, `tool/convert_packs_v3.dart` CLI, **Markdown description generator** (one text template per legacy effect kind, ~65), `tool/validate_template.dart`, conversion-report plumbing. | 5d |
| **3.1–3.10** | **JIT category waves** (protocol below), one PR per wave. | 1–3d each |
| **3.5a** | **Rule-attachment editor UI** (`rule_attachment_editor.dart`) — built mid-phase, after Wave 2, once real rule shapes exist to design against. | 3–4d |
| **3.11** | **Authority flip + retirement train** (=T9): per-world authority keyed on embedded `_schema` formatVersion; on-open shim for personal packages + world entities (trash backup first); 19 bundled packs converted via CLI; **old engine deleted in the same release**. | 5–6d |

#### The JIT evolution protocol (centerpiece)

**Wave order** (built-in pack, category by category):

| Wave | Categories | Expected template delta |
|---|---|---|
| 0 | lookups (`ability`, `skill`, `condition`, `damage-type`, `sense`, `language`, …) | none — verify-only; completes seedRows embedding |
| 1 | simple gear (`adventuring-gear`, `tool`, `pack`, `ammunition`, `trinket`, `mount`, `vehicle`, `animal`) | none — pure data + description completion |
| 2 | `armor`, `weapon` | **first rules**: `when_equipped` modify_stat (AC), `prereq_to_equip` check_clauses (Str req); mastery/properties → description |
| 3 | `species`, `subspecies`, `trait` | grant_refs; choose (subspecies preset); species levelUpTable for level-gated traits |
| 4 | `background` | grant_proficiency; ASI choose; equipment choose |
| 5 | `feat` (largest) | asi_options + choose; prerequisites + check_clauses; grant_pouch for resource feats; all combat effects → description |
| 6 | `class`, `subclass` | levelUpTable (**`auto_granted_by` edges inverted into forward grants**); levelMatrix + set_pouch_max; grant_pouch resources; **`planLevelUp` rewired to levelUpTable rows — name heuristics die here** |
| 7 | `spell` | display presets; essentially rule-free; description completion |
| 8 | `magic-item`, `curse`, `poison` | when_equipped stat mods; charge pouches (checkboxPouch + on_button refills); noted combat effects → description |
| 9 | `monster`, `npc`, `creature-action` | display-only (conditionStats preset); description completion |
| 10 | DM narrative (`quest`, `scene`, `location`, `encounter`, `trap`, `hazard`, …) | none — pass-through verification that static fields survived untouched |

**Per-card decision tree:**

```
1. Mechanic fits an EXISTING rule-bearing template field?       → fill the field (most cards after a wave's first few)
2. Existing field, needs a new typeConfig parameter?            → extend typeConfig (backward-compatible param only)
3. Needs a NEW field + rule, within the closed 8 kinds ×
   5 contexts (+on_button)?                                     → add the field to the template NOW (the JIT step)
4. Would need a NEW rule kind or trigger?                       → FORBIDDEN. Mechanic becomes Markdown in description.
5. Pure narrative?                                              → description only.
```

- **Who edits the template:** the developer, by editing `assets/templates/dnd5e_srd.template.json` directly in the wave PR — the built-in stays read-only in the UI, and the JSON diff is reviewable line-by-line. Every wave PR must pass `tool/validate_template.dart` (the same validation the editor UI enforces — JIT dogfoods the editor's validator).
- **Hash/version batching:** **one template version bump + one hash recompute per wave** (3.1.0, 3.2.0, …), never per card. Because the built-in asset ships in the app binary, users see at most **one** drift prompt per app release — waves batch into release trains and `applyTemplateUpdate` runs once against the release's final template.
- **Per-wave review gate:** analyze clean; converter idempotent (re-run = byte-identical); `conversion_report.json` shows `dropped: 0`; every `noted` mechanic visible in the card's description; one representative card opened on a sheet (Wave 6: a leveled PC resolves with identical derived values, old engine vs shadow resolver); **description-completeness lint** — no card with an empty description, no leftover `effects` / `auto_granted_by` / flat-ASI keys.
- **No-dead-fields enforcement:** end-of-phase audit PR runs `tool/audit_template_usage.dart` — for every rule-bearing template field, count cards across srd_core + 19 bundled packs with a non-empty value; **zero-usage fields (and their rules) are removed**; reverse check flags orphan card keys absent from the template. Audit report committed beside the final template.

### Phase 4 — Cleanup, Stabilization, Responsive UI Tests, Integration Tests (~8–10 pd)

| PR | Scope | Est. |
|---|---|---|
| **4.1** | **Legacy deletion sweep**: `rules/` catalog, `rule_compiler.dart`, `bound_rule.dart`, `rule_trigger.dart`, `prereq_evaluator.dart`, `choice_spec.dart`, `character_resolver_legacy.dart`, removed FieldTypes + dead widgets; old-type alias parsers retired after one deprecation release. | 3d |
| **4.2** | **Responsive UI verification matrix** (manual scripted checklist — project forbids `flutter test`): editor + sheet + library across phone portrait/landscape, tablet, desktop; `ResizableSplit` drag persistence; nested-Navigator back behavior on phone; sheet-vs-dialog dispatch touch vs desktop. | 2–3d |
| **4.3** | **Integration passes** (scripted end-to-end manual scenarios + CLI checks): converter idempotency re-run; `validate_template` over all shipped assets; usage-audit re-run; world v2→v3 migration walkthrough incl. trash backup; multiplayer drift-prompt smoke. | 2–3d |
| **4.4** | **Docs/vault sync**: changelog, MoC updates; retire superseded sections of the two detail docs with pointers back to this roadmap. | 1d |

---

## 4. Data Conversion Standards

### 4.1 The Markdown description standard

**Decision — one field.** The card's **`description`** is the single canonical player-facing text. The `rules_text` side-field from content-convert.md is **rescinded**: the converter's per-kind text templates emit sections appended **into `description`**. Where a category historically split prose across `description` + `benefits` (feats), the converter **merges** `benefits` into the Effects section (content-preserving — no text is lost, honoring the static-field rule; the now-redundant `benefits` field is retired by the Phase 3 usage audit).

**Canonical section templates per category** (`###` subheads; card name is the implicit title):

| Category | Sections |
|---|---|
| feat | intro → `### Prerequisites` → `### Effects` (one **bold-led** paragraph per benefit) → `### When You Gain This Feat` (choices/ASI the player will be prompted for) |
| class | intro → `### Hit Points` → `### Proficiencies` → `### Starting Equipment` → `### Level Progression` (prose; the mechanical table is the levelUpTable field) → `### Class Features` (one line each; full text on feature cards) |
| subclass | intro → `### Features by Level` (**Level N — Feature.** paragraphs) |
| species / subspecies | intro → `### Traits` (bold trait names) → `### Choices` (lineage prompts) |
| background | intro → `### Ability Scores` → `### Feat` → `### Proficiencies` → `### Equipment` |
| item (gear/armor/weapon/magic-item) | intro → `### Properties` → `### When Equipped` → `### Attunement` (if any) |
| spell | intro → `### Casting` (**Level.** 3 · **Time.** Action · **Range.** 60 ft …) → `### Effect` → `### At Higher Levels` |
| monster / npc | intro → `### Traits` → `### Actions` |

**Formatting rules:** max heading depth `###`; **bold** for keyed terms (feature names, conditions, actions); `-` bullets for enumerations; **no Markdown tables** (cards render in narrow `MarkdownBody` columns on phones); no HTML; dice plain inline (`2d8`); entity cross-links via the existing `entity:` link scheme / @mentions (`markdown_text_area.dart`); long descriptions render through `expandable_markdown.dart` unchanged.

**Generation pipeline:** one Dart text-template function per legacy effect kind (~65) in `legacy_content_converter.dart`; the wave run assembles sections in the fixed category order from *(old description ⊕ benefits ⊕ rendered effect rows ⊕ prereq clauses ⊕ level-grant rows)*. Idempotent: cards already stamped `"format": 3` are skipped.

**Sync/drift policy:** **template rules + card data fields are the sole source of truth for mechanics; the description is documentation.** It is generated once at conversion and never auto-regenerated — DM hand-edits are user-owned. The per-wave review gate certifies initial text↔mechanics sync; for SRD content, regeneration from Dart sources keeps them in lockstep until pack freeze. After that, a mechanics edit on a card places the burden of updating the prose on the editor — an explicit, accepted trade-off.

### 4.2 Schematic before/after example — Athlete (feat)

**BEFORE** — current card (`builtin/srd_core/feats.dart:500`); mechanics half on the card, half in engine code (`feat_asi_apply`, `rule_compiler.dart:455`):

```json
{
  "slug": "feat", "name": "Athlete",
  "description": "You hone your physique. Climbing and jumping become trivial.",
  "attributes": {
    "category_ref": {"lookup": "feat-category/General"},
    "prereq_min_character_level": 4,
    "prerequisite": "Level 4+",
    "repeatable": false,
    "asi_amount": 1, "asi_max_score": 20,
    "asi_ability_options": ["Strength", "Dexterity"],
    "benefits": "**Ability Score Increase.** Increase your Strength or Dexterity… **Climbing.** …"
  }
}
```

**AFTER** — pure data + complete description; zero rule rows on the card:

```json
{
  "slug": "feat", "name": "Athlete", "format": 3,
  "description": "You hone your physique. Climbing and jumping become trivial.\n\n### Prerequisites\n- Character level 4+\n\n### Effects\n**Climbing.** Climbing doesn't cost you extra movement.\n\n**Jumping.** You can make a running long jump or high jump after moving only 5 feet.\n\n**Standing Up.** Standing up from Prone uses only 5 feet of movement.\n\n### When You Gain This Feat\n**Ability Score Increase.** Choose Strength or Dexterity and increase it by 1 (max 20).",
  "attributes": {
    "category_ref": {"ref": "<feat-category-general-uuid>"},
    "asi_options": [
      {"ability": "<str-uuid>", "amount": 1},
      {"ability": "<dex-uuid>", "amount": 1}
    ],
    "prerequisites": [{"kind": "min_character_level", "value": 4}]
  }
}
```

**TEMPLATE SIDE** — the feat category's two rule-bearing fields that make it work (full JSON in [the-template-system.md §2.4](docs/new_system/the-template-system.md)):

- `asi_options` — `recordList` (ability ref + amount columns) with rule `{trigger: when_granted, kind: choose, pick: 1, perPick: [modify_stat ability:{row.ability} +{row.amount}]}`.
- `prerequisites` — `recordList` preset `prereq-clauses` with rule `{trigger: prereq_to_grant, kind: check_clauses, policy: warn}`.

The player's pick persists on the PC card as `rule_choices["<athleteId>:asi_options:feat-asi"]` — the modern replacement for `feat_asi_choices`.

```
mechanics  ──────────→ template field rules (asi_options.choose, prerequisites.check_clauses)
player picks ────────→ PC card data (rule_choices)
everything else ─────→ description Markdown (the player-readable contract)
```

---

## Appendix A — Old roadmap (PR-T1..T9) → new phase mapping

| Old | New | Note |
|---|---|---|
| T1 | PR-1.1 | unchanged |
| T2 | PR-1.2 | unchanged |
| T3 | PR-1.3 | **modified**: exporter emits zero rules (rule reset) |
| T4 | PR-1.4 | **moved to Phase 1** (copy infrastructure up front) |
| T5 | PR-1.5 + 2.1 + 2.2 | editor split: shell/design rules (Phase 1), components (Phase 2) |
| T6 | PR-2.3 | + static-field preservation checklist |
| T7 | PR-2.4 | shadow has no built-in rules until Phase 3 |
| T8 | **dead** | bulk-ruleset drop replaced by JIT waves 3.1–3.10 + mid-phase rule editor 3.5a |
| T9 | PR-3.0 + 3.11 | converter tooling pulled to Phase 3 start; flip/retirement at Phase 3 end |
| — | Phase 4 | new stabilization phase |

## Appendix B — Schedule summary

| Phase | Estimate |
|---|---|
| Phase 1 — UI cleanup, copy infra, editor design rules | ~10–13 pd |
| Phase 2 — rule-free infra, static preservation, editor components | ~16–20 pd |
| Phase 3 — conversion, Markdown completion, JIT evolution | ~25–30 pd |
| Phase 4 — cleanup, stabilization, responsive + integration tests | ~8–10 pd |
| **Total** | **~60–73 person-days** |

JIT waves are parallelizable two-at-a-time once Wave 2 has stabilized the protocol. Release trains batch waves so users see at most one template drift prompt per app release.
