import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package_import_service.dart';

const _uuid = Uuid();

/// One-shot bootstrap that seeds a freshly-created v2 D&D 5e campaign with:
///   1. Tier-0 lookup rows from [BuiltinDnd5eV2Build.seedRows] (abilities,
///      skills, damage types, conditions, sizes, alignments, …).
///   2. The hand-authored SRD 5.2.1 content pack from [buildSrdCorePack] —
///      classes, spells, monsters, magic items, … with relation references
///      resolved against the Tier-0 UUIDs minted in step 1.
///
/// Operates directly on [AppDatabase] (not via [EntityNotifier]) because it
/// runs during `CampaignRepositoryImpl.create`, before any campaign is
/// loaded into the active-campaign provider.
///
/// Idempotent guard via [WorldSchemas.metadataJson] → `srdCoreImportedAt`.
/// v1 schema (`builtin-dnd5e-default`) campaigns are intentionally skipped.
class SrdCoreBootstrap {
  final AppDatabase _db;
  SrdCoreBootstrap(this._db);

  /// Tier-0 `(slug, name) -> uuid` index built during seeding; consumed by
  /// the SRD pack import to resolve `_lookup` placeholders.
  Map<String, Map<String, String>> _tier0Ids = const {};

  /// Returns the number of entities inserted (Tier-0 + Tier-1).
  /// Returns 0 when the schema isn't v2 or the guard flag is already set.
  Future<int> ensureImported({
    required String campaignId,
    required BuiltinDnd5eV2Build build,
  }) async {
    // Trigger gate — only the v2 schema gets the bootstrap.
    if (build.schema.schemaId != builtinDnd5eV2SchemaId) return 0;

    // Idempotent guard — read the schema row, check metadata.
    final schemaRow = await (_db.select(_db.worldSchemas)
          ..where((t) => t.campaignId.equals(campaignId)))
        .getSingleOrNull();
    if (schemaRow == null) return 0;
    final meta =
        _decodeMetadata(schemaRow.metadataJson);
    if (meta['srdCoreImportedAt'] is String) return 0;

    final inserted = await _db.transaction(() async {
      final tier0Count =
          await _seedTier0(campaignId: campaignId, build: build);
      final tier1Count = await _importSrdCore(
        campaignId: campaignId,
        build: build,
      );
      return tier0Count + tier1Count;
    });

    // Persist guard. Adds attribution + license to schema metadata so the
    // About panel can read it from the world schema.
    meta['srdCoreImportedAt'] = DateTime.now().toUtc().toIso8601String();
    meta['attribution'] = srdAttribution;
    meta['license'] = srdLicense;
    meta['source'] = srdSourceTag;
    await (_db.update(_db.worldSchemas)
          ..where((t) => t.id.equals(schemaRow.id)))
        .write(WorldSchemasCompanion(
      metadataJson: Value(jsonEncode(meta)),
      updatedAt: Value(DateTime.now()),
    ));

    return inserted;
  }

  Map<String, dynamic> _decodeMetadata(String raw) {
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Inserts every seed row from [build.seedRows] as a real Entity record
  /// belonging to [campaignId]. Populates [_tier0Ids] for downstream
  /// relation resolution. Returns the inserted row count.
  Future<int> _seedTier0({
    required String campaignId,
    required BuiltinDnd5eV2Build build,
  }) async {
    final rows = <EntitiesCompanion>[];
    final index = <String, Map<String, String>>{};

    for (final entry in build.seedRows.entries) {
      final slug = entry.key;
      final slugIdx = index.putIfAbsent(slug, () => <String, String>{});
      for (final row in entry.value) {
        final id = _uuid.v4();
        final name = (row['name'] as String?) ?? '';
        if (name.isEmpty) continue;
        slugIdx[name] = id;
        rows.add(EntitiesCompanion.insert(
          id: id,
          campaignId: campaignId,
          categorySlug: slug,
          name: name,
          source: const Value(srdSourceTag),
          description: Value((row['description'] as String?) ?? ''),
          fieldsJson: Value(jsonEncode(row['fields'] ?? <String, dynamic>{})),
        ));
      }
    }

    if (rows.isEmpty) {
      _tier0Ids = index;
      return 0;
    }

    await _db.entityDao.insertAll(rows);
    _tier0Ids = index;
    return rows.length;
  }

  Future<int> _importSrdCore({
    required String campaignId,
    required BuiltinDnd5eV2Build build,
  }) async {
    final pack = buildSrdCorePack();
    if (pack.entities.isEmpty) return 0;

    final rows = <EntitiesCompanion>[];
    for (final entry in pack.entities.entries) {
      final id = entry.key;
      final raw = Map<String, dynamic>.from(entry.value as Map);
      final attrs = raw['attributes'] is Map
          ? Map<String, dynamic>.from(raw['attributes'] as Map)
          : <String, dynamic>{};
      // Resolve Tier-0 lookup placeholders against the campaign's freshly
      // seeded Tier-0 row UUIDs.
      final resolvedAttrs =
          PackageImportService.resolveLookupPlaceholder(attrs, _tier0Ids)
              as Map<String, dynamic>;
      rows.add(EntitiesCompanion.insert(
        id: id,
        campaignId: campaignId,
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
        fieldsJson: Value(jsonEncode(resolvedAttrs)),
      ));
    }

    if (rows.isEmpty) return 0;
    await _db.entityDao.insertAll(rows);
    return rows.length;
  }
}
