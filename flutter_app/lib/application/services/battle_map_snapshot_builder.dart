import 'dart:io';
import 'dart:ui' as ui show instantiateImageCodec;

import '../../domain/entities/entity.dart';
import '../../domain/entities/projection/battle_map_snapshot.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/session.dart';

/// Builds a [BattleMapSnapshot] from a live [Encounter] + the entity map.
/// Pure function (no Riverpod, no state) so it can be unit-tested and reused
/// from anywhere.
///
/// The snapshot is built once per push — the canvas dimensions are derived
/// from the background image when available, otherwise default 2048x2048.
class BattleMapSnapshotBuilder {
  /// Builds a snapshot synchronously. Canvas dimensions default to 2048x2048
  /// if the background hasn't been measured yet — call [measureCanvas] first
  /// for accurate dimensions.
  ///
  /// [schema] is used to mirror the DM-side category color on the player
  /// view (the DM token border is the entity's category color from the
  /// world schema). Pass `null` only from contexts where no schema is
  /// available — colors will fall back to a neutral gray.
  static BattleMapSnapshot build({
    required Encounter encounter,
    required Map<String, Entity> entities,
    WorldSchema? schema,
    int canvasWidth = 2048,
    int canvasHeight = 2048,
  }) {
    // Index categories by slug for O(1) color lookup.
    final categoryColors = <String, String>{};
    if (schema != null) {
      for (final cat in schema.categories) {
        categoryColors[cat.slug] = cat.color;
      }
    }

    final tokens = <TokenSnapshot>[];
    var col = 0;
    var row = 0;
    for (final c in encounter.combatants) {
      // Resolve position from encounter.tokenPositions or default grid
      double x;
      double y;
      final raw = encounter.tokenPositions[c.id];
      if (raw is Map) {
        x = (raw['x'] as num?)?.toDouble() ?? 0;
        y = (raw['y'] as num?)?.toDouble() ?? 0;
      } else {
        final gs = encounter.gridSize.toDouble();
        x = (col + 1.5) * gs;
        y = (row + 1.5) * gs;
        col++;
        if (col > 4) {
          col = 0;
          row++;
        }
      }

      // Entity-derived visuals
      final entity = c.entityId != null ? entities[c.entityId!] : null;
      String? imagePath;
      if (entity != null) {
        if (entity.imagePath.isNotEmpty) {
          imagePath = entity.imagePath;
        } else if (entity.images.isNotEmpty) {
          imagePath = entity.images.first;
        }
      }
      final colorHex = _resolveColor(entity, c, categoryColors);
      final isPlayer = entity?.categorySlug == 'player_character' ||
          entity?.categorySlug == 'player' ||
          entity?.categorySlug == 'pc';

      tokens.add(TokenSnapshot(
        id: c.id,
        name: c.name,
        x: x,
        y: y,
        imagePath: imagePath,
        colorHex: colorHex,
        isPlayer: isPlayer,
        hp: c.hp,
        maxHp: c.maxHp,
        init: c.init,
        conditions: c.conditions.map((cond) {
          // Resolve the condition entity's first image so the player-side
          // initiative panel can show condition art instead of plain text.
          String? condImage;
          if (cond.entityId != null) {
            final ce = entities[cond.entityId!];
            if (ce != null) {
              if (ce.imagePath.isNotEmpty) {
                condImage = ce.imagePath;
              } else if (ce.images.isNotEmpty) {
                condImage = ce.images.first;
              }
            }
          }
          return ConditionSnapshot(
            name: cond.name,
            turns: cond.duration,
            imagePath: condImage,
          );
        }).toList(),
      ));
    }

    final tokenSizeMultsDouble = <String, double>{};
    encounter.tokenSizeMultipliers.forEach((k, v) {
      tokenSizeMultsDouble[k] = v;
    });

    return BattleMapSnapshot(
      mapPath: encounter.mapPath,
      fogDataBase64: encounter.fogData,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      gridSize: encounter.gridSize,
      gridVisible: encounter.gridVisible,
      feetPerCell: encounter.feetPerCell,
      tokenSize: encounter.tokenSize,
      tokenSizeMultipliers: tokenSizeMultsDouble,
      tokens: tokens,
      turnIndex: encounter.turnIndex,
    );
  }

  /// Reads the background image at [mapPath] and returns its pixel
  /// dimensions. Used once per map change to set the snapshot's canvas
  /// dimensions accurately.
  static Future<(int, int)> measureCanvas(String? mapPath) async {
    if (mapPath == null || mapPath.isEmpty) return (2048, 2048);
    try {
      final bytes = await File(mapPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      return (w, h);
    } catch (_) {
      return (2048, 2048);
    }
  }

  /// Mirrors the DM-side `_categoryColor` lookup in `battle_map_screen.dart`
  /// — the token border on the DM is the **entity category color** from
  /// the world schema, not a hash. We resolve to the same value here so the
  /// player view paints identical colors. Per-entity overrides via
  /// `fields['color']` take precedence (matching nothing in the DM today,
  /// but preserved for forward-compat).
  static String _resolveColor(
    Entity? entity,
    Combatant c,
    Map<String, String> categoryColors,
  ) {
    if (entity != null) {
      // Per-entity field override (forward-compat — not used by DM today).
      for (final key in ['color', 'token_color', 'tokenColor']) {
        final v = entity.fields[key];
        if (v is String && v.isNotEmpty) {
          return v.startsWith('#') ? v : '#$v';
        }
      }
      // Category color from the world schema (the DM's actual source).
      final cat = categoryColors[entity.categorySlug];
      if (cat != null && cat.isNotEmpty) {
        return cat.startsWith('#') ? cat : '#$cat';
      }
    }
    // Neutral fallback — matches `palette.tokenBorderNeutral` semantically.
    return '#808080';
  }
}
