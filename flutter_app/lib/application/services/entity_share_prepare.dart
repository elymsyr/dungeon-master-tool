import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/relation_value.dart';
import '../providers/campaign_provider.dart';
import '../providers/entity_provider.dart';
import '../providers/entity_share_provider.dart';
import '../providers/online_worlds_provider.dart';
import '../providers/pinned_entity_provider.dart' show parseEntityIdSet;
import '../providers/role_provider.dart';
import '../providers/shared_entity_provider.dart';
import 'content_ref_index.dart';
import 'world_media_sync.dart';

/// Ref köprüsü — paylaşım hem widget'lardan (`WidgetRef`) hem
/// [EntityNotifier]'dan (`Ref`) tetikleniyor; aradaki tip farkını bu provider
/// kapatır.
final entitySharerProvider = Provider<EntitySharer>(EntitySharer.new);

class EntitySharer {
  EntitySharer(this._ref);
  final Ref _ref;

  Future<void> share({required String entityId, required String worldId}) =>
      shareEntityWithPlayers(_ref, entityIds: {entityId}, worldId: worldId);

  Future<void> unshare({required String entityId, required String worldId}) =>
      unshareEntity(_ref, entityId: entityId, worldId: worldId);

  /// Kartın paylaşım işaretini değiştirir — paylaşımın TEK giriş kapısı.
  ///
  /// İşaret ([sharedEntityIdsProvider]) her zaman yazılır, dünya offline
  /// olsa da: DM böylece dünyayı kurarken neyin oyuncuya gideceğini önden
  /// seçer. Bulut satırı yalnızca dünya gerçekten online ve rol DM ise
  /// yazılır; aksi halde publish tohumu onu sonra taşır.
  ///
  /// Dönen değer buluta gerçekten yazılıp yazılmadığı — çağıran UI mesajını
  /// ona göre kurar.
  Future<bool> setShared({
    required String entityId,
    required bool shared,
    String? worldId,
  }) async {
    await _ref.read(sharedEntityIdsProvider.notifier).setShared(
          entityId,
          shared,
        );
    if (worldId == null) return false;
    if (!_ref.read(onlineWorldIdsProvider).contains(worldId)) return false;
    if (await _ref.read(currentWorldRoleProvider.future) != WorldRole.dm) {
      return false;
    }
    if (shared) {
      await share(entityId: entityId, worldId: worldId);
    } else {
      await unshare(entityId: entityId, worldId: worldId);
    }
    _ref.invalidate(worldEntitySharesProvider(worldId));
    return true;
  }

  Future<void> seedSharedContent({
    required String worldId,
    Map<String, dynamic>? campaignData,
  }) =>
      seedSharedContentToPlayers(
        _ref,
        worldId: worldId,
        campaignData: campaignData,
      );
}

/// Dünya online'a alındığında çalışır: DM'in paylaşıma işaretlediği
/// ([kSharedEntitiesKey]) kartları oyunculara açar.
///
/// **Kategori/tier kuralı yok.** Eski davranış Tier 0 + Tier 1'i
/// kendiliğinden paylaşıyordu; artık oyuncuya giden her satır DM'in bilinçli
/// işaretidir. İşaret dünya offline'ken de konulabildiği için burada
/// yapılacak seçim hazır bekliyor olur.
///
/// Bayrak tutulmuyor — `unpublishWorld` bulut satırlarını cascade siliyor,
/// yani tekrar online olmak zaten sıfırdan tohumlamalı.
///
/// [campaignData] verilirse kartlar, şema **ve işaret seti** o dünyanın
/// diskteki blob'undan okunur. Hub'daki dünya ayarları diyaloğu aktif olmayan
/// bir dünyayı publish edebiliyor; provider'lar ise her zaman AKTİF kampanyayı
/// okur, yani oradan tohumlamak yanlış dünyanın kartlarını paylaşırdı.
Future<void> seedSharedContentToPlayers(
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
  final marked = campaignData == null
      ? ref.read(sharedEntityIdsProvider)
      : parseEntityIdSet(campaignData[kSharedEntitiesKey]);
  final ids = seedShareIds(entities, marked);
  if (ids.isEmpty) return Future.value();
  return shareEntityWithPlayers(
    ref,
    entityIds: ids,
    worldId: worldId,
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
      debugPrint('seedSharedContent: entity ${e.key} parse failed: $err');
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
    debugPrint('seedSharedContent: world_schema parse failed: $err');
    return null;
  }
}

/// [seedSharedContentToPlayers]'ın seçim kuralı, saf hâlde: DM'in işaretleri
/// kesişim dünyada gerçekten duran kartlar. Silinmiş bir kartın işareti
/// blob'da kalabiliyor (silme yolu seti temizlemiyor); onu buraya sokmak
/// gövdesiz satır yazardı.
Set<String> seedShareIds(
  Map<String, Entity> entities,
  Set<String> markedIds,
) =>
    {
      for (final id in markedIds)
        if (entities.containsKey(id)) id,
    };

