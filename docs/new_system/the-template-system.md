# The Template System

> Design + roadmap for moving the rules system off entity cards and into user-editable templates.
> Status: DESIGN (2026-06-10). Companion doc: [content-convert.md](content-convert.md).

---

## 1. Core model shift

**Today.** The schema (74 hardcoded categories in `builtin_dnd5e_v2_schema.dart`) defines *shape*; rules live as DSL rows **on entity cards** (`rule_effects`, `effects`, `granted_modifiers`, `prereq_clauses`, `auto_granted_by`) and are compiled per-card by `RuleCompiler` into `BoundRule`s, executed by `character_resolver.dart` (~67 effect kinds).

**Target.** A **Template** is a user-editable JSON document = categories + fields, where **each field can carry rule attachments**. Entity cards become pure data — the DM fills values into template-defined fields; rules fire from field *semantics* declared once in the template.

Example: the template's `feat` category declares an `asi_options` list field with a `when_granted` choose-one rule. Each feat card just lists its options (`STR +1`, `DEX +1`). The PC who gains the feat gets a picker. The creator never touches a rule editor on the card; the card has no rule schema at all.

**Locked decisions (2026-06-10):**

1. The trigger rules engine (commit `8abc9a7`: `RuleCompiler`/`BoundRule`/8 triggers) is **fully replaced**. Combat/VTT-side rule automation is **removed entirely**. Trigger contexts sufficient for now: `level_up` (per level), `when_granted`, `prereq_to_grant`, `when_equipped`, `prereq_to_equip` — plus `on_button` (rest/level-up hooks; non-VTT, needed so pouches can name their refill button).
2. **Hub-level template library** — like the packages tab: list, copy built-in, edit. The built-in SRD template stays, read-only.
3. **Rule-DSL fields are stripped from the schema too** → all content converts (SRD core, 19 bundled packs, personal packages, world entities). See [content-convert.md](content-convert.md).
4. The UI stays **pixel-identical**. Only the hardcoded template machinery underneath changes.

**Key architectural decision: `WorldSchema` evolves in place into the Template (formatVersion 3)** — it is not replaced. It is already JSON-serializable freezed, already has dual-hash lineage (`originalHash` + `computeWorldSchemaContentHash` in `world_schema_hash.dart`), already binds to worlds (`templateId`/`templateHash`/`templateOriginalHash`), already embeds in packages (`package_schemas.categoriesJson`), and already has drift detection (`campaign_provider.applyTemplateUpdate`). Replacing it would churn every one of those surfaces for zero benefit.

**Second key decision: new field types reuse the old value wire-shapes verbatim** wherever a 1:1 ancestor exists (`checkboxPouch` value = `slot`'s `{count, states[]}`; `pouchMatrix` value = `spellSlotGrid`'s `{max:{}, remaining:{}}`; `skillTree` rows = `proficiencyTable` rows). This makes the 20k-card value migration near-zero and is the single biggest de-risking move in the whole plan.

---

## 2. Template JSON format (formatVersion 3)

A template is one JSON document. The built-in ships as `flutter_app/assets/templates/dnd5e_srd.template.json`. User copies live as rows in a new `templates` Drift table (one JSON blob per row).

### 2.1 Top level

```json
{
  "formatVersion": 3,
  "schemaId": "builtin-dnd5e-default-v3",
  "name": "D&D 5e (Default)",
  "version": "3.0.0",
  "baseSystem": "dnd5e",
  "description": "SRD 5.2.1 built-in template",
  "originalHash": "<sha256, frozen at creation — existing dual-hash semantics unchanged>",
  "createdAt": "...",
  "updatedAt": "...",
  "categories": [ ... ],
  "encounterConfig": { ... },
  "encounterLayouts": [ ... ],
  "seedRows": {
    "ability":   [{"name": "Strength", "abbr": "STR"}, ...],
    "skill":     [{"name": "Acrobatics", "ability_ref": "Dexterity"}, ...],
    "condition": [ ... ],
    "damage-type": [ ... ]
  },
  "metadata": { ... }
}
```

