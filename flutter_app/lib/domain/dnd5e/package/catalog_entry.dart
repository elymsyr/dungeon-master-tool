/// Package-import payload for a Tier 1 catalog row (Doc 03 `_CatalogTable`
/// shape: id + name + bodyJson + sourcePackageId). Ships as raw JSON blob
/// because per-entity Dart codecs land with Doc 15 (SRD Core) — the importer
/// only needs a stable Drift row shape now.
///
/// `id` here is the **local id** (e.g. `stunned`) — the importer namespaces it
/// to `<packageIdSlug>:<localId>` before writing.
class CatalogEntry {
  final String id;
  final String name;
  final String bodyJson;

  const CatalogEntry({
    required this.id,
    required this.name,
    required this.bodyJson,
  });

  CatalogEntry namespaced(String slug) => CatalogEntry(
        id: id.contains(':') ? id : '$slug:$id',
        name: name,
        bodyJson: bodyJson,
      );

  @override
  bool operator ==(Object other) =>
      other is CatalogEntry &&
      other.id == id &&
      other.name == name &&
      other.bodyJson == bodyJson;

  @override
  int get hashCode => Object.hash(id, name, bodyJson);
}
