import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../data/datasources/local/campaign_local_ds.dart';
import '../../data/repositories/campaign_repository_impl.dart';

final campaignLocalDsProvider = Provider((_) => CampaignLocalDataSource());

final campaignRepositoryProvider = Provider(
  (ref) => CampaignRepository(ref.read(campaignLocalDsProvider)),
);

/// Mevcut kampanya listesi.
final campaignListProvider = FutureProvider<List<String>>((ref) {
  return ref.read(campaignRepositoryProvider).getAvailable();
});

/// Kampanya isim + template bilgisi.
class CampaignInfo {
  final String name;
  final String templateName;
  const CampaignInfo({required this.name, required this.templateName});
}

/// Kampanya listesi + template bilgileri.
final campaignInfoListProvider = FutureProvider<List<CampaignInfo>>((ref) async {
  final ds = ref.read(campaignLocalDsProvider);
  final names = await ref.read(campaignRepositoryProvider).getAvailable();
  final infos = <CampaignInfo>[];
  for (final name in names) {
    final path = p.join(AppPaths.worldsDir, name);
    final templateName = await ds.getTemplateName(path);
    infos.add(CampaignInfo(name: name, templateName: templateName));
  }
  return infos;
});

/// Aktif kampanya adı. null = henüz seçilmedi.
class ActiveCampaignNotifier extends StateNotifier<String?> {
  final CampaignRepository _repo;

  ActiveCampaignNotifier(this._repo) : super(null);

  Map<String, dynamic>? _data;
  Map<String, dynamic>? get data => _data;

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

  Future<bool> create(String worldName) async {
    try {
      await _repo.create(worldName);
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
}

final activeCampaignProvider =
    StateNotifierProvider<ActiveCampaignNotifier, String?>((ref) {
  return ActiveCampaignNotifier(ref.read(campaignRepositoryProvider));
});
