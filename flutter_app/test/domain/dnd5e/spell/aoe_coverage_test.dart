import 'package:dungeon_master_tool/domain/dnd5e/spell/area_of_effect.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/grid_cell.dart';
import 'package:flutter_test/flutter_test.dart';

const origin = GridCell(0, 0);

void main() {
  group('SphereAoE.coverage', () {
    test('radius 5 ft = 1 cell → 3x3 disc (9 cells)', () {
      final cells = SphereAoE(5).coverage(origin, GridDirection.east);
      expect(cells.length, 9);
      expect(cells.contains(origin), true);
      expect(cells.contains(const GridCell(-1, -1)), true);
      expect(cells.contains(const GridCell(1, 1)), true);
    });

    test('radius 20 ft = 4 cells → 9x9 disc (81 cells)', () {
      final cells = SphereAoE(20).coverage(origin, GridDirection.east);
      expect(cells.length, 9 * 9);
    });

    test('radius 12 ft rounds up to 3 cells', () {
      final cells = SphereAoE(12).coverage(origin, GridDirection.east);
      expect(cells.length, 7 * 7);
    });
  });

  group('EmanationAoE.coverage', () {
    test('matches SphereAoE disc of same size', () {
      final s = SphereAoE(10).coverage(origin, GridDirection.east);
      final e = EmanationAoE(10).coverage(origin, GridDirection.east);
      expect(e, s);
    });
  });

  group('CylinderAoE.coverage', () {
    test('matches sphere disc on 2D grid (height ignored)', () {
      final s = SphereAoE(15).coverage(origin, GridDirection.east);
      final c = CylinderAoE(radiusFt: 15, heightFt: 40)
          .coverage(origin, GridDirection.east);
      expect(c, s);
    });
  });

  group('ConeAoE.coverage', () {
    test('15 ft cone → rows of width 3/5/7 at distances 1/2/3', () {
      final cells = ConeAoE(15).coverage(origin, GridDirection.east);
      // row d=1: (1, -1), (1, 0), (1, 1) → 3
      // row d=2: (2, -2)..(2, 2) → 5
      // row d=3: (3, -3)..(3, 3) → 7
      expect(cells.length, 3 + 5 + 7);
      expect(cells.contains(const GridCell(1, 0)), true);
      expect(cells.contains(const GridCell(3, 3)), true);
      expect(cells.contains(origin), false);
    });

    test('orientation follows direction: north reaches -y', () {
      final cells = ConeAoE(10).coverage(origin, GridDirection.north);
      expect(cells.contains(const GridCell(0, -1)), true);
      expect(cells.contains(const GridCell(0, -2)), true);
      expect(cells.contains(const GridCell(0, 1)), false);
    });
  });

  group('CubeAoE.coverage', () {
    test('10 ft cube → 2x2 footprint forward from origin', () {
      final cells = CubeAoE(10).coverage(origin, GridDirection.east);
      expect(cells.length, 2 * 2);
      // face flush with origin (forward=0), then forward=1.
      expect(cells.contains(const GridCell(0, 0)), true);
      expect(cells.contains(const GridCell(1, 1)), true);
    });

    test('15 ft cube → 3x3 centred', () {
      final cells = CubeAoE(15).coverage(origin, GridDirection.east);
      expect(cells.length, 3 * 3);
    });
  });

  group('LineAoE.coverage', () {
    test('30x5 line east → 6 cells, one cell wide, starts at (1,0)', () {
      final cells = LineAoE(lengthFt: 30, widthFt: 5)
          .coverage(origin, GridDirection.east);
      expect(cells.length, 6);
      expect(cells.contains(const GridCell(1, 0)), true);
      expect(cells.contains(const GridCell(6, 0)), true);
      expect(cells.contains(origin), false);
    });

    test('excludes origin (starts at forward=1)', () {
      final cells = LineAoE(lengthFt: 30, widthFt: 5)
          .coverage(origin, GridDirection.south);
      expect(cells.contains(origin), false);
      expect(cells.contains(const GridCell(0, 1)), true);
    });
  });

  group('GridCell', () {
    test('chebyshevTo king-move distance', () {
      expect(const GridCell(0, 0).chebyshevTo(const GridCell(3, 4)), 4);
      expect(const GridCell(-2, -2).chebyshevTo(const GridCell(2, 2)), 4);
      expect(const GridCell(1, 1).chebyshevTo(const GridCell(1, 1)), 0);
    });

    test('translate', () {
      expect(const GridCell(1, 1).translate(3, -2), const GridCell(4, -1));
    });
  });
}
