import 'package:dungeon_master_tool/domain/dnd5e/core/death_saves.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeathSaves invariants', () {
    test('successes 0..3', () {
      expect(() => DeathSaves(successes: -1), throwsArgumentError);
      expect(() => DeathSaves(successes: 4), throwsArgumentError);
    });
    test('failures 0..3', () {
      expect(() => DeathSaves(failures: 4), throwsArgumentError);
    });
  });

  test('addSuccess clamps at 3', () {
    var s = DeathSaves.zero;
    for (var i = 0; i < 5; i++) {
      s = s.addSuccess();
    }
    expect(s.successes, 3);
  });

  test('addCriticalFailure adds two', () {
    final s = DeathSaves.zero.addCriticalFailure();
    expect(s.failures, 2);
  });

  test('state flags', () {
    expect(DeathSaves.zero.isActive, isTrue);
    expect(DeathSaves(successes: 3).isStable, isTrue);
    expect(DeathSaves(failures: 3).isDead, isTrue);
  });
}
