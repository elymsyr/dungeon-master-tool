import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/personal_sync_provider.dart';
import '../providers/world_mirror_provider.dart';
import 'srd_core_bootstrap.dart';
import 'srd_core_package_bootstrap.dart';
import 'world_mirror_service.dart';

/// Beta'dan çıkarken kullanıcının sahip olduğu tüm online içeriği lokale
/// indirir, ardından CDC'de gelecek DELETE event'lerinin lokal kopyayı
/// temizlememesi için guard'ları arm eder.
///
/// Akış (BetaNotifier.leaveBeta tarafından çağrılır):
///   1. [summarize] — confirm dialog'da gösterilecek özet ([SummaryCounts]).
///   2. [preserve]  — owned world'leri hydrate + guard'ları arm + personal
///      paketler/orphan char'lar için guard kayıtları.
class BetaExitPreserveService {
  BetaExitPreserveService({
    required this.ref,
    required this.client,
    required this.db,
    required this.repository,
    required this.mirror,
  });

  final Ref ref;
  final SupabaseClient client;
  final AppDatabase db;
  final CampaignRepository repository;
  final WorldMirrorService mirror;

  Future<SummaryCounts> summarize() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) {
      return const SummaryCounts.empty();
    }
    final owned = await _fetchOwnedSnapshot(uid);
    final localWorldIds = (await db.worldsDao.getAll()).map((w) => w.id).toSet();
    final cloudOnlyWorlds = owned.worlds
        .where((w) => !localWorldIds.contains(w.id))
        .length;
    final localCharIds =
        (await db.worldCharactersDao.getAllChars()).map((c) => c.id).toSet();
    final cloudOnlyChars =
        owned.orphanChars.where((c) => !localCharIds.contains(c.id)).length;
    final localPkgNames =
        (await db.packagesDao.getAll()).map((p) => p.name).toSet();
    final cloudOnlyPackages =
        owned.personalPackageNames.where((n) => !localPkgNames.contains(n)).length;
    return SummaryCounts(
      ownedWorlds: owned.worlds.length,
      orphanChars: owned.orphanChars.length,
      personalPackages: owned.personalPackageNames.length,
      cloudOnlyWorlds: cloudOnlyWorlds,
      cloudOnlyChars: cloudOnlyChars,
      cloudOnlyPackages: cloudOnlyPackages,
    );
  }

  /// Owned content'i lokale çek + guard'ları arm. Hata olursa caller akışa
  /// devam edebilsin diye [PreserveResult] döner.
  Future<PreserveResult> preserve() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return const PreserveResult.empty();
    final owned = await _fetchOwnedSnapshot(uid);
    final failedIds = <String>[];

    // Hydrate worlds that have no local mirror yet.
    final localWorldIds = (await db.worldsDao.getAll()).map((w) => w.id).toSet();
    for (final w in owned.worlds) {
      if (!localWorldIds.contains(w.id)) {
        try {
          await _hydrateWorld(w);
        } catch (e, st) {
          debugPrint('BetaExitPreserve hydrate world ${w.id} error: $e\n$st');
          failedIds.add('world:${w.id}');
        }
      }
    }

    // Hydrate orphan online characters (world_id IS NULL). World-bound chars
    // are covered by the world hydration loop above.
    final localCharIds =
        (await db.worldCharactersDao.getAllChars()).map((c) => c.id).toSet();
    for (final c in owned.orphanChars) {
      if (!localCharIds.contains(c.id)) {
        try {
          await _hydrateOrphanCharacter(c);
        } catch (e, st) {
          debugPrint('BetaExitPreserve hydrate char ${c.id} error: $e\n$st');
          failedIds.add('char:${c.id}');
        }
      }
    }

    // Personal packages — auto-bootstrap on sign-in already pulled these,
    // but force-call here to cover edge cases.
    try {
      final applier = ref.read(personalMirrorApplierProvider);
      await applier?.bootstrap();
    } catch (e) {
      debugPrint('BetaExitPreserve personal bootstrap error: $e');
      failedIds.add('personal_bootstrap');
    }

    // Arm CDC delete guards so the imminent leave_beta cascade doesn't purge
    // the local mirrors we just secured.
    for (final w in owned.worlds) {
      mirror.registerExpectedUnpublish(w.id);
    }
    for (final c in owned.orphanChars) {
      mirror.registerExpectedCharDelete(c.id);
    }

    return PreserveResult(
      worldIds: owned.worlds.map((w) => w.id).toList(growable: false),
      orphanCharIds: owned.orphanChars.map((c) => c.id).toList(growable: false),
      personalPackageNames: owned.personalPackageNames,
      failedIds: List.unmodifiable(failedIds),
    );
  }

  Future<_OwnedSnapshot> _fetchOwnedSnapshot(String uid) async {
    final worldsRaw = await client
        .from('worlds')
        .select(
            'id, owner_id, template_id, template_hash, state_json, created_at, updated_at')
        .eq('owner_id', uid);
    final orphanCharsRaw = await client
        .from('world_characters')
        .select(
            'id, owner_id, world_id, template_id, template_name, payload_json, referenced_entity_ids, created_at, updated_at')
        .eq('owner_id', uid)
        .isFilter('world_id', null);
    final pkgsRaw = await client
        .from('personal_packages')
        .select('package_name')
        .eq('owner_id', uid);

    final worlds = <_OwnedWorld>[
      for (final raw in worldsRaw as List)
        _OwnedWorld.fromRow(raw as Map<String, dynamic>),
    ];
    final chars = <_OrphanChar>[
      for (final raw in orphanCharsRaw as List)
        _OrphanChar.fromRow(raw as Map<String, dynamic>),
    ];
    final pkgs = <String>[
      for (final raw in pkgsRaw as List)
        if ((raw as Map)['package_name'] is String)
          raw['package_name'] as String,
    ];
    return _OwnedSnapshot(worlds: worlds, orphanChars: chars, personalPackageNames: pkgs);
  }

  Future<void> _hydrateWorld(_OwnedWorld w) async {
    // Resolve a local name that doesn't clash with existing campaigns.
    final cloudName = w.worldName;
    var localName = cloudName;
    final clash = await db.worldsDao.getByName(localName);
    if (clash != null && clash.id != w.id) {
      var attempt = 2;
      while (true) {
        final candidate = '$cloudName ($attempt)';
        final c = await db.worldsDao.getByName(candidate);
        if (c == null) {
          localName = candidate;
          break;
        }
        attempt++;
        if (attempt > 99) {
          localName = '$cloudName-${w.id.substring(0, 8)}';
          break;
        }
      }
    }

    final now = DateTime.now().toUtc();
    await db.worldsDao.upsert(
      WorldsCompanion.insert(
        id: w.id,
        worldName: localName,
        ownerId: Value(w.ownerId),
        templateId: Value(w.templateId),
        templateHash: Value(w.templateHash),
        createdAt: Value(w.createdAt ?? now),
        updatedAt: Value(w.updatedAt ?? now),
      ),
    );

    // Persist the state_json blob via the existing campaign repo path.
    if (w.stateJson != null && w.stateJson!.isNotEmpty && w.stateJson != '{}') {
      try {
        final decoded = jsonDecode(w.stateJson!);
        if (decoded is Map) {
          final parsed = Map<String, dynamic>.from(decoded);
          parsed['world_id'] = w.id;
          parsed['world_name'] = localName;
          await repository.save(localName, parsed);
        }
      } catch (e) {
        debugPrint('BetaExitPreserve state_json decode error for ${w.id}: $e');
      }
    }

    // Pull granular tables.
    await _hydrateWorldSettings(w.id);
    await _hydrateWorldMapData(w.id);
    await _hydrateWorldSessions(w.id);
    await _hydrateWorldEntities(w.id);
    await _hydrateWorldCharacters(w.id);
    await _hydrateWorldPackages(w.id);

    // SRD link for built-in template, matching WorldJoinService behaviour.
    if (w.templateId == builtinDnd5eV2SchemaId) {
      try {
        await SrdCorePackageBootstrap(db).ensureInstalled();
        await SrdCoreBootstrap(db).ensureImported(
          worldId: w.id,
          build: generateBuiltinDnd5eV2Schema(),
        );
      } catch (e) {
        debugPrint('BetaExitPreserve SRD link error for ${w.id}: $e');
      }
    }
  }

  Future<void> _hydrateWorldSettings(String worldId) async {
    final row = await client
        .from('world_settings')
        .select()
        .eq('world_id', worldId)
        .maybeSingle();
    if (row == null) return;
    await db.worldSettingsDao.upsert(
      WorldSettingsCompanion(
        worldId: Value(worldId),
        settingsJson: Value((row['settings_json'] as String?) ?? '{}'),
        updatedAt: Value(_parseTs(row['updated_at']) ?? DateTime.now()),
      ),
    );
  }

  Future<void> _hydrateWorldMapData(String worldId) async {
    final row = await client
        .from('world_map_data')
        .select()
        .eq('world_id', worldId)
        .maybeSingle();
    if (row == null) return;
    await db.worldMapDataDao.upsert(
      WorldMapDataCompanion(
        worldId: Value(worldId),
        dataJson: Value((row['data_json'] as String?) ?? '{}'),
        updatedAt: Value(_parseTs(row['updated_at']) ?? DateTime.now()),
      ),
    );
  }

  Future<void> _hydrateWorldSessions(String worldId) async {
    final rows = await client
        .from('world_sessions')
        .select()
        .eq('world_id', worldId);
    final companions = <WorldSessionsCompanion>[
      for (final raw in rows as List)
        WorldSessionsCompanion(
          id: Value((raw as Map)['id'] as String),
          worldId: Value(worldId),
          name: Value((raw['name'] as String?) ?? ''),
          dataJson: Value((raw['data_json'] as String?) ?? '{}'),
          isActive: Value((raw['is_active'] as bool?) ?? false),
          sortOrder: Value(((raw['sort_order'] as num?) ?? 0).toInt()),
          updatedAt: Value(_parseTs(raw['updated_at']) ?? DateTime.now()),
        ),
    ];
    if (companions.isNotEmpty) {
      await db.worldSessionsDao.upsertAll(companions);
    }
  }

  Future<void> _hydrateWorldEntities(String worldId) async {
    final rows = await client
        .from('world_entities')
        .select()
        .eq('world_id', worldId);
    final companions = <WorldEntitiesCompanion>[
      for (final raw in rows as List) _entityCompanion(raw as Map<String, dynamic>),
    ];
    if (companions.isNotEmpty) {
      await db.worldEntitiesDao.upsertAll(companions);
    }
  }

  WorldEntitiesCompanion _entityCompanion(Map<String, dynamic> raw) {
    return WorldEntitiesCompanion(
      id: Value(raw['id'] as String),
      worldId: Value(raw['world_id'] as String),
      categorySlug: Value((raw['category_slug'] as String?) ?? ''),
      name: Value((raw['name'] as String?) ?? ''),
      source: Value((raw['source'] as String?) ?? ''),
      description: Value((raw['description'] as String?) ?? ''),
      imagePath: Value((raw['image_path'] as String?) ?? ''),
      imagesJson: Value((raw['images_json'] as String?) ?? '[]'),
      tagsJson: Value((raw['tags_json'] as String?) ?? '[]'),
      dmNotes: Value((raw['dm_notes'] as String?) ?? ''),
      pdfsJson: Value((raw['pdfs_json'] as String?) ?? '[]'),
      locationId: Value(raw['location_id'] as String?),
      fieldsJson: Value((raw['fields_json'] as String?) ?? '{}'),
      packageId: Value(raw['package_id'] as String?),
      packageEntityId: Value(raw['package_entity_id'] as String?),
      linked: Value((raw['linked'] as bool?) ?? false),
      createdAt: Value(_parseTs(raw['created_at']) ?? DateTime.now()),
      updatedAt: Value(_parseTs(raw['updated_at']) ?? DateTime.now()),
    );
  }

  Future<void> _hydrateWorldCharacters(String worldId) async {
    final rows = await client
        .from('world_characters')
        .select()
        .eq('world_id', worldId);
    final companions = <WorldCharactersCompanion>[
      for (final raw in rows as List)
        _characterCompanion(raw as Map<String, dynamic>, fallbackWorldId: worldId),
    ];
    if (companions.isNotEmpty) {
      await db.worldCharactersDao.upsertAll(companions);
    }
  }

  WorldCharactersCompanion _characterCompanion(
    Map<String, dynamic> raw, {
    required String fallbackWorldId,
  }) {
    return WorldCharactersCompanion(
      id: Value(raw['id'] as String),
      worldId: Value((raw['world_id'] as String?) ?? fallbackWorldId),
      ownerId: Value(raw['owner_id'] as String?),
      templateId: Value((raw['template_id'] as String?) ?? ''),
      templateName: Value((raw['template_name'] as String?) ?? ''),
      payloadJson: Value((raw['payload_json'] as String?) ?? '{}'),
      referencedEntityIdsJson:
          Value(_refsToJsonStatic(raw['referenced_entity_ids'])),
      createdAt: Value(_parseTs(raw['created_at']) ?? DateTime.now()),
      updatedAt: Value(_parseTs(raw['updated_at']) ?? DateTime.now()),
    );
  }

  Future<void> _hydrateWorldPackages(String worldId) async {
    final rows = await client
        .from('world_packages')
        .select()
        .eq('world_id', worldId);
    final companions = <WorldPackagesCompanion>[
      for (final raw in rows as List)
        WorldPackagesCompanion(
          packageId: Value((raw as Map)['package_id'] as String),
          worldId: Value(worldId),
          packageName: Value((raw['package_name'] as String?) ?? ''),
          sharedBy: Value(raw['shared_by'] as String?),
          stateJson: Value((raw['state_json'] as String?) ?? '{}'),
          createdAt: Value(_parseTs(raw['created_at']) ?? DateTime.now()),
          updatedAt: Value(_parseTs(raw['updated_at']) ?? DateTime.now()),
        ),
    ];
    if (companions.isNotEmpty) {
      await db.worldPackagesDao.upsertAll(companions);
    }
  }

  Future<void> _hydrateOrphanCharacter(_OrphanChar c) async {
    await db.worldCharactersDao.upsert(
      WorldCharactersCompanion(
        id: Value(c.id),
        // Orphan online char has no world_id on the server, but Drift requires
        // a non-null worldId (FK). Hydration is "best-effort archive" — bind
        // to a synthetic id derived from the char so it stays addressable
        // without polluting any real world's view. Caller never opens this
        // through a world tab; hub char list resolves by char id.
        worldId: Value(c.worldId ?? c.id),
        ownerId: Value(c.ownerId),
        templateId: Value(c.templateId),
        templateName: Value(c.templateName),
        payloadJson: Value(c.payloadJson),
        referencedEntityIdsJson: Value(c.referencedEntityIdsJson),
        createdAt: Value(c.createdAt ?? DateTime.now()),
        updatedAt: Value(c.updatedAt ?? DateTime.now()),
      ),
    );
  }

  DateTime? _parseTs(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}

