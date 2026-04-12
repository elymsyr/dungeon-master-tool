import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';

/// Şu anki kullanıcının admin olup olmadığı. Email kaynak kodda DEĞİL —
/// Supabase tarafındaki `app_admins` tablosu ve `is_admin()` RPC'si
/// üzerinden doğrulanır. Auth state değişince otomatik refresh.
///
/// Atama: Supabase SQL editor'da elle:
///   INSERT INTO public.app_admins (user_id)
///     SELECT id FROM auth.users WHERE email = '...';
final isAdminProvider = FutureProvider<bool>((ref) async {
  if (!SupabaseConfig.isConfigured) return false;
  final auth = ref.watch(authProvider);
  if (auth == null) return false;

  try {
    final result = await Supabase.instance.client.rpc('is_admin');
    return result == true;
  } catch (e, st) {
    debugPrint('isAdmin RPC error: $e\n$st');
    return false;
  }
});
