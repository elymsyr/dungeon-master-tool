import 'catalog_entry.dart';
import 'content_entry.dart';
import 'dnd5e_package.dart';

/// JSON encode/decode for the `dnd5e-pkg/2` format (Doc 14 §File Format).
///
/// Wire shape (top level):
/// ```json
/// {
///   "id": "...",
///   "packageIdSlug": "srd",
///   "name": "D&D 5e SRD Core Rules",
///   "version": "1.0.0",
///   "gameSystemId": "dnd5e",
///   "formatVersion": "2",
///   "authorId": "wizards",
///   "authorName": "Wizards of the Coast",
///   "sourceLicense": "CC BY 4.0",
///   "description": null,
///   "tags": [],
///   "requiredRuntimeExtensions": [],
///   "catalogs": {
///     "conditions": [{"id": "stunned", "name": "Stunned", "body": {...}}, ...],
///     "damageTypes": [...],
///     ...
///   },
///   "content": {
///     "spells": [{"id": "fireball", "name": "Fireball", "level": 3, "schoolId": "evocation", "body": {...}}],
///     "monsters": [{"id": "goblin", "name": "Goblin", "statBlock": {...}}],
///     "items": [{"id": "longsword", "name": "Longsword", "itemType": "weapon", "rarityId": null, "body": {...}}],
///     "feats": [...],
///     "backgrounds": [...],
///     "species": [...],
///     "subclasses": [{"id": "champion", "name": "Champion", "parentClassId": "fighter", "body": {...}}],
///     "classProgressions": [...]
///   }
/// }
/// ```
///
/// `body` / `statBlock` are arbitrary JSON objects — they round-trip as
/// [Map<String, Object?>] and get serialized back into the entry's `bodyJson`
/// string column at encode time. Decoders that don't yet know how to parse a
/// specific entity's body can leave it as the blob — domain-object codecs for
/// Tier 1 entities land in later turns without touching this file.
class Dnd5ePackageCodec {
  const Dnd5ePackageCodec();

  Map<String, Object?> encode(Dnd5ePackage pkg) {
    return <String, Object?>{
      'id': pkg.id,
      'packageIdSlug': pkg.packageIdSlug,
      'name': pkg.name,
      'version': pkg.version,
      'gameSystemId': pkg.gameSystemId,
      'formatVersion': pkg.formatVersion,
      'authorId': pkg.authorId,
      'authorName': pkg.authorName,
      'sourceLicense': pkg.sourceLicense,
      'description': pkg.description,
      'tags': List<String>.from(pkg.tags),
      'requiredRuntimeExtensions':
          List<String>.from(pkg.requiredRuntimeExtensions),
      'catalogs': <String, Object?>{
        'conditions': pkg.conditions.map(_catalogToMap).toList(),
        'damageTypes': pkg.damageTypes.map(_catalogToMap).toList(),
        'skills': pkg.skills.map(_catalogToMap).toList(),
        'sizes': pkg.sizes.map(_catalogToMap).toList(),
        'creatureTypes': pkg.creatureTypes.map(_catalogToMap).toList(),
        'alignments': pkg.alignments.map(_catalogToMap).toList(),
        'languages': pkg.languages.map(_catalogToMap).toList(),
        'spellSchools': pkg.spellSchools.map(_catalogToMap).toList(),
        'weaponProperties': pkg.weaponProperties.map(_catalogToMap).toList(),
        'weaponMasteries': pkg.weaponMasteries.map(_catalogToMap).toList(),
        'armorCategories': pkg.armorCategories.map(_catalogToMap).toList(),
        'rarities': pkg.rarities.map(_catalogToMap).toList(),
      },
      'content': <String, Object?>{
        'spells': pkg.spells.map(_spellToMap).toList(),
        'monsters': pkg.monsters.map(_monsterToMap).toList(),
        'items': pkg.items.map(_itemToMap).toList(),
        'feats': pkg.feats.map(_namedToMap).toList(),
        'backgrounds': pkg.backgrounds.map(_namedToMap).toList(),
        'species': pkg.species.map(_namedToMap).toList(),
        'subclasses': pkg.subclasses.map(_subclassToMap).toList(),
        'classProgressions': pkg.classProgressions.map(_namedToMap).toList(),
      },
    };
  }

  Dnd5ePackage decode(Map<String, Object?> json) {
    final catalogs = _requireMap(json, 'catalogs');
    final content = _requireMap(json, 'content');

    return Dnd5ePackage(
      id: _requireString(json, 'id'),
      packageIdSlug: _requireString(json, 'packageIdSlug'),
      name: _requireString(json, 'name'),
      version: _requireString(json, 'version'),
      authorId: _requireString(json, 'authorId'),
      authorName: _requireString(json, 'authorName'),
      gameSystemId: _optString(json, 'gameSystemId') ?? 'dnd5e',
      formatVersion: _optString(json, 'formatVersion') ?? '2',
      sourceLicense: _optString(json, 'sourceLicense') ?? '',
      description: _optString(json, 'description'),
      tags: _optStringList(json, 'tags'),
      requiredRuntimeExtensions:
          _optStringList(json, 'requiredRuntimeExtensions'),
      conditions: _decodeCatalogList(catalogs, 'conditions'),
      damageTypes: _decodeCatalogList(catalogs, 'damageTypes'),
      skills: _decodeCatalogList(catalogs, 'skills'),
      sizes: _decodeCatalogList(catalogs, 'sizes'),
      creatureTypes: _decodeCatalogList(catalogs, 'creatureTypes'),
      alignments: _decodeCatalogList(catalogs, 'alignments'),
      languages: _decodeCatalogList(catalogs, 'languages'),
      spellSchools: _decodeCatalogList(catalogs, 'spellSchools'),
      weaponProperties: _decodeCatalogList(catalogs, 'weaponProperties'),
      weaponMasteries: _decodeCatalogList(catalogs, 'weaponMasteries'),
      armorCategories: _decodeCatalogList(catalogs, 'armorCategories'),
      rarities: _decodeCatalogList(catalogs, 'rarities'),
      spells: _decodeList(content, 'spells', _spellFromMap),
      monsters: _decodeList(content, 'monsters', _monsterFromMap),
      items: _decodeList(content, 'items', _itemFromMap),
      feats: _decodeList(content, 'feats', _namedFromMap),
      backgrounds: _decodeList(content, 'backgrounds', _namedFromMap),
      species: _decodeList(content, 'species', _namedFromMap),
      subclasses: _decodeList(content, 'subclasses', _subclassFromMap),
      classProgressions:
          _decodeList(content, 'classProgressions', _namedFromMap),
    );
  }
}

