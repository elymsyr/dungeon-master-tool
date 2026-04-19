import 'package:dungeon_master_tool/application/dnd5e/effect/srd_custom_effects.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/custom_effect_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SRD CustomEffect impls', () {
    test('all nine ids match Doc 15 whitelist exactly', () {
      final ids = srdCustomEffectImpls.map((e) => e.id).toList();
      expect(ids, <String>[
        'srd:wish',
        'srd:wild_shape',
        'srd:polymorph',
        'srd:animate_dead',
        'srd:simulacrum',
        'srd:summon_family',
        'srd:conjure_family',
        'srd:shapechange',
        'srd:glyph_of_warding',
      ]);
    });

    test('every id is namespaced under "srd:"', () {
      for (final impl in srdCustomEffectImpls) {
        expect(impl.id, startsWith('srd:'), reason: impl.runtimeType.toString());
      }
    });

    test('ids are unique within the impl list', () {
      final ids = srdCustomEffectImpls.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('registerSrdCustomEffects populates a fresh registry', () {
      final reg = CustomEffectRegistry();
      registerSrdCustomEffects(reg);
      expect(reg.ids.toSet(),
          srdCustomEffectImpls.map((e) => e.id).toSet());
      for (final impl in srdCustomEffectImpls) {
        expect(reg.contains(impl.id), isTrue, reason: impl.id);
      }
    });

    test('double registration throws via duplicate-id guard', () {
      final reg = CustomEffectRegistry();
      registerSrdCustomEffects(reg);
      expect(() => registerSrdCustomEffects(reg), throwsStateError);
    });

    test('individual impls are const-constructible', () {
      const a = WishImpl();
      const b = WishImpl();
      expect(identical(a, b), isTrue);
    });
  });
}
