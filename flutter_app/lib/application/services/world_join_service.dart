
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
///   2. [materializeWorld]: lokal Drift'te boş bir Campaign kabuğu upsert et
///   3. caller hub list invalidation yapar
///
/// İkinci cihaz 1'i atlar: üyelik zaten var, [listMemberWorlds] dünyayı
/// listeler ve doğrudan 2 çalışır.
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
    return materializeWorld(res.worldId, res.worldName);
  }

  /// Faz 5.5a — oyuncu olarak üyesi olduğum, bu cihazda olmayan dünyalar.
  /// Hub'ın "bulutta, bu cihazda yok" bölümünde listelenir; DM'in kendi
  /// dünyaları oraya `listCloudOnlyWorlds` ile geliyor.
  Future<List<({String id, String name})>> listMemberWorlds() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('world_members')
        .select('world_id, worlds(world_name)')
        .eq('user_id', uid)
        .eq('role', 'player');
    final local = {for (final w in await db.worldsDao.getAll()) w.id};
    return [
      for (final r in rows)
        if (!local.contains(r['world_id']))
          (
            id: r['world_id'] as String,
            name: (r['worlds'] as Map?)?['world_name'] as String? ?? '',
          ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Üyesi olunan dünyanın yerel kabuğunu kurar — her yeni cihazda bir kez.
  /// Davet kodu harcamaz (§2.9: `redeemInvite` yalnız ilk katılışta). İçerik
  /// burada inmez: dünya açılınca `applyInitialState` paylaşılan kartları,
  /// karakterleri (oyuncunun kendisininki dahil) ve projeksiyonu getirir.
  Future<({String worldId, String worldName})> materializeWorld(
    String worldId,
    String worldName,
  ) async {
    // Şablon id'si gerekli — SRD bootstrap'ı ona bakıyor. İçerik çekilmez.
    String? templateId;
    try {
      final row = await supabase
          .from('worlds')
          .select('template_id')
          .eq('id', worldId)
          .maybeSingle();
      templateId = row?['template_id'] as String?;
    } catch (e, st) {
      debugPrint('materializeWorld template fetch error: $e\n$st');
    }
    // Ayrı select: `meta_json` migration 093 ile geldi. Aynı select'te
    // olsaydı kolon yoksa/erişilemezse template_id de kaybolur, dünya
    // şemasız + SRD linki olmadan kalırdı.
    Map<String, dynamic>? meta;
    try {
      final row = await supabase
          .from('worlds')
          .select('meta_json')
          .eq('id', worldId)
          .maybeSingle();
      meta = decodeWorldMeta(row?['meta_json']);
    } catch (e, st) {
      debugPrint('materializeWorld meta fetch error: $e\n$st');
    }

    final now = DateTime.now().toUtc();
    // Dünya kimliği id — isim yalnız etiket. Eskiden burada isim çakışması
    // "Ad (2)" ile çözülüyordu, çünkü `repository.save` isimle anahtarlıyordu;
    // sonucu, aynı dünyanın telefonda ve laptop'ta farklı ada sahip olmasıydı.
    final existingById = await db.worldsDao.getById(worldId);
    final localName = existingById?.worldName ?? worldName;
    if (existingById == null) {
      await db.worldsDao.upsert(
        WorldsCompanion.insert(
          id: worldId,
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
        await repository.saveSettingsPatch(worldId, {'metadata': meta});
      } catch (e, st) {
        debugPrint('materializeWorld meta apply error: $e\n$st');
      }
    }

    // Link built-in SRD pack into the joined world so synth resolves
    // pristine Tier-0/Tier-1 entries. Idempotent — flag in world_settings.
    final effectiveTemplateId = templateId;
    if (effectiveTemplateId == builtinDnd5eV2SchemaId) {
      try {
        await SrdCorePackageBootstrap(db).ensureInstalled();
        await SrdCoreBootstrap(db).ensureImported(
          worldId: worldId,
          build: generateBuiltinDnd5eV2Schema(),
        );
      } catch (e, st) {
        debugPrint('materializeWorld SRD link error: $e\n$st');
      }
    }
    return (worldId: worldId, worldName: localName);
  }
}
