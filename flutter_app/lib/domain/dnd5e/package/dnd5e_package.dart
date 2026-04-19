import 'catalog_entry.dart';
import 'content_entry.dart';
import 'package_slug.dart';

/// Doc 14 — `dnd5e-pkg/2` container. Holds catalog + content entries
/// pre-namespacing (local ids) alongside metadata. The importer calls
/// [namespaced] to rewrite every id to `<slug>:<localId>`.
///
/// Typed per-entity content (Condition, Spell, Monster, ...) is deferred to
/// Doc 15 when per-entity JSON codecs get written; until then entries carry
/// raw `bodyJson` blobs that the importer writes verbatim to Drift.
class Dnd5ePackage {
  final String id;
  final String packageIdSlug;
  final String name;
  final String version;
  final String gameSystemId;
  final String formatVersion;
  final String authorId;
  final String authorName;
  final String sourceLicense;
  final String? description;
  final List<String> tags;
  final List<String> requiredRuntimeExtensions;

  final List<CatalogEntry> conditions;
  final List<CatalogEntry> damageTypes;
  final List<CatalogEntry> skills;
  final List<CatalogEntry> sizes;
  final List<CatalogEntry> creatureTypes;
  final List<CatalogEntry> alignments;
  final List<CatalogEntry> languages;
  final List<CatalogEntry> spellSchools;
  final List<CatalogEntry> weaponProperties;
  final List<CatalogEntry> weaponMasteries;
  final List<CatalogEntry> armorCategories;
  final List<CatalogEntry> rarities;

  final List<SpellEntry> spells;
  final List<MonsterEntry> monsters;
  final List<ItemEntry> items;
  final List<NamedEntry> feats;
  final List<NamedEntry> backgrounds;
  final List<NamedEntry> species;
  final List<SubclassEntry> subclasses;
  final List<NamedEntry> classProgressions;

  Dnd5ePackage({
    required this.id,
    required String packageIdSlug,
    required this.name,
    required this.version,
    required this.authorId,
    required this.authorName,
    this.gameSystemId = 'dnd5e',
    this.formatVersion = '2',
    this.sourceLicense = '',
    this.description,
    List<String> tags = const [],
    List<String> requiredRuntimeExtensions = const [],
    List<CatalogEntry> conditions = const [],
    List<CatalogEntry> damageTypes = const [],
    List<CatalogEntry> skills = const [],
    List<CatalogEntry> sizes = const [],
    List<CatalogEntry> creatureTypes = const [],
    List<CatalogEntry> alignments = const [],
    List<CatalogEntry> languages = const [],
    List<CatalogEntry> spellSchools = const [],
    List<CatalogEntry> weaponProperties = const [],
    List<CatalogEntry> weaponMasteries = const [],
    List<CatalogEntry> armorCategories = const [],
    List<CatalogEntry> rarities = const [],
    List<SpellEntry> spells = const [],
    List<MonsterEntry> monsters = const [],
    List<ItemEntry> items = const [],
    List<NamedEntry> feats = const [],
    List<NamedEntry> backgrounds = const [],
    List<NamedEntry> species = const [],
    List<SubclassEntry> subclasses = const [],
    List<NamedEntry> classProgressions = const [],
  })  : packageIdSlug = validatePackageSlug(packageIdSlug),
        tags = List.unmodifiable(tags),
        requiredRuntimeExtensions = List.unmodifiable(requiredRuntimeExtensions),
        conditions = List.unmodifiable(conditions),
        damageTypes = List.unmodifiable(damageTypes),
        skills = List.unmodifiable(skills),
        sizes = List.unmodifiable(sizes),
        creatureTypes = List.unmodifiable(creatureTypes),
        alignments = List.unmodifiable(alignments),
        languages = List.unmodifiable(languages),
        spellSchools = List.unmodifiable(spellSchools),
        weaponProperties = List.unmodifiable(weaponProperties),
        weaponMasteries = List.unmodifiable(weaponMasteries),
        armorCategories = List.unmodifiable(armorCategories),
        rarities = List.unmodifiable(rarities),
        spells = List.unmodifiable(spells),
        monsters = List.unmodifiable(monsters),
        items = List.unmodifiable(items),
        feats = List.unmodifiable(feats),
        backgrounds = List.unmodifiable(backgrounds),
        species = List.unmodifiable(species),
        subclasses = List.unmodifiable(subclasses),
        classProgressions = List.unmodifiable(classProgressions);

  /// Returns a copy where every content id has been rewritten to
  /// `<slug>:<localId>` and every intra-package reference (schoolId, rarityId,
  /// parentClassId) has been resolved against the same slug. Idempotent for
  /// already-namespaced ids.
  Dnd5ePackage namespaced() {
    final s = packageIdSlug;
    return Dnd5ePackage(
      id: id,
      packageIdSlug: packageIdSlug,
      name: name,
      version: version,
      authorId: authorId,
      authorName: authorName,
      gameSystemId: gameSystemId,
      formatVersion: formatVersion,
      sourceLicense: sourceLicense,
      description: description,
      tags: tags,
      requiredRuntimeExtensions: requiredRuntimeExtensions,
      conditions: conditions.map((e) => e.namespaced(s)).toList(),
      damageTypes: damageTypes.map((e) => e.namespaced(s)).toList(),
      skills: skills.map((e) => e.namespaced(s)).toList(),
      sizes: sizes.map((e) => e.namespaced(s)).toList(),
      creatureTypes: creatureTypes.map((e) => e.namespaced(s)).toList(),
      alignments: alignments.map((e) => e.namespaced(s)).toList(),
      languages: languages.map((e) => e.namespaced(s)).toList(),
      spellSchools: spellSchools.map((e) => e.namespaced(s)).toList(),
      weaponProperties: weaponProperties.map((e) => e.namespaced(s)).toList(),
      weaponMasteries: weaponMasteries.map((e) => e.namespaced(s)).toList(),
      armorCategories: armorCategories.map((e) => e.namespaced(s)).toList(),
      rarities: rarities.map((e) => e.namespaced(s)).toList(),
      spells: spells.map((e) => e.namespaced(s)).toList(),
      monsters: monsters.map((e) => e.namespaced(s)).toList(),
      items: items.map((e) => e.namespaced(s)).toList(),
      feats: feats.map((e) => e.namespaced(s)).toList(),
      backgrounds: backgrounds.map((e) => e.namespaced(s)).toList(),
      species: species.map((e) => e.namespaced(s)).toList(),
      subclasses: subclasses.map((e) => e.namespaced(s)).toList(),
      classProgressions:
          classProgressions.map((e) => e.namespaced(s)).toList(),
    );
  }
}
