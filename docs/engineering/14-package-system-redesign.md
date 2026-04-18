# 14 — Package System Redesign (DnD 5e Native)

> **For Claude.** Replace template-coupled packages with DnD5e-native typed content packs.
> **Target:** `flutter_app/lib/domain/dnd5e/package/`, `flutter_app/lib/application/dnd5e/package/`
> **Format version:** `dnd5e-pkg/2` (bumped from `/1` to add catalog content types and namespaced ids — see [01-domain-model-spec.md](./01-domain-model-spec.md)).

## What Packages Contain (DnD 5e)

A package is a bundle of typed content + metadata, exportable as a single file. Packages are the **only** vehicle for concrete D&D content; the built-in dnd5e module ships *mechanics* (rules engine, effect DSL, type shapes) and zero content. See [15-srd-core-package.md](./15-srd-core-package.md) for the bundle that ships the SRD 5.2.1 content.

```dart
// flutter_app/lib/domain/dnd5e/package/dnd5e_package.dart

class Dnd5ePackage {
  final String id;                      // UUID; becomes the catalog-id namespace for contained entities
  final String name;                    // 'Forgotten Realms Bestiary v1'
  final String authorId;                // user UUID
  final String authorName;
  final String version;                 // semver '1.2.0'
  final String gameSystemId;            // always 'dnd5e' for this format
  final String formatVersion;           // '2' (this spec)
  final String packageIdSlug;           // e.g. 'srd', 'arctic_homebrew' — used as id prefix
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String sourceLicense;           // package-level, e.g. 'CC BY 4.0'
  final List<String> tags;              // 'monsters', 'homebrew', 'official-style'
  final List<String> requiredRuntimeExtensions;  // CustomEffect.implementationId values assumed present

  // --- Catalog content (Tier 1 mechanic primitives) ---
  final List<Condition> conditions;
  final List<DamageType> damageTypes;
  final List<Skill> skills;
  final List<Size> sizes;
  final List<CreatureType> creatureTypes;
  final List<Alignment> alignments;
  final List<Language> languages;
  final List<SpellSchool> spellSchools;
  final List<WeaponProperty> weaponProperties;
  final List<WeaponMastery> weaponMasteries;
  final List<ArmorCategory> armorCategories;
  final List<Rarity> rarities;

  // --- Entity content ---
  final List<Spell> spells;
  final List<Monster> monsters;
  final List<Item> items;               // weapons, armor, magic items, gear
  final List<Feat> feats;
  final List<Background> backgrounds;
  final List<Species> species;
  final List<CharacterClass> classes;
  final List<Subclass> subclasses;

  // --- Optional auxiliary content ---
  final List<Encounter> encounters;     // pre-built encounters
  final List<NpcTemplate> npcs;         // recurring NPC stat blocks

  // Hash for integrity check
  final String contentHash;             // sha256 of content (excluding metadata)
}
```

**Content packs are immutable on import.** Each entity carries a namespaced id of shape `<packageIdSlug>:<localId>` (e.g. `srd:stunned`, `arctic_homebrew:frozen`). Internal cross-references inside the package may use bare local ids; the importer rewrites them to fully-namespaced form pre-write. Collisions between unrelated packages are impossible by construction.

## File Format

Single JSON file with `.dnd5e-pkg.json` extension. Optionally bundled as `.zip` if including images.

```json
{
  "format": "dnd5e-pkg/2",
  "metadata": {
    "id": "uuid",
    "packageIdSlug": "srd",
    "name": "...",
    "version": "1.0.0",
    "gameSystemId": "dnd5e",
    "author": { "id": "...", "name": "..." },
    "createdAt": "ISO8601",
    "description": "...",
    "sourceLicense": "CC BY 4.0",
    "tags": ["monsters", "homebrew"],
    "requiredRuntimeExtensions": ["srd:wish", "srd:wild_shape"]
  },
  "content": {
    "conditions": [ /* array of Condition objects (see 01) */ ],
    "damageTypes": [],
    "skills": [],
    "sizes": [],
    "creatureTypes": [],
    "alignments": [],
    "languages": [],
    "spellSchools": [],
    "weaponProperties": [],
    "weaponMasteries": [],
    "armorCategories": [],
    "rarities": [],
    "spells": [ /* array of Spell objects */ ],
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

    // 0. Runtime extension check.
    for (final extId in pkg.requiredRuntimeExtensions) {
      if (customEffectRegistry.byId(extId) == null) {
        return PackageImportResult.error(
          'Package requires runtime extension "$extId" which is not registered.');
      }
    }

    final report = ImportReport();

    // 1. Rewrite local ids to namespaced form: '<slug>:<localId>'.
    //    Internal cross-refs inside the package resolve here.
    final normalized = _namespaceAndResolve(pkg);

    // 2. Import catalog content first (entities may reference these).
    await _importConditions(normalized.conditions, report);
    await _importDamageTypes(normalized.damageTypes, report);
    await _importSkills(normalized.skills, report);
    await _importSizes(normalized.sizes, report);
    await _importCreatureTypes(normalized.creatureTypes, report);
    await _importAlignments(normalized.alignments, report);
    await _importLanguages(normalized.languages, report);
    await _importSpellSchools(normalized.spellSchools, report);
    await _importWeaponProperties(normalized.weaponProperties, report);
    await _importWeaponMasteries(normalized.weaponMasteries, report);
    await _importArmorCategories(normalized.armorCategories, report);
    await _importRarities(normalized.rarities, report);

    // 3. Import entity content.
    await _importSpells(normalized.spells, report);
    await _importItems(normalized.items, report);
    await _importMonsters(normalized.monsters, report);
    await _importFeats(normalized.feats, report);
    await _importBackgrounds(normalized.backgrounds, report);
    await _importSpecies(normalized.species, report);
    await _importClasses(normalized.classes, report);
    await _importSubclasses(normalized.subclasses, report);

    // 4. Validate all ContentReferences resolve (inside package or already-installed catalog).
    final danglingRefs = contentRegistryValidator.validate(normalized);
    if (danglingRefs.isNotEmpty) {
      return PackageImportResult.error(
        'Dangling references: ${danglingRefs.take(5).join(', ')}...');
    }

    // 5. Encounters / NPCs reference monsters + spells.
    await _importEncountersAndNpcs(normalized, report);

    // 6. Record installed package.
    await packageRegistry.recordInstall(pkg, report);

    return PackageImportResult.success(report);
  }
}
```

