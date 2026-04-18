# 03 — Database Schema (Drift v5)

> **For Claude.** Drift schema after template removal. Fresh start (no migration from v4 — see [42](./42-fresh-start-db-reset.md)).
> **Target:** `flutter_app/lib/data/database/`
> **Content policy.** No Tier 1 enums (Condition, DamageType, Skill, Size, SpellSchool, Alignment, Rarity, Language, WeaponProperty, WeaponMastery, ArmorCategory, CreatureType). All catalog columns are `text()` holding namespaced ids like `srd:stunned`. See [01-domain-model-spec.md](./01-domain-model-spec.md) §Tier Split, §ID Namespacing.

## Migration Strategy

```
v4 → v5: drop entire database, recreate with v5 schema.
```

Implementation in `app_database.dart`:

```dart
@override
int get schemaVersion => 5;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 5) {
      // Fresh start: drop everything, recreate.
      for (final t in allTables) {
        await m.deleteTable(t.actualTableName);
      }
      await m.createAll();
    }
  },
);
```

User-facing notice handled in [42](./42-fresh-start-db-reset.md).

## Tables to DROP (existing in v4)

```
world_schemas        — entire template system
template_local_cache — file-based, also delete `cache/templates/` directory
```

## Tables to KEEP (with column changes)

| Table | Changes |
|---|---|
| `campaigns` | Drop `template_id`, `template_hash`, `template_original_hash`. Add `game_system_id TEXT NOT NULL DEFAULT 'dnd5e'`. |
| `entities` | **Drop entirely.** Replaced by typed tables below. |
| `sessions` | Keep. Encounter data moves into `encounters` typed table. |
| `combatants` | Replace with typed schema (see below). |
| `combat_conditions` | Keep (typed enum string). |
| `map_pins`, `mind_map_nodes`, `mind_map_edges` | Keep as-is. |
| `package_*` | Replace with typed package tables (see [14](./14-package-system-redesign.md)). |

## New Tables (DnD 5e Typed)

All tables include `id TEXT PRIMARY KEY`, `created_at INTEGER`, `updated_at INTEGER`.

### `characters`

```dart
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().references(Campaigns, #id)();
  TextColumn get name => text()();
  TextColumn get speciesId => text()();                    // 'srd:human'
  TextColumn get lineageId => text().nullable()();
  TextColumn get backgroundId => text()();                  // 'srd:soldier'
  TextColumn get alignmentId => text()();                   // 'srd:lawful_good'
  IntColumn get experiencePoints => integer().withDefault(const Constant(0))();
  // Ability scores (final, post-background-bonus)
  IntColumn get strScore => integer()();
  IntColumn get dexScore => integer()();
  IntColumn get conScore => integer()();
  IntColumn get intScore => integer()();
  IntColumn get wisScore => integer()();
  IntColumn get chaScore => integer()();
  // HP
  IntColumn get hpCurrent => integer()();
  IntColumn get hpMax => integer()();
  IntColumn get hpTemp => integer().withDefault(const Constant(0))();
  IntColumn get hpMaxOverride => integer().nullable()();   // for life-drain
  // Death saves
  IntColumn get deathSavesSuccesses => integer().withDefault(const Constant(0))();
  IntColumn get deathSavesFailures => integer().withDefault(const Constant(0))();
  // Exhaustion
  IntColumn get exhaustionLevel => integer().withDefault(const Constant(0))();
  // Misc
  BoolColumn get hasInspiration => boolean().withDefault(const Constant(false))();
  TextColumn get languageIdsJson => text()();   // List<String> of namespaced language ids
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override Set<Column> get primaryKey => {id};
}
```

### `character_class_levels`

Multi-row per character (one per class).

```dart
class CharacterClassLevels extends Table {
  TextColumn get id => text()();
  TextColumn get characterId => text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get classId => text()();             // 'srd:barbarian'
  TextColumn get subclassId => text().nullable()();
  IntColumn get level => integer()();
  IntColumn get hitDiceRemaining => integer()();  // for short rest
  IntColumn get displayOrder => integer()();      // for UI sort
  @override Set<Column> get primaryKey => {id};
}
```

### `character_spell_slots`

Per spell-level row.

```dart
class CharacterSpellSlots extends Table {
  TextColumn get characterId => text().references(Characters, #id, onDelete: KeyAction.cascade)();
  IntColumn get slotLevel => integer()();    // 1..9
  IntColumn get current => integer()();
  IntColumn get maximum => integer()();
  @override Set<Column> get primaryKey => {characterId, slotLevel};
}
```

(Pact magic uses same row pattern in `character_pact_slots`.)

### `character_prepared_spells`

