import 'package:dungeon_master_tool/application/services/package_source_entities.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Audit phase L1 — which card wins a name collision.**
///
/// L1 asked whether a bundled pack should stop shipping what the built-in SRD
/// already ships. Measured, the answer is *nothing gets dropped*: every one of
/// the 1,643 section-A collisions is an A5E restat, a separate Tome of Beasts
/// edition, a monster-owned child, or one of two additive singletons. So the
/// collisions stay — and then the only question that matters to a user is which
/// of the two cards a soft ref lands on.
///
/// That is decided by *insertion order*, because `findEntityIdByName` indexes
/// `byId.values` first-writer-wins, and ids never collide (uuidv5 of pack +
/// slug + name), so both cards are always in the map. The pack the user ticked
/// has to win, and it has to win on **both** entity-source paths.
Entity _e(String id, String name) =>
    Entity(id: id, categorySlug: 'spell', name: name, fields: const {});

void main() {
  final builtin = {'srd-fireball': _e('srd-fireball', 'Fireball')};
  final a5e = {'a5e-fireball': _e('a5e-fireball', 'Fireball')};

  test('a package shadows the built-in card of the same name', () {
    final merged = layerPackagesOverBuiltin(builtin, [a5e]);
    // Both cards survive — this is shadowing, not deletion.
    expect(merged.length, 2);
    expect(findEntityIdByName(merged, 'spell', 'Fireball'), 'a5e-fireball');
  });

  test('later packages win over earlier ones (the link closure order)', () {
    final other = {'toh-fireball': _e('toh-fireball', 'Fireball')};
    // Closure is dependency-ordered: links first, the picked pack last.
    expect(
      findEntityIdByName(
          layerPackagesOverBuiltin(builtin, [other, a5e]), 'spell', 'Fireball'),
      'a5e-fireball',
    );
  });

  test('no packages, or none loaded yet, leaves the built-in map alone', () {
    expect(layerPackagesOverBuiltin(builtin, const []), same(builtin));
    expect(layerPackagesOverBuiltin(builtin, [const {}]), same(builtin));
  });

  test('a name only the built-in ships still resolves', () {
    final merged = layerPackagesOverBuiltin(
        {...builtin, 'srd-bless': _e('srd-bless', 'Bless')}, [a5e]);
    expect(findEntityIdByName(merged, 'spell', 'Bless'), 'srd-bless');
  });
}