class SummaryCounts {
  const SummaryCounts({
    required this.ownedWorlds,
    required this.orphanChars,
    required this.personalPackages,
    required this.cloudOnlyWorlds,
    required this.cloudOnlyChars,
    required this.cloudOnlyPackages,
  });

  const SummaryCounts.empty()
      : ownedWorlds = 0,
        orphanChars = 0,
        personalPackages = 0,
        cloudOnlyWorlds = 0,
        cloudOnlyChars = 0,
        cloudOnlyPackages = 0;

  final int ownedWorlds;
  final int orphanChars;
  final int personalPackages;
  final int cloudOnlyWorlds;
  final int cloudOnlyChars;
  final int cloudOnlyPackages;

  bool get hasAnything =>
      ownedWorlds > 0 || orphanChars > 0 || personalPackages > 0;
  bool get hasDownloads =>
      cloudOnlyWorlds > 0 || cloudOnlyChars > 0 || cloudOnlyPackages > 0;
}

class PreserveResult {
  const PreserveResult({
    required this.worldIds,
    required this.orphanCharIds,
    required this.personalPackageNames,
    this.failedIds = const <String>[],
  });

  const PreserveResult.empty()
      : worldIds = const <String>[],
        orphanCharIds = const <String>[],
        personalPackageNames = const <String>[],
        failedIds = const <String>[];

