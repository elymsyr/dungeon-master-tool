import 'package:dungeon_master_tool/domain/dnd5e/effect/custom_effect_registry.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeImpl implements CustomEffectImpl {
  @override
  final String id;
  _FakeImpl(this.id);
}

void main() {
  group('CustomEffectRegistry', () {
    test('register then lookup', () {
      final r = CustomEffectRegistry();
      r.register(_FakeImpl('srd:wish'));
      expect(r.byId('srd:wish'), isNotNull);
      expect(r.contains('srd:wish'), isTrue);
    });

    test('rejects duplicate id', () {
      final r = CustomEffectRegistry();
      r.register(_FakeImpl('srd:wish'));
      expect(() => r.register(_FakeImpl('srd:wish')), throwsStateError);
    });

    test('rejects non-namespaced id', () {
      final r = CustomEffectRegistry();
      expect(() => r.register(_FakeImpl('wish')), throwsArgumentError);
    });

    test('clear empties the map', () {
      final r = CustomEffectRegistry();
      r.register(_FakeImpl('srd:a'));
      r.register(_FakeImpl('srd:b'));
      expect(r.ids, unorderedEquals(['srd:a', 'srd:b']));
      r.clear();
      expect(r.ids, isEmpty);
    });
  });
}
