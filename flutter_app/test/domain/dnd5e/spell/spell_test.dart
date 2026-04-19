import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/area_of_effect.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/casting_time.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_components.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_duration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_range.dart';
import 'package:flutter_test/flutter_test.dart';

Spell _fireball() => Spell(
      id: 'srd:fireball',
      name: 'Fireball',
      level: SpellLevel(3),
      schoolId: 'srd:evocation',
      castingTime: const ActionCast(),
      range: FeetRange(150),
      components: [
        const VerbalComponent(),
        const SomaticComponent(),
        MaterialComponent(description: 'A tiny ball of bat guano and sulfur.'),
      ],
      duration: const SpellInstantaneous(),
      area: SphereAoE(20),
      classListIds: ['srd:wizard', 'srd:sorcerer'],
    );

void main() {
  group('Spell', () {
    test('builds fireball cleanly', () {
      final s = _fireball();
      expect(s.level.value, 3);
      expect(s.isCantrip, isFalse);
      expect(s.classListIds, ['srd:wizard', 'srd:sorcerer']);
      expect(s.area, isA<SphereAoE>());
    });

    test('rejects malformed id', () {
      expect(
          () => Spell(
                id: 'fireball',
                name: 'Fireball',
                level: SpellLevel(3),
                schoolId: 'srd:evocation',
                castingTime: const ActionCast(),
                range: const SelfRange(),
                components: const [],
                duration: const SpellInstantaneous(),
              ),
          throwsArgumentError);
    });

    test('rejects malformed schoolId', () {
      expect(
          () => Spell(
                id: 'srd:x',
                name: 'X',
                level: SpellLevel(0),
                schoolId: 'evocation',
                castingTime: const ActionCast(),
                range: const SelfRange(),
                components: const [],
                duration: const SpellInstantaneous(),
              ),
          throwsArgumentError);
    });

    test('cantrip flag tracks level 0', () {
      final s = Spell(
        id: 'srd:mage_hand',
        name: 'Mage Hand',
        level: SpellLevel(0),
        schoolId: 'srd:conjuration',
        castingTime: const ActionCast(),
        range: FeetRange(30),
        components: const [VerbalComponent(), SomaticComponent()],
        duration: SpellMinutes(minutes: 1),
      );
      expect(s.isCantrip, isTrue);
    });

    test('equality by id', () {
      expect(_fireball(), _fireball());
    });
  });
}
