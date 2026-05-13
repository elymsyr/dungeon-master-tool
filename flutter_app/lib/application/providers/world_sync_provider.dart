import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../services/world_sync_service.dart';
import 'auth_provider.dart';

/// Tekil [WorldSyncService] — Supabase yapılandırılmış ve auth varsa. Aksi
/// halde null; tüketiciler null guard ile offline davranır.
final worldSyncServiceProvider = Provider<WorldSyncService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  final auth = ref.watch(authProvider);
  if (auth == null) return null;

  final svc = WorldSyncService(Supabase.instance.client);
  ref.onDispose(svc.dispose);
  return svc;
});
