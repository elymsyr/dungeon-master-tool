# 50 — Typed UI Migration (Phase D Master Plan)

> **For Claude.** End-to-end plan for removing the generic schema-driven UI and replacing it with a typed, D&D-5e-native UI while **preserving every existing screen layout**. This is the work that finally closes Phase A's structural goal (delete `lib/domain/entities/schema/`) and opens Phase D (typed UI).
> **Status:** 🟡 Batches 1-7 landed (additive); Batch 8 blocked on legacy-consumer sweep.
> **Last updated:** 2026-04-20

## Implementation Status

| Batch | Scope | Status |
|---|---|---|
| 1 | `Dnd5eContentDao` + typed providers + 5 cards + dispatcher + DatabaseScreen wiring | 🟢 Done |
| 2 | Npc / Player / Class / Race / Action cards | 🟢 Done |
| 3 | Location / Quest / Lore / Plane / Condition / StatusEffect cards | 🟢 Done |
| 4 | `combinedEntitySummaryProvider` merging generic + typed rows; `EntitySidebar` swapped onto merged provider | 🟢 Done |
| 5 | `entitySummaryByIdProvider` fallback in `mind_map_node_widget._buildEntityContent` + `battle_map_screen._categoryColor`; SessionScreen `WorldSchema` decoupling deferred (condition stat fields still schema-driven) | 🟡 Partial |
| 6 | `Dnd5eCharacterSheetView` read-only 3-tab scaffold at `lib/presentation/screens/dnd5e/character/`; legacy `CharacterEditorScreen` still the router target | 🟡 Scaffold only |
| 7 | `homebrew_entries` Drift table + v10 additive migration + DAO + `homebrewEntryRowProvider` + `HomebrewPlaceholderCard` renders real rows; legacy `entities` blob **NOT** dropped; bulk migration of legacy rows deferred | 🟡 Additive only |
| 8 | Delete `lib/domain/entities/schema/`, `lib/data/schema/`, `field_widgets/`, `entity_sidebar.dart`, legacy `EntityCard`, legacy importers + dialogs | ⛔ Blocked — see Blockers |

### Blockers on Batch 8

`lib/domain/entities/schema/` cannot be deleted until every live consumer is either rewritten or retired. Current live consumers:

- `CharacterEditorScreen` + `character_editor_screen.dart` (1166 LOC) — router still points here; typed editor + creation wizard (Doc 10) has not shipped.
- `EntityCard` / `field_widgets/` — DatabaseScreen falls back here for generic blob ids; while the dispatcher covers every SRD slug, user-created entity blob rows still render via the legacy form path.
- `SessionScreen` reads `EncounterConfig.conditionStatsFieldKey` + `WorldSchema.categories[].fields[].subFields` to render condition tooltips.
- `package_import_service.dart` + `import_dialog.dart` — import flow for v5 `packages` / `package_schemas` / `package_entities` still the user-facing importer; typed `Dnd5ePackageImporter` (Doc 14) coexists but hasn't replaced it in the Hub.

Unblocking Batch 8 requires Doc 10 (character creation wizard) + completing the typed package import path in the Hub UI + typed condition-stat surface.

## Mission

**Keep every screen's layout, navigation, and interaction model identical. Replace only the content of cards / forms / lists with typed-model renderers.**

Users must see:
- Same Hub tabs (Worlds / Packages / Characters / Social / Settings).
- Same MainScreen 3-pane layout (left sidebar tree + center canvas + right inspector).
- Same DatabaseScreen sidebar grouping by category.
- Same SessionScreen initiative column + HP bars + condition chips + AoE overlay.
- Same MindMap graph editor.
- Same BattleMap + WorldMap pan/zoom/fog/token/draw.
- Same CharacterEditor 3-panel form.
- Same ProjectionWindow split.
- Same Sound sidebar + PDF sidebar.
- Same import/export flow.

Users must no longer see:
- Any generic `FieldSchema`-driven form. Every `FieldGroup` / `FieldSchema` render path replaced by a typed widget.
- Any user-editable schema / rule builder UI.
- Any reference to "templates" as a user-facing concept.

## Why Now

Plan B (2026-04-20) trimmed the `world_schemas` Drift table but kept `lib/domain/entities/schema/` domain classes alive because 60+ files read them to render the generic UI. Closing Phase A means deleting those classes. Deletion blocks on typed replacement renderers existing. This doc specifies them.

## Scope — What Gets Built vs Deleted

### Built (new code, ~4500-6000 LOC)

