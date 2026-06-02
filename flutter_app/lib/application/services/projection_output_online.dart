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
  ProjectionOutputOnline({required this.client, required this.worldId});

  final SupabaseClient client;
  final String worldId;

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
      final json = _stripNavState(state).toJson();
      // F7 debug guard: state_json'da AssetRef olmayan ham path varsa
      // player çözemez. Caller (entity_share_prepare /
      // prepareEntityImagesForProjection) bunu önceden upload etmiş
      // olmalı. Sessiz fail yerine debug log → erken yakala.
      assert(() {
        _warnRawPaths(json);
        return true;
      }());
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

  /// Debug-only: state_json içinde ham filesystem path (AssetRef DEĞİL)
  /// var mı? Varsa player tarafı çözemez (RLS yok, file sistem yok).
  static void _warnRawPaths(Object? node) {
    if (node is String) {
      if (node.isEmpty) return;
      if (node.startsWith(AssetRef.scheme) ||
          node.startsWith(AssetRef.publicScheme) ||
          node.startsWith(AssetRef.transientScheme)) {
        return;
      }
      // Heuristic: path-like (slash + dot extension); base64 fog veya kısa
      // string'leri eleme.
      if (node.length > 8 &&
          node.contains('/') &&
          RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false)
              .hasMatch(node)) {
        debugPrint('ProjectionOutputOnline: raw path in state_json → '
            'player will not resolve: ${node.substring(0, node.length.clamp(0, 80))}');
      }
      return;
    }
    if (node is Map) {
      for (final v in node.values) {
        _warnRawPaths(v);
      }
      return;
    }
    if (node is List) {
      for (final v in node) {
        _warnRawPaths(v);
      }
    }
  }

  @override
  Stream<void> get onExternalClose => _externalCloseController.stream;

  @override
  void dispose() {
    _bmCoalesceTimer?.cancel();
    _externalCloseController.close();
  }
}
