import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/field_schema.dart';
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
      shareEntityWithPlayers(_ref, entityId: entityId, worldId: worldId);

  Future<void> unshare({required String entityId, required String worldId}) =>
      unshareEntity(_ref, entityId: entityId, worldId: worldId);
}

/// Shares an entity with all players, making it actually usable on the
/// remote side:
///
///  1. Walks the relation graph from [entityId] (transitive closure) so
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
/// would fork-on-edit. The entry [entityId] is always shared even if linked
/// (explicit user action); cascade targets are restricted to non-linked.
Future<void> shareEntityWithPlayers(
  Ref ref, {
  required String entityId,
  required String worldId,
}) async {
  final svc = ref.read(entityShareServiceProvider);
  if (svc == null) return;

  final entities = ref.read(entityProvider);
  final schema = ref.read(worldSchemaProvider);

  // Relation + image field keys per category slug.
  final relationKeys = <String, List<String>>{};
  final imageKeys = <String, List<String>>{};
  for (final c in schema.categories) {
    relationKeys[c.slug] = [
      for (final f in c.fields)
        if (f.fieldType == FieldType.relation) f.fieldKey,
    ];
    imageKeys[c.slug] = [
      for (final f in c.fields)
        if (f.fieldType == FieldType.image) f.fieldKey,
    ];
  }

  // Transitive closure over relation fields (cycle-guarded).
  final closure = <String>{};
  final queue = <String>[entityId];
  while (queue.isNotEmpty) {
    final id = queue.removeLast();
    if (!closure.add(id)) continue;
    final e = entities[id];
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
  for (final id in closure) {
    final e = entities[id];
    if (e == null) continue;
    if (e.linked && id != entityId) continue;
    try {
      await svc.shareWithAll(
        entityId: id,
        worldId: worldId,
        // Linked (paket/built-in) kartın gövdesi zaten oyuncunun kurulu
        // paketinden geliyor; payload göndermek kopya olurdu.
        payload: e.linked
            ? null
            : await _payloadWithTransientRefs(
                courier,
                e,
                imageKeys[e.categorySlug] ?? const [],
              ),
      );
    } catch (err) {
      debugPrint('shareEntityWithPlayers: share $id failed: $err');
    }
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
) async {
  final remap = <String, String>{};
  for (final path in localMediaPathsOf(e, imageFieldKeys)) {
    final ref = await courier.refFor(path);
    if (ref != null) remap[path] = ref;
  }
  return entityToRaw(remapEntityMedia(e, remap, imageFieldKeys));
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
