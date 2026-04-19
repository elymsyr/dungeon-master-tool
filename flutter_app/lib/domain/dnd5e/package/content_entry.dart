/// Package-import payloads for Doc 03 typed content tables (Monsters, Spells,
/// Items, Feats, Backgrounds, Species, Subclasses, ClassProgressions). Each
/// variant mirrors the Drift columns beyond the shared id/name/bodyJson.
///
/// Like [CatalogEntry], `id` is the local id and is namespaced by the importer.
library;

sealed class ContentEntry {
  String get id;
  String get name;
  ContentEntry namespaced(String slug);
}

class SpellEntry implements ContentEntry {
  @override
  final String id;
  @override
  final String name;
  final int level;
  final String schoolId;
  final String bodyJson;

  const SpellEntry({
    required this.id,
    required this.name,
    required this.level,
    required this.schoolId,
    required this.bodyJson,
  });

  @override
  SpellEntry namespaced(String slug) => SpellEntry(
        id: _nsRef(id, slug),
        name: name,
        level: level,
        schoolId: _nsRef(schoolId, slug),
        bodyJson: bodyJson,
      );
}

class MonsterEntry implements ContentEntry {
  @override
  final String id;
  @override
  final String name;
  final String statBlockJson;

  const MonsterEntry({
    required this.id,
    required this.name,
    required this.statBlockJson,
  });

  @override
  MonsterEntry namespaced(String slug) => MonsterEntry(
        id: _nsRef(id, slug),
        name: name,
        statBlockJson: statBlockJson,
      );
}

class ItemEntry implements ContentEntry {
  @override
  final String id;
  @override
  final String name;
  final String itemType;
  final String? rarityId;
  final String bodyJson;

  const ItemEntry({
    required this.id,
    required this.name,
    required this.itemType,
    required this.bodyJson,
    this.rarityId,
  });

  @override
  ItemEntry namespaced(String slug) => ItemEntry(
        id: _nsRef(id, slug),
        name: name,
        itemType: itemType,
        rarityId: rarityId == null ? null : _nsRef(rarityId!, slug),
        bodyJson: bodyJson,
      );
}

class NamedEntry implements ContentEntry {
  @override
  final String id;
  @override
  final String name;
  final String bodyJson;

  const NamedEntry({
    required this.id,
    required this.name,
    required this.bodyJson,
  });

  @override
  NamedEntry namespaced(String slug) => NamedEntry(
        id: _nsRef(id, slug),
        name: name,
        bodyJson: bodyJson,
      );
}

class SubclassEntry implements ContentEntry {
  @override
  final String id;
  @override
  final String name;
  final String parentClassId;
  final String bodyJson;

  const SubclassEntry({
    required this.id,
    required this.name,
    required this.parentClassId,
    required this.bodyJson,
  });

  @override
  SubclassEntry namespaced(String slug) => SubclassEntry(
        id: _nsRef(id, slug),
        name: name,
        parentClassId: _nsRef(parentClassId, slug),
        bodyJson: bodyJson,
      );
}

/// Intra-package references may be bare local ids — namespace them on the way
/// in. Already-namespaced refs (containing `:`) are left alone so a package
/// can reference a dependency's already-installed catalog.
String _nsRef(String raw, String slug) =>
    raw.contains(':') ? raw : '$slug:$raw';
