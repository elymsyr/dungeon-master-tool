import 'package:dungeon_master_tool/application/providers/auth_provider.dart';
import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/character_ext.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Giriş yapmamış kullanıcı bir dünyanın karakterini sahiplendikten sonra
/// tekrar bırakabilmeli. `delete()`'in offline dalı `ownerId`'yi `null`'a
/// çekiyordu; guest için `null` zaten "benim" demek (`isOwnedBy`), yani
/// release hiçbir şey yapmamış gibi görünüyor ve karakter own-only char
/// tab'ında kilitli kalıyordu.
Future<void> pumpUntil(bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('guest can release a world-bound character', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    expect(container.read(authProvider), isNull, reason: 'test runs as guest');

    final repo = container.read(campaignRepositoryProvider);
    await repo.create('Keep on the Borderlands',
        template: generateBuiltinDnd5eV2Schema().schema);
    final worldId =
        (await repo.load('Keep on the Borderlands'))['world_id'] as String;

    final now = DateTime.now().toUtc().toIso8601String();
    await container.read(characterRepositoryProvider).save(Character(
          id: 'c1',
          templateId: 'dnd5e-v2',
          templateName: 'D&D 5e',
          entity: const Entity(
              id: 'c1', categorySlug: 'player-character', name: 'Pip'),
          worldId: worldId,
          createdAt: now,
          updatedAt: now,
        ));
    final chars = container.read(characterListProvider.notifier);
    await pumpUntil(() => chars.state.hasValue);
    // Guest claim = local ownership patch; `null` guest için "benim".
    expect(chars.state.value!.single.isOwnedBy(null), isTrue);

    await chars.delete('c1');

    final released = chars.state.value!.single;
    expect(released.isOwnedBy(null), isFalse, reason: 'release must stick');
    expect(released.worldId, worldId, reason: 'char stays in its world');
    expect(released.normalizedOwnerId, isNull, reason: 'cloud sees no owner');
  });
}
