# 14 — Package System Redesign (DnD 5e Native)

> **For Claude.** Replace template-coupled packages with DnD5e-native typed content packs.
> **Target:** `flutter_app/lib/domain/dnd5e/package/`, `flutter_app/lib/application/dnd5e/package/`

## What Packages Contain (DnD 5e)

A package is a bundle of typed content + metadata, exportable as a single file.

```dart
// flutter_app/lib/domain/dnd5e/package/dnd5e_package.dart

class Dnd5ePackage {
  final String id;                      // UUID
  final String name;                    // 'Forgotten Realms Bestiary v1'
  final String authorId;                // user UUID
  final String authorName;
  final String version;                 // semver '1.2.0'
  final String gameSystemId;            // always 'dnd5e' for this format
  final String formatVersion;           // '1' (this spec)
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final List<String> tags;              // 'monsters', 'homebrew', 'official-style'

  // Content (any subset can be present; package can be partial)
  final List<Spell> spells;
  final List<Monster> monsters;
  final List<Item> items;               // weapons, armor, magic items, gear
  final List<Feat> feats;
  final List<Background> backgrounds;
  final List<Species> species;
  final List<CharacterClass> classes;
  final List<Subclass> subclasses;

  // Optional auxiliary content
  final List<Encounter> encounters;     // pre-built encounters
  final List<NpcTemplate> npcs;         // recurring NPC stat blocks

  // Hash for integrity check
  final String contentHash;             // sha256 of content (excluding metadata)
}
```

**Content packs are immutable on import.** Each entity gets a fresh local UUID at import time; the package's UUIDs become source IDs for traceability.

## File Format

Single JSON file with `.dnd5e-pkg.json` extension. Optionally bundled as `.zip` if including images.

```json
{
  "format": "dnd5e-pkg/1",
  "metadata": {
    "id": "uuid",
    "name": "...",
    "version": "1.0.0",
    "gameSystemId": "dnd5e",
    "author": { "id": "...", "name": "..." },
    "createdAt": "ISO8601",
    "description": "...",
    "tags": ["monsters", "homebrew"]
  },
  "content": {
    "spells": [ /* array of Spell objects (see 01) */ ],
    "monsters": [ /* array of Monster objects */ ],
    "items": [ /* polymorphic — itemType discriminator */ ],
    "feats": [],
    "backgrounds": [],
    "species": [],
    "classes": [],
    "subclasses": [],
    "encounters": [],
    "npcs": []
  },
  "contentHash": "sha256:abc..."
}
```

## Package Importer

```dart
// flutter_app/lib/application/dnd5e/package/package_importer.dart

class Dnd5ePackageImporter implements PackageImporter {
  final SpellRepository spellRepo;
  final MonsterRepository monsterRepo;
  // ... others

  @override
  Future<PackageImportResult> import(File file) async {
    final json = await _readPackageFile(file);
    final pkg = _parsePackage(json);
    _validateHash(pkg);

    if (pkg.gameSystemId != 'dnd5e') {
      return PackageImportResult.error('Package is not for D&D 5e (got: ${pkg.gameSystemId})');
    }

    final report = ImportReport();

    // 1. Import each content type. Remap IDs to local UUIDs.
    final spellIdMap = await _importSpells(pkg.spells, pkg.id, report);
    final itemIdMap = await _importItems(pkg.items, pkg.id, report);
    final monsterIdMap = await _importMonsters(pkg.monsters, pkg.id, report);
    final featIdMap = await _importFeats(pkg.feats, pkg.id, report);
    final bgIdMap = await _importBackgrounds(pkg.backgrounds, pkg.id, report);
    final spIdMap = await _importSpecies(pkg.species, pkg.id, report);
    final classIdMap = await _importClasses(pkg.classes, pkg.id, report);
    final subIdMap = await _importSubclasses(pkg.subclasses, pkg.id, report);

    // 2. Cross-reference fixup (e.g., subclass → class, monster → spell).
    await _fixupReferences(pkg, {
      'spell': spellIdMap, 'item': itemIdMap, 'monster': monsterIdMap,
      'feat': featIdMap, 'background': bgIdMap, 'species': spIdMap,
      'class': classIdMap, 'subclass': subIdMap,
    });

    // 3. Encounters / NPCs that reference monsters: same fixup.
    await _importEncountersAndNpcs(pkg, monsterIdMap, report);

    // 4. Record installed package.
    await packageRegistry.recordInstall(pkg, report);

    return PackageImportResult.success(report);
  }
}
```

