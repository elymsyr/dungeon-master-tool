import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Dünya silinince karakter kilitlenmemeli — yalnız dünya bağı kopmalı.
/// `ActiveCampaignNotifier.delete` bunu `orphanForWorld` ile yapıyordu ama
/// ona **kampanya adını** geçiyordu; fonksiyon `worldId` ile karşılaştırdığı
/// için hiçbir karakter eşleşmiyor, satırda ölü bir `world_id` kalıyordu
/// (docs/KNOWN_ISSUES.md — "Deleting a world bricks its characters").
Future<void> pumpUntil(bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('deleting a world clears its characters world link', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final repo = container.read(campaignRepositoryProvider);
    // NB: `create` returns the world *name*, not its id — the same trap that
    // produced the bug this test guards.
    await repo.create('Doomed World',
        template: generateBuiltinDnd5eV2Schema().schema);
    final worldId =
        (await repo.load('Doomed World'))['world_id'] as String;

    final now = DateTime.now().toUtc().toIso8601String();
    await container.read(characterRepositoryProvider).save(Character(
          id: 'c1',
          templateId: 'dnd5e-v2',
          templateName: 'D&D 5e',
          entity: const Entity(id: 'c1', categorySlug: 'player-character', name: 'Pip'),
          worldId: worldId,
          createdAt: now,
          updatedAt: now,
        ));
    final chars = container.read(characterListProvider.notifier);
    await pumpUntil(() => chars.state.hasValue);
    expect(chars.state.value!.single.worldId, worldId);

    await container.read(activeCampaignProvider.notifier).delete('Doomed World');

    expect(chars.state.value!.single.worldId, isNull);
    final reloaded =
        await container.read(characterRepositoryProvider).loadAll();
    expect(reloaded.single.worldId, isNull);
  });
}