```dart
class CharacterPreparedSpells extends Table {
  TextColumn get characterId => text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get spellId => text()();         // references spells.id
  TextColumn get sourceClassId => text()();   // which class prepared this
  BoolColumn get alwaysPrepared => boolean()();
  @override Set<Column> get primaryKey => {characterId, spellId, sourceClassId};
}
```

### `character_inventory`

```dart
class CharacterInventory extends Table {
  TextColumn get id => text()();
  TextColumn get characterId => text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId => text()();          // references items.id (or marketplace UUID)
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  BoolColumn get equipped => boolean().withDefault(const Constant(false))();
  BoolColumn get attuned => boolean().withDefault(const Constant(false))();
  IntColumn get chargesRemaining => integer().nullable()();
  TextColumn get customNotes => text().nullable()();
  @override Set<Column> get primaryKey => {id};
}
```

### `character_proficiencies`

```dart
class CharacterProficiencies extends Table {
  TextColumn get characterId => text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get profType => text()();        // 'skill'|'tool'|'weapon'|'armor'|'save'|'language'
  TextColumn get profKey => text()();         // Ability short for 'save' (e.g. 'STR'); namespaced id otherwise ('srd:athletics')
  TextColumn get level => textEnum<Proficiency>()();   // Tier 0 enum: 'half'|'full'|'expertise'
  TextColumn get sourceJson => text().nullable()();
  @override Set<Column> get primaryKey => {characterId, profType, profKey};
}
```

### `character_feats`

```dart
class CharacterFeats extends Table {
  TextColumn get characterId => text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get featId => text()();
  TextColumn get optionsJson => text().nullable()();   // selected sub-options
  @override Set<Column> get primaryKey => {characterId, featId};
}
```

### `monsters`

Static catalog (system + package data).

```dart
class Monsters extends Table {
  TextColumn get id => text()();              // 'srd:goblin' or 'pkg:abc:custom_dragon'
  TextColumn get name => text()();
  TextColumn get sourcePackageId => text().nullable()();
  TextColumn get statBlockJson => text()();   // Full StatBlock as JSON (acceptable: read-mostly catalog)
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}
```

**Note:** monster definitions are immutable catalog data. Per-instance state (HP, position, conditions) lives in `combatants`. JSON-blob storage is acceptable here because monsters are not queried by individual fields, only loaded whole.

### `spells`

```dart
class Spells extends Table {
  TextColumn get id => text()();              // 'srd:fireball'
  TextColumn get name => text()();
  IntColumn get level => integer()();         // 0..9
  TextColumn get schoolId => text()();        // 'srd:evocation'
  TextColumn get sourcePackageId => text().nullable()();
  TextColumn get bodyJson => text()();        // full Spell as JSON (effects are EffectDescriptor list)
  @override Set<Column> get primaryKey => {id};
}
```

### `items`

```dart
class Items extends Table {
  TextColumn get id => text()();              // 'srd:longsword'
  TextColumn get name => text()();
  TextColumn get itemType => text()();        // 'weapon'|'armor'|'shield'|'gear'|'magic'|'tool'|'ammo'
  TextColumn get rarityId => text().nullable()();            // 'srd:rare'
  TextColumn get sourcePackageId => text().nullable()();
  TextColumn get bodyJson => text()();        // full Item subtype as JSON
  @override Set<Column> get primaryKey => {id};
}
```

### `feats`, `backgrounds`, `species`, `subclasses`, `class_progressions`

All same shape: `id, name, body_json, source_package_id`. JSON blob OK (catalog data).

### Catalog tables (Tier 1 mechanic primitives)

All catalog tables share the same shape: namespaced `id TEXT PRIMARY KEY`, `name`, `body_json`, `source_package_id`, `created_at`, `updated_at`. The body JSON carries type-specific fields (including `List<EffectDescriptor>` where applicable). These rows are populated by the package importer ([14-package-system-redesign.md](./14-package-system-redesign.md)); the built-in dnd5e module itself seeds zero rows.

```dart
abstract class _CatalogTable extends Table {
  TextColumn get id => text()();                    // '<packageSlug>:<localId>'
  TextColumn get name => text()();
  TextColumn get bodyJson => text()();
  TextColumn get sourcePackageId => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class Conditions        extends _CatalogTable {}
class DamageTypes       extends _CatalogTable {}
class Skills            extends _CatalogTable {}
class Sizes             extends _CatalogTable {}
class CreatureTypes     extends _CatalogTable {}
class Alignments        extends _CatalogTable {}
class Languages         extends _CatalogTable {}
class SpellSchools      extends _CatalogTable {}
class WeaponProperties  extends _CatalogTable {}
class WeaponMasteries   extends _CatalogTable {}
class ArmorCategories   extends _CatalogTable {}
class Rarities          extends _CatalogTable {}
```

