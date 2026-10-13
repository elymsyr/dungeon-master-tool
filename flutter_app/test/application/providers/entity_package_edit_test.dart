import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/services/pending_write_buffer.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// SRD kartını düzenlemek kartın kendisini değiştirir: aynı id, aynı kaynak,
/// kopya yok. Düzenleme dünyanın `package_entity_id`'li satırı olur; dünya
/// yeniden açılınca (başka cihazda da: sentez id'si deterministik) SRD
/// sentezi onu ezmez.
void main() {
  test('SRD kartı yerinde düzenlenir, yeniden açılışta düzenleme kalır',
      () async {
    final db = openTestDatabase();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    final worldId = await container
        .read(campaignRepositoryProvider)
        .create('W', template: generateBuiltinDnd5eV2Schema().schema);
    await container.read(activeCampaignProvider.notifier).load(worldId);
    List<Entity> arcana() => container
        .read(entityProvider)
        .values
        .where((e) => e.categorySlug == 'skill' && e.name.startsWith('Arcana'))
        .toList();
    final srd = arcana().single;
    expect(srd.linked, isTrue);

    container.read(entityProvider.notifier).update(srd.copyWith(name: 'Arcana X'));
    final edited = arcana().single;
    expect(edited.id, srd.id);
    expect(edited.name, 'Arcana X');
    expect(edited.source, srd.source);
    expect(edited.linked, isFalse);
    expect(edited.packageEntityId, srd.packageEntityId);

    await container.read(pendingWriteBufferProvider).flush();
    final row = await (db.select(db.worldEntities)
          ..where((t) => t.id.equals(srd.id)))
        .getSingle();
    expect(row.packageEntityId, srd.packageEntityId);
    expect(row.linked, isFalse);

    await container.read(activeCampaignProvider.notifier).reload();
    final back = arcana().single;
    expect(back.id, srd.id);
    expect(back.name, 'Arcana X');

    container.dispose();
    await db.close();
  });
}
