import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/projection/battle_map_snapshot.dart';
import '../../domain/entities/projection/image_view_state.dart';
import '../../domain/entities/projection/projection_item.dart';
import '../../domain/entities/projection/projection_state.dart';
import '../../domain/value_objects/asset_ref.dart';
import 'projection_output.dart';
import 'shared_media_courier.dart';

/// Online projection output — mirrors the projection manifest into the
/// `world_projection` Supabase table. Remote players receive the row via the
/// world CDC channel and render it in `PlayerSecondScreenTab`.
///
/// Unlike the window/screencast outputs there is no local surface and no
/// external-close signal: the manifest lives in the DB. [deactivate] deletes
/// the row so a late-joining player sees "nothing shared".
///
/// Battle-map live data (token moves, drawings) does NOT flow through the
/// manifest — that is the Faz D collab layer (`world_battlemap_marks`).
/// [pushBattleMapPatch] is a deliberate no-op here so manifest writes stay
/// low-frequency (only "which item is active" changes the manifest).
class ProjectionOutputOnline extends ProjectionOutput {
  ProjectionOutputOnline({
    required this.client,
    required this.worldId,
    required this.courier,
  });

  final SupabaseClient client;
  final String worldId;

  /// Yerel medyayı transient havuza çıkarır — bkz. [_withPublishedMedia].
  final SharedMediaCourier courier;

  /// Yerel yol → transient ref (başarısızsa null). Instance ömrü boyunca
  /// bellekte: `_upsert` token sürüklemesinde saniyede ~8 kez çağrılıyor,
  /// aynı arka planı her turda yeniden hash'leyip yüklemek anlamsız.
  final Map<String, Future<String?>> _publishCache = {};

  bool _active = false;

  /// Last full state pushed — `pushPatch` merges onto it (the manifest column
  /// is a single JSON blob, so a patch must re-upload the whole state).
  ProjectionState? _last;

  final _externalCloseController = StreamController<void>.broadcast();

  @override
  bool get isActive => _active;

  @override
  Future<bool> activate() async {
    _active = true;
    return true;
  }

  @override
  Future<void> deactivate() async {
    _active = false;
    _bmCoalesceTimer?.cancel();
    _bmCoalesceTimer = null;
    try {
      await client.from('world_projection').delete().eq('world_id', worldId);
    } catch (e, st) {
      debugPrint('ProjectionOutputOnline.deactivate failed: $e\n$st');
    }
  }

  @override
  Future<bool> pushFull(ProjectionState state) async {
    _last = state;
    return _upsert(state);
  }

  @override
  Future<bool> pushPatch(Map<String, dynamic> patch) async {
    final base = _last;
    if (base == null) return _active;
    final merged = ProjectionState.fromJson(base.toJson()..addAll(patch));
    _last = merged;
    return _upsert(merged);
  }

  Timer? _bmCoalesceTimer;

  /// Tiered window: viewport / token-only patches fire fast (120ms), heavier
  /// patches (strokes / fog / measurements) coalesce at 500ms. Caller may
  /// send many small token-move patches per second; we still write at most
  /// ~8 updates/sec to `world_projection`.
  static const Duration _fastBmDebounce = Duration(milliseconds: 120);
  static const Duration _slowBmDebounce = Duration(milliseconds: 500);

  @override
  Future<bool> pushBattleMapPatch(
      String itemId, Map<String, dynamic> patch) async {
    if (!_active) return false;
    final base = _last;
    if (base == null) return _active;

    BattleMapProjection? target;
    for (final it in base.items) {
      if (it is BattleMapProjection && it.id == itemId) {
        target = it;
        break;
      }
    }
    if (target == null) return _active;

    final mergedSnapJson = <String, dynamic>{
      ...target.snapshot.toJson(),
      ...patch,
    };
    final mergedSnap = BattleMapSnapshot.fromJson(
      jsonDecode(jsonEncode(mergedSnapJson)) as Map<String, dynamic>,
    );
    final newItems = <ProjectionItem>[
      for (final it in base.items)
        if (it is BattleMapProjection && it.id == itemId)
          it.copyWith(snapshot: mergedSnap)
        else
          it,
    ];
    _last = base.copyWith(items: newItems);

    final isHeavy = patch.containsKey('strokes') ||
        patch.containsKey('measurements') ||
        patch.containsKey('shapes') ||
        patch.containsKey('fogDataBase64');
    final debounce = isHeavy ? _slowBmDebounce : _fastBmDebounce;
    _bmCoalesceTimer?.cancel();
    _bmCoalesceTimer = Timer(debounce, () {
      final s = _last;
      if (s != null) _upsert(s);
    });
    return _active;
  }

