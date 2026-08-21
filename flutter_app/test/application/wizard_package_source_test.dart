import 'package:dungeon_master_tool/application/character_creation/character_draft_notifier.dart';
import 'package:dungeon_master_tool/application/providers/package_link_provider.dart';
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/application/services/package_source_entities.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: package names contain spaces ("Adventurer's Guide"). The
/// wizard used to join/split its picked-package key on a space, so such a
/// package resolved to two nonexistent names and none of its content
/// (backgrounds, species, …) ever reached the pickers.
void main() {
  test('multi-word source package contributes its entities', () async {
    const pkg = "Adventurer's Guide";
    const bg = Entity(
      id: 'bg-1',
      name: 'Guild Artisan',
      categorySlug: 'background',
    );

    final container = ProviderContainer(overrides: [
      builtinSrdEntitiesProvider.overrideWithValue(const {}),
      packageEntitiesProvider(pkg).overrideWith((ref) async => {bg.id: bg}),
      packageLinkClosureOfAllProvider(packageSetKey(const [pkg]))
          .overrideWith((ref) async => const [pkg]),
    ]);
    addTearDown(container.dispose);

    container.read(characterDraftProvider.notifier).setSourcePackages([pkg]);
    // Let the overridden futures settle.
    await container.read(packageEntitiesProvider(pkg).future);
    await container
        .read(packageLinkClosureOfAllProvider(packageSetKey(const [pkg])).future);

    expect(container.read(wizardEntitiesProvider).values.map((e) => e.name),
        contains('Guild Artisan'));
  });
}