// ----------------------------------------------------------------------------
// Entry <-> Map helpers.
// ----------------------------------------------------------------------------

Map<String, Object?> _catalogToMap(CatalogEntry e) => <String, Object?>{
      'id': e.id,
      'name': e.name,
      'body': e.bodyJson,
    };

CatalogEntry _catalogFromMap(Map<String, Object?> m) => CatalogEntry(
      id: _requireString(m, 'id'),
      name: _requireString(m, 'name'),
      bodyJson: _requireString(m, 'body'),
    );

Map<String, Object?> _spellToMap(SpellEntry e) => <String, Object?>{
      'id': e.id,
      'name': e.name,
      'level': e.level,
      'schoolId': e.schoolId,
      'body': e.bodyJson,
    };

SpellEntry _spellFromMap(Map<String, Object?> m) => SpellEntry(
      id: _requireString(m, 'id'),
      name: _requireString(m, 'name'),
      level: _requireInt(m, 'level'),
      schoolId: _requireString(m, 'schoolId'),
      bodyJson: _requireString(m, 'body'),
    );

Map<String, Object?> _monsterToMap(MonsterEntry e) => <String, Object?>{
      'id': e.id,
      'name': e.name,
      'statBlock': e.statBlockJson,
    };

MonsterEntry _monsterFromMap(Map<String, Object?> m) => MonsterEntry(
      id: _requireString(m, 'id'),
      name: _requireString(m, 'name'),
      statBlockJson: _requireString(m, 'statBlock'),
    );

Map<String, Object?> _itemToMap(ItemEntry e) => <String, Object?>{
      'id': e.id,
      'name': e.name,
      'itemType': e.itemType,
      'rarityId': e.rarityId,
      'body': e.bodyJson,
    };

ItemEntry _itemFromMap(Map<String, Object?> m) => ItemEntry(
      id: _requireString(m, 'id'),
      name: _requireString(m, 'name'),
      itemType: _requireString(m, 'itemType'),
      rarityId: _optString(m, 'rarityId'),
      bodyJson: _requireString(m, 'body'),
    );

Map<String, Object?> _namedToMap(NamedEntry e) => <String, Object?>{
      'id': e.id,
      'name': e.name,
      'body': e.bodyJson,
    };

NamedEntry _namedFromMap(Map<String, Object?> m) => NamedEntry(
      id: _requireString(m, 'id'),
      name: _requireString(m, 'name'),
      bodyJson: _requireString(m, 'body'),
    );

Map<String, Object?> _subclassToMap(SubclassEntry e) => <String, Object?>{
      'id': e.id,
      'name': e.name,
      'parentClassId': e.parentClassId,
      'body': e.bodyJson,
    };

SubclassEntry _subclassFromMap(Map<String, Object?> m) => SubclassEntry(
      id: _requireString(m, 'id'),
      name: _requireString(m, 'name'),
      parentClassId: _requireString(m, 'parentClassId'),
      bodyJson: _requireString(m, 'body'),
    );

// ----------------------------------------------------------------------------
// Generic list/map decoders with pointed error messages.
// ----------------------------------------------------------------------------

List<CatalogEntry> _decodeCatalogList(Map<String, Object?> m, String key) {
  return _decodeList(m, key, _catalogFromMap);
}

List<T> _decodeList<T>(
  Map<String, Object?> m,
  String key,
  T Function(Map<String, Object?>) fromMap,
) {
  final raw = m[key];
  if (raw == null) return <T>[];
  if (raw is! List) {
    throw FormatException('Field "$key" must be a JSON array (got ${raw.runtimeType}).');
  }
  final out = <T>[];
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) {
      throw FormatException(
          'Field "$key"[$i] must be a JSON object (got ${item.runtimeType}).');
    }
    out.add(fromMap(item.cast<String, Object?>()));
  }
  return out;
}

Map<String, Object?> _requireMap(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! Map) {
    throw FormatException('Missing or non-object field "$key".');
  }
  return v.cast<String, Object?>();
}

String _requireString(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('Missing or non-string field "$key".');
  }
  return v;
}

int _requireInt(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! int) {
    throw FormatException('Missing or non-int field "$key".');
  }
  return v;
}

String? _optString(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v == null) return null;
  if (v is! String) {
    throw FormatException('Field "$key" must be a string when present.');
  }
  return v;
}

List<String> _optStringList(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v == null) return const <String>[];
  if (v is! List) {
    throw FormatException('Field "$key" must be a string array.');
  }
  return v.map((e) {
    if (e is! String) {
      throw FormatException('Field "$key" must contain only strings.');
    }
    return e;
  }).toList();
}
