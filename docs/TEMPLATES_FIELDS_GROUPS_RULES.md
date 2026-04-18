# Templates, Fields, Groups & Rules — System Reference

Internal reference for the schema-driven entity system. Dense format optimized for re-reading.

---

## 1. Core Concepts

Schema-driven, rule-based entity system for D&D 5e + custom TTRPGs. Everything declarative — no hardcoded game logic.

```
WorldSchema           → top-level template (whole "world")
  └─ EntityCategorySchema  → one entity type (NPC, Item, Spell...)
       ├─ FieldSchema[]    → data points
       ├─ FieldGroup[]     → visual layout buckets
       └─ RuleV2[]         → condition/effect logic
Entity                → runtime instance conforming to a category
```

Mental model: Google Forms + spreadsheet + rule engine.

---

## 2. WorldSchema

**File**: [flutter_app/lib/domain/entities/schema/world_schema.dart](flutter_app/lib/domain/entities/schema/world_schema.dart)

```dart
@freezed
abstract class WorldSchema with _$WorldSchema {
  const factory WorldSchema({
    required String schemaId,
    @Default('D&D 5e (Default)') String name,
    @Default('1.0.0') String version,
    String? baseSystem,
    @Default('') String description,
    @Default([]) List<EntityCategorySchema> categories,
    @Default([]) List<EncounterLayout> encounterLayouts,
    @Default(EncounterConfig()) EncounterConfig encounterConfig,
    @Default({}) Map<String, dynamic> metadata,
    required String createdAt,
    required String updatedAt,
    String? originalHash,  // frozen lineage id — stable across installs
  }) = _WorldSchema;
}
```

Key fields:
- `schemaId` — globally unique template id. Builtin: `'builtin-dnd5e-default'`
- `originalHash` — content hash frozen at creation, tracks template lineage across installations
- `categories` — 15 builtin D&D categories

Default schema builder: [flutter_app/lib/domain/entities/schema/default_dnd5e_schema.dart](flutter_app/lib/domain/entities/schema/default_dnd5e_schema.dart) (lines 40-296).

---

## 3. EntityCategorySchema ("Template" per category)

**File**: [flutter_app/lib/domain/entities/schema/entity_category_schema.dart](flutter_app/lib/domain/entities/schema/entity_category_schema.dart)

```dart
@freezed
abstract class EntityCategorySchema with _$EntityCategorySchema {
  const factory EntityCategorySchema({
    required String categoryId,
    required String schemaId,
    required String name,
    required String slug,
    @Default('') String icon,
    @Default('#808080') String color,
    @Default(false) bool isBuiltin,
    @Default(false) bool isArchived,
    @Default(0) int orderIndex,
    @Default([]) List<FieldSchema> fields,
    @Default([]) List<String> allowedInSections,  // encounter/mindmap/worldmap/projection
    @Default([]) List<String> filterFieldKeys,    // sidebar filter fields
    @RulesJsonConverter() @Default([]) List<RuleV2> rules,
    @Default([]) List<FieldGroup> fieldGroups,
    required String createdAt,
    required String updatedAt,
  }) = _EntityCategorySchema;
}
```

Builtin D&D categories: NPC, Monster, Player, Item, Spell, Trait, Action, Reaction, Legendary Action, Condition, Location, Scene, Quest, etc.

---

## 4. FieldSchema

**File**: [flutter_app/lib/domain/entities/schema/field_schema.dart](flutter_app/lib/domain/entities/schema/field_schema.dart)

### 4.1 FieldType enum (15 types)

```dart
enum FieldType {
  text, textarea, markdown,
  integer, float_, boolean_, enum_, date,
  image, file, pdf,
  relation,               // single or list of entity refs
  tagList,
  statBlock,              // {STR, DEX, CON, INT, WIS, CHA}
  combatStats,            // HP, AC, Speed, Level, CR, XP, Initiative
  conditionStats,         // duration + effect
  dice,                   // "2d6+5"
  slot,                   // checkbox rows (spell slots, ammo)
  proficiencyTable,       // D&D skills matrix
  levelTable,             // Map<String, num>
}
```

### 4.2 FieldSchema class (lines 60-97)

