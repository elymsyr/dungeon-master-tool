/// Semantic version of an installed package.
class PackageVersion {
  final int major;
  final int minor;
  final int patch;

  const PackageVersion._(this.major, this.minor, this.patch);

  factory PackageVersion(int major, int minor, int patch) {
    if (major < 0 || minor < 0 || patch < 0) {
      throw ArgumentError('PackageVersion components must be >= 0');
    }
    return PackageVersion._(major, minor, patch);
  }

  @override
  bool operator ==(Object other) =>
      other is PackageVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;
  @override
  int get hashCode => Object.hash(major, minor, patch);
  @override
  String toString() => '$major.$minor.$patch';
}

/// Record of an installed package within a world. The world owns the registry
/// — installed content is addressable via the package's namespaced ids.
class InstalledPackage {
  final String packageId;
  final PackageVersion version;
  final DateTime installedAt;

  const InstalledPackage({
    required this.packageId,
    required this.version,
    required this.installedAt,
  });

  @override
  bool operator ==(Object other) =>
      other is InstalledPackage &&
      other.packageId == packageId &&
      other.version == version;
  @override
  int get hashCode => Object.hash(packageId, version);
}

/// Tier 1 container: a world is a campaign setting bound to a game system and
/// a set of installed content packages. Replaces the template-coupled world
/// model from the legacy architecture.
class World {
  final String id;
  final String name;
  final String gameSystemId;
  final List<InstalledPackage> installedPackages;
  final String description;
  final DateTime createdAt;

  World._(this.id, this.name, this.gameSystemId, this.installedPackages,
      this.description, this.createdAt);

  factory World({
    required String id,
    required String name,
    String gameSystemId = 'dnd5e',
    List<InstalledPackage> installedPackages = const [],
    String description = '',
    required DateTime createdAt,
  }) {
    if (id.isEmpty) throw ArgumentError('World.id must not be empty');
    if (name.isEmpty) throw ArgumentError('World.name must not be empty');
    final seen = <String>{};
    for (final p in installedPackages) {
      if (!seen.add(p.packageId)) {
        throw ArgumentError(
            'World.installedPackages contains duplicate "${p.packageId}"');
      }
    }
    return World._(id, name, gameSystemId,
        List.unmodifiable(installedPackages), description, createdAt);
  }

  bool hasPackage(String packageId) =>
      installedPackages.any((p) => p.packageId == packageId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is World && other.id == id;
  @override
  int get hashCode => id.hashCode;
  @override
  String toString() => 'World($id, $name)';
}
