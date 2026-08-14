import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/chargen.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B3 — species / subspecies / background grants.**
///
/// The phase was filed as "match `SpeciesTrait.type` and `BackgroundBenefit.type`
/// instead of names". The snapshot reverses half of it and confirms the other:
///
///   * `BackgroundBenefit.type` was *already* the key `mapBackgrounds` matches
///     on. What was actually missing is the `tool_proficiency` bucket — 40 rows
///     across the shipped documents, `granted_tool_refs` at 0%.
///   * `SpeciesTrait.type` is **null on 100% of the rows we ship**. It is
///     populated in exactly one document (`srd-2024`, 18 rows), which the
///     publisher-wide SRD skip never builds. Name matching is the only key the
///     data has, so there is nothing to switch to.
///
/// The tool parser's two failure modes are both silent, which is why most of
/// the cases below are about what it refuses to emit: granting an alternative
/// hands the player a proficiency they never picked, and emitting one family
/// out of two deletes a choice.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  Iterable<Map<String, dynamic>> rows() =>
      pack.entities.values.cast<Map<String, dynamic>>();

  Map<String, dynamic> entity(String type, String name) =>
      rows().firstWhere((e) => e['type'] == type && e['name'] == name);

  group('background tool proficiencies', () {
    List<String> refs(String desc) =>
        [for (final r in parseToolProficiencies(desc).refs) r['name']!];
    String? group(String desc) => parseToolProficiencies(desc).group;

    test('named tools become softRefs to the built-in cards', () {
      // Real rows. Upstream punctuation differs from the card names in three
      // ways at once: curly apostrophe, plural possessive, straight quote.
      expect(refs('Disguise kit, forgery kit.'), ['Disguise Kit', 'Forgery Kit']);
      expect(refs('Cartographers’ tools.'), ["Cartographer's Tools"]);
      expect(refs('Navigator’s tools, water vehicles.'), ["Navigator's Tools"]);
      expect(refs("Alchemist's supplies, herbalism kit"),
          ["Alchemist's Supplies", 'Herbalism Kit']);
      expect(parseToolProficiencies('Disguise kit.').refs.single,
          {'slug': 'tool', 'name': 'Disguise Kit'});
    });

    test('a "one type of X" line becomes a variant group, not a ref', () {
      expect(group('One type of gaming set.'), 'gaming_set');
      expect(group('One gaming set.'), 'gaming_set');
      expect(group('One type of musical instrument'), 'musical_instrument');
      expect(group("One artisan's tools set of your choice"), 'artisans_tools');
      expect(refs('One type of gaming set.'), isEmpty);
    });

    test('a family absorbs its own members but not outsiders', () {
      // The umbrella `Gaming Set` card must not ship alongside the group — that
      // would grant the whole family instead of offering a pick from it.
      expect(group("Gaming set, thieves' tools."), 'gaming_set');
      expect(refs("Gaming set, thieves' tools."), ["Thieves' Tools"]);
    });

    test('an "or" makes every named tool an alternative, never a grant', () {
      // Three real cards, none of them granted.
      const pick = 'Your choice of one from Thieves’ Tools, Forgery Kit, '
          'or Disguise Kit.';
      expect(refs(pick), isEmpty);
      expect(group(pick), isNull);
      // A single family survives an `or` when every tool named belongs to it —
      // `artisans_tools` already offers Smith's Tools.
      expect(group('One type of artisan’s tools or smith’s tools.'),
          'artisans_tools');
      expect(refs('One type of artisan’s tools or smith’s tools.'), isEmpty);
    });

    test('two families are not representable, so neither is emitted', () {
      // `granted_tool_variant_group` is a single text field. Picking the first
      // would silently delete the second choice.
      expect(group('One type of gaming set, one musical instrument'), isNull);
      expect(group('One type of artisan’s tools or one type of musical instrument'),
          isNull);
      expect(
          group('Either one type of artisan’s tools, musical instrument, '
              'or vehicle.'),
          isNull);
    });

    test('non-grants and vehicles yield nothing', () {
      for (final d in [
        'No additional tool proficiencies',
        'Two of your choice',
        'Land vehicles.',
        'One vehicle.',
        '',
      ]) {
        expect(refs(d), isEmpty, reason: d);
        expect(group(d), isNull, reason: d);
      }
      // A family still lands when only the vehicle half is unmappable.
      expect(group('One type of artisan’s tools, one vehicle.'), 'artisans_tools');
    });

    test('the fields land on the background entity', () {
      mapBackgrounds(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        backgrounds: [
          <String, dynamic>{'_pk': 'b1', 'name': 'Criminal', 'desc': 'A crook.'},
        ],
        benefits: [
          <String, dynamic>{
            '_pk': 'x1',
            'parent': 'b1',
            'type': 'tool_proficiency',
            'desc': "One type of gaming set, thieves' tools",
          },
        ],
      );
      final bg = entity('background', 'Criminal');
      expect(bg['attributes']['granted_tool_variant_group'], 'gaming_set');
      expect(bg['attributes']['granted_tool_refs'],
          [{'slug': 'tool', 'name': "Thieves' Tools"}]);
    });
  });

  group('v1 species trait recovery', () {
    void run({
      required List<Fixture> species,
      List<Fixture> traits = const [],
      V1SpeciesIndex v1Traits = const {},
    }) =>
        mapSpecies(
          pack: pack,
          norm: norm,
          source: 'Test Doc',
          species: species,
          traits: traits,
          v1Traits: v1Traits,
        );

    Fixture sp(String pk, String name) =>
        <String, dynamic>{'_pk': pk, 'name': name, 'desc': 'A shade.'};
    Fixture trait(String pk, String parent, String name, String desc) =>
        <String, dynamic>{
          '_pk': pk,
          'parent': parent,
          'name': name,
          'desc': desc,
        };

    test('a species v2 converted with zero traits is filled from v1', () {
      // `toh`'s Shade: 0 SpeciesTrait rows in v2, a full statblock in v1.
      run(
        species: [sp('toh_shade', 'Shade')],
        v1Traits: {
          'shade': [
            {'name': 'Ability Score Increase', 'desc': 'Your Charisma score increases by 1.'},
            {'name': 'Languages', 'desc': 'You can speak, read, and write Common.'},
            {'name': 'Darkvision', 'desc': 'You can see in dim light within 60 feet.'},
          ],
        },
      );
      final s = entity('species', 'Shade')['attributes'] as Map;
      expect(s['ability_bonuses'], {'CHA': 1});
      expect(s['granted_languages'], [
        {'_lookup': 'language', 'name': 'Common'},
      ]);
      // `range_ft` comes from the recovered v1 prose (audit B5).
      expect(s['granted_senses'], [
        {
          'sense_ref': {'_lookup': 'sense', 'name': 'Darkvision'},
          'range_ft': 60,
        },
      ]);
      expect(s['description'], contains('Darkvision'));
    });

    test('a species v2 did convert is never overridden', () {
      run(
        species: [sp('toh_derro', 'Derro')],
        traits: [trait('t1', 'toh_derro', 'Size', 'Your size is Small.')],
        v1Traits: {
          'derro': [
            {'name': 'Size', 'desc': 'Your size is Medium.'},
            {'name': 'Languages', 'desc': 'You can speak Common.'},
          ],
        },
      );
      final s = entity('species', 'Derro')['attributes'] as Map;
      expect(s['size_ref'], {'_lookup': 'size', 'name': 'Small'},
          reason: 'v1 must not overwrite a size v2 supplied');
      expect(s.containsKey('granted_languages'), isFalse,
          reason: 'the backfill is all-or-nothing per species, like B8');
    });

    test('with no v1 index the mapper behaves exactly as before', () {
      run(species: [sp('toh_shade', 'Shade')]);
      final s = entity('species', 'Shade')['attributes'] as Map;
      expect(s.keys, unorderedEquals(['description', 'creature_type_ref']));
    });

    test('a resistance that only lasts for an activated trait is not a grant',
        () {
      // Shade's Ghostly Flesh is 3rd level, 1/long rest, 1 minute. Its B/P/S
      // resistance shipped as three permanent level-1 grants until B3.
      run(
        species: [sp('toh_shade', 'Shade')],
        v1Traits: {
          'shade': [
            {
              'name': 'Ghostly Flesh',
              'desc': 'Your transformation lasts for 1 minute. During it, you '
                  'have resistance to bludgeoning, piercing, and slashing '
                  'damage from nonmagical attacks.',
            },
            {
              'name': 'Spectral Resilience',
              'desc': 'You have resistance to necrotic damage.',
            },
          ],
        },
      );
      expect(
        (entity('species', 'Shade')['attributes'] as Map)['granted_damage_resistances'],
        [{'_lookup': 'damage-type', 'name': 'Necrotic'}],
        reason: 'the filter is per sentence, so the unconditional one survives',
      );
    });

    test('every recovered species ref resolves — nothing dangles', () {
      run(
        species: [sp('toh_shade', 'Shade')],
        v1Traits: {
          'shade': [
            {'name': 'Size', 'desc': 'Your size is Medium.'},
            {'name': 'Speed', 'desc': 'Your base walking speed is 30 feet.'},
          ],
        },
      );
      expect(pack.resolveRefs(), isEmpty);
      final s = entity('species', 'Shade')['attributes'] as Map;
      expect(s['size_ref'], {'_lookup': 'size', 'name': 'Medium'});
      expect(s['speed_ft'], 30);
    });
  });
}
