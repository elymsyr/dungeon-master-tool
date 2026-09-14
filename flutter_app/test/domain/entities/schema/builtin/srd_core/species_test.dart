import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/subspecies.dart';
import 'package:flutter_test/flutter_test.dart';

/// Subspecies ship as first-class `subspecies` entities linked to their species
/// by `parent_species_ref`; the nested `subspecies_options` list is gone.
/// `legacy_subspecies_key` is the old option name that pre-migration
/// characters still store, so it is what these sets are keyed on.
void main() {
  group('srdSubspecies (SRD 5.2.1)', () {
    final all = srdSubspecies();
    List<Map<String, dynamic>> ofSpecies(String species) => all.where((s) {
          final parent = (s['attributes'] as Map)['parent_species_ref'] as Map;
          return parent['_ref'] == 'species' && parent['name'] == species;
        }).toList();
    Set<String> legacyKeys(String species) => ofSpecies(species)
        .map((s) => (s['attributes'] as Map)['legacy_subspecies_key'] as String)
        .toSet();

    test('Dragonborn ships all 10 chromatic + metallic ancestries', () {
      expect(legacyKeys('Dragonborn'), {
        'Black', 'Blue', 'Brass', 'Bronze', 'Copper',
        'Gold', 'Green', 'Red', 'Silver', 'White',
      });
    });

    test('Elf ships Drow / High Elf / Wood Elf', () {
      expect(legacyKeys('Elf'), {'Drow', 'High Elf', 'Wood Elf'});
    });

    test('Goliath ships all 6 giant ancestries', () {
      expect(legacyKeys('Goliath'), {
        'Cloud Giant', 'Fire Giant', 'Frost Giant',
        'Hill Giant', 'Stone Giant', 'Storm Giant',
      });
    });

    test('Tiefling ships Abyssal / Chthonic / Infernal', () {
      expect(legacyKeys('Tiefling'), {'Abyssal', 'Chthonic', 'Infernal'});
    });

    test('Wood Elf grants +5 ft speed', () {
      final wood = ofSpecies('Elf').firstWhere((s) => s['name'] == 'Wood Elf');
      expect((wood['attributes'] as Map)['speed_bonus_ft'], 5);
    });
  });
}
