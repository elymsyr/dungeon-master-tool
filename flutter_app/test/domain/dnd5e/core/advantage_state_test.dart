import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdvantageState.combine', () {
    test('idempotent with self', () {
      expect(
          AdvantageState.advantage.combine(AdvantageState.advantage),
          AdvantageState.advantage);
      expect(
          AdvantageState.disadvantage.combine(AdvantageState.disadvantage),
          AdvantageState.disadvantage);
    });
    test('normal acts as identity', () {
      expect(
          AdvantageState.normal.combine(AdvantageState.advantage),
          AdvantageState.advantage);
      expect(
          AdvantageState.disadvantage.combine(AdvantageState.normal),
          AdvantageState.disadvantage);
    });
    test('advantage + disadvantage cancels', () {
      expect(
          AdvantageState.advantage.combine(AdvantageState.disadvantage),
          AdvantageState.normal);
    });
  });

  group('AdvantageState.fromFlags', () {
    test('both flags → normal (cancel)', () {
      expect(
          AdvantageState.fromFlags(anyAdvantage: true, anyDisadvantage: true),
          AdvantageState.normal);
    });
    test('advantage only', () {
      expect(
          AdvantageState.fromFlags(
              anyAdvantage: true, anyDisadvantage: false),
          AdvantageState.advantage);
    });
    test('disadvantage only', () {
      expect(
          AdvantageState.fromFlags(
              anyAdvantage: false, anyDisadvantage: true),
          AdvantageState.disadvantage);
    });
    test('neither → normal', () {
      expect(
          AdvantageState.fromFlags(
              anyAdvantage: false, anyDisadvantage: false),
          AdvantageState.normal);
    });
  });
}