- **`TypedCardDispatcher`** — one widget, maps category slug → typed card.
- **15 typed card widgets** (per SRD category):
  - Combat: `SpellCard`, `MonsterCard`, `ItemCard`, `ActionCard`, `ReactionCard`, `TraitCard`, `LegendaryActionCard`.
  - Character: `NpcCard`, `PlayerCard`, `BackgroundCard`, `FeatCard`, `ClassCard`, `RaceCard` (species).
  - World: `LocationCard`, `QuestCard`, `LoreCard`, `PlaneCard`, `ConditionCard`, `StatusEffectCard`.
- **Typed content provider set** — providers returning typed Drift rows (`Spell`, `Monster`, `Item`, `Feat`, `Background`, `Species`, `Subclass`, `ClassProgression`) instead of generic `Entity`.
- **Typed entity sidebar tree** — same tree look, nodes bound to typed categories + typed row counts.
- **Typed Character editor** — 3-panel form driven by `Dnd5eCharacter` shape (class/species/ability/inventory/spells/feats/background), not `FieldSchema`.
- **Typed encounter combatant view** — SessionScreen reads `EncounterService` + typed `Combatant` shape.
- **Typed mind map node** — node refs typed entity id (`srd:fireball`, `srd:goblin`, `user:npc-123`) instead of raw blob id.
- **Typed battle map token** — token carries typed entity ref; cast/attack actions use typed `EncounterService`.
- **Homebrew entity create flow** — user custom NPC/Spell/Item writes to typed tables (`monsters` / `spells` / `items`) with `source_package_id = 'homebrew'`. Same "Create Entity" button in sidebar, target is typed table.

### Deleted (once all above ship)

- `lib/domain/entities/schema/` — 13 files (`world_schema.dart`, `entity_category_schema.dart`, `field_schema.dart`, `field_group.dart`, `category_rule.dart`, `rule_v2.dart`, `template_compatibility.dart`, `world_schema_hash.dart`, `world_schema_diff.dart`, `default_dnd5e_schema.dart`, `dnd5e_constants.dart`, `encounter_config.dart`, `encounter_layout.dart`).
- `lib/data/schema/` — 3 files (`legacy_maps.dart`, `schema_migration.dart`, `rule_migration_v2.dart`).
- `lib/application/services/package_import_service.dart` — replaced by `Dnd5ePackageImporter`.
- `lib/application/services/entity_parser.dart`.
- `lib/application/providers/template_provider.dart` (8 LOC, one provider).
- `lib/presentation/widgets/field_widgets/` — entire directory (generic field renderer + factory + all sub-widgets).
- `lib/presentation/widgets/entity_sidebar.dart` — replaced by typed sidebar.
- `lib/presentation/screens/database/entity_card.dart` — replaced by `TypedCardDispatcher`.
- `lib/presentation/dialogs/import_dialog.dart` + `import_package_dialog.dart` — replaced by typed import dialog.
- Drift tables (v9→v10):
  - `entities` blob — user content migrated to typed tables.
  - `packages` / `package_schemas` / `package_entities` — replaced by `installed_packages` + typed catalog/content tables.
- Legacy `@DriftDatabase` table list references.
- Tests: `default_schema_test.dart`, `schema_migration_test.dart`, `field_group_test.dart`, `field_widget_factory_test.dart`, `entity_parser_test.dart`, template-related tests in `campaign_test.dart` + `combat_provider_test.dart`.

## Preserved — Layout Invariants

The migration **must not change**:

1. **Hub tab structure** — five tabs, same order, same icons, same marketplace link.
2. **MainScreen 3-pane layout** — left sidebar tree (entities by category), center canvas (mode switcher: database / map / mindmap / session / soundmap / pdf), right inspector (per-mode contextual).
3. **Sidebar tree visual** — same category icons, same color coding, same expand/collapse, same "Create" affordance, same right-click menu.
4. **DatabaseScreen layout** — sidebar tree → select entity → center pane shows entity card → right inspector shows relations. Card is flush-mounted, scrolls independently.
5. **SessionScreen combat layout** — top bar (encounter name + "End Encounter"), left column initiative list (portraits + HP bar + condition chips + turn arrow), center arena (optional battle map overlay), right column action log + encounter column config.
6. **CharacterEditor** — top header (name + class + level + portrait), three tabs (Stats / Combat / Personal), save/cancel/revert buttons, inline validation chips.
7. **MindMapScreen** — node + edge graph, right-click node menu, drag-to-reposition, edge-create gesture, node settings dialog.
8. **BattleMapScreen** — pan/zoom canvas, layer toggle (fog / grid / draw), draw tools (pen / rectangle / circle), measurement ruler, AoE preview overlay, token layer with drag + right-click menu.
9. **WorldMapScreen** — same pan/zoom, pin layer, timeline pin layer.
10. **ProjectionWindow** — dual-monitor split, DM-only overlay visibility config.
11. **Sound sidebar** — theme list + per-track volume + one-shot SFX grid.
12. **PDF sidebar** — viewer pane + bookmark list + search.
13. **Hub card grid** — `HubCardGrid` shipped in Plan B stays (already typed-ready).