- **`seedRows` move INTO the template.** Lookup rows (abilities, skills, conditions, …) are not world content — they are what the system needs to function. A custom template with different abilities needs different lookup rows. They currently live beside the schema in `lookups.dart`; embedding them makes a template self-contained. `srd_core_package_bootstrap.dart` and the world-create flow read them from the loaded template instead of from `generateBuiltinDnd5eV2Schema().seedRows`.
- **Hashing:** `computeWorldSchemaContentHash` extends its relevant-field map with `seedRows` and the new per-field keys (they ride inside `categories` already). Dual-hash lineage is reused as-is — no new mechanism.
- **Category shape is unchanged:** `categoryId, name, slug, icon, color, isBuiltin, isArchived, orderIndex, fields[], allowedInSections, filterFieldKeys, fieldGroups`. `slug` remains the stable matching key (import matching becomes slug-first, §6 PR-T5).

### 2.2 Field

Existing `FieldSchema` keys survive. Two new keys:

```json
{
  "fieldId": "...",
  "fieldKey": "rage_uses",
  "label": "Rage",
  "fieldType": "intPouch",
  "typeConfig": { ... },
  "rules": [ ... ],
  "groupId": "...", "gridColumnSpan": 1, "visibility": "shared"
}
```

- **`typeConfig`** — per-type parametric payload (replaces ad-hoc `subFields`/`defaultValue` tricks).
- **`rules`** — rule attachments (§4). Absent/empty on most fields.

### 2.3 `typeConfig` payloads per new type

#### `abilityScoreTable` (parameterized `statBlock`)

```json
{
  "columns": [
    {"key": "str", "label": "STR"}, {"key": "dex", "label": "DEX"},
    {"key": "con", "label": "CON"}, {"key": "int", "label": "INT"},
    {"key": "wis", "label": "WIS"}, {"key": "cha", "label": "CHA"}
  ],
  "modifierBase": 10,
  "modifierStep": 2,
  "publishAspects": true
}
```

Modifier = `floor((score − modifierBase) / modifierStep)`. The built-in config reproduces today's hardcoded `(score−10)/2` exactly. Creators can change the columns, the base, and the step; the system and UI stay the same. With `publishAspects`, each column exports `<key>` and `<key>_mod` as **aspects** (§4.3) referencable by any other field's formula.

#### `combatStatsTable` (fixed semantics — NOT creator-editable structure, by decision)

Canonical key set: `hp, max_hp, ac, speed, level, initiative, xp`.

```json
{"visibleKeys": ["hp", "max_hp", "ac", "initiative", "level"]}
```

The built-in shows exactly today's five (speed/xp render elsewhere today; `xp` stays a separate integer field for pixel parity). The hp/max_hp lock-edit, the `extra_hp` signed-delta atomic patch (`onPatchFields`), the ac/level read-only-when-resolver-derived overrides, and the armor-notes banner all stay **in the widget**, unchanged. Publishes aspects `level`, `ac`, `max_hp`.

#### `intPouch` (current/max pair: "23/40")

```json
{
  "maxSource": {"kind": "manual"}
}
```

`maxSource` kinds:
- `{"kind": "fixed", "value": 4}`
- `{"kind": "levelTable", "table": {"1": 2, "3": 3, "6": 4}, "levelAspect": "class_level"}`
- `{"kind": "formula", "expr": "prof_bonus + cha_mod"}`
- `{"kind": "manual"}` — DM types the max on the card (default)

Value wire: `{"current": 23, "max": 40}`.

#### `checkboxPouch` (N pips: death saves, hit dice, charges)

```json
{
  "countSource": {"kind": "fixed", "value": 3},
  "style": "pips"
}
```

`countSource` kinds = same as `intPouch.maxSource`. Value wire: `{"count": 3, "states": [true, false, false]}` — **byte-identical to today's `slot` value**, so existing hit-dice/charges values load unchanged. Count can be changed by the level-up system or other triggers; buttons can fill/empty it via rules declared on this field (§4.2).

