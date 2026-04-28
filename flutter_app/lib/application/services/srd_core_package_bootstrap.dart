import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import '../../domain/entities/schema/world_schema_hash.dart';

const _uuid = Uuid();

/// Canonical name of the built-in SRD content package shown in the
/// Packages tab. The package row is owned by the app — never deleted by
/// `getAvailableNames` cleanup, refreshed on every app start so newly-
/// authored Tier-1 rows land without a manual reinstall.
const srdCorePackageName = 'SRD 5.2.1 Core';

/// Idempotent installer that materialises the hand-authored SRD 5.2.1
/// content pack as a real `Packages` row in the DB. Runs once per app
/// session (gated by [_installed]) so the Packages tab can list and load
/// it like any user-authored package.
///
/// On re-run the pack is replaced in full: stale package entities are
/// dropped and fresh ones inserted. This keeps the visible pack in lock-
/// step with the code-defined `buildSrdCorePack()` output without the
/// user having to click anything.
class SrdCorePackageBootstrap {
  final AppDatabase _db;
  SrdCorePackageBootstrap(this._db);

  static bool _installed = false;

  /// Installs (or refreshes) the SRD 5.2.1 Core package row. Returns the
  /// number of pack entities written (0 when already current).
  Future<int> ensureInstalled() async {
    if (_installed) return 0;
    _installed = true;

    final build = generateBuiltinDnd5eV2Schema();
    final schema = build.schema;
    final pack = buildSrdCorePack();

    return _db.transaction(() async {
      // Look up an existing row by the canonical name.
      final existing = await _db.packageDao.getByName(srdCorePackageName);
      final packageId = existing?.id ?? _uuid.v4();

      if (existing == null) {
        await _db.packageDao.createPackage(PackagesCompanion.insert(
          id: packageId,
          name: srdCorePackageName,
          stateJson: Value(jsonEncode({
            'metadata': pack.metadata,
          })),
        ));
      } else {
        await _db.packageDao.updatePackage(PackagesCompanion(
          id: Value(packageId),
          name: const Value(srdCorePackageName),
          stateJson: Value(jsonEncode({
            'metadata': pack.metadata,
          })),
          updatedAt: Value(DateTime.now()),
        ));
      }

      // Replace schema row.
      await (_db.delete(_db.packageSchemas)
            ..where((t) => t.packageId.equals(packageId)))
          .go();
      final schemaJson = schema.toJson();
      final currentHash = computeWorldSchemaContentHash(schema);
      final originalHash = schema.originalHash ?? currentHash;
      await (_db.into(_db.packageSchemas))
          .insert(PackageSchemasCompanion.insert(
        id: _uuid.v4(),
        packageId: packageId,
        name: Value(schema.name),
        version: Value(schema.version),
        description: Value(schema.description),
        categoriesJson: Value(jsonEncode(schemaJson['categories'] ?? [])),
        encounterConfigJson:
            Value(jsonEncode(schemaJson['encounterConfig'] ?? {})),
        encounterLayoutsJson:
            Value(jsonEncode(schemaJson['encounterLayouts'] ?? [])),
        metadataJson: Value(jsonEncode({
          if (schemaJson['metadata'] is Map)
            ...(schemaJson['metadata'] as Map).cast<String, dynamic>(),
          ...pack.metadata,
        })),
        templateId: Value(schema.schemaId),
        templateHash: Value(currentHash),
        templateOriginalHash: Value(originalHash),
      ));

      // Replace package entities.
      await (_db.delete(_db.packageEntities)
            ..where((t) => t.packageId.equals(packageId)))
          .go();

      final companions = <PackageEntitiesCompanion>[];

      // Mirror Tier-0 lookup seedRows (abilities, skills, damage types,
      // conditions, …) into package_entities so the package's visible
      // entity count matches the rows materialised in a fresh world. Ids
      // are deterministic v5 (`slug:name`) so SrdCoreBootstrap can tag the
      // freshly seeded campaign rows with a matching `package_entity_id`
      // and keep PackageSync from treating them as orphans.
      for (final entry in build.seedRows.entries) {
        final slug = entry.key;
        for (final row in entry.value) {
          final name = (row['name'] as String?) ?? '';
          if (name.isEmpty) continue;
          companions.add(PackageEntitiesCompanion.insert(
            id: srdStableEntityId(slug, name),
            packageId: packageId,
            categorySlug: slug,
            name: name,
            source: const Value(srdSourceTag),
            description: Value((row['description'] as String?) ?? ''),
            fieldsJson:
                Value(jsonEncode(row['fields'] ?? <String, dynamic>{})),
          ));
        }
      }

      if (pack.entities.isEmpty && companions.isEmpty) return 0;

      for (final entry in pack.entities.entries) {
        final id = entry.key;
        final raw = Map<String, dynamic>.from(entry.value as Map);
        final attrs = raw['attributes'] is Map
            ? Map<String, dynamic>.from(raw['attributes'] as Map)
            : <String, dynamic>{};
        // Tier-0 lookup placeholders inside `attrs` stay as placeholders
        // here — `PackageImportService` resolves them at campaign-import
        // time against the destination campaign's seeded Tier-0 UUIDs.
        // Encoding placeholders as-is keeps the package self-contained.
        companions.add(PackageEntitiesCompanion.insert(
          id: id,
          packageId: packageId,
          categorySlug: raw['type'] as String? ?? 'unknown',
          name: raw['name'] as String? ?? 'Unnamed',
          source: Value((raw['source'] as String?) ?? srdSourceTag),
          description: Value((raw['description'] as String?) ?? ''),
          imagePath: Value((raw['image_path'] as String?) ?? ''),
          imagesJson: Value(jsonEncode(raw['images'] ?? const [])),
          tagsJson: Value(jsonEncode(raw['tags'] ?? const [])),
          dmNotes: Value((raw['dm_notes'] as String?) ?? ''),
          pdfsJson: Value(jsonEncode(raw['pdfs'] ?? const [])),
          locationId: Value(raw['location_id'] as String?),
          fieldsJson: Value(jsonEncode(attrs)),
        ));
      }

      await _db.packageDao.insertAllEntities(companions);

      // One-shot migration: rewrite stale `package_entity_id` foreign keys
      // on installed campaigns. Pack entity ids switched from random v4
      // (per-session) to deterministic v5 (slug:name). Without this fix,
      // PackageSync.sync would see every existing linked entity as
      // orphaned and delete-and-reinsert, stranding any open EntityCard
      // tab on a now-invalid id.
      final packIdsBySlugName = <String, Map<String, String>>{};
      for (final entry in pack.entities.entries) {
        final raw = entry.value as Map;
        final slug = raw['type'] as String?;
        final name = raw['name'] as String?;
        if (slug != null && name != null) {
          packIdsBySlugName.putIfAbsent(slug, () => <String, String>{})[name] =
              entry.key;
        }
      }
      final installedRows = await (_db.select(_db.entities)
            ..where((t) =>
                t.packageId.equalsExp(Variable<String>(packageId)) &
                t.packageEntityId.isNotNull()))
          .get();
      for (final row in installedRows) {
        final newPackId =
            packIdsBySlugName[row.categorySlug]?[row.name];
        if (newPackId != null && row.packageEntityId != newPackId) {
          await _db.entityDao.updateEntity(EntitiesCompanion(
            id: Value(row.id),
            packageEntityId: Value(newPackId),
          ));
        }
      }

      // Backfill: legacy worlds seeded Tier-0 rows with packageId only and
      // no packageEntityId. Now that Tier-0 lives in package_entities with
      // deterministic v5 ids, link those existing campaign rows to the
      // matching pack row so PackageSync sees them as already-installed
      // (otherwise the next sync would insert duplicates).
      final tier0Slugs = build.seedRows.keys.toSet();
      if (tier0Slugs.isNotEmpty) {
        final unlinked = await (_db.select(_db.entities)
              ..where((t) =>
                  t.packageId.equalsExp(Variable<String>(packageId)) &
                  t.packageEntityId.isNull() &
                  t.categorySlug.isIn(tier0Slugs)))
            .get();
        for (final row in unlinked) {
          // Leave `linked` alone: legacy worlds may have user-edited Tier-0
          // rows the bootstrap can't distinguish from pristine ones. Keeping
          // them detached means sync won't overwrite local edits — at the
          // cost of those rows not auto-updating from the pack. Users can
          // re-link manually if they want pack updates to flow through.
          await _db.entityDao.updateEntity(EntitiesCompanion(
            id: Value(row.id),
            packageEntityId:
                Value(srdStableEntityId(row.categorySlug, row.name)),
          ));
        }
      }

      return companions.length;
    });
  }

  /// Test seam — resets the install gate so multiple test runs each
  /// re-bootstrap on a fresh in-memory DB.
  static void resetInstallGate() {
    _installed = false;
  }
}
