/// Static registry of the SRD packages bundled with the app (produced by
/// `tool/build_srd_pkg.dart`). Drives the world-create / world-edit package
/// picker so users opt in to the SRD subsets they want per world.
///
/// `sourcePackageId` matches the `id` field written into each envelope by
/// `build_srd_pkg.dart`. It's what `installed_packages.sourcePackageId`
/// stamps, so "already installed?" detection is `sourcePackageId.equals(...)`.
///
/// Keep in sync with `tool/build_srd_pkg.dart` metadata.
class BundledSrdPackage {
  final String id;
  final String assetPath;
  final String sourcePackageId;
  final String name;
  final String description;
  final bool recommended;

  const BundledSrdPackage({
    required this.id,
    required this.assetPath,
    required this.sourcePackageId,
    required this.name,
    required this.description,
    this.recommended = false,
  });
}

/// `sourcePackageId` values retired from the bundled registry. Lingering
/// rows in `installed_packages` with these ids are silently cleaned up on
/// boot (see `CampaignPackagesController.migrateRetiredBundles`).
const List<String> retiredBundledSourcePackageIds = <String>[
  'srd-rules-1',
  'srd-heroes-1',
];

const List<BundledSrdPackage> bundledSrdPackages = <BundledSrdPackage>[
  BundledSrdPackage(
    id: 'core',
    assetPath: 'assets/packages/srd_core.dnd5e-pkg.json',
    sourcePackageId: 'srd-core-1',
    name: 'SRD — Core',
    description:
        'Rules + Heroes merged: conditions, damage types, skills, sizes, '
            'spell-schools, weapon properties, rarities, feats, backgrounds, '
            'species, lineages, classes, subclasses, and items. Required for '
            'Spells and Bestiary.',
    recommended: true,
  ),
  BundledSrdPackage(
    id: 'spells',
    assetPath: 'assets/packages/srd_spells.dnd5e-pkg.json',
    sourcePackageId: 'srd-spells-1',
    name: 'SRD — Spells',
    description: 'Cantrips through 9th-level spells from the SRD 5.2.1.',
  ),
  BundledSrdPackage(
    id: 'bestiary',
    assetPath: 'assets/packages/srd_bestiary.dnd5e-pkg.json',
    sourcePackageId: 'srd-bestiary-1',
    name: 'SRD — Bestiary',
    description: 'Monster stat blocks from the SRD 5.2.1.',
  ),
];
