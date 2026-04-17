import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/deep_copy.dart';
import '../../data/database/database_provider.dart';
import '../../data/datasources/local/package_local_ds.dart';
import '../../data/repositories/package_repository_impl.dart';
import '../../domain/entities/package_info.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/package_repository.dart';
import 'campaign_provider.dart' show campaignRevisionProvider;

final packageLocalDsProvider = Provider((_) => PackageLocalDataSource());

final packageRepositoryProvider = Provider<PackageRepository>(
  (ref) => PackageRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.read(packageLocalDsProvider),
  ),
);

/// Paket listesi — hub ekranında gösterim için.
final packageListProvider = FutureProvider<List<PackageInfo>>((ref) {
  return ref.watch(packageRepositoryProvider).getPackageInfoList();
});

/// Per-package metadata lookup — cover / description / tags için.
final packageMetadataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, packageName) async {
  try {
    final data = await ref.read(packageRepositoryProvider).load(packageName);
    final meta = data['metadata'];
    return meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Package metadata writer — sadece metadata'yı değiştirir.
Future<void> updatePackageMetadata(
  WidgetRef ref,
  String packageName,
  Map<String, dynamic> newMetadata,
) async {
  final repo = ref.read(packageRepositoryProvider);
  final data = await repo.load(packageName);
  data['metadata'] = newMetadata;
  await repo.save(packageName, data);
  ref.invalidate(packageMetadataProvider(packageName));
  ref.invalidate(packageListProvider);
}

/// Aktif paket adı. null = henüz seçilmedi.
class ActivePackageNotifier extends StateNotifier<String?> {
  final PackageRepository _repo;
  final Ref _ref;

  ActivePackageNotifier(this._repo, this._ref) : super(null);

  Map<String, dynamic>? _data;
  Map<String, dynamic>? get data => _data;

  Future<bool> load(String name) async {
    try {
      _data = await _repo.load(name);
      state = name;
      return true;
    } catch (e, st) {
      debugPrint('Package load error: $e\n$st');
      return false;
    }
  }

  Future<bool> create(String packageName, {WorldSchema? template}) async {
    try {
      await _repo.create(packageName, template: template);
      return load(packageName);
    } catch (e, st) {
      debugPrint('Package create error: $e\n$st');
      return false;
    }
  }

  Future<void> save() async {
    if (state != null && _data != null) {
      await _repo.save(state!, _data!);
    }
  }

  /// Replaces the in-memory package data with [newData] and persists
  /// it. Mirrors [ActiveCampaignNotifier.replaceWithData]; used by the
  /// cloud "restore into the open item" flow to overwrite the running
  /// package session with fresh downloaded content.
  Future<void> replaceWithData(Map<String, dynamic> newData) async {
    if (state == null) return;
    final name = state!;
    if (_data == null) {
      _data = Map<String, dynamic>.from(newData);
    } else {
      _data!
        ..clear()
        ..addAll(newData);
    }
    await _repo.save(name, _data!);
    _bumpRevision();
  }

  void _bumpRevision() {
    final notifier = _ref.read(campaignRevisionProvider.notifier);
    notifier.state = notifier.state + 1;
  }

  Future<void> delete(String packageName) async {
    await _repo.delete(packageName);
    if (state == packageName) {
      _data = null;
      state = null;
    }
  }

  /// Applies a template update to the active package (mirrors campaign logic).
  Future<void> applyTemplateUpdate(WorldSchema newTemplate) async {
    if (state == null || _data == null) return;
    final currentHash = computeWorldSchemaContentHash(newTemplate);
    _data!['world_schema'] = deepCopyJson(newTemplate.toJson());
    _data!['template_id'] = newTemplate.schemaId;
    _data!['template_hash'] = currentHash;
    if (newTemplate.originalHash != null) {
      _data!['template_original_hash'] = newTemplate.originalHash;
    }
    _data!.remove('template_dismissed_hash');
    _data!.remove('template_updates_muted');
    await _repo.save(state!, _data!);
    _bumpRevision();
  }

  /// Dismisses a specific template version for the active package.
  Future<void> dismissTemplateUpdate(String templateHash) async {
    if (state == null || _data == null) return;
    _data!['template_dismissed_hash'] = templateHash;
    await _repo.save(state!, _data!);
  }

  /// Permanently mutes template update prompts for the active package.
  Future<void> muteTemplateUpdates() async {
    if (state == null || _data == null) return;
    _data!['template_updates_muted'] = true;
    await _repo.save(state!, _data!);
  }
}

final activePackageProvider =
    StateNotifierProvider<ActivePackageNotifier, String?>((ref) {
  return ActivePackageNotifier(ref.watch(packageRepositoryProvider), ref);
});
