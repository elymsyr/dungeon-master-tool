import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';

/// Per-item upload ceiling for R2 assets — mirrors the Worker's
/// `MAX_UPLOAD_BYTES`. `AssetService.maxItemBytes` is derived from this, so the
/// client rejects an oversized file before spending the round-trip.
const mediaItemSizeLimit = 20 * 1024 * 1024; // 20 MB

/// Per-user total media ceiling — mirrors the Worker's `USER_QUOTA_BYTES`
/// (`cloudflare/wrangler.toml`), which is what actually enforces it. Client
/// side this only drives the usage bar; changing it here changes nothing on
/// the server.
const mediaUserQuota = 100 * 1024 * 1024; // 100 MB

/// The user's total counted cloud storage (bytes) — R2 assets plus the free
/// media bucket, as tallied server-side by `get_user_total_storage_used`.
///
/// Bulut sync kaldırıldıktan sonra geriye sayılan tek şey medya: dünyalar ve
/// karakterler artık buluta kopyalanmıyor.
final cloudStorageUsedProvider = FutureProvider<int>((ref) async {
  final auth = ref.watch(authProvider);
  if (!SupabaseConfig.isConfigured || auth == null) return 0;
  final result = await Supabase.instance.client.rpc(
    'get_user_total_storage_used',
    params: {'p_user_id': auth.uid},
  );
  if (result == null) return 0;
  if (result is num) return result.toInt();
  return int.tryParse(result.toString()) ?? 0;
});