```dart
const factory FieldSchema({
  required String fieldId,
  required String categoryId,
  required String fieldKey,          // unique within category
  required String label,
  required FieldType fieldType,
  @Default(false) bool isRequired,
  @Default(null) dynamic defaultValue,
  @Default('') String placeholder,
  @Default('') String helpText,
  @Default(FieldValidation()) FieldValidation validation,
  @Default(FieldVisibility.shared) FieldVisibility visibility,
  @Default(0) int orderIndex,
  @Default(false) bool isBuiltin,
  @Default(false) bool isList,       // array variant
  @Default(false) bool hasEquip,     // relation list with equip toggle
  @Default(false) bool showSourceFilter,
  @Default([]) List<String> allowedInSections,
  @Default([]) List<Map<String, String>> subFields,  // for combatStats/slot/proficiencyTable
  @Default(null) String? groupId,
  @Default(1) int gridColumnSpan,    // 1-4
  required String createdAt,
  required String updatedAt,
}) = _FieldSchema;
```

### 4.3 FieldValidation (lines 41-58)

```dart
const factory FieldValidation({
  double? minValue,
  double? maxValue,
  int? minLength,
  int? maxLength,
  String? pattern,                  // regex
  List<String>? allowedValues,      // enum_ options
  List<String>? allowedTypes,       // relation target category slugs
  List<String>? allowedExtensions,  // ['.pdf', '.jpg']
  String? customMessage,
}) = _FieldValidation;
```

### 4.4 FieldVisibility

```dart
enum FieldVisibility { shared, dmOnly, private_ }
```

---

## 5. FieldGroup

**File**: [flutter_app/lib/domain/entities/schema/field_group.dart](flutter_app/lib/domain/entities/schema/field_group.dart)

```dart
@freezed
abstract class FieldGroup with _$FieldGroup {
  const factory FieldGroup({
    required String groupId,
    @Default('') String name,
    @Default(1) int gridColumns,   // 1-4 grid layout
    @Default(0) int orderIndex,
    @Default(false) bool isCollapsed,
  }) = _FieldGroup;
}
```

Important: **groups are purely UI layout** — no semantic meaning, no effect on rules or data. Fields link back via `FieldSchema.groupId`.

