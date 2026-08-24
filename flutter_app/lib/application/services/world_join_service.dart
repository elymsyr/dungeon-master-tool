
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/app_database.dart';
import '../../data/network/world_membership_service.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/repositories/campaign_repository.dart';
import 'srd_core_bootstrap.dart';
import 'srd_core_package_bootstrap.dart';

/// "Join with code" akışını koordine eder:
///   1. RPC redeem_world_invite → (worldId, worldName)
///   2. Lokal Drift'te boş bir Campaign kabuğu upsert et
///   3. caller hub list invalidation yapar
///
/// Dünyanın içeriği ARTIK katılırken çekilmez. Oyuncu boş bir kabukla başlar;
/// içerik DM paylaştıkça `entity_shares` ve projeksiyon manifesti üzerinden
/// canlı gelir (bkz. [WorldMirrorApplier]). Eskiden burada `worlds.state_json`
/// blob'u indiriliyordu — yani DM'in tüm dünyası, paylaşmadıkları dahil.
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

    // Şablon id'si gerekli — SRD bootstrap'ı ona bakıyor. İçerik çekilmez.
    String? templateId;
    try {
      final row = await supabase
          .from('worlds')
          .select('template_id')
          .eq('id', res.worldId)
          .maybeSingle();
      templateId = row?['template_id'] as String?;
    } catch (e, st) {
      debugPrint('joinWithCode template fetch error: $e\n$st');
    }

    final now = DateTime.now().toUtc();
    // Resolve local name — repository.save keys by worldName, so if the
    // player already has a different campaign with the same name we must
    // pick a unique local label to avoid overwriting their local data.
    final existingById =
        await (db.select(db.worlds)..where((t) => t.id.equals(res.worldId)))
            .getSingleOrNull();
    String localName = existingById?.worldName ?? res.worldName;
    if (existingById == null) {
      final clash =
          await (db.select(db.worlds)..where((t) => t.worldName.equals(localName)))
              .getSingleOrNull();
      if (clash != null) {
        // Suffix until unique.
        var attempt = 2;
        while (true) {
          final candidate = '$localName ($attempt)';
          final c = await (db.select(db.worlds)
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
      await db.worldsDao.upsert(
        WorldsCompanion.insert(
          id: res.worldId,
          worldName: localName,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    // Link built-in SRD pack into the joined world so synth resolves
    // pristine Tier-0/Tier-1 entries. Idempotent — flag in world_settings.
    final effectiveTemplateId = templateId;
    if (effectiveTemplateId == builtinDnd5eV2SchemaId) {
      try {
        await SrdCorePackageBootstrap(db).ensureInstalled();
        await SrdCoreBootstrap(db).ensureImported(
          worldId: res.worldId,
          build: generateBuiltinDnd5eV2Schema(),
        );
      } catch (e, st) {
        debugPrint('joinWithCode SRD link error: $e\n$st');
      }
    }
    return (worldId: res.worldId, worldName: localName);
  }
}
