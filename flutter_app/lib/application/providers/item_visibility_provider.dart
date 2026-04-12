import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/datasources/remote/shared_items_remote_ds.dart';
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

  /// Public'e al: yerel payload'ı yükle.
  Future<bool> publish({
    required String itemType,
    required String localId,
    required String title,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final payload = await _loadPayload(itemType, localId);
      await _ref.read(sharedItemsRemoteDsProvider).publish(
            itemType: itemType,
            localId: localId,
            title: title,
            description: description,
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
}

final itemVisibilityNotifierProvider =
    StateNotifierProvider<ItemVisibilityNotifier, AsyncValue<void>>(
  (ref) => ItemVisibilityNotifier(ref),
);