  /// Strips DM-side navigation state (battle-map viewport, image zoom/pan)
  /// from the payload so the remote viewer is free to pan/zoom locally
  /// without being yanked by the DM's view.
  static ProjectionState _stripNavState(ProjectionState state) {
    return state.copyWith(
      items: state.items.map<ProjectionItem>((item) {
        if (item is ImageProjection) {
          return item.copyWith(viewState: const ImageViewState());
        }
        if (item is BattleMapProjection) {
          return item.copyWith(
            snapshot: item.snapshot.copyWith(clearViewport: true),
          );
        }
        return item;
      }).toList(),
    );
  }

  /// Upserts the manifest row. A failed write does NOT kill the output —
  /// the manifest is last-write-wins and the next push reconciles; only an
  /// explicit [deactivate] ends the session.
  Future<bool> _upsert(ProjectionState state) async {
    if (!_active) return false;
    try {
      final json = await withPublishedMedia(
        _stripNavState(state).toJson(),
        _publishTransient,
      );
      await client.from('world_projection').upsert({
        'world_id': worldId,
        'state_json': jsonEncode(json),
        'updated_by': client.auth.currentUser?.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, st) {
      debugPrint('ProjectionOutputOnline._upsert failed: $e\n$st');
    }
    return _active;
  }

  /// [withPublishedMedia] için yükleme adımı. Sonuç (başarısızlık dahil)
  /// önbelleklenir: `_upsert` token sürüklemesinde saniyede ~8 kez
  /// çağrılıyor, aynı arka planı her turda yeniden hash'leyip yüklemek
  /// anlamsız.
  Future<String?> _publishTransient(String localPath) =>
      _publishCache[localPath] ??= courier.publish(worldId, localPath).then((r) {
        if (r == null) {
          debugPrint('ProjectionOutputOnline: yerel medya yayınlanamadı, '
              'oyuncu çözemeyecek: $localPath');
        }
        return r;
      });

  @override
  Stream<void> get onExternalClose => _externalCloseController.stream;

  @override
  void dispose() {
    _bmCoalesceTimer?.cancel();
    _externalCloseController.close();
  }
}

/// [node] (bir `state_json` ağacı) içindeki her yerel medya yolunu
/// [publish]'in döndürdüğü ref'le değiştirmiş kopyası.
///
/// Oyuncunun dosya sistemi yok: manifest'e sızan ham bir path
/// (`C:\...\media\map.png`) karşı tarafta kırık resim demek. Dönüşüm
/// [ProjectionOutputOnline._upsert]'te, yani buluta giden TEK çıkış
/// noktasında yapılıyor — böylece battle map arka planı, token ve condition
/// görselleri, entity kartı ve düz resim projeksiyonu aynı anda kapanıyor ve
/// çağıranların ayrı ayrı "önce yükle" adımı eklemesi gerekmiyor. Eklemiş
/// olanlar (`projectableMapImage`, `prepareEntityImagesForProjection`) zaten
/// ref döndürdüğü için burada no-op'a düşer.
///
/// [publish] null dönerse yol olduğu gibi kalır — yarım bir manifest
/// göndermektense o tek resmi eksik göndermek yeğ.
///
/// I/O'yu tamamen [publish] taşıyor; ağaç yürüyüşü saf.
Future<Object?> withPublishedMedia(
  Object? node,
  Future<String?> Function(String localPath) publish,
) async {
  if (node is String) {
    if (!isProjectableLocalMedia(node)) return node;
    return await publish(node) ?? node;
  }
  if (node is Map) {
    final out = <String, dynamic>{};
    for (final e in node.entries) {
      out['${e.key}'] = await withPublishedMedia(e.value, publish);
    }
    return out;
  }
  if (node is List) {
    final out = <dynamic>[];
    for (final v in node) {
      out.add(await withPublishedMedia(v, publish));
    }
    return out;
  }
  return node;
}

/// Yüklenmesi gereken bir yerel medya yolu mu? Şema'lı ref'ler (`dmt-*://`),
/// resim uzantısı taşımayan string'ler ve fog/base64 blob'ları elenir —
/// uzunluk eşiği blob'ları regex'e hiç sokmamak için, dosya yolu bu kadar
/// uzun olmuyor.
bool isProjectableLocalMedia(String value) =>
    value.isNotEmpty &&
    value.length <= 1024 &&
    _mediaPathRe.hasMatch(value) &&
    AssetRef(value).isLocal;

final RegExp _mediaPathRe =
    RegExp(r'\.(png|jpe?g|webp|gif|bmp)$', caseSensitive: false);
