import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/presentation/widgets/character_stat_chips.dart';

Character _char(Map<String, dynamic> fields) => Character(
      id: 'c1',
      templateId: 't1',
      templateName: 'PC',
      createdAt: '',
      updatedAt: '',
      entity: Entity(
        id: 'e1',
        name: 'Jamal',
        categorySlug: 'player-character',
        fields: fields,
      ),
    );

String _value(List<CharacterStatLine> lines, String label) =>
    lines.firstWhere((l) => l.label == label).value;

void main() {
  test('resolved id refs still win over the envelope name', () {
    final lines = characterStatLines(
      _char({
        'species_ref': 'sp1',
        'class_refs': ['cl1'],
      }),
      {
        'sp1': const Entity(id: 'sp1', name: 'Elf', categorySlug: 'species'),
        'cl1': const Entity(id: 'cl1', name: 'Bard', categorySlug: 'class'),
      },
    );
    expect(_value(lines, 'Species'), 'Elf');
    expect(_value(lines, 'Class'), 'Bard');
  });

  test('unresolved soft-ref envelopes fall back to their name, not "—"', () {
    final lines = characterStatLines(
      _char({
        'species_ref': {'slug': 'species', 'name': 'Human'},
        'class_refs': [
          {'slug': 'class', 'name': 'Fighter'},
        ],
      }),
      const {},
    );
    expect(_value(lines, 'Species'), 'Human');
    expect(_value(lines, 'Class'), 'Fighter');
  });

  test('soft-ref envelopes resolve to the live entity when it is installed', () {
    final entities = {
      'sp1': const Entity(id: 'sp1', name: 'Human', categorySlug: 'species'),
      'cl1': const Entity(id: 'cl1', name: 'Fighter', categorySlug: 'class'),
    };
    final character = _char({
      'species_ref': {'slug': 'species', 'name': 'Human'},
      'class_refs': [
        {'slug': 'class', 'name': 'Fighter'},
      ],
    });
    final ids = characterRaceClassIds(character, entities);
    expect(ids.raceId, 'sp1');
    expect(ids.classId, 'cl1');
    final lines = characterStatLines(character, entities);
    expect(_value(lines, 'Species'), 'Human');
    expect(_value(lines, 'Class'), 'Fighter');
  });
}