**Principle:** Paint a typed renderer inside the same Widget tree; do not move / reflow / renumber panels.

## Architecture

### Typed Content Layer

```
┌──────────────────────────┐      ┌──────────────────────────┐
│ Tier 1 catalog Drift     │      │ Tier 2 content Drift     │
│ tables (Doc 03)          │      │ tables (Doc 03)          │
│ conditions, damage_types,│      │ monsters, spells, items, │
│ skills, sizes, creature_ │      │ feats, backgrounds,      │
│ types, alignments, …     │      │ species, subclasses,     │
└──────┬───────────────────┘      │ class_progressions       │
       │                          └──────┬───────────────────┘
       ▼                                 ▼
┌───────────────────────────────────────────┐
│ Typed Providers (Riverpod)                │
│ - spellsByLevelProvider                   │
│ - monstersByCrProvider                    │
│ - itemsByCategoryProvider                 │
│ - charactersProvider (user-created)       │
│ - npcsProvider (homebrew monsters)        │
│ - homebrewContentProvider (source=hb)     │
└──────┬────────────────────────────────────┘
       ▼
┌───────────────────────────────────────────┐
│ TypedCardDispatcher                       │
│ switch (categorySlug) {                   │
│   case 'spell'     → SpellCard            │
│   case 'monster'   → MonsterCard          │
│   case 'item'      → ItemCard             │
│   case 'feat'      → FeatCard             │
│   case 'background'→ BackgroundCard       │
│   case 'class'     → ClassCard            │
│   case 'race'      → RaceCard             │
│   case 'npc'       → NpcCard              │
│   case 'player'    → PlayerCard           │
│   case 'location'  → LocationCard         │
│   case 'quest'     → QuestCard            │
│   case 'lore'      → LoreCard             │
│   case 'plane'     → PlaneCard            │
│   case 'condition' → ConditionCard        │
│   case 'status-effect' → StatusEffectCard │
│   case 'trait' / 'action' / 'reaction' /  │
│     'legendary-action' → ActionCard       │
│ }                                         │
└───────────────────────────────────────────┘
```

### Entity Identity Unification

- Catalog content: `srd:fireball`, `srd:goblin`, `srd:longsword`.
- Homebrew content: `hb:<uuid>` or `user:<uuid>` (decision: **`hb:`** prefix — matches existing `source_package_id = 'homebrew'`).
- Campaign-scoped content (user-created NPCs tied to a single campaign): `hb:<campaignId>:<uuid>`.

All IDs are plain strings. Relation fields (spell-known list, action list, encounter combatant list) store typed ID strings.

### User-Created Content Migration Path

The legacy `entities` Drift blob carries user-created content (custom NPCs, homebrew spells, quest notes). During the v9→v10 migration:

1. For each `entities` row, infer target typed table from `category_slug`:
   - `spell` → `spells` table.
   - `monster` / `npc` → `monsters` table.
   - `equipment` → `items` table.
   - `feat` → `feats` table.
   - `background` → `backgrounds` table.
   - `race` → `species_catalog` table.
   - `class` → `class_progressions` table.
   - `quest` / `location` / `lore` / `plane` / `condition` / `status-effect` → **new `homebrew_entries` table** (catalog-style with typed body per category).
2. Translate the row's `fields_json` into the typed body shape (fields match the current schema defaults; translation is mechanical).
3. Write with `source_package_id = 'homebrew'`.
4. Drop the `entities` table at end of migration.

Edge case: a row whose `category_slug` doesn't match any typed table → landed in `homebrew_entries` with a `category_slug` column; UI shows it in the "Other" tree node.

### Homebrew Entries Table (new)

Small Drift table for categories that don't map to existing typed content (quests, locations, lore, planes, status effects):

