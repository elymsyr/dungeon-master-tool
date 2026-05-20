import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

/// Verilen campaign id'sinin Supabase'de "publish" edilmiş olup olmadığını
/// söyler (yani `worlds` tablosunda satır var mı). UI online toggle'ı
/// göstermek + invite yönetimini açıp kapamak için kullanır.
final worldOnlineStatusProvider =
    FutureProvider.family<bool, String>((ref, worldId) async {
  if (!SupabaseConfig.isConfigured) return false;
  final auth = ref.watch(authProvider);
  if (auth == null) return false;
  try {
    final row = await guardedNetwork(
      ref,
      () => Supabase.instance.client
          .from('worlds')
          .select('id')
          .eq('id', worldId)
          .maybeSingle(),
    );
    return row != null;
  } catch (_) {
    return false;
  }
});
