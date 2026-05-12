import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/species.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('srdSpecies subspecies_options (SRD 5.2.1)', () {
    final all = srdSpecies();
    Map<String, dynamic>? bySpecies(String name) =>
        all.firstWhere((s) => s['name'] == name, orElse: () => {});

    test('Dragonborn ships all 10 chromatic + metallic ancestries', () {
      final attrs = bySpecies('Dragonborn')!['attributes']
          as Map<String, dynamic>;
      final names = (attrs['subspecies_options'] as List)
          .map((r) => (r as Map)['name'])
          .toSet();
      expect(
        names,
        containsAll(<String>{
          'Black', 'Blue', 'Brass', 'Bronze', 'Copper',
          'Gold', 'Green', 'Red', 'Silver', 'White',
        }),
      );
      expect(names.length, 10);
    });

    test('Elf ships Drow / High Elf / Wood Elf', () {
      final attrs =
          bySpecies('Elf')!['attributes'] as Map<String, dynamic>;
      final names = (attrs['subspecies_options'] as List)
          .map((r) => (r as Map)['name'])
          .toSet();
      expect(names, {'Drow', 'High Elf', 'Wood Elf'});
    });

    test('Goliath ships all 6 giant ancestries', () {
      final attrs =
          bySpecies('Goliath')!['attributes'] as Map<String, dynamic>;
      final names = (attrs['subspecies_options'] as List)
          .map((r) => (r as Map)['name'])
          .toSet();
      expect(
        names,
        {'Cloud Giant', 'Fire Giant', 'Frost Giant',
            'Hill Giant', 'Stone Giant', 'Storm Giant'},
      );
    });

    test('Tiefling ships Abyssal / Chthonic / Infernal', () {
      final attrs =
          bySpecies('Tiefling')!['attributes'] as Map<String, dynamic>;
      final names = (attrs['subspecies_options'] as List)
          .map((r) => (r as Map)['name'])
          .toSet();
      expect(names, {'Abyssal', 'Chthonic', 'Infernal'});
    });

    test('Wood Elf grants +5 speed_bonus', () {
      final attrs =
          bySpecies('Elf')!['attributes'] as Map<String, dynamic>;
      final wood = (attrs['subspecies_options'] as List).firstWhere(
          (r) => (r as Map)['name'] == 'Wood Elf') as Map<String, dynamic>;
      final mods = wood['granted_modifiers'] as List;
      expect(mods, hasLength(1));
      expect(mods.first, {'kind': 'speed_bonus', 'value': 5});
    });
  });
}