  final List<String> worldIds;
  final List<String> orphanCharIds;
  final List<String> personalPackageNames;

  /// Rows that failed to hydrate locally. Tagged as `world:<id>`,
  /// `char:<id>`, or a free-form scope (`personal_bootstrap`). Caller uses
  /// [hasFailures] to abort the destructive `leave_beta` RPC.
  final List<String> failedIds;

  bool get hasFailures => failedIds.isNotEmpty;
}

class _OwnedSnapshot {
  const _OwnedSnapshot({
    required this.worlds,
    required this.orphanChars,
    required this.personalPackageNames,
  });

  final List<_OwnedWorld> worlds;
  final List<_OrphanChar> orphanChars;
  final List<String> personalPackageNames;
}

class _OwnedWorld {
  const _OwnedWorld({
    required this.id,
    required this.worldName,
    required this.ownerId,
    required this.templateId,
    required this.templateHash,
    required this.stateJson,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _OwnedWorld.fromRow(Map<String, dynamic> row) {
    final stateRaw = row['state_json'];
    String? state;
    String name = '';
    if (stateRaw is String && stateRaw.isNotEmpty) {
      state = stateRaw;
      try {
        final decoded = jsonDecode(stateRaw);
        if (decoded is Map) {
          final n = decoded['world_name'];
          if (n is String && n.isNotEmpty) name = n;
        }
      } catch (_) {}
    }
    if (name.isEmpty) name = (row['id'] as String?) ?? '';
    return _OwnedWorld(
      id: row['id'] as String,
      worldName: name,
      ownerId: row['owner_id'] as String?,
      templateId: row['template_id'] as String?,
      templateHash: row['template_hash'] as String?,
      stateJson: state,
      createdAt: _parseTsStatic(row['created_at']),
      updatedAt: _parseTsStatic(row['updated_at']),
    );
  }

  final String id;
  final String worldName;
  final String? ownerId;
  final String? templateId;
  final String? templateHash;
  final String? stateJson;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class _OrphanChar {
  const _OrphanChar({
    required this.id,
    required this.worldId,
    required this.ownerId,
    required this.templateId,
    required this.templateName,
    required this.payloadJson,
    required this.referencedEntityIdsJson,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _OrphanChar.fromRow(Map<String, dynamic> row) {
    return _OrphanChar(
      id: row['id'] as String,
      worldId: row['world_id'] as String?,
      ownerId: row['owner_id'] as String?,
      templateId: (row['template_id'] as String?) ?? '',
      templateName: (row['template_name'] as String?) ?? '',
      payloadJson: (row['payload_json'] as String?) ?? '{}',
      referencedEntityIdsJson: _refsToJsonStatic(row['referenced_entity_ids']),
      createdAt: _parseTsStatic(row['created_at']),
      updatedAt: _parseTsStatic(row['updated_at']),
    );
  }

  final String id;
  final String? worldId;
  final String? ownerId;
  final String templateId;
  final String templateName;
  final String payloadJson;
  final String referencedEntityIdsJson;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

DateTime? _parseTsStatic(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

/// Supabase JSONB `referenced_entity_ids` → Drift TEXT (`_json` suffix).
/// Sunucu List döner; null → "[]"; tip uyumsuz → "[]".
String _refsToJsonStatic(Object? v) {
  if (v == null) return '[]';
  if (v is String) return v.isEmpty ? '[]' : v;
  if (v is List) return jsonEncode(v);
  return '[]';
}

/// Supabase konfigüre değilse null döner — çağıranlar no-op yapar.
final betaExitPreserveServiceProvider =
    Provider<BetaExitPreserveService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  final mirror = ref.watch(worldMirrorServiceProvider);
  if (mirror == null) return null;
  return BetaExitPreserveService(
    ref: ref,
    client: Supabase.instance.client,
    db: ref.read(appDatabaseProvider),
    repository: ref.read(campaignRepositoryProvider),
    mirror: mirror,
  );
});
