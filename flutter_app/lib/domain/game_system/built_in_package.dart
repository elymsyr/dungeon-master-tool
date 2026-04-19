/// A package bundled with the app binary (loaded from assets) that a
/// [GameSystem] offers to auto-install on fresh-world creation. Licensing
/// metadata travels with the package itself (per [14-package-system-redesign]),
/// not with the [GameSystem].
class BuiltInPackage {
  final String assetPath;
  final bool recommendedDefault;
  final String displayName;
  final String description;

  const BuiltInPackage({
    required this.assetPath,
    required this.displayName,
    this.recommendedDefault = true,
    this.description = '',
  });

  @override
  bool operator ==(Object other) =>
      other is BuiltInPackage &&
      other.assetPath == assetPath &&
      other.recommendedDefault == recommendedDefault &&
      other.displayName == displayName &&
      other.description == description;

  @override
  int get hashCode =>
      Object.hash(assetPath, recommendedDefault, displayName, description);

  @override
  String toString() => 'BuiltInPackage($displayName @ $assetPath)';
}
