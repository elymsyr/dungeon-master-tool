import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/relation_value.dart';
import '../providers/entity_provider.dart';
import '../providers/entity_share_provider.dart';
import 'entity_image_upload.dart';
import 'shared_media_courier.dart';

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
  WidgetRef ref, {
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
  WidgetRef ref, {
  required String entityId,
  required String worldId,
}) async {
  final svc = ref.read(entityShareServiceProvider);
  if (svc == null) return;
  await svc.unshareAll(entityId: entityId, worldId: worldId);
}

/// Uploads an entity's still-local images so a PROJECTION of it carries
/// player-resolvable refs. Counted (`dmt-asset://`) refs are persisted onto
/// the entity (permanent, sync-safe). Quota-full uploads fall back to a
/// transient (`dmt-transient://`) share — these are NOT persisted (R2 ~1-day
/// TTL would orphan the entity row) and returned as `{localPath:
/// transientRef}` for the caller to apply to the projection snapshot only.
///
/// Linked (package / built-in) entities are skipped — their images are
/// already cloud-hosted and editing them would fork-on-edit.
Future<Map<String, String>> prepareEntityImagesForProjection(
  WidgetRef ref, {
  required String entityId,
}) async {
  final entities = ref.read(entityProvider);
  final e = entities[entityId];
  if (e == null || e.linked) return const {};

  final schema = ref.read(worldSchemaProvider);
  final imageFieldKeys = <String>[
    for (final c in schema.categories)
      if (c.slug == e.categorySlug)
        for (final f in c.fields)
          if (f.fieldType == FieldType.image) f.fieldKey,
  ];

  // Gather distinct local paths across portrait / gallery / image fields.
  final localPaths = <String>{};
  void scan(String s) {
    if (s.isNotEmpty && AssetRef(s).isLocal) localPaths.add(s);
  }

  scan(e.imagePath);
  e.images.forEach(scan);
  for (final k in imageFieldKeys) {
    for (final v in _asStringList(e.fields[k])) {
      scan(v);
    }
  }
  if (localPaths.isEmpty) return const {};

  final ordered = localPaths.toList();
  final result =
      await eagerUploadEntityImages(ref, ordered, transientFallback: true);

  // Counted/public refs → persist; transient refs → projection-only remap.
  final countedRemap = <String, String>{};
  final transientRemap = <String, String>{};
  for (var i = 0; i < ordered.length; i++) {
    final from = ordered[i];
    final to = result.refs[i];
    if (from == to) continue;
    if (AssetRef(to).isTransient) {
      transientRemap[from] = to;
    } else {
      countedRemap[from] = to;
    }
  }

  if (countedRemap.isNotEmpty) {
    String repl(String s) => countedRemap[s] ?? s;
    final newFields = Map<String, dynamic>.from(e.fields);
    for (final k in imageFieldKeys) {
      final v = e.fields[k];
      if (v is List) {
        newFields[k] = v.map((x) => x is String ? repl(x) : x).toList();
      } else if (v is String && v.isNotEmpty) {
        newFields[k] = repl(v);
      }
    }
    ref.read(entityProvider.notifier).update(
          e.copyWith(
            imagePath: repl(e.imagePath),
            images: e.images.map(repl).toList(),
            fields: newFields,
          ),
        );
  }

  return transientRemap;
}

List<String> _asStringList(dynamic v) {
  if (v is List) return v.whereType<String>().toList();
  if (v is String && v.isNotEmpty) return [v];
  return const [];
}
