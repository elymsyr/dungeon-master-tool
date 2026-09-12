import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/builtin/content.dart'
    show seedExcludedSlugs, tier1Slugs;
import '../../domain/entities/schema/builtin/lookups.dart' show tier0Slugs;
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/value_objects/relation_value.dart';
import '../providers/campaign_provider.dart';
import '../providers/entity_provider.dart';
import '../providers/entity_share_provider.dart';
import '../providers/online_worlds_provider.dart';
import 'shared_media_courier.dart';

/// Ref köprüsü — paylaşım hem widget'lardan (`WidgetRef`) hem
/// [EntityNotifier]'dan (`Ref`) tetikleniyor; aradaki tip farkını bu provider
/// kapatır. `SharedMediaCourier` ile aynı desen.
final entitySharerProvider = Provider<EntitySharer>(EntitySharer.new);

class EntitySharer {
  EntitySharer(this._ref);
  final Ref _ref;

  Future<void> share({required String entityId, required String worldId}) =>
      shareEntityWithPlayers(_ref, entityIds: {entityId}, worldId: worldId);

  Future<void> unshare({required String entityId, required String worldId}) =>
      unshareEntity(_ref, entityId: entityId, worldId: worldId);

  Future<void> seedTierContent({
    required String worldId,
    Map<String, dynamic>? campaignData,
  }) =>
      seedTierContentToPlayers(
        _ref,
        worldId: worldId,
        campaignData: campaignData,
      );
}

/// Dünya online'a alındığında tek seferlik çalışır: DM'in **kendi yazdığı**
/// (linked olmayan) Tier 0 + Tier 1 kural kartlarını oyunculara paylaşır.
///
/// Gerekçe karakter yaratılabilirlik — oyuncu katıldığında yalnızca SRD
/// bootstrap'ini alıyor, DM'in homebrew sınıf/tür/geçmişi olmadan karakterini
/// yanlış yaratıyor. [seedExcludedSlugs] (canavar, hayvan, creature-action,
/// büyülü eşya) kapsam dışı; onlar DM'in tekil "Paylaş" akışında kalır.
///
/// `linked == true` kartlar da kapsam dışı: oyuncunun kurulu paketinde zaten
/// varlar ve satır yazmak 4000 satır/dünya tavanını gereksiz yere yer.
///
/// Bayrak tutulmuyor — `unpublishWorld` bulut satırlarını cascade siliyor,
/// yani tekrar online olmak zaten sıfırdan tohumlamalı.
///
/// [campaignData] verilirse kartlar ve şema **o dünyanın** diskteki
/// blob'undan okunur. Hub'daki dünya ayarları diyaloğu aktif olmayan bir
/// dünyayı publish edebiliyor; `entityProvider` / `worldSchemaProvider` ise
/// her zaman AKTİF kampanyayı okur, yani oradan tohumlamak yanlış dünyanın
/// kartlarını paylaşırdı (ya da hiçbir şey paylaşmazdı).
Future<void> seedTierContentToPlayers(
  Ref ref, {
  required String worldId,
  Map<String, dynamic>? campaignData,
}) {
  final entities = campaignData == null
      ? ref.read(entityProvider)
      : entitiesFromCampaignData(campaignData);
  final schema = campaignData == null
      ? null
      : _schemaFromCampaignData(campaignData);
  final ids = seedShareIds(entities);
  if (ids.isEmpty) return Future.value();
  return shareEntityWithPlayers(
    ref,
    entityIds: ids,
    worldId: worldId,
    allowedSlugs: seedAllowedSlugs,
    entities: entities,
    schema: schema,
  );
}

/// Kampanya blob'undaki `entities` haritasını parse eder. Bozuk satır atlanır
/// — tek bir kart yüzünden tüm tohum düşmesin.
Map<String, Entity> entitiesFromCampaignData(Map<String, dynamic> data) {
  final raw = data['entities'] as Map<String, dynamic>? ?? const {};
  final out = <String, Entity>{};
  for (final e in raw.entries) {
    try {
      out[e.key] = entityFromRaw(e.key, Map<String, dynamic>.from(e.value));
    } catch (err) {
      debugPrint('seedTierContent: entity ${e.key} parse failed: $err');
    }
  }
  return out;
}

WorldSchema? _schemaFromCampaignData(Map<String, dynamic> data) {
  final raw = data['world_schema'];
  if (raw is! Map) return null;
  try {
    return WorldSchema.fromJson(Map<String, dynamic>.from(raw));
  } catch (err) {
    debugPrint('seedTierContent: world_schema parse failed: $err');
    return null;
  }
}

/// Tohumun kapsadığı kategoriler: tüm Tier 0 + Tier 1 eksi
/// [seedExcludedSlugs]. Tier 0 tamamen dahil, çünkü Tier 1'in relation
/// alanları oraya bakıyor — eksik kalırlarsa kartlar oyuncuda yarım görünür.
final seedAllowedSlugs = <String>{
  ...tier0Slugs,
  ...tier1Slugs.where((s) => !seedExcludedSlugs.contains(s)),
};

