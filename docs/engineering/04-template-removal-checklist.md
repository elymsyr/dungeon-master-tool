# 04 — Template Removal Checklist

> **For Claude.** Ordered file deletion + refactor steps. Each step compiles on its own (`flutter analyze` passes after each commit).
> **Total scope:** ~40 files, ~3000 LOC.

## Strategy

Remove from **leaves inward**. Order:
1. UI screens that reference template (no other dependencies).
2. Services that depend on template providers.
3. Providers that depend on template repositories/datasources.
4. Repositories / datasources.
5. Domain entities.
6. Drift table + migration cleanup.

After each step: `flutter analyze && flutter test`. Commit.

## Step 1 — Delete Template UI

```
DELETE flutter_app/lib/presentation/screens/templates/                         (entire dir)
DELETE flutter_app/lib/presentation/screens/hub/templates_tab.dart
DELETE flutter_app/lib/presentation/screens/hub/template_editor.dart
DELETE flutter_app/lib/presentation/dialogs/template_picker_dialog.dart        (if exists)
DELETE flutter_app/lib/presentation/dialogs/template_drift_dialog.dart         (if exists)
```

EDIT `presentation/screens/hub/hub_screen.dart`:
- Remove `TemplatesTab` from tab list.
- Renumber tab indices in any switch/case.

EDIT `presentation/router/app_router.dart`:
- Remove `/templates` route.
- Remove `/template/edit` route.
- Remove imports.

**Verify:** `grep -r 'templates_tab\|TemplateEditor\|template_picker' flutter_app/lib/` returns 0 hits.

## Step 2 — Delete Template Application Services

```
DELETE flutter_app/lib/application/services/template_sync_service.dart
DELETE flutter_app/lib/application/services/template_compatibility_service.dart
```

EDIT any service that imported these (likely `package_import_service.dart`):
- Remove `TemplateCompatibilityService` import.
- Replace compatibility check with constant `true` (DnD 5e packages are always compatible with DnD 5e campaigns).
- Or: delegate to new `Dnd5ePackageImporter` (planned in [14](./14-package-system-redesign.md)) — leave a `TODO(14):` comment.

## Step 3 — Delete Template Providers

```
DELETE flutter_app/lib/application/providers/template_provider.dart
```

EDIT `application/providers/campaign_provider.dart`:
- Remove `applyTemplateUpdate`, `dismissTemplateUpdate`, `muteTemplateUpdates` methods.
- Remove `templateId`, `templateHash`, `templateOriginalHash` from `ActiveCampaignState`.
- Remove drift detection logic in `loadCampaign`.
- Add `gameSystemId` field defaulting to `'dnd5e'`.

EDIT any widget consuming `activeTemplateProvider` / `allTemplatesProvider`:
- Drop the watcher.
- Replace template-name display with hardcoded "D&D 5e".

## Step 4 — Delete Template Datasources

```
DELETE flutter_app/lib/data/datasources/local/template_local_ds.dart
DELETE flutter_app/lib/data/repositories/template_repository_impl.dart        (if exists)
DELETE flutter_app/lib/domain/repositories/template_repository.dart           (if exists)
```

DELETE on-disk template cache directory (`{appCacheDir}/templates/`) — handled at runtime by app first launch v5 (see step 7).

EDIT `data/repositories/campaign_repository_impl.dart`:
- Remove template tracking in `createCampaign`, `loadCampaign`, `saveCampaign`.

## Step 5 — Delete Template Domain

```
DELETE flutter_app/lib/domain/entities/schema/                                (entire dir)
  - world_schema.dart
  - world_schema_hash.dart
  - world_schema_diff.dart
  - default_dnd5e_schema.dart
  - template_compatibility.dart
  - entity_category_schema.dart
  - field_schema.dart
  - rule_v2.dart                    (also see step 6 — moved here for grouping)
```

EDIT `domain/entities/entity.dart`:
- This file probably stays for now if other code still uses it. **Plan:** delete in subsequent task once typed Character/Monster replace it. Mark with `// TODO(01): Replace with typed Character/Monster.`

EDIT `domain/entities/session.dart`:
- Remove any template references.

## Step 6 — Delete Rule Engine V2

