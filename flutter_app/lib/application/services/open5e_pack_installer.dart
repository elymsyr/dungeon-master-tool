import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/repositories/package_repository.dart';

/// Installs the offline-built Open5e content packs (under `assets/open5e_packs/`)
/// into the local package store.
///
/// The bundled `*.pkg.json` payloads carry only `package_name` + `metadata` +
/// `entities` (deterministic ids, `_ref`s already resolved, `_lookup`s left for
/// import-time resolution). The world schema is NOT shipped in the asset — it is
/// attached HERE from the live built-in v2 schema, so a pack always renders
/// against the current category/field definitions instead of a frozen copy.
class Open5ePackInstaller {
  final PackageRepository _repo;
  Open5ePackInstaller(this._repo);

  static const _manifestAsset = 'assets/open5e_packs/manifest.json';
  static const _assetDir = 'assets/open5e_packs';

  /// Read the bundled manifest describing the available packs.
  Future<List<Open5ePackInfo>> available() async {
    final raw = await _tryLoadString(_manifestAsset);
    if (raw == null) return const [];
    final json = jsonDecode(raw);
    final packs = (json is Map ? json['packs'] : null);
    if (packs is! List) return const [];
    return packs
        .whereType<Map>()
        .map((m) => Open5ePackInfo.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Install one pack by its manifest [info]. Returns the local package name.
  Future<String> install(Open5ePackInfo info) async {
    final raw = await rootBundle.loadString('$_assetDir/${info.asset}');
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final packageName = payload['package_name'] as String;
    final entities = (payload['entities'] as Map).cast<String, dynamic>();
    final metadata = (payload['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    // Attach the live built-in v2 schema so attribute keys match the category
    // field schemas (R1: embed rather than reference, keeping the pack
    // self-contained for marketplace download).
    final schema = generateBuiltinDnd5eV2Schema().schema;

    final data = <String, dynamic>{
      'entities': entities,
      'world_schema': schema.toJson(),
      'template_id': builtinDnd5eV2SchemaId,
      'template_original_hash': builtinDnd5eV2OriginalHash,
      // Non-typed keys land in the package state_json (title, attribution, …).
      'metadata': metadata,
    };

    await _repo.save(packageName, data);
    return packageName;
  }

  Future<String?> _tryLoadString(String asset) async {
    try {
      return await rootBundle.loadString(asset);
    } catch (_) {
      return null;
    }
  }
}

/// One entry from `assets/open5e_packs/manifest.json`.
class Open5ePackInfo {
  final String asset;
  final String packageName;
  final String title;
  final String publisher;
  final String license;
  final String gameSystem;
  final bool isSrdOverlap;
  final Map<String, int> counts;

  const Open5ePackInfo({
    required this.asset,
    required this.packageName,
    required this.title,
    required this.publisher,
    required this.license,
    required this.gameSystem,
    required this.isSrdOverlap,
    required this.counts,
  });

  int get totalEntities => counts.values.fold(0, (a, b) => a + b);

  factory Open5ePackInfo.fromJson(Map<String, dynamic> j) => Open5ePackInfo(
        asset: j['asset'] as String,
        packageName: j['package_name'] as String,
        title: j['title'] as String? ?? j['package_name'] as String,
        publisher: j['publisher'] as String? ?? '',
        license: j['license'] as String? ?? '',
        gameSystem: j['game_system'] as String? ?? '',
        isSrdOverlap: j['is_srd_overlap'] as bool? ?? false,
        counts: ((j['counts'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );
}
