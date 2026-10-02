import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/database/database_provider.dart';
import '../services/world_join_service.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'world_membership_provider.dart';

final worldJoinServiceProvider = Provider<WorldJoinService>((ref) {
  return WorldJoinService(
    membership: ref.watch(worldMembershipServiceProvider),
    db: ref.watch(appDatabaseProvider),
    supabase: Supabase.instance.client,
    repository: ref.watch(campaignRepositoryProvider),
  );
});

/// Faz 5.5a — oyuncu olarak üyesi olunan, bu cihazda olmayan dünyalar. Yerel
/// liste değişince (kabuk kuruldu, dünya silindi) yeniden sorulur;
/// çevrimdışıyken boş.
final memberWorldsProvider =
    FutureProvider<List<({String id, String name})>>((ref) async {
  ref.watch(campaignInfoListProvider);
  if (!SupabaseConfig.isConfigured || ref.watch(authProvider) == null) {
    return const [];
  }
  try {
    return await ref.read(worldJoinServiceProvider).listMemberWorlds();
  } catch (e) {
    debugPrint('memberWorlds: ${isOfflineError(e) ? 'offline' : e}');
    return const [];
  }
});
