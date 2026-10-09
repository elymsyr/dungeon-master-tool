import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/services/pending_write_buffer.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// SRD kartını düzenlemek 'Homebrew' bir kopya forklar. Fork'tan hemen sonra
/// eski id'ye gelen gecikmeli düzenleme (kartın kapanışta flush'ı, sekme
/// henüz kopyaya dönmemişken yazılan) kopyanın ilk düzenlemesini ve
/// kaynağını ezmemeli.
void main() {
  test('eski id\'ye gelen gecikmeli düzenleme kopyaya eklenir', () async {
    final db = openTestDatabase();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    final worldId = await container
        .read(campaignRepositoryProvider)
        .create('W', template: generateBuiltinDnd5eV2Schema().schema);
    await container.read(activeCampaignProvider.notifier).load(worldId);
    final notifier = container.read(entityProvider.notifier);
    final srd = container.read(entityProvider).values.firstWhere(
        (e) => e.categorySlug == 'skill' && e.name == 'Arcana');
    expect(srd.linked, isTrue);

    notifier.update(srd.copyWith(name: 'Arcana X'));
    final fork = container.read(entityProvider).values
        .singleWhere((e) => e.name == 'Arcana X');
    expect(fork.source, 'Homebrew');
    expect(fork.linked, isFalse);

    // Eski kart orijinalin üstüne kurduğu ikinci düzenlemeyi gönderir.
    notifier.update(srd.copyWith(
      description: 'yeni',
      fields: {...srd.fields, 'summary': 'özet'},
    ));

    final copies = container.read(entityProvider).values
        .where((e) => e.categorySlug == 'skill' && !e.linked &&
            e.name.startsWith('Arcana'))
        .toList();
    expect(copies, hasLength(1));
    final after = copies.single;
    expect(after.id, fork.id);
    expect(after.name, 'Arcana X');
    expect(after.description, 'yeni');
    expect(after.fields['summary'], 'özet');
    expect(after.source, 'Homebrew');
    // Orijinal SRD kartı değişmedi.
    expect(container.read(entityProvider)[srd.id], srd);

    await container.read(pendingWriteBufferProvider).flush();
    container.dispose();
    await db.close();
  });
}
