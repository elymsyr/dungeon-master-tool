import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../data/datasources/local/campaign_local_ds.dart' show CampaignLocalDataSource, TrashItem;
import '../../data/repositories/campaign_repository_impl.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../services/campaign_import_service.dart';

final campaignLocalDsProvider = Provider((_) => CampaignLocalDataSource());

final campaignRepositoryProvider = Provider<CampaignRepository>(
  (ref) => CampaignRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.read(campaignLocalDsProvider),
  ),
);

/// Legacy (Python v0.8.4) world klasörlerini [AppPaths.worldsDir] altına
/// kopyalayan servis. UI bunu çağırır; mevcut load pipeline sonrasında
/// otomatik olarak MsgPack → SQLite migration'u devralır.
final campaignImportServiceProvider = Provider<CampaignImportService>(
  (ref) => CampaignImportService(
    ref.watch(campaignRepositoryProvider),
    ref.watch(campaignLocalDsProvider),
  ),
);

/// Mevcut kampanya listesi.
final campaignListProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(campaignRepositoryProvider).getAvailable();
});

/// Monotonic revision counter for the active campaign/package data.
///
/// Bumped when `_data` is mutated in-place and downstream providers need
/// to re-read without forcing a full `activeCampaignProvider` rebuild
/// (which used to be done by null-toggling `state`, triggering a cascade
/// reparse of WorldSchema and EntityNotifier on every bump). Watchers
/// that care about data-content changes should watch this provider in
/// addition to `activeCampaignProvider`.
final campaignRevisionProvider = StateProvider<int>((_) => 0);

/// Kampanya isim + template bilgisi.
class CampaignInfo {
  final String id;
  final String name;
  final String templateName;
  const CampaignInfo({
    required this.id,
    required this.name,
    required this.templateName,
  });
}

/// Kampanya listesi + template bilgileri.
final campaignInfoListProvider = FutureProvider<List<CampaignInfo>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await db.campaignDao.getCampaignInfoList();
  return rows
      .map((r) => CampaignInfo(
            id: r.id,
            name: r.worldName,
            templateName: r.templateName,
          ))
      .toList();
});

/// Per-campaign metadata lookup — cover / description / tags için.
/// Campaign blob'undan `metadata` alanını okur. List UI bu provider'ı
/// watch ederek cover/desc/tags gösterimi için kullanır.
final campaignMetadataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, campaignName) async {
  try {
    final data = await ref.read(campaignRepositoryProvider).load(campaignName);
    final meta = data['metadata'];
    return meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Campaign metadata writer — sadece metadata'yı değiştirir, diğer verilere
/// dokunmaz. Ayarlar dialog'undan çağrılır.
Future<void> updateCampaignMetadata(
  WidgetRef ref,
  String campaignName,
  Map<String, dynamic> newMetadata,
) async {
  final repo = ref.read(campaignRepositoryProvider);
  final data = await repo.load(campaignName);
  data['metadata'] = newMetadata;
  await repo.save(campaignName, data);
  ref.invalidate(campaignMetadataProvider(campaignName));
  ref.invalidate(campaignInfoListProvider);
}

/// Aktif kampanya adı. null = henüz seçilmedi.
class ActiveCampaignNotifier extends StateNotifier<String?> {
  final CampaignRepository _repo;
  final Ref _ref;

  ActiveCampaignNotifier(this._repo, this._ref) : super(null);

  Map<String, dynamic>? _data;
  Map<String, dynamic>? get data => _data;

  /// Dışarıdan veri ile önceden yükle (paket ProviderScope override için).
  void preload(String name, Map<String, dynamic> data) {
    _data = data;
    state = name;
  }

  Future<bool> load(String name) async {
    try {
      _data = await _repo.load(name);
      state = name;
      return true;
    } catch (e, st) {
      debugPrint('Campaign load error: $e\n$st');
      return false;
    }
  }

  Future<bool> create(String worldName, {WorldSchema? template}) async {
    try {
      await _repo.create(worldName, template: template);
      return load(worldName);
    } catch (e, st) {
      debugPrint('Campaign create error: $e\n$st');
      return false;
    }
  }

  Future<void> save() async {
    if (state != null && _data != null) {
      await _repo.save(state!, _data!);
    }
  }

  /// Re-reads the active campaign from disk, replaces [_data] in place
  /// (so any cached references — e.g. the wrapped notifier inside
  /// PackageScreen's ProviderScope — observe the new values), and
  /// bumps [campaignRevisionProvider] so downstream providers
  /// (worldSchemaProvider, entityProvider, …) re-read from the fresh
  /// data without a full notifier recreation cascade. Used by the
  /// cloud "restore into the currently open item" flow.
  Future<void> reload() async {
    if (state == null) return;
    final name = state!;
    final fresh = await _repo.load(name);
    if (_data == null) {
      _data = fresh;
    } else {
      _data!
        ..clear()
        ..addAll(fresh);
    }
    _bumpRevision();
  }

  /// Replaces the in-memory data map with [newData] and persists it.
  /// Like [reload], but uses a caller-supplied payload instead of
  /// reading from disk. Used by cloud restore where we already have
  /// the downloaded backup envelope.
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

  Future<void> delete(String campaignName) async {
    await _repo.delete(campaignName);
    if (state == campaignName) {
      _data = null;
      state = null;
    }
  }
}

final activeCampaignProvider =
    StateNotifierProvider<ActiveCampaignNotifier, String?>((ref) {
  return ActiveCampaignNotifier(ref.watch(campaignRepositoryProvider), ref);
});

/// Active campaign's DB id (`world_id`), or null when none loaded. Pulled
/// from the loaded campaign data map; updates whenever
/// [campaignRevisionProvider] bumps.
final activeCampaignIdProvider = Provider<String?>((ref) {
  ref.watch(campaignRevisionProvider);
  final notifier = ref.watch(activeCampaignProvider.notifier);
  final data = notifier.data;
  if (data == null) return null;
  final id = data['world_id'];
  return id is String ? id : null;
});

/// Trash'teki silinen kampanyalar.
final trashListProvider = FutureProvider<List<TrashItem>>((ref) {
  return ref.read(campaignLocalDsProvider).listTrash();
});