Querying catalog rows by name or filter fields happens in-memory after bulk load (catalogs are small; typical SRD bundle is 17 conditions, 14 damage types, etc.). The `source_package_id` column supports "uninstall package X removes all its catalog rows."

### `encounters`

```dart
class Encounters extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().references(Campaigns, #id)();
  TextColumn get name => text()();
  IntColumn get round => integer().withDefault(const Constant(1))();
  IntColumn get turnIndex => integer().withDefault(const Constant(0))();
  TextColumn get mapPath => text().nullable()();
  TextColumn get fogDataBase64 => text().nullable()();
  IntColumn get gridSize => integer().withDefault(const Constant(50))();
  BoolColumn get gridSnap => boolean().withDefault(const Constant(true))();
  BoolColumn get gridVisible => boolean().withDefault(const Constant(true))();
  IntColumn get feetPerCell => integer().withDefault(const Constant(5))();
  TextColumn get viewportJson => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}
```

### `combatants`

```dart
class Combatants extends Table {
  TextColumn get id => text()();
  TextColumn get encounterId => text().references(Encounters, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();                // 'player'|'monster'
  TextColumn get characterId => text().nullable()();    // if player
  TextColumn get monsterId => text().nullable()();      // if monster (catalog ref)
  TextColumn get displayName => text()();
  IntColumn get initiativeRoll => integer()();
  IntColumn get hpCurrent => integer()();
  IntColumn get hpMax => integer()();
  IntColumn get hpTemp => integer().withDefault(const Constant(0))();
  IntColumn get armorClass => integer()();
  RealColumn get tokenX => real().nullable()();   // canvas-space
  RealColumn get tokenY => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get displayOrder => integer()();
  TextColumn get resistancesJson => text().withDefault(const Constant('[]'))();     // List<String> of DamageType ids
  TextColumn get vulnerabilitiesJson => text().withDefault(const Constant('[]'))();
  TextColumn get immunitiesJson => text().withDefault(const Constant('[]'))();
  @override Set<Column> get primaryKey => {id};
}
```

### `combatant_conditions`

```dart
class CombatantConditions extends Table {
  TextColumn get combatantId => text().references(Combatants, #id, onDelete: KeyAction.cascade)();
  TextColumn get conditionId => text()();                            // 'srd:stunned' — namespaced ContentReference<Condition>
  IntColumn get durationRoundsRemaining => integer().nullable()();   // null = indefinite
  IntColumn get exhaustionLevel => integer().nullable()();           // for Exhaustion only
  @override Set<Column> get primaryKey => {combatantId, conditionId};
}
```

### `combatant_concentration`

```dart
class CombatantConcentration extends Table {
  TextColumn get combatantId => text().references(Combatants, #id, onDelete: KeyAction.cascade)();
  TextColumn get spellId => text()();
  IntColumn get roundsRemaining => integer().nullable()();
  TextColumn get targetIdsJson => text()();       // affected combatants
  @override Set<Column> get primaryKey => {combatantId};
}
```

## Indexes

```sql
CREATE INDEX idx_characters_campaign ON characters(campaign_id);
CREATE INDEX idx_class_levels_char ON character_class_levels(character_id);
CREATE INDEX idx_inventory_char ON character_inventory(character_id);
CREATE INDEX idx_combatants_encounter ON combatants(encounter_id);
CREATE INDEX idx_combatant_conditions_combatant ON combatant_conditions(combatant_id);
```

## JSON-Blob Justification

For **catalog data** (monsters, spells, items, feats, backgrounds, species, subclasses), JSON blob storage is OK because:
- Read-mostly; whole entity loaded for display.
- No per-field SQL queries needed beyond `id`/`name`/`level`/`school`.
- Schema can evolve without DB migration.

For **per-instance / mutable** state (characters, combatants, conditions), use typed columns to enable updates and indexed queries.

## Acceptance

- `flutter_app/lib/data/database/app_database.dart` reports `schemaVersion = 5`.
- `flutter analyze` passes.
- Fresh app launch creates v5 schema with all 12 catalog tables empty.
- After SRD Core package auto-install: `conditions` has 17 rows, `damage_types` has 14, `skills` has 18, etc. Every row's `id` matches `srd:.*`.
- Uninstalling a package deletes all its catalog rows via `source_package_id` match.
- Upgrade from v4 drops & recreates (with user warning shown by app code, see [42](./42-fresh-start-db-reset.md)).
- Loading 1000 monsters from `monsters` table completes < 200 ms on debug build.

## Open Questions

1. Should we use Drift type converters for enums, or store as text + parse in mappers? → **Use `textEnum<>()` converter.** Built-in.
2. Migrate `package_*` tables in this doc or separately? → **Separately**, in [14](./14-package-system-redesign.md).
3. Encrypt at rest? → No. Local SQLite trusted by user. Sensitive data (campaign notes) is user's own.
