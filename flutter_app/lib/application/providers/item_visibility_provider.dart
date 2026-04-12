import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/datasources/remote/shared_items_remote_ds.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/shared_item.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'package_provider.dart';
import 'template_provider.dart';

final sharedItemsRemoteDsProvider =
    Provider<SharedItemsRemoteDataSource>((_) => SharedItemsRemoteDataSource());

/// (item_type, local_id) için public/private state.
typedef ItemVisibilityKey = ({String itemType, String localId});

final itemVisibilityProvider =
    FutureProvider.family<SharedItem?, ItemVisibilityKey>((ref, key) async {
  if (!SupabaseConfig.isConfigured) return null;
  final auth = ref.watch(authProvider);
  if (auth == null) return null;
  return ref.read(sharedItemsRemoteDsProvider).fetch(
        itemType: key.itemType,
        localId: key.localId,
      );
});

class ItemVisibilityNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  ItemVisibilityNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Public'e al: yerel payload'ı yükle. Description, language ve tags
  /// marketplace görüntülenmesi için zorunlu niteliktedir ama zorunlu
  /// constraint'ler yalnızca UI'da (publish dialog) uygulanır.
  Future<bool> publish({
    required String itemType,
    required String localId,
    required String title,
    String? description,
    String? language,
    List<String> tags = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      final payload = await _loadPayload(itemType, localId);
      await _ref.read(sharedItemsRemoteDsProvider).publish(
            itemType: itemType,
            localId: localId,
            title: title,
            description: description,
            language: language,
            tags: tags,
            payload: payload,
          );
      _ref.invalidate(itemVisibilityProvider((itemType: itemType, localId: localId)));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      debugPrint('Publish error: $e\n$st');
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Private'a dön: row + storage sil.
  Future<bool> unpublish({
    required String itemType,
    required String localId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(sharedItemsRemoteDsProvider).unpublish(
            itemType: itemType,
            localId: localId,
          );
      _ref.invalidate(itemVisibilityProvider((itemType: itemType, localId: localId)));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      debugPrint('Unpublish error: $e\n$st');
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Yerel kayıttan item payload'ını çıkar. Tip bazlı yönlendirme.
  Future<Map<String, dynamic>> _loadPayload(String itemType, String localId) async {
    switch (itemType) {
      case 'world':
        return _ref.read(campaignRepositoryProvider).load(localId);
      case 'template':
        final tpl = await _ref.read(templateLocalDsProvider).loadById(localId);
        if (tpl == null) throw StateError('Template not found: $localId');
        return {'world_schema': tpl.toJson()};
      case 'package':
        return _ref.read(packageRepositoryProvider).load(localId);
    }
    throw ArgumentError('Unknown itemType: $itemType');
  }

  /// Marketplace'ten bir item'ı indir, yerel DB'ye kaydet ve download_count'u
  /// 1 artır. Çakışan isimler için otomatik " (imported)" eki uygulanır.
  Future<bool> downloadAndImport({
    required String itemId,
    required String itemType,
    required String payloadPath,
    required String title,
  }) async {
    state = const AsyncValue.loading();
    try {
      final payload = await _ref.read(sharedItemsRemoteDsProvider).download(
            itemId: itemId,
            payloadPath: payloadPath,
          );
      await _importPayload(itemType, title, payload);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      debugPrint('Download error: $e\n$st');
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> _importPayload(
    String itemType,
    String title,
    Map<String, dynamic> payload,
  ) async {
    switch (itemType) {
      case 'world':
        await _ref.read(campaignRepositoryProvider).save(title, payload);
        return;
      case 'package':
        await _ref.read(packageRepositoryProvider).save(title, payload);
        return;
      case 'template':
        final raw = payload['world_schema'];
        if (raw is! Map<String, dynamic>) {
          throw StateError('Invalid template payload: world_schema missing');
        }
        final schema = WorldSchema.fromJson(raw);
        await _ref.read(templateLocalDsProvider).save(schema);
        return;
    }
    throw ArgumentError('Unknown itemType: $itemType');
  }
}

final itemVisibilityNotifierProvider =
    StateNotifierProvider<ItemVisibilityNotifier, AsyncValue<void>>(
  (ref) => ItemVisibilityNotifier(ref),
);
