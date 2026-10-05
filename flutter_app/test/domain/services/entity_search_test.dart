import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/entity_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wizardId = '00000000-0000-4000-8000-000000000001';
  const srdWizardId = '00000000-0000-4000-8000-000000000002';
  const humanId = '00000000-0000-4000-8000-000000000003';

  final byId = <String, Entity>{
    wizardId: const Entity(id: wizardId, name: 'Wizard', categorySlug: 'class'),
    // Same class from another source (bundled SRD) under its own id.
    srdWizardId:
        const Entity(id: srdWizardId, name: 'Wizard', categorySlug: 'class'),
    humanId: const Entity(id: humanId, name: 'Human', categorySlug: 'species'),
  };

  const archmagi = Entity(
    id: 'archmagi',
    name: 'Robe of the Archmagi',
    categorySlug: 'magic-item',
    description: 'AC 15 + your Dex modifier (no armor required).',
    fields: {'attunement_prereq': 'Sorcerer, Warlock, or Wizard'},
  );
  const robe = Entity(
    id: 'robe',
    name: 'Robe',
    categorySlug: 'adventuring-gear',
    tags: ['wizard', 'clothing'],
  );
  const leather =
      Entity(id: 'leather', name: 'Leather Armor', categorySlug: 'armor');
  const missile = Entity(
    id: 'missile',
    name: 'Magic Missile',
    categorySlug: 'spell',
    fields: {
      'class_refs': [srdWizardId],
    },
  );
  const charm = Entity(
    id: 'charm',
    name: 'Charm Person',
    categorySlug: 'spell',
    description: 'One Humanoid you can see makes a Wisdom save itself.',
  );
  final pool = [charm, leather, missile, archmagi, robe];

  test('suggestions: refs across sources, whole-word names, tags', () {
    final s = suggestedEntityIds(pool, {
      'class_refs': [
        {'id': wizardId, 'equipped': false},
      ],
      'species_ref': humanId,
      'languages': ['Common'],
    }, byId);
    // missile via class_refs → SRD twin of the card's Wizard; archmagi via
    // attunement text; robe via its homebrew tag. "Humanoid" ≠ "Human".
    expect(s, {'missile', 'archmagi', 'robe'});
    expect(suggestedEntityIds(pool, {'notes': 'x'}, byId), isEmpty);
  });

  test('ranking: more tokens first, name over text, suggested boost', () {
    final names = rankEntities(pool, 'wizard armor',
            suggested: {'missile', 'archmagi', 'robe'})
        .map((e) => e.name)
        .toList();
    expect(names.first, 'Robe of the Archmagi'); // both tokens hit
    expect(names, containsAll(['Robe', 'Leather Armor']));
    expect(names, isNot(contains('Charm Person')));

    // Old rule kept: name substring still matches mid-word.
    expect(rankEntities(pool, 'issil').map((e) => e.id), ['missile']);
    // Text tier needs a word start: "rmor" must not hit "armor".
    expect(rankEntities(pool, 'rmor').map((e) => e.id), ['leather']);
    expect(rankEntities(pool, '  '), same(pool));
  });

  test('EntityRanking: typing, spaces and backspace match a full rank', () {
    final suggested = {'robe'};
    final r = EntityRanking(pool, suggested: suggested);
    for (final q in [
      'w', 'wi', 'Wiz', 'wizard', 'wizard ', 'wizard a', 'wizard arm', //
      'wizard ar', 'wizard', 'rob', 'robe', 'robes', '', 'r', 'rmor', 'x',
    ]) {
      expect(r.rank(q), rankEntities(pool, q, suggested: suggested),
          reason: q);
    }
    expect(r.rank(''), same(pool));
  });
}