/// [seedTierContentToPlayers]'ın seçim kuralı, saf hâlde.
Set<String> seedShareIds(Map<String, Entity> entities) => {
      for (final e in entities.values)
        if (!e.linked && seedAllowedSlugs.contains(e.categorySlug)) e.id,
    };

/// Shares entities with all players, making them actually usable on the
/// remote side:
///
///  1. Walks the relation graph from [entityIds] (transitive closure) so
///     linked entities the card points at get shared too — otherwise the
///     player sees a card with dangling relation rows.
///  2. Rewrites every still-local image (portrait, gallery, and `image`-type
///     custom fields) **in the payload only** to a content-addressed
///     `dmt-transient://{sha}{ext}` ref. Nothing is uploaded here and the
///     DM's own entity is left untouched — the bytes travel later, and only
///     for the SHAs a player actually reports missing
///     ([SharedMediaCourier] / [MissingMediaReporter]).
///  3. Inserts the world-wide `entity_shares` rows.
///
/// Linked (package / built-in) entities are traversed THROUGH (to discover
/// nested custom entities) but never re-uploaded or persisted — editing them
/// would fork-on-edit. The entry [entityIds] are always shared even if linked
/// (explicit user action); cascade targets are restricted to non-linked.
///
/// [allowedSlugs] non-null ise closure sonucu o kategorilere kısılır. Tohum
/// yolu ([seedTierContentToPlayers]) bunu kullanır: aksi halde dışarıda
/// bıraktığımız kategoriler relation alanları üzerinden arka kapıdan girerdi
/// (homebrew bir `species` bir `monster`'a referans veriyorsa). Tekil paylaşım
/// yolunda null — DM bir kartı paylaştığında bağlı her şey gitmeye devam eder.
Future<void> shareEntityWithPlayers(
  Ref ref, {
  required Set<String> entityIds,
  required String worldId,
  Set<String>? allowedSlugs,
  Map<String, Entity>? entities,
  WorldSchema? schema,
}) async {
  final svc = ref.read(entityShareServiceProvider);
  if (svc == null) return;

  // Verilmediyse aktif kampanyadan oku (tekil paylaşım yolu).
  final Map<String, Entity> cards = entities ?? ref.read(entityProvider);
  final WorldSchema worldSchema = schema ?? ref.read(worldSchemaProvider);

  // Relation + image field keys per category slug.
  final relationKeys = <String, List<String>>{};
  final imageKeys = <String, List<String>>{};
  final dmOnlyKeys = <String, List<String>>{};
  for (final c in worldSchema.categories) {
    relationKeys[c.slug] = [
      for (final f in c.fields)
        if (f.fieldType == FieldType.relation) f.fieldKey,
    ];
    imageKeys[c.slug] = [
      for (final f in c.fields)
        if (f.fieldType == FieldType.image) f.fieldKey,
    ];
    dmOnlyKeys[c.slug] = [
      for (final f in c.fields)
        if (f.visibility == FieldVisibility.dmOnly ||
            f.visibility == FieldVisibility.private_)
          f.fieldKey,
    ];
  }

  // Transitive closure over relation fields (cycle-guarded).
  final closure = <String>{};
  final queue = entityIds.toList();
  while (queue.isNotEmpty) {
    final id = queue.removeLast();
    if (!closure.add(id)) continue;
    final e = cards[id];
    if (e == null) continue;
    for (final key in relationKeys[e.categorySlug] ?? const <String>[]) {
      for (final rid in extractRelationIds(e.fields[key])) {
        if (!closure.contains(rid)) queue.add(rid);
      }
    }
  }

  // Insert the share rows. Cascade is limited to non-linked entities; the
  // entry entity is shared regardless.
  //
  // Her satır kartın kendi JSON'unu taşır: `world_entities` aynası artık yok,
  // oyuncunun tek içerik kaynağı bu payload. Yerel görseller payload'da
  // içerik-adresli transient ref'e çevrilir; baytlar DM'in diskinde kalır ve
  // ancak bir oyuncu eksik bildirince yüklenir.
  final courier = ref.read(sharedMediaCourierProvider);
  final payloads = <String, Map<String, dynamic>?>{};
  for (final id in closure) {
    final e = cards[id];
    if (e == null) continue;
    if (e.linked && !entityIds.contains(id)) continue;
    if (allowedSlugs != null && !allowedSlugs.contains(e.categorySlug)) {
      continue;
    }
    // Linked (paket/built-in) kartın gövdesi zaten oyuncunun kurulu
    // paketinden geliyor; payload göndermek kopya olurdu.
    payloads[id] = e.linked
        ? null
        : await _payloadWithTransientRefs(
            courier,
            e,
            imageKeys[e.categorySlug] ?? const [],
            dmOnlyKeys[e.categorySlug] ?? const [],
          );
  }

  // Tek sorguda sil + 50'lik parçalar hâlinde yaz. Kart başına iki round
  // trip atan eski döngü, tohum yolunda (yüzlerce kart) publish'i
  // dakikalarca bekletiyordu.
  try {
    final failed =
        await svc.shareManyWithAll(worldId: worldId, payloads: payloads);
    if (failed.isNotEmpty) {
      debugPrint('shareEntityWithPlayers: ${failed.length} kart yazılamadı: '
          '${failed.take(5).join(", ")}');
    }
  } catch (err) {
    debugPrint('shareEntityWithPlayers: bulk share failed: $err');
  }
}

