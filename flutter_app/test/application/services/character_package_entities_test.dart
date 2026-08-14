import 'package:dungeon_master_tool/application/providers/package_link_provider.dart';
import 'package:dungeon_master_tool/application/services/package_source_entities.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the card-side entity source: a character built from a non-builtin
/// package must resolve its species/class names, or every stat chip renders
/// "—" (the bug this test was written for).
Entity _e(String id, String slug, String name) =>
    Entity(id: id, categorySlug: slug, name: name, fields: const {});

Character _char(List<String> packages) => Character(
      id: 'c1',
      templateId: 't',
      templateName: 'PC',
      entity: Entity(
        id: 'c1',
        categorySlug: 'player_character',
        name: 'Vex',
        fields: {
          'species_ref': 'a5e-species',
          'source_packages': packages,
        },
      ),
      createdAt: '',
      updatedAt: '',
    );

void main() {
  final builtin = {'srd-elf': _e('srd-elf', 'species', 'Elf')};
  final pack = {'a5e-species': _e('a5e-species', 'species', 'Planetouched')};

  ProviderContainer container(List<String> closure) => ProviderContainer(
        overrides: [
          packageLinkClosureOfAllProvider
              .overrideWith((ref, key) async => closure),
          packageEntitiesProvider.overrideWith(
            (ref, name) async => name == 'a5e' ? pack : const {},
          ),
        ],
      );

  test('source packages layer over the builtin map', () async {
    final c = container(['a5e']);
    addTearDown(c.dispose);
    await c.read(packageEntitiesProvider('a5e').future);
    await c.read(packageLinkClosureOfAllProvider('a5e').future);

    final entities = withCharacterPackages(c.read, builtin, _char(['a5e']));
    expect(entities['a5e-species']?.name, 'Planetouched');
    expect(entities['srd-elf']?.name, 'Elf');
  });

  test('no source packages leaves the base map untouched', () {
    final c = container(const []);
    addTearDown(c.dispose);
    expect(withCharacterPackages(c.read, builtin, _char(const [])),
        same(builtin));
  });
}
