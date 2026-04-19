import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Die', () {
    test('sides + notation', () {
      expect(Die.d4.sides, 4);
      expect(Die.d4.notation, 'd4');
      expect(Die.d20.sides, 20);
      expect(Die.d100.sides, 100);
    });

    test('averageFloor matches SRD monster damage convention', () {
      expect(Die.d4.averageFloor, 2);
      expect(Die.d6.averageFloor, 3);
      expect(Die.d8.averageFloor, 4);
      expect(Die.d10.averageFloor, 5);
      expect(Die.d12.averageFloor, 6);
      expect(Die.d20.averageFloor, 10);
    });

    test('fromSides round-trips', () {
      for (final d in Die.values) {
        expect(Die.fromSides(d.sides), d);
      }
    });

    test('fromSides rejects unknown', () {
      expect(() => Die.fromSides(7), throwsArgumentError);
    });
  });
}
