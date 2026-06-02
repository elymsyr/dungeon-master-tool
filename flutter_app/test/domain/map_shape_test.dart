import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/projection/battle_map_snapshot.dart';
import 'package:dungeon_master_tool/domain/value_objects/map_shape.dart';

void main() {
  group('MapShape', () {
    test('toJson / fromJson round-trips every kind + layer', () {
      const shapes = [
        MapShape(
          id: 'r1',
          kind: ShapeKind.rect,
          layer: ShapeLayer.background,
          points: [Offset(10, 20), Offset(110, 220)],
          colorHex: '#66bb6a',
          strokeWidth: 3,
          filled: true,
        ),
        MapShape(
          id: 'l1',
          kind: ShapeKind.line,
          layer: ShapeLayer.object,
          points: [Offset(0, 0), Offset(50, 50)],
        ),
        MapShape(
          id: 'p1',
          kind: ShapeKind.polygon,
          layer: ShapeLayer.gm,
          points: [Offset(0, 0), Offset(10, 0), Offset(5, 8)],
        ),
        MapShape(
          id: 't1',
          kind: ShapeKind.text,
          layer: ShapeLayer.object,
          points: [Offset(7, 9)],
          text: 'Trap!',
          fontSize: 22,
        ),
      ];

      for (final s in shapes) {
        final back = MapShape.fromJson(s.toJson());
        expect(back.id, s.id);
        expect(back.kind, s.kind);
        expect(back.layer, s.layer);
        expect(back.points, s.points);
        expect(back.colorHex, s.colorHex);
        expect(back.strokeWidth, s.strokeWidth);
        expect(back.filled, s.filled);
        expect(back.text, s.text);
        expect(back.fontSize, s.fontSize);
      }
    });

    test('fromJson tolerates missing optional keys', () {
      final s = MapShape.fromJson({
        'k': 0,
        'l': 1,
        'p': [1.0, 2.0, 3.0, 4.0],
      });
      expect(s.kind, ShapeKind.rect);
      expect(s.layer, ShapeLayer.object);
      expect(s.points, const [Offset(1, 2), Offset(3, 4)]);
      expect(s.filled, false);
      expect(s.text, isNull);
    });

    test('enum-index decoders clamp out-of-range to safe defaults', () {
      expect(shapeKindFromInt(99), ShapeKind.rect);
      expect(shapeLayerFromInt(-1), ShapeLayer.object);
    });
  });

  group('ShapeSnapshot', () {
    test('toJson / fromJson round-trip (flat points + optional text)', () {
      const snap = ShapeSnapshot(
        kind: 3, // text
        layer: 1, // object
        points: [12, 34],
        colorHex: '#ffca28',
        strokeWidth: 2,
        text: 'label',
        fontSize: 18,
      );
      final back = ShapeSnapshot.fromJson(snap.toJson());
      expect(back.kind, snap.kind);
      expect(back.layer, snap.layer);
      expect(back.points, snap.points);
      expect(back.colorHex, snap.colorHex);
      expect(back.text, snap.text);
      expect(back.fontSize, snap.fontSize);
    });
  });

  group('BattleMapSnapshot', () {
    test('shapes survive a toJson/fromJson round-trip', () {
      const snap = BattleMapSnapshot(
        shapes: [
          ShapeSnapshot(kind: 0, layer: 0, points: [0, 0, 10, 10]),
        ],
      );
      final back = BattleMapSnapshot.fromJson(snap.toJson());
      expect(back.shapes.length, 1);
      expect(back.shapes.first.kind, 0);
      expect(back.shapes.first.points, const [0, 0, 10, 10]);
    });

    test('an empty shapes list is omitted and defaults back to []', () {
      const snap = BattleMapSnapshot();
      expect(snap.toJson().containsKey('shapes'), isFalse);
      expect(BattleMapSnapshot.fromJson(const {}).shapes, isEmpty);
    });

    test('schemaVersion is 4 (shapes are additive)', () {
      expect(BattleMapSnapshot.schemaVersion, 4);
    });
  });
}