```
DELETE flutter_app/lib/application/services/rule_engine_v2.dart
DELETE flutter_app/lib/domain/entities/schema/rule_v2.dart                   (already in step 5 list)
DELETE flutter_app/test/application/services/rule_engine_v2_test.dart
DELETE any rule_v2_*.dart fixtures
```

See [05](./05-rule-engine-removal-spec.md) for replacement pattern.

EDIT consumers:
- `application/providers/entity_provider.dart` (or similar) — remove `RuleEngineV2.evaluate(...)` calls. Replace with `// TODO(05): Use class feature pure functions.`

## Step 7 — Drift Migration v4 → v5

EDIT `data/database/app_database.dart`:

```dart
@override
int get schemaVersion => 5;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 5) {
      // Drop everything; fresh start.
      for (final t in [...allTables].reversed) {
        try { await m.deleteTable(t.actualTableName); } catch (_) {}
      }
      await m.createAll();
      // Also delete file caches.
      await TemplateCacheCleaner.purge();
    }
  },
);
```

DELETE drift table file:
```
DELETE flutter_app/lib/data/database/tables/world_schemas_table.dart
```

Update `app_database.dart` `@DriftDatabase(tables: [...])` — remove `WorldSchemas`. Add new typed tables per [03](./03-database-schema-spec.md).

Run `dart run build_runner build --delete-conflicting-outputs`.

ADD `data/storage/template_cache_cleaner.dart`:

```dart
class TemplateCacheCleaner {
  static Future<void> purge() async {
    final dir = await getApplicationCacheDirectory();
    final templatesDir = Directory('${dir.path}/templates');
    if (await templatesDir.exists()) await templatesDir.delete(recursive: true);
  }
}
```

## Step 8 — Marketplace Cleanup

EDIT `application/providers/marketplace_listing_provider.dart`:
- Remove template filtering / template listing type.
- Listings now exclusively typed packages (DnD 5e). See [14](./14-package-system-redesign.md).

EDIT `presentation/screens/social/marketplace_tab.dart`:
- Remove "Templates" sub-tab.
- Remove template listing card variant.

## Step 9 — Final Sweep

Run greps:

```bash
grep -rn 'WorldSchema\|EntityCategorySchema\|FieldSchema\|RuleV2\|RuleEngineV2\|TemplateSync\|TemplateCompatibility\|template_id\|templateHash\|templateOriginalHash' flutter_app/lib/ flutter_app/test/
```

Expected: 0 matches outside migration code (`app_database.dart` upgrade comments OK).

Run:
```bash
cd flutter_app && flutter analyze && flutter test
```

Both must pass.

## Step 10 — Update Imports & Barrel Files

Search for now-broken imports:
```bash
grep -rn "from 'package:dungeon_master_tool/.*template" flutter_app/lib/
grep -rn "from 'package:dungeon_master_tool/.*schema/" flutter_app/lib/
```

Remove all such imports.

If any barrel file (`lib/...index.dart`) re-exported template types, prune.

## Per-Step Commit Messages

```
chore(template-removal): step 1 — delete template UI screens
chore(template-removal): step 2 — delete template services
chore(template-removal): step 3 — delete template providers
chore(template-removal): step 4 — delete template datasources/repositories
chore(template-removal): step 5 — delete template domain entities
chore(template-removal): step 6 — delete RuleEngineV2
chore(template-removal): step 7 — drift v5 migration (drop & recreate)
chore(template-removal): step 8 — marketplace cleanup
chore(template-removal): step 9 — final sweep verified clean
chore(template-removal): step 10 — pruned dead imports
```

## Regression Risk

| Feature | Risk | Mitigation |
|---|---|---|
| Existing campaigns | **Lost** (fresh start) | User-facing notice (doc 42) |
| Marketplace listings | Template listings unfetchable | Filter to package-only in step 8 |
| Imported packages | Template-typed packages broken | Doc [14](./14-package-system-redesign.md) defines new format; old packages fail import gracefully |
| Battlemap fog data | None | Stored in `encounters` table, untouched |
| Sound/PDF sidebars | None | Independent subsystems |
| Mind map | None | Independent |

## Acceptance

- 0 grep hits for any template/schema/RuleV2 identifier.
- `flutter analyze` clean.
- `flutter test` green.
- App launches on fresh install: shows D&D 5e directly with no template selection screen.
- App launches on v4-upgrade: shows "Database reset" notice (per doc 42), then proceeds to fresh state.
