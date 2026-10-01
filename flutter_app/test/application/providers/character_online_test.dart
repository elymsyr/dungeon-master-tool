// Faz 5g — karakterin kendi anahtarı ve buluttan gelen silme. Pompa sahte
// PostgREST'e karşı gerçekten koşuyor; medya yolu kapalı.
//
//   flutter test test/application/providers/character_online_test.dart
//
// Kapsam:
//   1. Bulut satırı reddederse (kişi başı online karakter sınırı, 055) anahtar
//      geri alınır — kalsaydı karakter online görünür ama hiç gitmezdi.
//   2. Paylaşım yayınından gelen silme tombstone bırakmaz: bıraksaydı bir
//      sonraki tur aynı id'ye DELETE gönderirdi.

import 'package:dungeon_master_tool/application/providers/auth_provider.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/application/providers/cloud_push_provider.dart';
import 'package:dungeon_master_tool/application/providers/connectivity_provider.dart';
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/application/services/world_media_sync.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_postgrest.dart';
import '../../support/test_database.dart';

const _uid = '11111111-1111-1111-1111-111111111111';

class _SignedIn extends AuthNotifier {
  _SignedIn(super.ref) {
    state = const AuthState(uid: _uid, email: 'u@example.invalid');
  }
}

void main() {
  late AppDatabase db;
  late FakePostgrest cloud;
  late ProviderContainer container;
  late CharacterListNotifier chars;

  setUp(() async {
    db = openTestDatabase();
    await db.customSelect('SELECT 1').get();
    cloud = await FakePostgrest.start(uid: _uid);
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authProvider.overrideWith((ref) => _SignedIn(ref)),
      cloudPushServiceProvider
          .overrideWithValue(CloudPushService(db: db, client: cloud.client)),
      worldMediaSyncProvider.overrideWithValue(null),
      connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
    ]);
    final now = DateTime.now().toUtc().toIso8601String();
    await container.read(characterRepositoryProvider).save(Character(
          id: 'c1',
          templateId: 'dnd5e-v2',
          templateName: 'D&D 5e',
          entity: const Entity(
              id: 'c1', categorySlug: 'player-character', name: 'Kael'),
          ownerId: _uid,
          createdAt: now,
          updatedAt: now,
        ));
    chars = container.read(characterListProvider.notifier);
    for (var i = 0; i < 200 && !chars.state.hasValue; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  tearDown(() async {
    container.dispose();
    await cloud.close();
    await db.close();
  });

  test('bulut reddederse anahtar geri alınır', () async {
    cloud.replies.add(() => (
          400,
          {
            'code': '23514',
            'message': 'online character limit reached (10/10)',
          }
        ));

    expect(await chars.setOnline('c1', true), isFalse);
    expect(cloud.requests, ['POST /rest/v1/world_characters']);
    expect((await db.worldCharactersDao.getById('c1'))!.isOnline, isFalse);
  });

  test('buluttan gelen silme tombstone bırakmaz', () async {
    await db.worldCharactersDao.markOnline(['c1']);

    await chars.removeMirror('c1');

    expect(await db.worldCharactersDao.getById('c1'), isNull);
    expect(await db.customSelect('SELECT * FROM sync_tombstones').get(),
        isEmpty);
    expect(await db.trashDao.existsBySource('character', 'c1'), isTrue,
        reason: 'çöpten geri alınabilir');
  });
}
