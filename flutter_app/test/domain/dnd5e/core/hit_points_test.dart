import 'package:dungeon_master_tool/domain/dnd5e/core/hit_points.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HitPoints invariants', () {
    test('max ≥ 1', () {
      expect(() => HitPoints(current: 0, max: 0), throwsArgumentError);
    });
    test('current ∈ [0, max]', () {
      expect(
          () => HitPoints(current: -1, max: 10), throwsArgumentError);
      expect(
          () => HitPoints(current: 11, max: 10), throwsArgumentError);
    });
    test('temp ≥ 0', () {
      expect(
          () => HitPoints(current: 5, max: 10, temp: -1), throwsArgumentError);
    });
  });

  group('HitPoints.full', () {
    test('sets current = max', () {
      final hp = HitPoints.full(20);
      expect(hp.current, 20);
      expect(hp.isAtFull, isTrue);
    });
  });

  group('takeDamage', () {
    test('consumes temp first', () {
      final hp = HitPoints(current: 20, max: 20, temp: 5);
      final r = hp.takeDamage(3);
      expect(r.hp.current, 20);
      expect(r.hp.temp, 2);
      expect(r.overflow, 0);
    });

    test('overflow temp spills to current', () {
      final hp = HitPoints(current: 20, max: 20, temp: 5);
      final r = hp.takeDamage(8);
      expect(r.hp.temp, 0);
      expect(r.hp.current, 17);
    });

    test('clamps at 0 and reports overflow', () {
      final hp = HitPoints(current: 5, max: 10);
      final r = hp.takeDamage(20);
      expect(r.hp.current, 0);
      expect(r.hp.isDying, isTrue);
      expect(r.overflow, 15);
    });

    test('rejects negative', () {
      expect(() => HitPoints.full(10).takeDamage(-1), throwsArgumentError);
    });
  });

  group('heal', () {
    test('clamps at max', () {
      final hp = HitPoints(current: 5, max: 10);
      expect(hp.heal(100).current, 10);
    });
    test('leaves temp alone', () {
      final hp = HitPoints(current: 5, max: 10, temp: 3);
      expect(hp.heal(2).temp, 3);
    });
  });

  group('grantTemp', () {
    test('new > old replaces', () {
      final hp = HitPoints(current: 10, max: 10, temp: 3);
      expect(hp.grantTemp(7).temp, 7);
    });
    test('new ≤ old ignored', () {
      final hp = HitPoints(current: 10, max: 10, temp: 5);
      expect(hp.grantTemp(3).temp, 5);
      expect(hp.grantTemp(5).temp, 5);
    });
  });

  group('withMax', () {
    test('shrinks current if above new max', () {
      final hp = HitPoints(current: 10, max: 10);
      expect(hp.withMax(5).current, 5);
    });
  });
}