/// Shares entities with all players, making them actually usable on the
/// remote side:
///
///  1. Walks the relation graph from [entityIds] (transitive closure) so
///     linked entities the card points at get shared too — otherwise the
///     player sees a card with dangling relation rows.
///  2. Rewrites every still-local image (portrait, gallery, and `image`-type
///     custom fields) **in the payload only** to a content-addressed
///     `dmt-content://{sha}{ext}` ref. Nothing is uploaded here and the DM's
///     own entity is left untouched — the bytes are already in the world's
///     cloud media: the push round uploads every image its rows mention
///     (Faz 5d, [WorldMediaSync]).
///  3. Inserts the world-wide `entity_shares` rows.
///
/// Linked (package / built-in) entities are traversed THROUGH (to discover
/// nested custom entities) but never re-uploaded or persisted — editing them
/// would fork-on-edit. The entry [entityIds] are always shared even if linked
/// (explicit user action); cascade targets are restricted to non-linked.
///
/// Kapanış hem tekil paylaşımda hem publish tohumunda aynı: DM bir kartı
/// paylaştığında o kartın bağlı olduğu her şey de gider, yoksa oyuncuda
/// dangling relation satırları kalır.
Future<void> shareEntityWithPlayers(
  Ref ref, {
  required Set<String> entityIds,
  required String worldId,
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
  // Her satır kartın kendi JSON'unu taşır, oyuncunun tek içerik kaynağı bu
  // payload. Yerel görseller payload'da içerik-adresli ref'e çevrilir; baytlar
  // dünyanın bulut medyasında (push turu yüklüyor).
  final index = ref.read(contentRefIndexProvider);
  final payloads = <String, Map<String, dynamic>?>{};
  for (final id in closure) {
    final e = cards[id];
    if (e == null) continue;
    if (e.linked && !entityIds.contains(id)) continue;
    // Linked (paket/built-in) kartın gövdesi zaten oyuncunun kurulu
    // paketinden geliyor; payload göndermek kopya olurdu.
    payloads[id] = e.linked
        ? null
        : await _payloadWithContentRefs(
            index,
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

/// [e]'nin paylaşım gövdesi — yerel medya yolları `dmt-content://{sha}{ext}`
/// ile değiştirilmiş hâlde. Yükleme YOK, kalıcı yazma YOK: DM'in kendi satırı
/// yerel yollarını korur. Okunamayan bir dosya olduğu gibi bırakılır (oyuncuda
/// çözülemez — zaten kopyası olmayan bir dosyaydı).
Future<Map<String, dynamic>> _payloadWithContentRefs(
  ContentRefIndex index,
  Entity e,
  List<String> imageFieldKeys,
  List<String> dmOnlyFieldKeys,
) async {
  final remap = <String, String>{};
  for (final path in localMediaPathsOf(e, imageFieldKeys)) {
    final ref = await index.refFor(path);
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

/// Bir kartın hâlâ yerel olan görsellerini dünyanın bulut medyasına çıkarır
/// ve `{yerelYol: dmt-content://...}` eşlemesini döndürür. Kart bir satırda
/// duruyorsa push turu bunları zaten yüklemiştir; burada yeniden gitmez.
///
/// Eşleme **yalnızca projeksiyon anlık görüntüsüne** uygulanır; DM'in kendi
/// satırı yerel yollarını korur.
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

  final media = ref.read(worldMediaSyncProvider);
  if (media == null) return const {};
  final remap = <String, String>{};
  for (final path in localMediaPathsOf(e, imageFieldKeys)) {
    try {
      final uploaded = await media.publish(worldId, path);
      if (uploaded != null) remap[path] = uploaded;
    } catch (err) {
      debugPrint('prepareEntityImagesForProjection: $path: $err');
    }
  }
  return remap;
}

/// Entity'nin portre + galeri + `image` alanlarındaki **yerel** yolları
/// (tekilleştirilmiş, sırası korunmuş).
List<String> localMediaPathsOf(Entity e, List<String> imageFieldKeys) {
  final paths = <String>{};
  void scan(String s) {
    if (s.isNotEmpty && AssetRef(s).isLocal) paths.add(s);
  }

  scan(e.imagePath);
  e.images.forEach(scan);
  for (final k in imageFieldKeys) {
    final v = e.fields[k];
    if (v is List) {
      for (final x in v) {
        if (x is String) scan(x);
      }
    } else if (v is String) {
      scan(v);
    }
  }
  return paths.toList();
}

/// [e]'nin kopyasını, [remap]'teki yerel yollar ref'lerle değiştirilmiş olarak
/// döner. **Kaydedilmez** — yalnızca paylaşım payload'ı için.
Entity remapEntityMedia(
  Entity e,
  Map<String, String> remap,
  List<String> imageFieldKeys,
) {
  if (remap.isEmpty) return e;
  String repl(String s) => remap[s] ?? s;
  final fields = Map<String, dynamic>.from(e.fields);
  for (final k in imageFieldKeys) {
    final v = e.fields[k];
    if (v is List) {
      fields[k] = v.map((x) => x is String ? repl(x) : x).toList();
    } else if (v is String && v.isNotEmpty) {
      fields[k] = repl(v);
    }
  }
  return e.copyWith(
    imagePath: repl(e.imagePath),
    images: e.images.map(repl).toList(),
    fields: fields,
  );
}
