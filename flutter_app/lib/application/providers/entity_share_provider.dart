import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/network/entity_share_service.dart';
import '../../domain/entities/online/entity_share.dart';
import 'auth_provider.dart';

/// EntityShareService — yalnızca auth + Supabase configured ise non-null.
final entityShareServiceProvider = Provider<EntityShareService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.watch(authProvider) == null) return null;
  return EntityShareService(Supabase.instance.client);
});

/// Aktif worldün entity_shares kayıtları. Realtime subscribe ile invalidate
/// edilir (PR-O4 applier'ı entity_shares event'i için invalidate eder —
/// PR-O6'da bu eklenmiyor; manuel invalidate UI'dan).
///
/// Hata yukarı çıkar: boş liste "hiçbir kart paylaşılmıyor" demek, oyuncuda
/// her kartı gri yapardı. Tazelemede hata önceki listeyi korur.
final worldEntitySharesProvider =
    FutureProvider.family<List<EntityShare>, String>((ref, worldId) async {
  final svc = ref.watch(entityShareServiceProvider);
  if (svc == null) return const [];
  return svc.listForWorld(worldId);
});

/// Faz 5.5b — oyuncunun son kart doğrulamasında görünür olan kartlar
/// (`get_shared_entity_stamps`, `get_shared_entities` ile aynı predikat).
/// Paylaşım satırı duran ama bulutta artık olmayan kart — DM sildi — burada
/// yoktur ve gri görünür. İlk doğrulamaya kadar null.
final sharedEntityStampIdsProvider =
    StateProvider.family<Set<String>?, String>((ref, worldId) => null);