```dart
class HomebrewEntries extends Table {
  TextColumn get id => text()();                    // hb:<uuid>
  TextColumn get campaignId => text().nullable()();
  TextColumn get categorySlug => text()();
  TextColumn get name => text()();
  TextColumn get bodyJson => text()();              // typed per category
  TextColumn get sourcePackageId => text().withDefault(const Constant('homebrew'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override Set<Column> get primaryKey => {id};
}
```

Typed bodies per category (sealed classes in Dart):

- `QuestBody { status, giver, reward, description }`.
- `LocationBody { dangerLevel, environment, description, mapRef? }`.
- `LoreBody { category, secretInfo, description }`.
- `PlaneBody { type, description }`.
- `StatusEffectBody { duration, effectType, linkedConditionId }`.

## Batch Sequencing

Eight batches. Each ends green (analyze + tests). Smallest slice that ships a visible piece first so users see progress.

### Batch 1 — Typed cards foundation (8 turns)

**Goal:** `TypedCardDispatcher` + 5 cards (`SpellCard`, `MonsterCard`, `ItemCard`, `FeatCard`, `BackgroundCard`). DatabaseScreen renders typed cards for those 5 categories. Generic `EntityCard` still used for remaining 10.

**Files added:**
- `lib/presentation/widgets/dnd5e/typed_card_dispatcher.dart`.
- `lib/presentation/widgets/dnd5e/cards/spell_card.dart`.
- `lib/presentation/widgets/dnd5e/cards/monster_card.dart`.
- `lib/presentation/widgets/dnd5e/cards/item_card.dart`.
- `lib/presentation/widgets/dnd5e/cards/feat_card.dart`.
- `lib/presentation/widgets/dnd5e/cards/background_card.dart`.
- `lib/application/providers/typed_content_provider.dart` — reads Tier 2 tables.
- Tests per card + dispatcher.

**Files modified:**
- `lib/presentation/screens/database/database_screen.dart` (if exists; else `main_screen.dart` database mode) — dispatcher call for supported slugs, fallback to `EntityCard`.

**Verification:** DatabaseScreen shows typed card for spell/monster/item/feat/background; other categories unchanged.

### Batch 2 — Remaining character-focused cards (5 turns)

Cards: `NpcCard`, `PlayerCard`, `ClassCard`, `RaceCard` (species), `ActionCard` (shared by trait/action/reaction/legendary-action).

Dispatcher hooks up; DatabaseScreen now uses typed render for 10/15 categories.

### Batch 3 — World content cards (4 turns)

Cards: `LocationCard`, `QuestCard`, `LoreCard`, `PlaneCard`, `ConditionCard`, `StatusEffectCard`.

All 15 categories covered. `EntityCard` no longer reached from DatabaseScreen. Keep `EntityCard` file alive (MindMap / BattleMap / Session still use it).

### Batch 4 — Typed sidebar tree + typed content providers (5 turns)

**Goal:** Sidebar reads typed providers (counts come from typed Drift tables), replacing `entitiesByCategoryProvider`. `entity_sidebar.dart` copies into `typed_entity_sidebar.dart` with the same visual; old file stays for MindMap / BattleMap until Batch 5.

### Batch 5 — MindMap + BattleMap + Session typed entity refs (10 turns)

Mind map node + battle map token + session combatant read typed providers. Entity cards rendered via dispatcher in inspector panels.

Mind map relations: `MindMapNodes.entityId` column stays as plain text; convention changes — `srd:`/`hb:` prefix.

Battle map token: `MapPins.entityId` same treatment.

Session combatant: already typed via `EncounterService` + `Combatants` Drift table — just stop passing `WorldSchema` argument; the schema parameter becomes unused and is dropped.

### Batch 6 — Typed character editor (8 turns)

**Goal:** `CharacterEditor` form drives from `Dnd5eCharacter` typed model. Three tabs: Stats (ability scores + saves + skills), Combat (HP / AC / speed / initiative / actions), Personal (background + notes + portrait + inventory).

Old `CharacterEditorScreen` still exists until Batch 7.

### Batch 7 — Homebrew create flow + entities blob migration (6 turns)

**Goal:** "Create Entity" action in sidebar writes to typed tables with `source_package_id = 'homebrew'`. Per-category create dialogs typed.

Drift v9→v10 migration:
- New `homebrew_entries` table with typed bodies.
- Migration walks `entities` rows, dispatches to typed tables per `category_slug`, drops `entities` table at end.

Legacy `package_import_service.dart` deleted; all imports go through `Dnd5ePackageImporter`.

### Batch 8 — Schema dir deletion + final sweep (4 turns)

