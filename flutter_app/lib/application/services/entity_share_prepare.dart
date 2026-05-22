import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/relation_value.dart';
import '../providers/entity_provider.dart';
import '../providers/entity_share_provider.dart';
import '../providers/sync_engine_provider.dart';
import 'entity_image_upload.dart';
import 'pending_write_buffer.dart';

/// Shares an entity with all players, making it actually usable on the
/// remote side:
///
///  1. Walks the relation graph from [entityId] (transitive closure) so
///     linked entities the card points at get shared too — otherwise the
///     player sees a card with dangling relation rows.
///  2. Eager-uploads every still-local image (portrait, gallery, and
///     `image`-type custom fields) of each non-linked entity in the closure
///     to cloud storage, rewrites the entity to cloud refs, and drains the
///     outbox — so the player can actually resolve the images.
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

  // Eager-upload images for every non-linked entity in the closure.
  var anyPushed = false;
  for (final id in closure) {
    final e = entities[id];
    if (e == null || e.linked) continue;
    final pushed = await _uploadEntityImages(
      ref,
      e,
      imageKeys[e.categorySlug] ?? const [],
    );
    anyPushed = anyPushed || pushed;
  }
  if (anyPushed) {
    await ref
        .read(pendingWriteBufferProvider)
        .flushPrefix('entity:$worldId:');
    await ref.read(syncEngineProvider).forceTick();
  }

  // Insert the share rows. Cascade is limited to non-linked entities; the
  // entry entity is shared regardless.
  for (final id in closure) {
    final e = entities[id];
    if (e == null) continue;
    if (e.linked && id != entityId) continue;
    try {
      await svc.shareWithAll(entityId: id, worldId: worldId);
    } catch (err) {
      debugPrint('shareEntityWithPlayers: share $id failed: $err');
    }
  }
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

/// Uploads every still-local image of [e] to cloud storage and persists the
/// rewritten entity. Returns true when at least one ref actually changed.
Future<bool> _uploadEntityImages(
  WidgetRef ref,
  Entity e,
  List<String> imageFieldKeys,
) async {
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
  if (localPaths.isEmpty) return false;

  final ordered = localPaths.toList();
  final result = await eagerUploadEntityImages(ref, ordered);
  final remap = <String, String>{};
  for (var i = 0; i < ordered.length; i++) {
    remap[ordered[i]] = result.refs[i];
  }
  // Offline / quota-full → refs come back unchanged; nothing to persist.
  if (!remap.entries.any((en) => en.key != en.value)) return false;

  String repl(String s) => remap[s] ?? s;
  final newImages = e.images.map(repl).toList();
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
          images: newImages,
          fields: newFields,
        ),
      );
  return true;
}

List<String> _asStringList(dynamic v) {
  if (v is List) return v.whereType<String>().toList();
  if (v is String && v.isNotEmpty) return [v];
  return const [];
}