Default D&D groups ([default_dnd5e_schema.dart:241-258](flutter_app/lib/domain/entities/schema/default_dnd5e_schema.dart#L241-L258)):
- Attributes (2 cols)
- Ability Scores (1 col)
- Combat (2 cols)
- Resistances (2 cols)
- Actions (1 col)
- Spells (1 col)

---

## 6. RuleV2 — Condition/Effect Engine

**File**: [flutter_app/lib/domain/entities/schema/rule_v2.dart](flutter_app/lib/domain/entities/schema/rule_v2.dart)

Replaces legacy `CategoryRule`. Pattern: `when` (predicate) + `then` (effect), evaluated by priority.

### 6.1 RuleV2 (lines 200-220)

```dart
@freezed
abstract class RuleV2 with _$RuleV2 {
  const factory RuleV2({
    required String ruleId,
    required String name,
    @Default(true) bool enabled,
    @JsonKey(name: 'when') required Predicate when_,
    @JsonKey(name: 'then') required RuleEffect then_,
    @Default(0) int priority,
    @Default('') String description,
  }) = _RuleV2;
}
```

### 6.2 Predicate (lines 54-83)

```dart
@Freezed(unionKey: 'type')
abstract class Predicate with _$Predicate {
  const factory Predicate.compare({
    required FieldRef left,
    required CompareOp op,
    FieldRef? right,
    @JsonKey(name: 'literal') dynamic literalValue,
  }) = ComparePredicate;

  const factory Predicate.and(List<Predicate> children) = AndPredicate;
  const factory Predicate.or(List<Predicate> children) = OrPredicate;
  const factory Predicate.not(Predicate child) = NotPredicate;
  const factory Predicate.always() = AlwaysPredicate;
}

enum CompareOp {
  eq, neq, gt, gte, lt, lte,
  contains, notContains,
  isSubsetOf, isSupersetOf, isDisjointFrom,
  isEmpty, isNotEmpty,
}
```

### 6.3 FieldRef (lines 11-34)

```dart
enum RefScope {
  self,          // this entity's field
  related,       // single-ref field → target entity's field
  relatedItems,  // aggregate across relation list
}

@freezed
abstract class FieldRef with _$FieldRef {
  const factory FieldRef({
    required RefScope scope,
    required String fieldKey,
    String? relationFieldKey,   // for related/relatedItems
    String? nestedFieldKey,     // for stat_block.DEX, combat_stats.hp
  }) = _FieldRef;
}
```

Examples:
- `FieldRef(self, 'level')` → this entity's level
- `FieldRef(related, 'base_speed', relationFieldKey: 'race_ref')` → race entity's speed
- `FieldRef(relatedItems, 'bonus', relationFieldKey: 'equipment')` → all equipment bonuses
- `FieldRef(self, 'stat_block', nestedFieldKey: 'DEX')` → DEX ability score

### 6.4 ValueExpression (lines 100-141)

```dart
@Freezed(unionKey: 'type')
abstract class ValueExpression with _$ValueExpression {
  const factory ValueExpression.fieldValue(FieldRef source) = FieldValueExpr;

  const factory ValueExpression.aggregate({
    required String relationFieldKey,
    required String sourceFieldKey,
    required AggregateOp op,
    @Default(false) bool onlyEquipped,
  }) = AggregateExpr;

  const factory ValueExpression.literal(dynamic value) = LiteralExpr;

  const factory ValueExpression.arithmetic({
    required ValueExpression left,
    required ArithOp op,
    required ValueExpression right,
  }) = ArithmeticExpr;

  const factory ValueExpression.tableLookup({
    required FieldRef table,
    required ValueExpression key,
    ValueExpression? fallback,
  }) = TableLookupExpr;

  const factory ValueExpression.modifier(FieldRef source) = ModifierExpr;  // D&D (score-10)/2 floored
}

enum AggregateOp { sum, product, min, max, concat, append, replace }
enum ArithOp { add, subtract, multiply, divide }
```

### 6.5 RuleEffect (lines 163-197)

```dart
@Freezed(unionKey: 'type')
abstract class RuleEffect with _$RuleEffect {
  // write computed value to target field
  const factory RuleEffect.setValue({
    required String targetFieldKey,
    required ValueExpression value,
  }) = SetValueEffect;

  // "to be equipped" — block equip if predicate false
  const factory RuleEffect.gateEquip({
    @Default('') String blockReason,
  }) = GateEquipEffect;

  // "when equipped" — apply modifier only when item is equipped
  const factory RuleEffect.modifyWhileEquipped({
    required String targetFieldKey,
    required ValueExpression value,
  }) = ModifyWhileEquippedEffect;

  // visual styling on list items
  const factory RuleEffect.styleItems({
    required String listFieldKey,
    required ItemStyle style,
  }) = StyleItemsEffect;
}

@freezed
abstract class ItemStyle with _$ItemStyle {
  const factory ItemStyle({
    @Default(false) bool faded,
    @Default(false) bool strikethrough,
    String? color,      // hex
    String? tooltip,
    String? icon,       // Material icon name
  }) = _ItemStyle;
}
```

### 6.6 Rule Examples

**Copy race speed to base_speed**:
```dart
RuleV2(
  ruleId: 'r1', name: 'Pull Race Speed',
  when_: Predicate.always(),
  then_: RuleEffect.setValue(
    targetFieldKey: 'base_speed',
    value: ValueExpression.fieldValue(
      FieldRef(scope: RefScope.related, fieldKey: 'speed', relationFieldKey: 'race_ref'),
    ),
  ),
)
```

**Sum equipped bonuses**:
```dart
RuleV2(
  ruleId: 'r2', name: 'Total Bonus',
  when_: Predicate.always(),
  then_: RuleEffect.setValue(
    targetFieldKey: 'total_bonus',
    value: ValueExpression.aggregate(
      relationFieldKey: 'equipment',
      sourceFieldKey: 'bonus',
      op: AggregateOp.sum,
      onlyEquipped: true,
    ),
  ),
)
```

**Gate equip by STR**:
```dart
RuleV2(
  ruleId: 'r3', name: 'Require STR 15',
  when_: Predicate.compare(
    left: FieldRef(scope: RefScope.self, fieldKey: 'stat_block', nestedFieldKey: 'STR'),
    op: CompareOp.gte,
    literalValue: 15,
  ),
  then_: RuleEffect.gateEquip(blockReason: 'Requires STR 15+'),
)
```

**Fade unknown spells**:
```dart
RuleV2(
  ruleId: 'r4', name: 'Dim Unknown Spells',
  when_: Predicate.compare(
    left: FieldRef(scope: RefScope.self, fieldKey: 'known_spells'),
    op: CompareOp.notContains,
    right: FieldRef(scope: RefScope.self, fieldKey: 'id'),
  ),
  then_: RuleEffect.styleItems(
    listFieldKey: 'spells',
    style: ItemStyle(faded: true, tooltip: 'Unknown'),
  ),
)
```

---

## 7. RuleEngineV2

**File**: [flutter_app/lib/application/services/rule_engine_v2.dart](flutter_app/lib/application/services/rule_engine_v2.dart)

### 7.1 API

```dart
class RuleEvaluationResult {
  final Map<String, dynamic> computedValues;     // fieldKey → value
  final Map<String, ItemStyle> itemStyles;       // entityId → style
  final Map<String, String> equipGates;          // entityId → blockReason
  final Map<String, dynamic> equippedModifiers;  // fieldKey → aggregated value
}

static RuleEvaluationResult evaluate({
  required Entity entity,
  required EntityCategorySchema category,
  required Map<String, Entity> allEntities,
});
```

### 7.2 Execution (lines 43-125)

1. Collect manual-only base for relation lists (preserves manually-added items)
2. Sort rules by priority ascending
3. For each enabled rule:
   - Evaluate `when_` predicate in entity context
   - If true, execute `then_` effect:
     - **setValue** → merge manual + rule-sourced items (tagged `source: 'rule:{ruleId}'`)
     - **gateEquip** → add entry to equipGates
     - **modifyWhileEquipped** → accumulate into equippedModifiers
     - **styleItems** → set style per item
4. Return aggregated result

### 7.3 Safety

- **Depth limit**: 3 levels of relation traversal (no infinite loops)
- **Conflict**: later rules override earlier; manual items preserved in lists
- **Equipped filter**: `onlyEquipped: true` skips items where `equipped != true`
- **Source tagging**: rule-generated list items marked `source: 'rule:{ruleId}'` for filtering/UI

### 7.4 Stringification

```dart
static String stringify(ValueExpression expr);  // human-readable formula for UI
```

---

## 8. Entity (Runtime Instance)

**File**: [flutter_app/lib/domain/entities/entity.dart](flutter_app/lib/domain/entities/entity.dart)

```dart
@freezed
abstract class Entity with _$Entity {
  const factory Entity({
    required String id,
    @Default('New Record') String name,
    required String categorySlug,
    @Default('') String source,
    @Default('') String description,
    @Default([]) List<String> images,
    @Default([]) List<String> tags,
    @Default('') String dmNotes,
    @Default([]) List<String> pdfs,
    String? locationId,
    @Default({}) Map<String, dynamic> fields,   // fieldKey → value
  }) = _Entity;
}
```

### Example JSON

```json
{
  "id": "npc-gandalf",
  "name": "Gandalf",
  "categorySlug": "npc",
  "fields": {
    "level": 20,
    "class": "wizard",
    "stat_block": {"STR":8,"DEX":10,"CON":13,"INT":18,"WIS":16,"CHA":14},
    "spells": [
      {"id":"spell-fireball","equipped":true,"source":"manual"},
      {"id":"spell-shield","equipped":true,"source":"rule:auto_cantrips"}
    ],
    "equipment": [
      {"id":"item-staff","equipped":true,"source":"manual"}
    ]
  }
}
```

---

## 9. JSON Shapes

### Rule — SetValue

```json
{
  "ruleId": "rule-1",
  "name": "Pull Race Speed",
  "enabled": true,
  "when": { "type": "always" },
  "then": {
    "type": "setValue",
    "targetFieldKey": "base_speed",
    "value": {
      "type": "fieldValue",
      "source": {
        "scope": "related",
        "fieldKey": "speed",
        "relationFieldKey": "race_ref"
      }
    }
  },
  "priority": 0
}
```

### Rule — GateEquip

```json
{
  "ruleId": "rule-2",
  "name": "Require Strength",
  "when": {
    "type": "compare",
    "left": {"scope":"self","fieldKey":"stat_block","nestedFieldKey":"STR"},
    "op": "gte",
    "literal": 15
  },
  "then": {
    "type": "gateEquip",
    "blockReason": "Requires STR 15+"
  }
}
```

### Rule — Aggregate SetValue

```json
{
  "ruleId": "rule-3",
  "name": "Total Equipment Bonus",
  "when": { "type": "always" },
  "then": {
    "type": "setValue",
    "targetFieldKey": "total_bonus",
    "value": {
      "type": "aggregate",
      "relationFieldKey": "equipment",
      "sourceFieldKey": "bonus",
      "op": "sum",
      "onlyEquipped": true
    }
  }
}
```

---

## 10. Storage

### 10.1 Local — Drift SQLite

**File**: [flutter_app/lib/data/database/tables/world_schemas_table.dart](flutter_app/lib/data/database/tables/world_schemas_table.dart)

Table: `world_schemas`

```
id                    TEXT PK
campaignId            TEXT
name                  TEXT
version               TEXT
baseSystem            TEXT
description           TEXT
categoriesJson        TEXT  (JSONB: List<EntityCategorySchema>)
encounterConfigJson   TEXT  (JSONB: EncounterConfig)
encounterLayoutsJson  TEXT  (JSONB: List<EncounterLayout>)
metadataJson          TEXT  (JSONB)
templateId            TEXT  (source schemaId)
templateHash          TEXT  (current content hash)
templateOriginalHash  TEXT  (frozen lineage hash)
createdAt, updatedAt  DATETIME
```

**Fields, groups, rules all live nested inside `categoriesJson`**.

### 10.2 Cloud — Supabase

**File**: [supabase/migrations/001_cloud_backups.sql](supabase/migrations/001_cloud_backups.sql) (lines 15-41)

```sql
CREATE TABLE public.cloud_backups (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  item_name TEXT NOT NULL,
  item_id TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'world',  -- 'world' | 'template' | 'package'
  storage_path TEXT NOT NULL,          -- {user_id}/{type}s/{item_id}.json.gz
  size_bytes BIGINT NOT NULL,
  entity_count INT NOT NULL,
  schema_version INT NOT NULL,
  app_version TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

Templates stored as gzip JSON at `{user_id}/templates/{schemaId}.json.gz`.

### 10.3 Providers

**File**: [flutter_app/lib/application/providers/template_provider.dart](flutter_app/lib/application/providers/template_provider.dart)

```dart
final allTemplatesProvider = FutureProvider<List<WorldSchema>>(...);

class ActiveTemplateNotifier extends StateNotifier<String?> {
  void open(WorldSchema schema);
  Future<void> save();
}
```

---

## 11. UI Layer

| Concern | File |
|---------|------|
| Fullscreen template editor (undo/redo, autosave) | [flutter_app/lib/presentation/screens/templates/template_editor_screen.dart](flutter_app/lib/presentation/screens/templates/template_editor_screen.dart) |
| Left sidebar (categories) + right detail panel | [flutter_app/lib/presentation/screens/hub/template_editor.dart](flutter_app/lib/presentation/screens/hub/template_editor.dart) |
| Per-category editor (fields/groups/rules UI) | same file, lines 376-800 |
| Rule builder dialog (4-tab: Set/Gate/Equip/Style) | [flutter_app/lib/presentation/dialogs/rule_builder_dialog.dart](flutter_app/lib/presentation/dialogs/rule_builder_dialog.dart) |
| FieldType → Widget factory | [flutter_app/lib/presentation/widgets/field_widgets/field_widget_factory.dart](flutter_app/lib/presentation/widgets/field_widgets/field_widget_factory.dart) |

### FieldType → Widget mapping

| FieldType | Widget |
|-----------|--------|
| text, textarea | TextFormField |
| markdown | MarkdownTextArea (editor + preview + @mention) |
| integer, float_ | NumericField |
| boolean_ | Checkbox |
| enum_ | Dropdown (allowedValues) |
| date | DateField |
| image | ImageFieldWidget (gallery) |
| file, pdf | FilePickerWidget |
| relation | ReferenceListWidget (entity selector + equip checkbox) |
| statBlock | StatBlockFieldWidget (6 ability scores) |
| combatStats | CombatStatsFieldWidget (subFields) |
| conditionStats | ConditionStatsFieldWidget |
| dice | DiceFieldWidget (2d6+5 parser) |
| slot | SlotFieldWidget (checkbox matrix) |
| proficiencyTable | ProficiencyTableWidget |
| levelTable | LevelTableFieldWidget |
| tagList | TagListFieldWidget |

---

## 12. Relationships Diagram

```
WorldSchema
├─ schemaId, originalHash
├─ EntityCategorySchema[]
│   ├─ FieldSchema[]
│   │   ├─ fieldKey, label, fieldType
│   │   ├─ validation (FieldValidation)
│   │   ├─ visibility (shared/dmOnly/private)
│   │   └─ groupId → FieldGroup.groupId
│   ├─ FieldGroup[]
│   │   ├─ groupId, gridColumns, orderIndex
│   │   └─ (pure UI layout, no semantics)
│   └─ RuleV2[]
│       ├─ when: Predicate
│       │   └─ FieldRef(scope: self|related|relatedItems)
│       └─ then: RuleEffect
│           ├─ setValue(fieldKey, ValueExpression)
│           ├─ gateEquip(blockReason)
│           ├─ modifyWhileEquipped(fieldKey, ValueExpression)
│           └─ styleItems(listFieldKey, ItemStyle)
│
Entity (runtime)
├─ categorySlug → EntityCategorySchema.slug
└─ fields: Map<fieldKey, dynamic>
    ├─ scalars
    ├─ nested maps (stat_block.STR)
    └─ relation lists [{id, equipped, source}]
```

---

## 13. Data Flow (Runtime)

```
1. User defines fields/groups/rules in TemplateEditor
   → WorldSchema saved to Drift (local) + Supabase (cloud)

2. User creates Entity (e.g. new NPC)
   → UI reads category schema
   → FieldWidgetFactory maps FieldType → Widget
   → User fills values into entity.fields map

3. On read/display, RuleEngineV2.evaluate() runs:
   - iterate rules sorted by priority
   - evaluate when_ predicate (walk self/related/relatedItems)
   - apply then_ effect if true
   - collect {computedValues, itemStyles, equipGates, equippedModifiers}

4. UI merges raw entity.fields + computed values
   - shows computed values as read-only with formula (via stringify)
   - blocks equip toggle if entity in equipGates
   - applies faded/strikethrough/color/tooltip/icon per itemStyles
```

---

## 14. Key File Index

| Concern | Path |
|---------|------|
| WorldSchema | lib/domain/entities/schema/world_schema.dart |
| EntityCategorySchema | lib/domain/entities/schema/entity_category_schema.dart |
| FieldSchema, FieldType, FieldValidation, FieldVisibility | lib/domain/entities/schema/field_schema.dart |
| FieldGroup | lib/domain/entities/schema/field_group.dart |
| RuleV2, Predicate, RuleEffect, ValueExpression, FieldRef, enums | lib/domain/entities/schema/rule_v2.dart |
| Entity | lib/domain/entities/entity.dart |
| Default D&D 5e schema builder | lib/domain/entities/schema/default_dnd5e_schema.dart |
| RuleEngineV2 (evaluation) | lib/application/services/rule_engine_v2.dart |
| Template provider (Riverpod) | lib/application/providers/template_provider.dart |
| Drift table | lib/data/database/tables/world_schemas_table.dart |
| Supabase migration | supabase/migrations/001_cloud_backups.sql |
| Template editor screen | lib/presentation/screens/templates/template_editor_screen.dart |
| Category editor panel | lib/presentation/screens/hub/template_editor.dart |
| Rule builder dialog | lib/presentation/dialogs/rule_builder_dialog.dart |
| Field widget factory | lib/presentation/widgets/field_widgets/field_widget_factory.dart |
| RuleEngineV2 tests | test/application/rule_engine_v2_test.dart |

All paths rooted at `/home/eren/GitHub/dungeon-master-tool/flutter_app/` unless noted.

---

## 15. Quick Reference Cheatsheet

| Concept | One-liner |
|---------|-----------|
| WorldSchema | Top-level template holding all categories |
| EntityCategorySchema | One entity type (NPC/Item/Spell...) with fields+groups+rules |
| FieldSchema | Single data point, 15 types, belongs to a group |
| FieldGroup | Visual layout bucket (no data semantics) |
| RuleV2 | `when: Predicate` + `then: RuleEffect`, sorted by priority |
| Predicate | always / compare / and / or / not |
| RuleEffect | setValue / gateEquip / modifyWhileEquipped / styleItems |
| ValueExpression | literal / fieldValue / aggregate / arithmetic / tableLookup / modifier |
| FieldRef | (scope, fieldKey, relationFieldKey?, nestedFieldKey?) |
| RefScope | self / related (single ref) / relatedItems (list aggregate) |
| Entity | Runtime instance with `fields: Map<String, dynamic>` |
| RuleEngineV2.evaluate | Returns computedValues + itemStyles + equipGates + equippedModifiers |

Core design principle: **game mechanics are data, not code.** Add new mechanic = define fields + rules, not write Dart.