## Conflict Resolution

When a package contains content that already exists locally (by source-id matching):

```dart
enum ConflictResolution {
  skip,        // keep local, ignore incoming
  overwrite,   // replace local with incoming
  duplicate,   // create as new entity (new local UUID)
}
```

User prompted per-conflict (or "apply to all"). Default = `duplicate` (safest; never destroys data).

Source-id matching: a content entity's `sourcePackageId` + original-package-content-id is the natural key. Two installs of the same pkg version → conflict on every entity.

## Package Registry

Local table tracking installed packages (out-of-scope tables to add to [03](./03-database-schema-spec.md)):

```dart
class InstalledPackages extends Table {
  TextColumn get id => text()();             // local install UUID
  TextColumn get sourcePackageId => text()();   // package's own UUID
  TextColumn get name => text()();
  TextColumn get version => text()();
  TextColumn get gameSystemId => text()();
  TextColumn get installedAt => integer()();
  TextColumn get reportJson => text()();      // count + warnings
  @override Set<Column> get primaryKey => {id};
}
```

Marketplace listings reference `sourcePackageId` so users can detect "already installed."

## Marketplace Integration

Marketplace lists Supabase-hosted packages. Backend table:

```sql
CREATE TABLE marketplace_packages (
  id UUID PRIMARY KEY,
  source_package_id UUID NOT NULL,
  name TEXT NOT NULL,
  version TEXT NOT NULL,
  game_system_id TEXT NOT NULL,
  author_id UUID NOT NULL,
  description TEXT,
  tags TEXT[],
  download_url TEXT NOT NULL,         -- Supabase Storage signed URL
  size_bytes INT,
  download_count INT DEFAULT 0,
  rating REAL,
  uploaded_at TIMESTAMPTZ
);
```

Filter by `game_system_id = 'dnd5e'` for in-app marketplace.

## Export Flow

User → "Export as Package" from any content-creation screen (custom monster, custom spell, etc.).

```dart
class PackageExporter {
  Future<File> export({
    required String name,
    required String version,
    required List<Spell> spells,
    required List<Monster> monsters,
    // ...
  }) async {
    final pkg = Dnd5ePackage(
      id: const Uuid().v4(),
      name: name,
      version: version,
      gameSystemId: 'dnd5e',
      formatVersion: '1',
      // ...
      contentHash: '',  // computed below
    );
    final json = _serialize(pkg);
    final hash = _computeContentHash(json['content']);
    json['contentHash'] = 'sha256:$hash';

    final file = File('${tempDir.path}/${name.replaceAll(' ', '_')}_v$version.dnd5e-pkg.json');
    await file.writeAsString(jsonEncode(json));
    return file;
  }
}
```

## Validation on Import

```dart
class PackageValidator {
  List<ValidationIssue> validate(Dnd5ePackage pkg) {
    final issues = <ValidationIssue>[];
    if (pkg.formatVersion != '1') issues.add(ValidationIssue.error('Unsupported format version'));
    if (pkg.gameSystemId != 'dnd5e') issues.add(ValidationIssue.error('Wrong game system'));

    for (final spell in pkg.spells) {
      if (spell.level.value < 0 || spell.level.value > 9) issues.add(...);
      if (spell.name.isEmpty) issues.add(...);
    }
    for (final monster in pkg.monsters) {
      if (monster.statBlock.cr.value < 0 || monster.statBlock.cr.value > 30) issues.add(...);
    }
    // ... etc.
    return issues;
  }
}
```

## Backwards Compat (Old Template Packages)

**Not supported.** Old template-format `.json` files fail import with clear message: "This package was made for the old template system, which is no longer supported. Ask the package author for a D&D 5e native version."

## Acceptance

- Import a sample package containing 10 spells, 5 monsters, 3 items, 1 background → all show up in respective catalogs.
- Conflict resolution prompt fires on second install of same package.
- Export → import round-trip preserves all content (hash matches).
- Marketplace shows DnD 5e packages only when current campaign is DnD 5e.
- `flutter test` covers serialization, hash, conflict resolution.

## Open Questions

1. Should images / portrait files be bundled as `.zip`? → MVP: JSON only. Images via URL. Bundle support later.
2. Versioning scheme: semver or sequential? → **Semver** for human readability.
3. Signed packages (cryptographic signature)? → Out of scope. Trust-based marketplace; flagging system instead.
