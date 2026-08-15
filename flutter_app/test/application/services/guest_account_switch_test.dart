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
///
/// **O6 narrowed the claim to the generation it was written over.** O4's claim
/// lived at the guest root forever, which made "one account may spend this
/// content" mean "this device may hand over once, ever" — sign out, build a
/// world offline, sign back in, and nothing happened. Retirement now drops the
/// claim together with the content it archives, so the cases below assert the
/// same protection over a *live* tree and the reopened door over an emptied
/// one. Nothing here got weaker: the second account still never sees the first
/// account's worlds, because those worlds are in the archive rather than merely
/// behind a flag.
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

  /// The same path, when the test needs to see what phase 2 did.
  Future<GuestFinalizeReport> promoteAndReport(String userId) async {
    await promotion.copyIntoAccount(userId);
    final db = AppDatabase.forUser(userId);
    final report = await promotion.finalizePromotion(userId, db);
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

      // The strongest form of "absorbs nothing": there is nothing here to
      // absorb. O4 stopped the second account with a flag over content that was
      // still lying around; the retirement it introduced took the content away,
      // and O6 stopped pretending the flag was the part doing the work.
      expect(promotion.canPromote('u2'), isFalse);
      final second = await promotion.copyIntoAccount('u2');
      expect(second.outcome, GuestPromotionOutcome.nothingToPromote);
      expect(second.databaseCopied, isFalse);
      expect(second.mediaSubtreesCopied, isEmpty);

      // Not "no database was copied" — no world of the first account's is
      // readable from the second account at all.
      expect(await worldsOf('u2'), isEmpty);
      expect(Directory(p.join(tmp.path, 'users', 'u2', 'worlds')).existsSync(),
          isFalse);
    });

    test('gets what was made after the first account left, and nothing else',
        () async {
      await seedGuestWorld('Barrowmoor');
      await promote('u1');

      // **O6.** Work done in the emptied guest space belongs to whoever signs
      // in next — it is theirs, made after the previous tree was archived, and
      // O4's claim outliving that tree is precisely the bug that made the
      // handover a once-per-device event. What the second account must not get
      // is the *first* account's work, and it does not: that is in the archive.
      await seedGuestMedia();
      expect(promotion.hasGuestData(), isTrue);
      expect(promotion.canPromote('u2'), isTrue);

      final second = await promoteAndReport('u2');
      expect(second.absorbedAnything, isTrue);
      expect(File(p.join(tmp.path, 'users', 'u2', 'worlds', 'w1', 'map.png'))
          .existsSync(), isTrue);
      expect(await worldsOf('u2'), isEmpty,
          reason: "the first account's world is archived, not on offer");
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
      // The account already had a database here, so the copy phase takes no
      // database — the rows are merged in phase 2 instead, and until that has
      // run nothing has been absorbed and nothing may be claimed.
      final existing = File(p.join(tmp.path, 'users', 'u1', 'db', 'dmt.sqlite'));
      await existing.parent.create(recursive: true);
      await existing.writeAsString('pre-existing');
      await seedGuestWorld('Barrowmoor');

      final report = await promotion.copyIntoAccount('u1');
      expect(report.outcome, GuestPromotionOutcome.mergedIntoAccountDatabase);
      expect(report.databaseCopied, isFalse);
      expect(report.databaseMergePending, isTrue);
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
      // **O6.** Nothing to move because nothing is left to claim: the first
      // pass archived the content and dropped the claim with it.
      expect(again.claim, isNull);
      expect(promotion.readClaim(), isNull);
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
      final report = await promoteAndReport('u1');

      // Read from the retirement it drove: under O6 the claim is deleted the
      // moment the content it names reaches the archive, so the file is gone by
      // the time the caller gets here. What it said is what is asserted.
      final claim = report.retirement!.claim!;
      expect(claim.claimedBy, 'u1');
      expect(claim.database, isTrue);
      expect(claim.media, contains('worlds'));
      expect(claim.claimedAt, isNotNull);
      expect(claim.generation, isNotNull);
      expect(report.retirement!.claimCleared, isTrue);
      expect(promotion.readClaim(), isNull);
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
      // The claim did its job and went with the content it named.
      expect(promotion.readClaim(), isNull);

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
      expect(promotion.readClaim(), isNull);
    });
  });
}
