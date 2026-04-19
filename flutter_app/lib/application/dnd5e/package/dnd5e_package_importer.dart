import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../../../domain/dnd5e/effect/custom_effect_registry.dart';
import '../../../domain/dnd5e/package/catalog_entry.dart';
import '../../../domain/dnd5e/package/conflict_resolution.dart';
import '../../../domain/dnd5e/package/content_entry.dart';
import '../../../domain/dnd5e/package/content_hash.dart';
import '../../../domain/dnd5e/package/dnd5e_package.dart';
import '../../../domain/dnd5e/package/import_report.dart';
import '../../../domain/dnd5e/package/package_validator.dart';

/// Doc 14 importer — writes a [Dnd5ePackage] into the Drift catalog + content
/// tables populated by Doc 03. Runs validation first, namespaces ids, resolves
/// same-source conflicts, and records the install in `installed_packages`.
///
/// **Scope note.** File-system JSON read + marketplace download are out of
/// scope here; callers hand over a pre-parsed [Dnd5ePackage]. JSON codecs
/// land with Doc 15 alongside the SRD content.
class Dnd5ePackageImporter {
  final AppDatabase db;
  final PackageValidator validator;

  Dnd5ePackageImporter(this.db, CustomEffectRegistry registry)
      : validator = PackageValidator(registry);

