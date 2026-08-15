import 'dart:io';

import 'package:dungeon_master_tool/application/providers/user_session_provider.dart';
import 'package:dungeon_master_tool/application/services/guest_promotion_service.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

/// **Audit phase O4 — sign-out, and the second account on one device.**
///
/// Everything here goes through [AppDatabase.forUser], the real open path, on
/// purpose. O3's roundtrip used `AppDatabase.forTesting`, which skips
/// `_openConnectionForUser` entirely — and that is exactly where the promotion
/// was being undone: the v12 fresh-cut renamed the freshly promoted database to
/// `dmt.sqlite.legacy.<ts>` and handed the account an empty one. A test that
/// opens the database the way the app opens it is the only kind that could have
/// caught it.
void main() {
  late Directory tmp;
  late GuestPromotionService promotion;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('o4_guest_switch');
    AppPaths.dataRoot = tmp.path;
    promotion = GuestPromotionService(dataRoot: tmp.path);
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {
      // Windows keeps a handle on a just-closed sqlite file now and then; the
      // temp directory is disposable either way.
    }
  });

  /// A guest who did some work and closed the app.
  Future<void> seedGuestWorld(String worldName) async {
    final file = File(p.join(tmp.path, 'db', 'dmt.sqlite'));
    await file.parent.create(recursive: true);
    final db = openTestDatabaseAt(file);
    await db
        .into(db.worlds)
        .insert(WorldsCompanion.insert(id: 'w1', worldName: worldName));
    await db.close();
  }

  Future<void> seedGuestMedia() async {
    final dir = Directory(p.join(tmp.path, 'worlds', 'w1'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'map.png')).writeAsString('not really a png');
  }

  /// The whole sign-up path, in the order `UserSessionNotifier.activate` runs
  /// it: copy with the guest database closed, open the account database, then
  /// rewrite and flip the sentinel.
  Future<GuestPromotionReport> promote(String userId) async {
    final report = await promotion.copyIntoAccount(userId);
    final db = AppDatabase.forUser(userId);
    await promotion.finalizePromotion(userId, db);
    await db.close();
    return report;
  }

  Future<List<World>> worldsOf(String? userId) async {
    final db = AppDatabase.forUser(userId);
    final rows = await db.select(db.worlds).get();
    await db.close();
    return rows;
  }

  List<String> namesIn(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return const [];
    return dir.listSync().map((e) => p.basename(e.path)).toList()..sort();
  }

  group('the database survives being opened', () {
    test('a database written in one session is still there in the next',
        () async {
      final first = AppDatabase.forUser('u1');
      await first
          .into(first.worlds)
          .insert(WorldsCompanion.insert(id: 'w1', worldName: 'Barrowmoor'));
      await first.close();

      // Before O4 this came back empty: the fresh v12 file had no
      // `.v12_cut_applied` beside it, so the second open read it as a pre-v12
      // database and renamed the session's work away.
      expect((await worldsOf('u1')).single.worldName, 'Barrowmoor');
      expect(
        namesIn(p.join(tmp.path, 'users', 'u1', 'db'))
            .where((n) => n.startsWith('dmt.sqlite.legacy.')),
        isEmpty,
      );
    });

    test('a promoted database survives the first real open', () async {
      await seedGuestWorld('Barrowmoor');
      final report = await promote('u1');

      expect(report.databaseCopied, isTrue);
      expect((await worldsOf('u1')).single.worldName, 'Barrowmoor');
      expect(
        namesIn(p.join(tmp.path, 'users', 'u1', 'db'))
            .where((n) => n.startsWith('dmt.sqlite.legacy.')),
        isEmpty,
        reason: 'the v12 cut must not fire on a promoted database',
      );
    });
  });

  group('the second account on one device', () {
    test('absorbs nothing the first account already took', () async {
      await seedGuestWorld('Barrowmoor');
      await seedGuestMedia();
      await promote('u1');

      expect(promotion.canPromote('u2'), isFalse);
      final second = await promotion.copyIntoAccount('u2');
      expect(second.outcome, GuestPromotionOutcome.guestAlreadyClaimed);
      expect(second.databaseCopied, isFalse);
      expect(second.mediaSubtreesCopied, isEmpty);

      // Not "no database was copied" — no world of the first account's is
      // readable from the second account at all.
      expect(await worldsOf('u2'), isEmpty);
      expect(Directory(p.join(tmp.path, 'users', 'u2', 'worlds')).existsSync(),
          isFalse);
    });

    test('cannot claim the tree by putting something back in it', () async {
      await seedGuestWorld('Barrowmoor');
      await promote('u1');

      // A signed-out session doing work in the emptied guest space does not
      // reopen the door: the claim, not the emptiness, is what closes it.
      await seedGuestMedia();
      expect(promotion.hasGuestData(), isTrue);
      expect(promotion.canPromote('u2'), isFalse);
      expect(
        (await promotion.copyIntoAccount('u2')).outcome,
        GuestPromotionOutcome.guestAlreadyClaimed,
      );
    });

    test('the claiming account is told it has already been through this',
        () async {
      await seedGuestWorld('Barrowmoor');
      await promote('u1');

      expect(promotion.isPromoted('u1'), isTrue);
      expect(promotion.canPromote('u1'), isFalse);
      expect(
        (await promotion.copyIntoAccount('u1')).outcome,
        GuestPromotionOutcome.alreadyPromoted,
      );
    });

    test('an unspent tree is still open to the next account', () async {
      // The account already had a database here, so the promotion took no
      // database — and an account that absorbed nothing does not get to spend
      // the scratch space.
      final existing = File(p.join(tmp.path, 'users', 'u1', 'db', 'dmt.sqlite'));
      await existing.parent.create(recursive: true);
      await existing.writeAsString('pre-existing');
      await seedGuestWorld('Barrowmoor');

      final report = await promotion.copyIntoAccount('u1');
      expect(report.outcome, GuestPromotionOutcome.accountAlreadyHasData);
      expect(report.databaseCopied, isFalse);
      expect(await existing.readAsString(), 'pre-existing');

      expect(promotion.readClaim(), isNull);
      expect(promotion.canPromote('u2'), isTrue);
    });
  });

  group('signing out lands in a clean workspace', () {
    test('the spent guest tree is archived, not deleted', () async {
      await seedGuestWorld('Barrowmoor');
      await seedGuestMedia();
      await promote('u1');

      expect(File(p.join(tmp.path, 'db', 'dmt.sqlite')).existsSync(), isFalse);
      expect(Directory(p.join(tmp.path, 'worlds')).existsSync(), isFalse);

      final archives = namesIn(p.join(tmp.path, GuestPromotionService.archiveDirName));
      expect(archives, hasLength(1));
      final archive = p.join(
          tmp.path, GuestPromotionService.archiveDirName, archives.single);

      // Still readable, still holding the guest's work.
      final archived = openTestDatabaseAt(File(p.join(archive, 'db', 'dmt.sqlite')));
      expect((await archived.select(archived.worlds).get()).single.worldName,
          'Barrowmoor');
      await archived.close();
      expect(File(p.join(archive, 'worlds', 'w1', 'map.png')).existsSync(),
          isTrue);
    });

    test('the signed-out session opens an empty database, not a stale one',
        () async {
      await seedGuestWorld('Barrowmoor');
      await promote('u1');

      // `deactivate()` → `AppPaths.setUser(null)` → this open.
      expect(await worldsOf(null), isEmpty);
      // And the account still has it.
      expect((await worldsOf('u1')).single.worldName, 'Barrowmoor');
    });

    test('retirement is idempotent and never overwrites an archive', () async {
      await seedGuestWorld('Barrowmoor');
      await seedGuestMedia();
      await promote('u1');

      final archiveRoot = p.join(tmp.path, GuestPromotionService.archiveDirName);
      final before = namesIn(archiveRoot);

      final again = await promotion.retireClaimedGuestTree();
      expect(again.movedAnything, isFalse);
      expect(again.claim, isNotNull);
      expect(namesIn(archiveRoot), before);
    });

    test('with no claim there is nothing to retire', () async {
      await seedGuestWorld('Barrowmoor');
      final report = await promotion.retireClaimedGuestTree();

      expect(report.claim, isNull);
      expect(report.movedAnything, isFalse);
      expect(File(p.join(tmp.path, 'db', 'dmt.sqlite')).existsSync(), isTrue);
    });
  });

  group('the claim itself', () {
    test('records who spent the tree and what they took', () async {
      await seedGuestWorld('Barrowmoor');
      await seedGuestMedia();
      await promote('u1');

      final claim = promotion.readClaim()!;
      expect(claim.claimedBy, 'u1');
      expect(claim.database, isTrue);
      expect(claim.media, contains('worlds'));
      expect(claim.claimedAt, isNotNull);
    });

    test('an unreadable claim still counts as a claim', () async {
      await File(p.join(tmp.path, GuestPromotionService.claimFileName))
          .writeAsString('{ this is not json');
      await seedGuestWorld('Barrowmoor');

      expect(promotion.readClaim(), isNotNull);
      expect(promotion.canPromote('u2'), isFalse);
      expect(
        (await promotion.copyIntoAccount('u2')).outcome,
        GuestPromotionOutcome.guestAlreadyClaimed,
      );
    });
  });

  group('the session notifier, end to end', () {
    // The wiring, not just the service: `activate` must promote before it
    // switches the paths, and `deactivate` must retire before the guest
    // database is reopened under the signed-out session.
    Future<List<World>> worldsInContainer(ProviderContainer c) async {
      final db = c.read(appDatabaseProvider);
      return db.select(db.worlds).get();
    }

    test('signing in promotes, signing out lands in an empty workspace',
        () async {
      await AppPaths.setUser(null);
      await seedGuestWorld('Barrowmoor');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = container.read(userSessionProvider.notifier);

      await session.activate('u1');
      expect((await worldsInContainer(container)).single.worldName,
          'Barrowmoor');
      expect(promotion.isPromoted('u1'), isTrue);
      expect(promotion.readClaim()!.claimedBy, 'u1');

      await session.deactivate();
      expect(await worldsInContainer(container), isEmpty,
          reason: 'a signed-out session must not read the promoted tree');

      // And it is in the archive, not gone.
      final archive = namesIn(p.join(tmp.path, GuestPromotionService.archiveDirName));
      final archived = openTestDatabaseAt(File(p.join(
          tmp.path, GuestPromotionService.archiveDirName, archive.single,
          'db', 'dmt.sqlite')));
      expect((await archived.select(archived.worlds).get()).single.worldName,
          'Barrowmoor');
      await archived.close();
    });

    test('the next account to sign in on the device starts empty', () async {
      await AppPaths.setUser(null);
      await seedGuestWorld('Barrowmoor');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = container.read(userSessionProvider.notifier);

      await session.activate('u1');
      await session.deactivate();
      await session.activate('u2');

      expect(await worldsInContainer(container), isEmpty);
      expect(promotion.isPromoted('u2'), isFalse);
      expect(promotion.readClaim()!.claimedBy, 'u1');
    });
  });
}