## Conflict Resolution

Catalog-id collisions between *different* packages are impossible by design (ids are namespaced by `packageIdSlug`). Conflicts only fire on **same-source re-installs** — e.g. `srd` v1 is already installed and the user imports `srd` v2.

```dart
enum ConflictResolution {
  skip,        // keep local, ignore incoming
  overwrite,   // replace local with incoming (upgrade path)
  duplicate,   // create side-by-side install (new packageIdSlug suffix, e.g. 'srd_2')
}
```

User prompted per-package (not per-entity). Default for same-source upgrades = `overwrite`. Default for unrecognized collisions = `duplicate`.

Source-id matching: a content entity's `(packageIdSlug, version, localId)` is the natural key. The `source_package_id` column on each catalog table records the installing package for traceability.

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
    if (pkg.formatVersion != '2') issues.add(ValidationIssue.error('Unsupported format version (expected 2)'));
    if (pkg.gameSystemId != 'dnd5e') issues.add(ValidationIssue.error('Wrong game system'));
    if (pkg.packageIdSlug.isEmpty || !_slugPattern.hasMatch(pkg.packageIdSlug)) {
      issues.add(ValidationIssue.error('packageIdSlug must match [a-z][a-z0-9_]{0,31}'));
    }

    for (final c in pkg.conditions) {
      if (c.name.isEmpty) issues.add(...);
      for (final e in c.effects) _validateEffectDescriptor(e, issues);
    }
    for (final spell in pkg.spells) {
      if (spell.level.value < 0 || spell.level.value > 9) issues.add(...);
      if (spell.name.isEmpty) issues.add(...);
      for (final e in spell.effects) _validateEffectDescriptor(e, issues);
    }
    for (final monster in pkg.monsters) {
      if (monster.statBlock.cr.value < 0 || monster.statBlock.cr.value > 30) issues.add(...);
    }
    // ... etc. per catalog type.
    return issues;
  }
}
```

`_validateEffectDescriptor` ensures any `CustomEffect.implementationId` it encounters appears in `pkg.requiredRuntimeExtensions`, and any catalog `ContentReference` resolves locally or is declared as an external dependency.

## Backwards Compat (Old Template Packages)

**Not supported.** Old template-format `.json` files fail import with clear message: "This package was made for the old template system, which is no longer supported. Ask the package author for a D&D 5e native version."

## Acceptance

- Import a sample package containing 3 conditions, 2 damage types, 10 spells, 5 monsters, 3 items, 1 background → all show up in respective catalogs with `<slug>:<localId>` ids.
- Import fails with clear error when a package declares a `requiredRuntimeExtensions` id the app doesn't have.
- Import fails with clear error when a `ContentReference` is dangling and not provided by an already-installed package.
- Conflict prompt fires only on same-source re-install (e.g. `srd` already installed, user re-imports `srd`); never on cross-package id reuse.
- Export → import round-trip preserves all content (hash matches, ids round-trip identically after re-namespacing).
- Marketplace shows DnD 5e packages only when current campaign is DnD 5e.
- `flutter test` covers serialization, hash, conflict resolution, id namespacing, runtime-extension validation.

## Open Questions

1. Should images / portrait files be bundled as `.zip`? → MVP: JSON only. Images via URL. Bundle support later.
2. Versioning scheme: semver or sequential? → **Semver** for human readability.
3. Signed packages (cryptographic signature)? → Out of scope. Trust-based marketplace; flagging system instead.