  Future<PackageImportResult> import(
    Dnd5ePackage pkg, {
    ConflictResolution onConflict = ConflictResolution.overwrite,
    String? expectedContentHash,
  }) async {
    final issues = validator.validate(pkg);
    if (validator.isFatal(issues)) {
      return PackageImportResult.error(
          issues.map((i) => i.message).join('; '));
    }

    final normalized = pkg.namespaced();

    if (expectedContentHash != null) {
      final actual = computeContentHash(normalized);
      if (actual != expectedContentHash) {
        return PackageImportResult.error(
            'Content hash mismatch: expected $expectedContentHash, got $actual');
      }
    }

    final existing = await (db.select(db.installedPackages)
          ..where((t) => t.sourcePackageId.equals(pkg.id)))
        .getSingleOrNull();

    if (existing != null) {
      switch (onConflict) {
        case ConflictResolution.skip:
          final report = ImportReport()
            ..warn(
                'Package ${pkg.id} already installed as ${existing.packageIdSlug}; skipped.');
          return PackageImportResult.success(report);
        case ConflictResolution.overwrite:
          await _deleteBySlug(existing.packageIdSlug);
          await (db.delete(db.installedPackages)
                ..where((t) => t.id.equals(existing.id)))
              .go();
          break;
        case ConflictResolution.duplicate:
          return PackageImportResult.error(
              'ConflictResolution.duplicate requires the caller to pass a fresh '
              'packageIdSlug on the package before re-importing.');
      }
    }

    final report = ImportReport();
    await db.transaction(() async {
      await _writeCatalog(db.conditions, normalized.conditions,
          normalized.packageIdSlug, 'conditions', report);
      await _writeCatalog(db.damageTypes, normalized.damageTypes,
          normalized.packageIdSlug, 'damageTypes', report);
      await _writeCatalog(db.skills, normalized.skills,
          normalized.packageIdSlug, 'skills', report);
      await _writeCatalog(db.sizes, normalized.sizes,
          normalized.packageIdSlug, 'sizes', report);
      await _writeCatalog(db.creatureTypes, normalized.creatureTypes,
          normalized.packageIdSlug, 'creatureTypes', report);
      await _writeCatalog(db.alignments, normalized.alignments,
          normalized.packageIdSlug, 'alignments', report);
      await _writeCatalog(db.languages, normalized.languages,
          normalized.packageIdSlug, 'languages', report);
      await _writeCatalog(db.spellSchools, normalized.spellSchools,
          normalized.packageIdSlug, 'spellSchools', report);
      await _writeCatalog(db.weaponProperties, normalized.weaponProperties,
          normalized.packageIdSlug, 'weaponProperties', report);
      await _writeCatalog(db.weaponMasteries, normalized.weaponMasteries,
          normalized.packageIdSlug, 'weaponMasteries', report);
      await _writeCatalog(db.armorCategories, normalized.armorCategories,
          normalized.packageIdSlug, 'armorCategories', report);
      await _writeCatalog(db.rarities, normalized.rarities,
          normalized.packageIdSlug, 'rarities', report);

      for (final s in normalized.spells) {
        await db.into(db.spells).insert(
              SpellsCompanion.insert(
                id: s.id,
                name: s.name,
                level: s.level,
                schoolId: s.schoolId,
                bodyJson: s.bodyJson,
                sourcePackageId: Value(normalized.packageIdSlug),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      report.record('spells', normalized.spells.length);

      for (final m in normalized.monsters) {
        await db.into(db.monsters).insert(
              MonstersCompanion.insert(
                id: m.id,
                name: m.name,
                statBlockJson: m.statBlockJson,
                sourcePackageId: Value(normalized.packageIdSlug),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      report.record('monsters', normalized.monsters.length);

      for (final i in normalized.items) {
        await db.into(db.items).insert(
              ItemsCompanion.insert(
                id: i.id,
                name: i.name,
                itemType: i.itemType,
                bodyJson: i.bodyJson,
                rarityId: Value(i.rarityId),
                sourcePackageId: Value(normalized.packageIdSlug),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      report.record('items', normalized.items.length);

      await _writeNamed(db.feats, normalized.feats,
          normalized.packageIdSlug, 'feats', report);
      await _writeNamed(db.backgrounds, normalized.backgrounds,
          normalized.packageIdSlug, 'backgrounds', report);
      await _writeNamed(db.speciesCatalog, normalized.species,
          normalized.packageIdSlug, 'species', report);
      await _writeNamed(db.classProgressions, normalized.classProgressions,
          normalized.packageIdSlug, 'classProgressions', report);

      for (final sc in normalized.subclasses) {
        await db.into(db.subclasses).insert(
              SubclassesCompanion.insert(
                id: sc.id,
                name: sc.name,
                bodyJson: sc.bodyJson,
                parentClassId: sc.parentClassId,
                sourcePackageId: Value(normalized.packageIdSlug),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      report.record('subclasses', normalized.subclasses.length);

      await db.into(db.installedPackages).insert(
            InstalledPackagesCompanion.insert(
              id: _installId(pkg, normalized.packageIdSlug),
              sourcePackageId: pkg.id,
              packageIdSlug: normalized.packageIdSlug,
              name: pkg.name,
              version: pkg.version,
              gameSystemId: pkg.gameSystemId,
              authorName: Value(pkg.authorName),
              sourceLicense: Value(pkg.sourceLicense),
              description: Value(pkg.description),
              reportJson: Value(jsonEncode(report.counts)),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });

    return PackageImportResult.success(report);
  }

  Future<void> _writeCatalog(
    TableInfo<Table, dynamic> table,
    List<CatalogEntry> rows,
    String slug,
    String reportKey,
    ImportReport report,
  ) async {
    for (final e in rows) {
      await db.customInsert(
        'INSERT OR REPLACE INTO ${table.actualTableName} '
        '(id, name, body_json, source_package_id) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(e.id),
          Variable.withString(e.name),
          Variable.withString(e.bodyJson),
          Variable.withString(slug),
        ],
        updates: {table},
      );
    }
    report.record(reportKey, rows.length);
  }

  Future<void> _writeNamed(
    TableInfo<Table, dynamic> table,
    List<NamedEntry> rows,
    String slug,
    String reportKey,
    ImportReport report,
  ) async {
    for (final e in rows) {
      await db.customInsert(
        'INSERT OR REPLACE INTO ${table.actualTableName} '
        '(id, name, body_json, source_package_id) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(e.id),
          Variable.withString(e.name),
          Variable.withString(e.bodyJson),
          Variable.withString(slug),
        ],
        updates: {table},
      );
    }
    report.record(reportKey, rows.length);
  }

  Future<void> _deleteBySlug(String slug) async {
    await db.transaction(() async {
      Future<void> del(TableInfo<Table, dynamic> t) async {
        await db.customStatement(
          'DELETE FROM ${t.actualTableName} WHERE source_package_id = ?',
          [slug],
        );
      }

      await del(db.conditions);
      await del(db.damageTypes);
      await del(db.skills);
      await del(db.sizes);
      await del(db.creatureTypes);
      await del(db.alignments);
      await del(db.languages);
      await del(db.spellSchools);
      await del(db.weaponProperties);
      await del(db.weaponMasteries);
      await del(db.armorCategories);
      await del(db.rarities);
      await del(db.spells);
      await del(db.monsters);
      await del(db.items);
      await del(db.feats);
      await del(db.backgrounds);
      await del(db.speciesCatalog);
      await del(db.subclasses);
      await del(db.classProgressions);
    });
  }

  String _installId(Dnd5ePackage pkg, String slug) =>
      'install:$slug:${pkg.version}';
}
