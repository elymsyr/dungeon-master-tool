import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  Future<bool> pushBattleMapPatch(
      String itemId, Map<String, dynamic> patch) async {
    // Battle-map live data flows through the Faz D collab table, not the
    // manifest — no-op keeps `world_projection` writes low-frequency.
    return _active;
  }

  /// Upserts the manifest row. A failed write does NOT kill the output —
  /// the manifest is last-write-wins and the next push reconciles; only an
  /// explicit [deactivate] ends the session.
  Future<bool> _upsert(ProjectionState state) async {
    if (!_active) return false;
    try {
      final json = state.toJson();
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
    _externalCloseController.close();
  }
}
