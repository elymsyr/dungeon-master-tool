import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/guest_promotion_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

/// **Audit phase O3.** The roundtrip the roadmap asks for: a guest builds a
/// world, a character and a package, signs up, and finds all of it under the
/// new user id — with the guest tree still sitting there untouched, because the
/// failure mode this phase exists to prevent is a move that half-succeeds.
///
/// The cloud half is deliberately absent. Once the rows are under
/// `users/{id}/` they are ordinary local rows, and `BetaEnterMergeService`'s
/// existing first-enter local-wins merge is what queues them into the sync
/// outbox; it needs a `SupabaseClient`, so it cannot run here, and duplicating
/// it would be the second merge O3 was told not to write.

const _userId = 'user-1';

void main() {
  late Directory root;
  late GuestPromotionService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dmt_guest_promotion');
    service = GuestPromotionService(dataRoot: root.path);
  });

  tearDown(() async {
    if (root.existsSync()) {
      try {
        await root.delete(recursive: true);
      } on FileSystemException {
        // Windows keeps a handle on a just-closed sqlite file for a moment.
      }
    }
  });

  String guestWorldsDir() => p.join(root.path, 'worlds');
  String accountWorldsDir() =>
      p.join(root.path, 'users', _userId, 'worlds');
  File guestDb() => File(p.join(root.path, 'db', 'dmt.sqlite'));
  File accountDb() =>
      File(p.join(root.path, 'users', _userId, 'db', 'dmt.sqlite'));

  /// Everything a guest can accumulate: a world with an entity that carries an
  /// absolute media path (both as a column and inside a JSON blob), a
  /// character, and an installed package.
  Future<void> seedGuestDatabase() async {
    await Directory(p.dirname(guestDb().path)).create(recursive: true);
    final db = openTestDatabaseAt(guestDb());
    await db.into(db.worlds).insert(
          WorldsCompanion.insert(id: 'w1', worldName: 'Barrowmoor'),
        );
    await db.into(db.worldEntities).insert(
          WorldEntitiesCompanion.insert(
            id: 'e1',
            worldId: 'w1',
            categorySlug: 'npc',
            name: 'Ilse the Cartwright',
            imagePath: Value(
              p.join(guestWorldsDir(), 'Barrowmoor', 'media', 'ilse.png'),
            ),
            fieldsJson: Value(jsonEncode({
              'portrait':
                  p.join(guestWorldsDir(), 'Barrowmoor', 'media', 'ilse.png'),
              'token': 'dmt-asset://sha256/abc',
            })),
          ),
        );
    await db.into(db.worldCharacters).insert(
          WorldCharactersCompanion.insert(
            id: 'c1',
            worldId: 'w1',
            templateId: 'dnd5e',
            templateName: 'D&D 5e',
          ),
        );
    await db.into(db.packages).insert(
          PackagesCompanion.insert(id: 'pk1', name: 'SRD 5.2.1'),
        );
    await db.close();
  }

  Future<void> seedGuestMedia() async {
    for (final subtree in GuestPromotionService.mediaSubtrees) {
      final dir = Directory(p.join(root.path, subtree, 'Barrowmoor', 'media'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'ilse.png')).writeAsString(subtree);
    }
  }

  Future<T> withAccountDatabase<T>(
    Future<T> Function(AppDatabase db) body,
  ) async {
    final db = openTestDatabaseAt(accountDb());
    try {
      return await body(db);
    } finally {
      await db.close();
    }
  }

  Future<GuestPromotionReport> promote() async {
    final report = await service.copyIntoAccount(_userId);
    await withAccountDatabase((db) => service.finalizePromotion(_userId, db));
    return report;
  }

  group('the roundtrip', () {
    test('every guest row is present under the new user id', () async {
      await seedGuestDatabase();
      await seedGuestMedia();

      final report = await promote();
      expect(report.outcome, GuestPromotionOutcome.promoted);
      expect(report.databaseCopied, isTrue);

      await withAccountDatabase((db) async {
        expect((await db.select(db.worlds).get()).map((w) => w.worldName),
            ['Barrowmoor']);
        expect((await db.select(db.worldEntities).get()).map((e) => e.name),
            ['Ilse the Cartwright']);
        expect((await db.select(db.worldCharacters).get()).length, 1);
        expect(
            (await db.select(db.packages).get()).map((x) => x.name),
            ['SRD 5.2.1']);
      });
    });

    test('the media subtrees ride along — characters/ included, which the old '
        'migration silently skipped', () async {
      await seedGuestDatabase();
      await seedGuestMedia();

      final report = await promote();
      expect(report.mediaSubtreesCopied,
          containsAll(GuestPromotionService.mediaSubtrees));
      for (final subtree in GuestPromotionService.mediaSubtrees) {
        final copied = File(p.join(
            root.path, 'users', _userId, subtree, 'Barrowmoor', 'media',
            'ilse.png'));
        expect(copied.existsSync(), isTrue, reason: subtree);
        expect(await copied.readAsString(), subtree);
      }
    });

    test('absolute guest media paths are rewritten to the account tree, in '
        'columns and inside JSON blobs alike', () async {
      await seedGuestDatabase();
      await seedGuestMedia();

      final report = await service.copyIntoAccount(_userId);
      expect(report.outcome, GuestPromotionOutcome.promoted);
      final rewritten = await withAccountDatabase(
          (db) => service.finalizePromotion(_userId, db));
      // Exactly the two values that carry a path: the `image_path` column and
      // the `portrait` key inside `fields_json`. The count is the same on
      // POSIX and on Windows, where the blob's doubled backslashes are a
      // third spelling of the same prefix.
      expect(rewritten, 2);

      await withAccountDatabase((db) async {
        final entity = (await db.select(db.worldEntities).get()).single;
        expect(entity.imagePath, startsWith(accountWorldsDir()));
        expect(entity.imagePath, contains('ilse.png'));
        final fields =
            jsonDecode(entity.fieldsJson) as Map<String, dynamic>;
        expect(fields['portrait'] as String, startsWith(accountWorldsDir()));
        // Scheme URIs are location-independent and must survive untouched —
        // this is why `asset_refs` needs no special case.
        expect(fields['token'], 'dmt-asset://sha256/abc');
      });
    });

    test('the rewrite is idempotent and never nests the account root inside '
        'itself', () async {
      await seedGuestDatabase();
      await promote();

      final second = await withAccountDatabase(
          (db) => service.rewriteGuestPaths(db, _userId));
      expect(second, 0);

      await withAccountDatabase((db) async {
        final entity = (await db.select(db.worldEntities).get()).single;
        expect(entity.imagePath,
            isNot(contains(p.join('users', _userId, 'users'))));
      });
    });
  });

  group('nothing is lost', () {
    test('the guest database is byte-for-byte unchanged by a promotion',
        () async {
      await seedGuestDatabase();
      final before = await guestDb().readAsBytes();

      await promote();

      expect(guestDb().existsSync(), isTrue);
      expect(await guestDb().readAsBytes(), before);
    });

    test('the guest database still opens and still holds its own paths after '
        'the promotion', () async {
      await seedGuestDatabase();
      await promote();

      final db = openTestDatabaseAt(guestDb());
      final entity = (await db.select(db.worldEntities).get()).single;
      expect(entity.imagePath, startsWith(guestWorldsDir()));
      expect(entity.imagePath, isNot(contains('users')));
      await db.close();
    });

    test('an interrupted promotion leaves no completion marker, and the next '
        'attempt finishes it', () async {
      await seedGuestDatabase();

      // Copy, then "crash" before finalize.
      await service.copyIntoAccount(_userId);
      expect(service.isPromoted(_userId), isFalse);
      expect(
          File(p.join(root.path, 'users', _userId, '.promotion_in_progress'))
              .existsSync(),
          isTrue);
      final guestBytes = await guestDb().readAsBytes();

      // Second attempt: the pending marker says the account database is our
      // own half-finished copy, not a foreign account's data.
      final resumed = await service.copyIntoAccount(_userId);
      expect(resumed.outcome, GuestPromotionOutcome.promoted);
      await withAccountDatabase((db) => service.finalizePromotion(_userId, db));

      expect(service.isPromoted(_userId), isTrue);
      expect(
          File(p.join(root.path, 'users', _userId, '.promotion_in_progress'))
              .existsSync(),
          isFalse);
      expect(await guestDb().readAsBytes(), guestBytes);
      await withAccountDatabase((db) async {
        expect((await db.select(db.worlds).get()).length, 1);
      });
    });
  });

  group('which merge this is', () {
    test('a second promotion of the same account is a no-op', () async {
      await seedGuestDatabase();
      await seedGuestMedia();
      await promote();

      final again = await service.copyIntoAccount(_userId);
      expect(again.outcome, GuestPromotionOutcome.alreadyPromoted);
      expect(again.databaseCopied, isFalse);
      expect(again.mediaSubtreesCopied, isEmpty);

      final rewritten = await withAccountDatabase(
          (db) => service.finalizePromotion(_userId, db));
      expect(rewritten, 0);

      await withAccountDatabase((db) async {
        expect((await db.select(db.worlds).get()).length, 1);
        expect((await db.select(db.worldEntities).get()).length, 1);
      });
    });

    test('signing into an account that already has a database here does not '
        'overwrite it with the guest database', () async {
      await seedGuestDatabase();

      // The account already lives on this device — a different merge.
      await Directory(p.dirname(accountDb().path)).create(recursive: true);
      await withAccountDatabase((db) async {
        await db.into(db.worlds).insert(
              WorldsCompanion.insert(id: 'w-own', worldName: 'Their Own World'),
            );
      });

      final report = await service.copyIntoAccount(_userId);
      expect(report.outcome, GuestPromotionOutcome.accountAlreadyHasData);
      expect(report.databaseCopied, isFalse);

      await withAccountDatabase((db) async {
        expect((await db.select(db.worlds).get()).map((w) => w.id), ['w-own']);
      });
      // And the guest work is still there to be recovered.
      expect(guestDb().existsSync(), isTrue);
    });

    test('a device that was never used offline has nothing to promote',
        () async {
      final report = await service.copyIntoAccount(_userId);
      expect(report.outcome, GuestPromotionOutcome.nothingToPromote);
      expect(service.isPromoted(_userId), isFalse);
      expect(accountDb().existsSync(), isFalse);
    });

    test('guest media without a guest database still promotes', () async {
      await seedGuestMedia();
      final report = await service.copyIntoAccount(_userId);
      expect(report.outcome, GuestPromotionOutcome.promoted);
      expect(report.databaseCopied, isFalse);
      expect(report.mediaSubtreesCopied,
          containsAll(GuestPromotionService.mediaSubtrees));
    });
  });
}