#### `pouchMatrix` (generalized `spellSlotGrid`)

```json
{
  "rowKeys": ["1","2","3","4","5","6","7","8","9"],
  "rowLabelPrefix": "Level ",
  "maxSource": {"kind": "manual"}
}
```

Value wire: `{"max": {"1": 4, "2": 2}, "remaining": {"1": 3, "2": 2}}` — identical to `spellSlotGrid` today. Decision: **subsume, don't keep a D&D-specific type** — this removes the last D&D-specific structured type from the engine while keeping `_SpellSlotGridFieldWidget` as the renderer (renamed, parameterized by `rowKeys`); refill semantics unify with all pouches. In the built-in, maxima are set by a `set_pouch_max` rule fed from class cards (§4.2).

#### `skillTree` (unifies saving throws + skills)

```json
{
  "abilityFieldKey": "stat_block",
  "proficiencyBonusAspect": "prof_bonus",
  "rowSeed": "skill",
  "tiers": ["proficient", "expertise"]
}
```

Row wire: `{"name", "ability", "proficient", "expertise", "misc"}` — identical to today's `proficiencyTable`. Bonus = `ability_mod + prof_bonus × tiers_checked + misc`. The built-in declares two skillTree fields: `saving_throws` (rowSeed `ability`, single tier) and `skills` (rowSeed `skill`, both tiers) — one field type, same idea, as required.

#### `actionButton` (level-up / short rest / long rest)

```json
{"action": "level_up", "placement": "header"}
```

`action` ∈ `level_up | short_rest | long_rest`. The button **label** is the FieldSchema `label` (creator-editable); the **process is fixed**. The widget invokes the existing flows (`planLevelUp`, the rest handlers from `character_editor_screen.dart:2598+`, extracted into a service). What a button *does to a pouch* is declared **on the target pouch field** (`refill_pouch`/`empty_pouch` rules naming the button), not on the button — per requirement.

#### `levelUpTable` (the level-up table system)

Declared on `class` (and `species` for level-gated traits):

```json
{"gate": "class"}
```

