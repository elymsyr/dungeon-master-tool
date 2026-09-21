
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/app_database.dart';
import '../../data/network/world_membership_service.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/repositories/campaign_repository.dart';
import 'srd_core_bootstrap.dart';
import 'srd_core_package_bootstrap.dart';
import 'world_meta_sync.dart';

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
    // Ayrı select: `meta_json` migration 093 ile geldi. Aynı select'te
    // olsaydı kolon yoksa/erişilemezse template_id de kaybolur, dünya
    // şemasız + SRD linki olmadan kalırdı.
    Map<String, dynamic>? meta;
    try {
      final row = await supabase
          .from('worlds')
          .select('meta_json')
          .eq('id', res.worldId)
          .maybeSingle();
      meta = decodeWorldMeta(row?['meta_json']);
    } catch (e, st) {
      debugPrint('joinWithCode meta fetch error: $e\n$st');
    }

    final now = DateTime.now().toUtc();
    // Dünya kimliği id — isim yalnız etiket. Eskiden burada isim çakışması
    // "Ad (2)" ile çözülüyordu, çünkü `repository.save` isimle anahtarlıyordu;
    // sonucu, aynı dünyanın telefonda ve laptop'ta farklı ada sahip olmasıydı.
    final existingById = await db.worldsDao.getById(res.worldId);
    final localName = existingById?.worldName ?? res.worldName;
    if (existingById == null) {
      await db.worldsDao.upsert(
        WorldsCompanion.insert(
          id: res.worldId,
          worldName: localName,
          // Şablon id'si yerel satıra da yazılır: `load()` SRD self-heal'i ve
          // built-in kategori overlay'i buna bakıyor.
          templateId: Value(templateId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    if (meta != null) {
      try {
        await repository.saveSettingsPatch(res.worldId, {'metadata': meta});
      } catch (e, st) {
        debugPrint('joinWithCode meta apply error: $e\n$st');
      }
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
