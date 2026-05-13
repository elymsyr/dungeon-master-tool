import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/app_database.dart';
import '../../data/network/world_membership_service.dart';

/// "Join with code" akışını koordine eder:
///   1. RPC redeem_world_invite → (worldId, worldName)
///   2. Supabase `worlds`'tan state_json initial snapshot çek
///   3. Lokal Drift'te Campaign satırı (state ile birlikte) upsert et
///   4. caller hub list invalidation yapar
///
/// Entity/mind map/character mirror pull'u PR-O4'te WorldSyncService
/// ile yapılır; bu noktada player worldü hub listesinde görür ve açabilir.
class WorldJoinService {
  final WorldMembershipService membership;
  final AppDatabase db;
  final SupabaseClient supabase;

  WorldJoinService({
    required this.membership,
    required this.db,
    required this.supabase,
  });

  Future<({String worldId, String worldName})> joinWithCode(String code) async {
    final res = await membership.redeemInvite(code);

    // Initial state snapshot — campaigns mirror'ı.
    String stateJson = '{}';
    try {
      final row = await supabase
          .from('worlds')
          .select('state_json')
          .eq('id', res.worldId)
          .maybeSingle();
      final raw = row?['state_json'];
      if (raw is String && raw.isNotEmpty) stateJson = raw;
    } catch (_) {
      // RLS ya da network: boş bırak, ileride sync tamamlar.
    }

    final now = DateTime.now().toUtc();
    final existing =
        await (db.select(db.campaigns)..where((t) => t.id.equals(res.worldId)))
            .getSingleOrNull();
    if (existing == null) {
      await db.into(db.campaigns).insert(
            CampaignsCompanion.insert(
              id: res.worldId,
              worldName: res.worldName,
              stateJson: Value(stateJson),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      await (db.update(db.campaigns)
            ..where((t) => t.id.equals(res.worldId)))
          .write(CampaignsCompanion(
        worldName: Value(res.worldName),
        stateJson: Value(stateJson),
        updatedAt: Value(now),
      ));
    }
    return res;
  }
}