`gate` ∈ `class` (owning class's level) | `character`. Row wire (card data, filled by the DM):

```json
{
  "level": 3,
  "description": "Primal Knowledge",
  "grants": [{"ref": "<entity-uuid>", "target": "trait_refs"}],
  "choices": [{
    "choiceId": "barb3-primal-path",
    "prompt": "Choose your Primal Path",
    "pick": 1,
    "optionRefs": ["<uuid>", "..."],
    "target": "subclass_refs"
  }]
}
```

Replaces both the narrative `classFeatures` table (its `description` column survives 1:1) and the *inverse* `auto_granted_by` edge (conversion inverts those edges into forward `grants` rows).

#### `recordList` (generic typed table)

```json
{
  "columns": [
    {"key": "sense_ref", "label": "Sense", "kind": "ref", "allowedTypes": ["sense"]},
    {"key": "range_ft", "label": "Range (ft)", "kind": "int"}
  ],
  "preset": "ranged-senses"
}
```

Column kinds: `text | int | float | dice | bool | enum | ref`. The optional `preset` selects today's bespoke renderer (`spell-effects`, `equipment-choices`, `subspecies-options`, `ranged-senses`, `prereq-clauses`) so those lists keep rendering byte-identically while the data model becomes generic.

### 2.4 Worked examples

**Feat ASI-choice field** (template's `feat` category):

```json
{
  "fieldKey": "asi_options", "label": "Ability Score Increase", "fieldType": "recordList",
  "typeConfig": {"columns": [
    {"key": "ability", "label": "Ability", "kind": "ref", "allowedTypes": ["ability"]},
    {"key": "amount", "label": "+", "kind": "int"}
  ]},
  "rules": [{
    "ruleId": "feat-asi", "trigger": "when_granted", "kind": "choose",
    "params": {
      "optionsFrom": "rows", "pick": 1, "prompt": "Choose an ability to increase",
      "perPick": [{"kind": "modify_stat", "target": "ability:{row.ability}", "value": "{row.amount}"}]
    }
  }]
}
```

Card data (Athlete feat): `"asi_options": [{"ability": "<str-uuid>", "amount": 1}, {"ability": "<dex-uuid>", "amount": 1}]`. Granting the feat surfaces a picker; the recorded pick persists on the PC under `rule_choices` (§4.4).

**Spell slots refilled by long rest** (PC category):

```json
{
  "fieldKey": "spell_slots", "label": "Spell Slots", "fieldType": "pouchMatrix",
  "typeConfig": {"rowKeys": ["1","2","3","4","5","6","7","8","9"], "maxSource": {"kind": "manual"}},
  "rules": [
    {"ruleId": "slots-refill", "trigger": "on_button", "kind": "refill_pouch",
     "params": {"button": "long_rest", "amount": "all"}}
  ]
}
```

Maxima flow from class cards' slot-progression field via a `set_pouch_max` rule on the class category.

**Barbarian rage pouch** (data-driven class resources on the `class` category):

```json
{
  "fieldKey": "resources", "label": "Class Resources", "fieldType": "recordList",
  "typeConfig": {"columns": [
    {"key": "name", "label": "Resource", "kind": "text"},
    {"key": "max_by_level", "label": "Uses per level", "kind": "text"},
    {"key": "refill_on", "label": "Refills on", "kind": "enum", "options": ["short_rest", "long_rest", "level_up"]}
  ]},
  "rules": [{
    "ruleId": "class-resource-pouch", "trigger": "when_granted", "kind": "grant_pouch",
    "params": {"nameCol": "name", "maxTableCol": "max_by_level", "refillCol": "refill_on", "gate": "class"}
  }]
}
```

Barbarian card data: `"resources": [{"name": "Rage", "max_by_level": "1:2,3:3,6:4,12:5,17:6", "refill_on": "long_rest"}]`. The PC sheet renders a "Rage 2/2" intPouch in the Class Resources group; current values persist on the PC under `granted_pouches: {"<classId>:Rage": {"current": 1}}`. Replaces today's `resource_pool_grant` effect kind.

---

## 3. Field type catalog mapping

| Old FieldType | New | Notes |
|---|---|---|
| text, textarea, markdown, integer, float, boolean, enum, date, dice | **keep** | unchanged |
| image, imagePerEra, file, pdf | **keep** | unchanged |
| relation (+isList/hasEquip/showSourceFilter), tagList | **keep** | hasEquip stays the equip/prepared toggle |
| statBlock | **abilityScoreTable** | parametric columns/base/step; built-in config = today exactly |
| combatStats | **combatStatsTable** | fixed semantics, `visibleKeys` config; widget behaviors unchanged |
| conditionStats | **keep** (combatStatsTable preset) | NPC/monster display only |
| slot | **checkboxPouch** | identical value wire |
| spellSlotGrid | **pouchMatrix** | identical value wire; D&D-specific seeding becomes a rule |
| proficiencyTable | **skillTree** | identical row wire; saves + skills + any custom table |
| levelTable, levelTextTable | **keep** | pure data |
| spellSlotProgression | **levelMatrix** (rename) | `Map<level, Map<key,int>>` generic data; feeds `set_pouch_max` |
| classFeatures | **levelUpTable** | description column survives; grants/choices columns added |
| equipmentChoiceGroups | **recordList** preset `equipment-choices` + `choose` rule | |
| spellEffectList | **recordList** preset `spell-effects` | display-only data; combat semantics dropped (no VTT automation) |
| rangedSenseList | **recordList** preset `ranged-senses` | |
| subspeciesOptions | **recordList** preset `subspecies-options` + `choose` rule | per-row grant columns mapped by the rule's `perPick` |
| crCalculator | **keep** | pure UI calculator, no rule semantics |
| prereqClauses | **recordList** preset `prereq-clauses` + `check_clauses` rule | clause vocabulary survives as *data* read by one rule kind |
| grantedModifiers | **REMOVED** | legacy DSL; converted (see content-convert.md) |
| featEffectList (`rule_effects`/`effects`) | **REMOVED** | converted |
| autoGrantSources (`auto_granted_by`) | **REMOVED** | inverted into class/species levelUpTable `grants` rows |
| — | **intPouch** (new) | charges, rage, ki, granted pouches |
| — | **actionButton** (new) | level_up / short_rest / long_rest |

### PC-sheet pixel-parity walkthrough

Every new type keeps its old renderer:

- `stat_block` → abilityScoreTable — same `_StatBlockFieldWidget`, now config-driven.
- `combat_stats` → combatStatsTable — same widget incl. extra_hp delta + lock-edit + derived overrides.
- `death_saves_successes`/`death_saves_failures` + `heroic_inspiration` → checkboxPouch count=3 — today these are integers special-rendered as 3 pips; conversion maps int *n* → states with *n* true. Visually identical.
- `saving_throws`/`skills` → skillTree — same `_ProficiencyTableFieldWidget`.
- `spell_slots` → pouchMatrix — same pip widget.
- `hit_dice_remaining` → checkboxPouch (was `slot`) — same widget.
- `spells_known` / inventory → relation + hasEquip, unchanged.
- Level-up / rest buttons → actionButton fields rendered in the same header slots; existing flows invoked.
- Class resources → granted pouches rendered in the same group.

No visual delta anywhere. PR-T6's gate includes a side-by-side screenshot pass.

---

## 4. New rules runtime — `TemplateRuleResolver`

Replaces `RuleCompiler` + `BoundRule` + `applyBound`/`applyEffect` (~67 kinds) + the `rules/` catalog. Lives at `flutter_app/lib/domain/services/template_rules/`.

### 4.1 Triggers (closed set of 6 wire values)

`when_granted` · `level_up` · `prereq_to_grant` · `when_equipped` · `prereq_to_equip` · `on_button`

- `when_granted` ≡ always-on at fold time. The resolver is a stateless re-derive — same invariant as the old engine; documented here to prevent stateful-semantics creep.
- `level_up` rules are *gated folds*: rows/values apply while `gateLevel >= row.level`; the level-up button merely raises the level and re-prompts pending choices. No event log.
- `on_button` exists so pouch fields can name which button refills/empties them.
- `when_attuned` / `prereq_to_attune` are **dropped** (were inert anyway).

### 4.2 Rule kinds (closed set of 8 + escape hatch — replaces 67)

| kind | params | semantics |
|---|---|---|
| `modify_stat` | target aspect path; value (field value / fixed / formula) | adds to ability score, ac, speed, max_hp, initiative, passive_x, pouch max |
| `grant_refs` | target PC list-field key; refs from field value | traits, languages, resistances, spells, actions |
| `grant_proficiency` | target skillTree fieldKey, tier, rows from field refs | sets proficient/expertise on matching rows |
| `choose` | optionsFrom (rows/refs), pick N, prompt, `perPick` nested effects, target | ASI picks, subspecies, equipment groups, expertise, fighting style |
| `set_pouch_max` | target pouch/pouchMatrix fieldKey; source (levelTable/levelMatrix field or formula) | spell-slot maxima from class cards; aggregates across multiclass |
| `refill_pouch` / `empty_pouch` | button (`long_rest`/`short_rest`/`level_up`), amount (`all`/`half_max_round_up`/formula) | declared **on the target pouch field**; button walks pouch fields and fires matching rules |
| `grant_pouch` | name/max-table/refill columns, gate | data-driven resource pouches (Rage, Ki, Channel Divinity) |
| `check_clauses` | clauses from field rows; policy `warn` (default) / `block` | prereq triggers; pickers filter (block), sheet warn-keeps (warn) — same policy split as today |
| `note` | text template (may interpolate field values) | **escape hatch**: non-automated rule text surfaced on the card; conversion target for all combat/VTT kinds |

Explicit non-goals (by decision): no combat/VTT automation — no advantage/reroll/reaction/opportunity-attack kinds, no per-attack predicates, no activation tracking beyond pouches. All such content converts to `note`.

### 4.3 Aspects

The **aspect context** is built from the PC card's own fields:

- Each `abilityScoreTable` with `publishAspects` exports `<col>` and `<col>_mod`.
- `combatStatsTable` exports `level`, `ac`, `max_hp`.
- Plain integer fields may opt in via `typeConfig.publishAspect: "prof_bonus"`.
- Computed: `class_level(<slug>)` from `class_levels`.

**Formula grammar** (tiny evaluator, ~150 lines, `template_rules/formula_evaluator.dart`): identifiers = aspect names, integer literals, `+ - * /`, `floor() ceil() min() max()`, `table(expr, "1:2,3:3,...")`, parentheses. Sufficient for unarmored AC (`10 + dex_mod + con_mod`), pact slots, pool sizes. No conditionals in v1 — anything needing predicates becomes a `note`.

### 4.4 Resolution flow

1. Build aspect context from the PC card.
2. **Gather attachments** exactly like today's pass skeleton: classes (+levels), subclasses, species/subspecies, background, feats, granted traits, equipped inventory rows (`when_equipped`), and transitively granted entities from levelUpTable `grants`.
3. **Fold**: per attachment, per category field carrying rules whose trigger is active, evaluate against the card's field value. levelUpTable rows gate on level. Deterministic order: category orderIndex → field orderIndex → rule index.
4. **Choices**: a `choose` rule with no recorded selection emits a pending choice. **Reuses the existing machinery**: one new generic `PendingChoiceKind.templateChoice` in `pending_choices.dart` carrying `{sourceEntityId, fieldKey, ruleId, prompt, pick, options}`; `pending_choice_resolver_dialog.dart` renders it with the existing list-picker UI. Selections persist on the PC card as data: `rule_choices: {"<sourceEntityId>:<fieldKey>:<ruleId>": ["<picked>", ...]}` — same pattern as today's `feat_asi_choices`.
5. **Output**: an `EffectiveCharacter`-equivalent (derived stat overlay + warnings + notes). `check_clauses` failures → typed warnings rendered where the prereq banner content appears today (re-introduced as part of the new runtime, not the old panel).
6. **Buttons are imperative, not folds**: `level_up` runs `planLevelUp` (rewired to read levelUpTable rows — the `isSubclassLevel`/`isDivineOrderLevel` name heuristics die), applies grants, queues choices, fires `refill_pouch(button: level_up)` rules; rests walk every pouch field on the sheet, fire matching refill/empty rules, then patch card values via the existing `onPatchFields` path.

---

## 5. Template library architecture

### 5.1 Storage

New Drift table `templates` (`lib/data/database/tables/templates_table.dart`):

```
id TEXT PK · name TEXT · dataJson TEXT (full template JSON) ·
originalHash TEXT · currentHash TEXT · createdAt / updatedAt
```

One blob column, not normalized rows — a template is a single document edited as a unit; mirrors how the schema already rides as one JSON in `world_settings.settings_json['_schema']` and `package_schemas.categoriesJson`. New `TemplateRepository` (list/load/save/copy/delete/rename) mirroring `PackageRepository`'s API shape.

**The built-in template is an asset, not a row**: `assets/templates/dnd5e_srd.template.json`, loaded by a cached `BuiltinTemplateLoader`. `allTemplatesProvider` = `[builtin] + tableRows`. The asset replaces `generateBuiltinDnd5eV2Schema()` at its call sites (template provider, `srd_core_package_bootstrap`, world-create flow, `_overlayMissingBuiltinCategories` in `world_repository_impl.dart`). Tier-0 seed rows live in the asset's `seedRows`; Tier-1/2 *content rows* stay where they are — in the SRD Core package (regenerated as a converted pack).

### 5.2 Hub UI

- `hub/templates_tab.dart` (exists, read-only browser) upgrades to a library — mirror `packages_tab.dart` exactly: list tiles (built-in first, distinct icon, delete/rename disabled), buttons Load / **Copy** / Delete. `_copyTemplate()` mirrors `_copyPackage()` (`packages_tab.dart:437`): suggest `"D&D 5e (Copy)"`, collision suffix `(Copy 2)`, name dialog, `templateRepository.copy(src, dst)`, invalidate provider.
- **Copy semantics: fresh `schemaId`, preserved `originalHash`** — lineage survives so world drift-detection keeps working; worlds bind by `templateId` first, `originalHash` fallback (existing lookup order).
- `hub/template_editor.dart` (exists, inspector) upgrades to a real editor for non-builtin templates: category pane (add/rename/archive/reorder, icon/color), field pane (add/edit/delete/reorder; type picker limited to the §3 catalog; typeConfig forms per type), group editor. **Rule-attachment UI ships in Phase C only** — the editor first ships without rule editing, per the agreed phasing.

### 5.3 World/package binding and sync

Unchanged by design. A world snapshots its template into `world_settings.settings_json['_schema']` at creation (now `loadedTemplate.toJson()` instead of generator output) and stores `templateId/templateHash/templateOriginalHash` flat on `worlds`. Library edits do NOT auto-propagate; campaign-open drift detection compares hashes and prompts `applyTemplateUpdate` — the lookup source extends from "the one builtin" to builtin + `templates` table.

**Multiplayer**: nothing new syncs — the embedded `_schema` already rides the existing `world_settings` CDC row and `template_hash` already rides `worlds`. The library itself is local-first (cloud backup of templates is a later, separate concern).

### 5.4 Existing-world migration

On world open, if the embedded `_schema` lacks `formatVersion: 3`: offer the standard template-update prompt against the v3 built-in (lineage matches via `originalHash`). `applyTemplateUpdate` runs, followed by a one-shot **value-shape migration** over world + package entities (death-save ints → pouch states; everything else is wire-identical per §3). `_overlayMissingBuiltinCategories` keeps overlaying by slug from the loaded v3 built-in.

---

## 6. Roadmap

Gate for every PR: `flutter analyze` clean (NO `flutter test`, per project rule) + manual smoke of the PC sheet. Vault SOP applies per PR (tracking notes for new files, MoC updates, changelog).

### Phase A — rules UI off the cards (user step a)

**PR-T1 — Remove rules UI from entity cards.**
- Remove `DerivedRulesPanel` mount (`entity_card.dart:534`); delete `derived_rules_panel.dart`, `prereq_warnings_banner.dart`.
- `field_widget_factory.dart`: branches for `spellEffectList` (~L379), `grantedModifiers` (~L395), `featEffectList` (~L426), `autoGrantSources` (~L435), `prereqClauses` (~L443) → `SizedBox.shrink()`.
- `structured_list_field_widgets.dart`: delete `FeatEffectListFieldWidget`, `_PredicateEditor`, `PrereqClausesFieldWidget`, `GrantedModifiersFieldWidget`, `SpellEffectListFieldWidget`, trigger dropdowns.
- **Resolver untouched** — the data fields still exist and still resolve; only authoring/display UI dies. Existing PCs unaffected.

### Phase B — template system, no rule editing (user step b)

**PR-T2 — Template model v3 (inert).** `FieldSchema` gains `typeConfig: Map<String,dynamic>?` and `rules: List<Map<String,dynamic>>` (raw maps, validated lazily — avoids a freezed explosion); `WorldSchema` gains `formatVersion` + `seedRows`; new FieldType enum values (abilityScoreTable, combatStatsTable, intPouch, checkboxPouch, pouchMatrix, skillTree, recordList, levelMatrix, levelUpTable, actionButton); hash function extended. Nothing consumes them yet.

**PR-T3 — Built-in template extraction.** One-shot exporter `tool/export_builtin_template.dart` serializes `generateBuiltinDnd5eV2Schema()` → v3 JSON asset (old types still in place; the type swap is T6). `BuiltinTemplateLoader` + call-site swap. Debug assert: loaded-asset content hash == generator hash; generator deleted at the end of this PR once the assert holds.

**PR-T4 — Template library.** `templates` Drift table + migration, `TemplateRepository` + impl, `templateListProvider`; `templates_tab.dart` rebuilt on the packages_tab pattern with `_copyTemplate`; builtin read-only affordances.

**PR-T5 — Template editor (no rules).** `template_editor.dart` editable for copies: category CRUD, field CRUD with typeConfig forms, groups. Save recomputes `currentHash`; drift prompt verified against an edited copy. **Import matching hardened: slug-first, name fallback** (fixes rename fragility in `package_payload_importer` + compatibility checks — must land before users can rename categories).

### Phase C — new types live, new runtime, rule editing, conversion (user step c)

**PR-T6 — Parity field types live.** Widgets renamed/parameterized (statBlock → abilityScoreTable, slot → checkboxPouch, spellSlotGrid → pouchMatrix, proficiencyTable → skillTree, recordList presets wrap the bespoke list widgets, actionButton renders and calls the extracted rest/level-up service). Built-in asset regenerated with new types for the PC category; death saves/heroic inspiration become checkboxPouch. World-open value migration (death-save ints → states). Old FieldTypes still parse as aliases so unconverted worlds render. **Gate adds: side-by-side screenshot pass of the PC sheet.**

**PR-T7 — TemplateRuleResolver (shadow).** `lib/domain/services/template_rules/` (resolver, formula evaluator, aspect context, choice integration via `PendingChoiceKind.templateChoice`). Runs only for fields carrying `rules` (none in built-in yet); debug panel compares old/new outputs on demand. Old engine remains authoritative.

**PR-T8 — Rules into the template + editor UI.** Built-in asset gains the full SRD ruleset as field rules (pouch refill rules, class levelUpTable semantics, feat asi_options + prereq fields, equipment choice rules, subspecies choose rule, slot-max rules). Template editor gains the rule-attachment UI (trigger + kind + params + choice forms). `planLevelUp` rewired to levelUpTable rows. **Authority flip is per-world**: worlds whose embedded `_schema` is v3-with-rules resolve via TemplateRuleResolver; v2 worlds stay on the old engine. This is the continuity mechanism — no world is ever mid-stripped.

**PR-T9 — Content conversion + engine retirement (one release train).** Run the converter (see content-convert.md) over srd_core (regenerated from Dart sources) and the 19 `assets/open5e_packs/*.pkg.json`; in-app shim converts personal packages + world entities on open. Once all bundled content is v3: delete the `rules/` catalog, `rule_compiler`/`bound_rule`/`rule_trigger`/`prereq_evaluator`/`choice_spec`, `character_resolver_legacy.dart`, old resolver effect passes (resolver becomes a thin shell over TemplateRuleResolver), removed FieldTypes and dead widgets. **Sequencing rule: content stripping and engine retirement land in the same release** — between T8 and T9 the per-world dual stack carries all states.

Dependency graph: `T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9` (T4/T5 can overlap T6 prep; T7 parallel to T5/T6 once T2 lands).

---

## 7. Risk register

| Risk | Mitigation |
|---|---|
| 20k-card conversion | Wire-shape-preserving types (§3); idempotent shared converter; per-pack `conversion_report.json`; trash-backup before in-place conversion |
| Sheet pixel-parity | Every new type keeps its old renderer; T6 screenshot gate; combatStatsTable behaviors live in the widget, untouched |
| Character resolution continuity | Per-world dual-stack authority keyed on embedded schema `formatVersion`; content strip + engine retirement ship in the same release; v2 worlds keep the frozen old engine until migrated |
| Template drift/update machinery | Dual-hash + `applyTemplateUpdate` reused verbatim; copies preserve `originalHash` lineage |
| Multiplayer sync | No new sync surface; embedded `_schema` rides existing `world_settings` CDC |
| Import matching fragility (renamed categories) | Slug-first matching lands in PR-T5, before users can rename |
| Lossy bespoke mechanics | Nothing deleted silently: every unmappable rule row becomes visible `note` rules text on the card (explicit product decision — no VTT automation) |
