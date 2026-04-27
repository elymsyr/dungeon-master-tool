import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package_import_service.dart';
import 'srd_core_package_bootstrap.dart' show srdCorePackageName;

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
      final pkg = await _db.packageDao.getByName(srdCorePackageName);
      final tier1Count = await _importSrdCore(
        campaignId: campaignId,
        build: build,
        packageId: pkg?.id,
      );
      // Record install row so the Packages tab + sync service know this
      // campaign is live-linked to the SRD pack.
      if (pkg != null) {
        await _db.installedPackageDao.upsert(
          InstalledPackagesCompanion.insert(
            campaignId: campaignId,
            packageId: pkg.id,
            packageName: Value(pkg.name),
          ),
        );
      }
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
    String? packageId,
  }) async {
    final pack = buildSrdCorePack();
    if (pack.entities.isEmpty) return 0;

    // First pass: mint campaign-side UUIDs for every pack entity. The pack
    // build resolves inter-Tier-1 `_ref` placeholders to pack-side UUIDs,
    // but each campaign needs its own UUIDs (entities table PK is global).
    // Build a pack_id → campaign_id map so the second pass can rewrite
    // every relation in attrs to point at this campaign's row UUIDs.
    final packToCampaign = <String, String>{
      for (final id in pack.entities.keys) id: _uuid.v4(),
    };

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
      // Rewrite any pack-side Tier-1 UUID inside the resolved attrs to the
      // matching campaign-side UUID so spell.class_refs etc. resolve
      // correctly post-import.
      final remappedAttrs =
          _remapPackRefs(resolvedAttrs, packToCampaign) as Map<String, dynamic>;
      final campaignEntityId = packToCampaign[id]!;
      rows.add(EntitiesCompanion.insert(
        id: campaignEntityId,
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
        fieldsJson: Value(jsonEncode(remappedAttrs)),
        packageId: Value(packageId),
        packageEntityId: Value(id),
        linked: Value(packageId != null),
      ));
    }

    if (rows.isEmpty) return 0;
    await _db.entityDao.insertAll(rows);
    return rows.length;
  }

  /// Walks [value] and replaces any string that matches a key in
  /// [packToCampaign] with the mapped campaign-side UUID. Used to rewrite
  /// inter-Tier-1 relations (class_refs, trait_refs, action_refs, …) so
  /// they point at this campaign's freshly minted row IDs instead of the
  /// pack-side UUIDs that are scoped to the package_entities table.
  static dynamic _remapPackRefs(
      dynamic value, Map<String, String> packToCampaign) {
    if (value is String) return packToCampaign[value] ?? value;
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = _remapPackRefs(v, packToCampaign);
      });
      return out;
    }
    if (value is List) {
      return value.map((e) => _remapPackRefs(e, packToCampaign)).toList();
    }
    return value;
  }
}