/// [e]'nin paylaşım gövdesi — yerel medya yolları `dmt-transient://{sha}{ext}`
/// ile değiştirilmiş hâlde. Yükleme YOK, kalıcı yazma YOK: DM'in kendi satırı
/// yerel yollarını korur, baytlar [SharedMediaCourier.serve] ile talep üzerine
/// çıkar. Okunamayan bir dosya olduğu gibi bırakılır (oyuncuda çözülemez —
/// zaten kopyası olmayan bir dosyaydı).
Future<Map<String, dynamic>> _payloadWithTransientRefs(
  SharedMediaCourier courier,
  Entity e,
  List<String> imageFieldKeys,
  List<String> dmOnlyFieldKeys,
) async {
  final remap = <String, String>{};
  for (final path in localMediaPathsOf(e, imageFieldKeys)) {
    final ref = await courier.refFor(path);
    if (ref != null) remap[path] = ref;
  }
  return redactDmOnly(
    entityToRaw(remapEntityMedia(e, remap, imageFieldKeys)),
    dmOnlyFieldKeys,
  );
}

/// Paylaşım gövdesinden DM'e özel her şeyi siler: şemada
/// [FieldVisibility.dmOnly] / `private_` işaretli alanlar (`secrets`,
/// `tactics`, …) ve kartın birinci sınıf `dm_notes` kolonu.
///
/// `entity_shares.payload_json` oyuncunun **tek** içerik kaynağı, yani
/// buradan çıkan her şey oyuncunun eline geçer. Gövde DM'in diskinde tam
/// kalır; yalnızca giden kopya kırpılır.
Map<String, dynamic> redactDmOnly(
  Map<String, dynamic> raw,
  List<String> dmOnlyFieldKeys,
) {
  final out = Map<String, dynamic>.from(raw)..['dm_notes'] = '';
  final attrs = out['attributes'];
  if (attrs is Map<String, dynamic> && dmOnlyFieldKeys.isNotEmpty) {
    out['attributes'] = Map<String, dynamic>.from(attrs)
      ..removeWhere((k, _) => dmOnlyFieldKeys.contains(k));
  }
  return out;
}

/// Stops sharing a single entity with players. No cascade unshare —
/// previously cascade-shared linked entities stay visible (harmless; another
/// shared card may still point at them).
Future<void> unshareEntity(
  Ref ref, {
  required String entityId,
  required String worldId,
}) async {
  final svc = ref.read(entityShareServiceProvider);
  if (svc == null) return;
  await svc.unshareAll(entityId: entityId, worldId: worldId);
}

/// Bir kartın hâlâ yerel olan görsellerini projeksiyon için transient havuza
/// yükler ve `{yerelYol: dmt-transient://...}` eşlemesini döndürür.
///
/// Eşleme **yalnızca projeksiyon anlık görüntüsüne** uygulanır; DM'in kendi
/// satırına yazılmaz — transient obje LRU ile atılabilir, kalıcı satırda ölü
/// ref bırakmak DM'in kendi resmini kaybetmesi demek olurdu (Phase C ile aynı
/// gerekçe; sayılan katman Phase D'de kaldırıldı).
///
/// Dünya online değilse, oturum yoksa ya da kart linked (paket/built-in) ise
/// boş döner — o durumda projeksiyon yerel yolla çalışır.
Future<Map<String, String>> prepareEntityImagesForProjection(
  WidgetRef ref, {
  required String entityId,
}) async {
  final entities = ref.read(entityProvider);
  final e = entities[entityId];
  if (e == null || e.linked) return const {};

  final worldId =
      ref.read(activeCampaignProvider.notifier).data?['world_id'] as String?;
  if (worldId == null || !ref.read(onlineWorldIdsProvider).contains(worldId)) {
    return const {};
  }

  final schema = ref.read(worldSchemaProvider);
  final imageFieldKeys = <String>[
    for (final c in schema.categories)
      if (c.slug == e.categorySlug)
        for (final f in c.fields)
          if (f.fieldType == FieldType.image) f.fieldKey,
  ];

  final courier = ref.read(sharedMediaCourierProvider);
  final remap = <String, String>{};
  for (final path in localMediaPathsOf(e, imageFieldKeys)) {
    final uploaded = await courier.publish(worldId, path);
    if (uploaded != null) remap[path] = uploaded;
  }
  return remap;
}
