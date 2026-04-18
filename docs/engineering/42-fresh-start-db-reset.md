# 42 — Fresh Start DB Reset (v4 → v5)

> **For Claude.** v5 = drop+recreate. No data preservation. User-facing notice required.

## Decision

Per scope decisions in [README.md](./README.md): **fresh start, no migration script**. Existing template-derived data is destroyed on upgrade.

Rationale:
- Template data structure is incompatible with typed DnD5e domain model.
- Mapping template fields to typed entities is error-prone; inconsistent results.
- Effort > value for a tool with active iteration phase.

## Implementation

### Schema Migration (already in [03](./03-database-schema-spec.md))

```dart
@override
int get schemaVersion => 5;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 5) {
      await _resetDatabase(m);
    }
  },
);

Future<void> _resetDatabase(Migrator m) async {
  // Drop all v4 tables.
  for (final t in [...allTables].reversed) {
    try { await m.deleteTable(t.actualTableName); } catch (_) { /* ignore if missing */ }
  }
  // Drop legacy template-only tables not in v5 schema.
  for (final legacy in ['world_schemas', 'entities', 'package_schemas']) {
    try { await m.customStatement('DROP TABLE IF EXISTS $legacy'); } catch (_) {}
  }
  // Create v5 schema.
  await m.createAll();
}
```

### File-Based Cleanup

Templates and packages had on-disk caches. Purge on first launch v5:

```dart
// flutter_app/lib/data/storage/legacy_data_purger.dart

class LegacyDataPurger {
  Future<void> purge() async {
    final cacheDir = await getApplicationCacheDirectory();
    for (final subdir in ['templates', 'package_cache_v4', 'rule_eval_cache']) {
      final dir = Directory('${cacheDir.path}/$subdir');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    // Also purge SharedPreferences keys with v4 prefix.
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs.getKeys().where((k) => k.startsWith('template_') || k.startsWith('rule_'));
    for (final k in keysToRemove) await prefs.remove(k);
  }
}
```

Invoked once on app start if SharedPreferences flag `v5_reset_complete != true`:

```dart
class AppBootstrap {
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('v5_reset_complete') != true) {
      await LegacyDataPurger().purge();
      await prefs.setBool('v5_reset_complete', true);
    }
    // Continue normal init...
  }
}
```

## User-Facing Notice

If app detects upgrade from v4 (Drift `from < 5` triggered, OR `v5_reset_complete` flag was just set), show one-time dialog on first launch after upgrade:

```dart
class UpgradeNoticeDialog extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return AlertDialog(
      title: const Text('Big update'),
      content: const Text(
        'This version replaces the previous flexible Template system with native D&D 5e support.\n\n'
        'Your previous campaigns, characters, and templates have been removed because they cannot be automatically converted to the new format.\n\n'
        'Going forward, all D&D 5e content is built-in and you can install community packages from the Marketplace.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
      ],
    );
  }
}
```

Trigger:

```dart
class AppBootstrap {
  Future<void> initialize() async {
    // ...
    if (_wasJustUpgraded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(context: navigatorKey.currentContext!, builder: (_) => UpgradeNoticeDialog());
      });
    }
  }

  bool _wasJustUpgraded = false;   // set in initialize() based on prefs flag transition
}
```

## Backup Recommendation (Optional Pre-Upgrade)

Optional: detect v4 install before upgrade via build-time version constant or PREFS flag. If detected, before purging, copy old DB file to `{appDocs}/backups/{timestamp}_v4_db.sqlite`. Show in dialog: "A backup was saved at ..."

```dart
Future<void> _backupV4DbBeforeReset() async {
  final dbPath = await _getCurrentDbPath();
  final backupDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'backups'));
  await backupDir.create(recursive: true);
  final backupPath = p.join(backupDir.path, '${DateTime.now().millisecondsSinceEpoch}_v4_db.sqlite');
  await File(dbPath).copy(backupPath);
}
```

User can manually inspect backup with SQLite tools if desired. App does NOT restore.

## Release Notes Snippet

```
# v5.0.0 — Native D&D 5e

## ⚠ Breaking Change
This update removes the Template system in favor of built-in D&D 5e support.

**Existing campaigns, characters, and templates will be lost on update.**
A backup of your previous database is saved to your app documents folder if you need to extract data manually.

## What's New
- Native D&D 5e mechanics (no JSON config needed)
- Online multiplayer via game codes
- Character creation wizard
- Visual spell AoE markers
- Improved combat tracker
- Marketplace packages for adding monsters, spells, items

## What's Removed
- Custom templates (replaced by built-in D&D 5e)
- Template editor screens
- Template marketplace listings
```

## Acceptance

- Fresh install on never-used device: v5 schema created; no purge needed.
- Existing v4 install: upgrade triggers DB drop+recreate; cache files purged; notice shown once.
- Backup file present in `{appDocs}/backups/` (if optional backup enabled).
- After dismissal of notice, app proceeds normally with empty state.
- `v5_reset_complete` flag persists; notice not re-shown on subsequent launches.

## Open Questions

1. Should the backup be enabled by default or opt-in? → **Default ON.** Small disk cost; user-friendly.
2. Allow downgrade back to v4? → No. One-way upgrade.
3. Provide a script to extract template content from backup for re-import? → Out of scope. Marketplace is the path forward for content.