Once no live code references `lib/domain/entities/schema/`:
- Delete `lib/domain/entities/schema/` (13 files).
- Delete `lib/data/schema/` (3 files).
- Delete `lib/presentation/widgets/field_widgets/` (directory).
- Delete `lib/presentation/widgets/entity_sidebar.dart`.
- Delete `lib/presentation/screens/database/entity_card.dart`.
- Delete `lib/application/services/package_import_service.dart` + `entity_parser.dart`.
- Delete `lib/application/providers/template_provider.dart`.
- Delete legacy `import_dialog.dart` + `import_package_dialog.dart`.
- Drop `packages` / `package_schemas` / `package_entities` tables in v10 migration (already replaced by `installed_packages`).
- Regen build_runner.
- Final grep:
  ```
  rg 'WorldSchema|EntityCategorySchema|FieldSchema|FieldGroup|CategoryRule|RuleV2|TemplateCompatibility|generateDefaultDnd5eSchema|allTemplatesProvider|EncounterConfig|EncounterLayout|Dnd5eConstants' lib test --type dart
  ```
  Expected: 0 hits.

## Verification Cross-Cutting

After **every batch**:
- `flutter analyze` → 0 issues.
- `flutter test` → all green (test count grows as typed tests ship, shrinks as generic tests delete).
- Manual smoke: launch app → Hub visible → Worlds/Characters/Packages tabs render → create world → create character → open world → MainScreen opens → sidebar populated → entity card renders → session encounter runs → mind map loads.

After **Batch 8**:
- No import of `lib/domain/entities/schema/` anywhere.
- `entities` Drift table gone.
- SRD + homebrew both route through typed tables exclusively.
- Phase A closed 🟢.

## Risks & Mitigation

| Risk | Mitigation |
|---|---|
| Typed card LOC explosion | Cards share `_CardShell` base (border + title + description block + tags). Per-category content ≤ 80 LOC typical. |
| User data loss on v9→v10 | Migration writes to typed tables; `LegacyDbBackup` already snapshots. Homebrew entries live on in `homebrew_entries` table. |
| Mind map relation breakage | Nodes carry entity id as string; prefix convention (`srd:`/`hb:`) preserved from codec output. Relation integrity re-validated post-migration via sweep script. |
| Encounter save/load regression | `EncounterService` surface unchanged; only the `WorldSchema` parameter removed. Regressions caught by existing combat test suite. |
| Partial migration leaves half-schema half-typed state visible to user | Each batch ships a complete slice; DatabaseScreen fallback to `EntityCard` in Batch 1-3 means every screen always renders something. |
| Card visual drift from legacy `EntityCard` | Each typed card opens with the same border/padding/header as `EntityCard`; only field layout changes. Golden tests optional (Phase 5 testing doc). |

## Acceptance

Phase D acceptance (all required):

- [ ] All 15 category cards typed; `TypedCardDispatcher` covers every category.
- [ ] DatabaseScreen reads typed providers exclusively.
- [ ] CharacterEditor drives from `Dnd5eCharacter`.
- [ ] SessionScreen encounter flow reads `EncounterService` without `WorldSchema`.
- [ ] MindMap / BattleMap / WorldMap entity refs typed.
- [ ] Homebrew create flow writes typed rows with `source_package_id = 'homebrew'`.
- [ ] `entities` Drift table dropped.
- [ ] `lib/domain/entities/schema/` deleted.
- [ ] `lib/data/schema/` deleted.
- [ ] `lib/presentation/widgets/field_widgets/` deleted.
- [ ] `flutter analyze` 0 issues.
- [ ] `flutter test` green.
- [ ] Manual smoke: fresh install → typed UI end-to-end; v9 upgrade → homebrew migration writes typed rows; all screens render.

## References

- [01-domain-model-spec.md](./01-domain-model-spec.md) — typed domain classes.
- [03-database-schema-spec.md](./03-database-schema-spec.md) — Tier 1/2 Drift tables.
- [04-template-removal-checklist.md](./04-template-removal-checklist.md) — legacy steps, now partially subsumed here.
- [11-combat-engine-spec.md](./11-combat-engine-spec.md) — session screen wiring target.
- [14-package-system-redesign.md](./14-package-system-redesign.md) — typed package importer (sole import path post-migration).
- [31-ui-component-library.md](./31-ui-component-library.md) — card widget contracts.
- [32-character-sheet-views.md](./32-character-sheet-views.md) — typed character editor layout.
- [33-battlemap-interaction-spec.md](./33-battlemap-interaction-spec.md) — typed token refs.
