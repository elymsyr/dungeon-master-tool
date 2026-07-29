/// Soft reference from one content package to another ("package A links
/// package B"). Linked packages stay separate stores — the link only makes
/// B's entities *visible* inside A and makes B follow A wherever A goes
/// (world import, catalog download).
///
/// Persisted as `packages.state_json['links']`, so it rides export /
/// marketplace payloads / personal cloud sync for free (see
/// `PackageRepositoryImpl._saveToDb`, which routes every non-typed top-level
/// key into `state_json`).
///
/// Both fields are resolution hints, not hard refs: [packageId] is tried
/// first, [name] is the fallback for packages that got a fresh local id
/// (homebrew copies, marketplace downloads). When neither resolves the link is
/// *dangling* — surfaced as a warning, never an error. See
/// `vault/20-Systems/Ref-Resolution-Hard-vs-Soft.md`.
class PackageLink {
  final String packageId;
  final String name;

  const PackageLink({required this.packageId, required this.name});

  Map<String, dynamic> toJson() => {'package_id': packageId, 'name': name};

  /// Returns null for shapes that carry neither a usable id nor a name — a
  /// malformed link is dropped rather than crashing the package load.
  static PackageLink? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = (raw['package_id'] ?? raw['packageId'] ?? '').toString();
    final name = (raw['name'] ?? raw['package_name'] ?? '').toString();
    if (id.isEmpty && name.isEmpty) return null;
    return PackageLink(packageId: id, name: name);
  }

  /// Display label — the human name when present, else the raw id.
  String get label => name.isNotEmpty ? name : packageId;

  @override
  bool operator ==(Object other) =>
      other is PackageLink &&
      other.packageId == packageId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(packageId, name);

  @override
  String toString() => 'PackageLink($label)';
}
