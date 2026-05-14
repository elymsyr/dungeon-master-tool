import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/app_database.dart';
import '../../data/network/world_membership_service.dart';
import '../../domain/repositories/campaign_repository.dart';

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
  final CampaignRepository repository;

  WorldJoinService({
    required this.membership,
    required this.db,
    required this.supabase,
    required this.repository,
  });

  Future<({String worldId, String worldName})> joinWithCode(String code) async {
    final res = await membership.redeemInvite(code);

    // Initial state snapshot — campaigns mirror'ı.
    Map<String, dynamic>? parsed;
    try {
      final row = await supabase
          .from('worlds')
          .select('state_json')
          .eq('id', res.worldId)
          .maybeSingle();
      final raw = row?['state_json'];
      if (raw is String && raw.isNotEmpty && raw != '{}') {
        final decoded = jsonDecode(raw);
        if (decoded is Map) parsed = Map<String, dynamic>.from(decoded);
      }
    } catch (e, st) {
      debugPrint('joinWithCode snapshot fetch error: $e\n$st');
    }

    final now = DateTime.now().toUtc();
    // Resolve local name — repository.save keys by worldName, so if the
    // player already has a different campaign with the same name we must
    // pick a unique local label to avoid overwriting their local data.
    final existingById =
        await (db.select(db.campaigns)..where((t) => t.id.equals(res.worldId)))
            .getSingleOrNull();
    String localName = existingById?.worldName ?? res.worldName;
    if (existingById == null) {
      final clash =
          await (db.select(db.campaigns)..where((t) => t.worldName.equals(localName)))
              .getSingleOrNull();
      if (clash != null) {
        // Suffix until unique.
        var attempt = 2;
        while (true) {
          final candidate = '$localName ($attempt)';
          final c = await (db.select(db.campaigns)
                ..where((t) => t.worldName.equals(candidate)))
              .getSingleOrNull();
          if (c == null) {
            localName = candidate;
            break;
          }
          attempt++;
          if (attempt > 99) {
            localName = '$localName-${res.worldId.substring(0, 8)}';
            break;
          }
        }
      }
      await db.into(db.campaigns).insert(
            CampaignsCompanion.insert(
              id: res.worldId,
              worldName: localName,
              stateJson: const Value('{}'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }

    if (parsed != null) {
      // Force id/name to match the resolved local label — server snapshot is
      // authoritative for content, but the local row keys off this id/name.
      parsed['world_id'] = res.worldId;
      parsed['world_name'] = localName;
      try {
        await repository.save(localName, parsed);
      } catch (e, st) {
        debugPrint('joinWithCode local save error: $e\n$st');
        rethrow;
      }
    }
    return (worldId: res.worldId, worldName: localName);
  }
}
