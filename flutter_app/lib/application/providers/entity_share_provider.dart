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
final worldEntitySharesProvider =
    FutureProvider.family<List<EntityShare>, String>((ref, worldId) async {
  final svc = ref.watch(entityShareServiceProvider);
  if (svc == null) return const [];
  try {
    return await svc.listForWorld(worldId);
  } catch (_) {
    return const [];
  }
});
