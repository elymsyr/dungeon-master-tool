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
/// new user id — with the guest tree still intact byte for byte, because the
/// failure mode this phase exists to prevent is a move that half-succeeds.
///
/// **O4 moved where "intact" lives.** A promotion that *finishes* now claims
/// the guest tree and parks it under `guest_archive/<ts>/`, so that the next
/// signed-out session opens a clean workspace instead of a stale duplicate of
/// somebody's account. Nothing here got weaker: the three cases below still
/// compare the same bytes and still open the same database, they just look for
/// it where the policy now keeps it. What O3 forbade — losing the guest copy
/// while the account copy is still in flight — is untouched, because the move
/// happens strictly after the completion marker exists.
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

  /// Where O4's retirement parks the guest database once it has been spent.
  File archivedGuestDb() {
    final archives =
        Directory(p.join(root.path, GuestPromotionService.archiveDirName));
    final stamped = archives.listSync().whereType<Directory>().toList();
    expect(stamped, hasLength(1), reason: 'exactly one retirement per device');
    return File(p.join(stamped.single.path, 'db', 'dmt.sqlite'));
  }

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
      expect(rewritten.pathsRewritten, 2);

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

      // O4: the same bytes, in the archive the claim moved them to.
      expect(guestDb().existsSync(), isFalse);
      expect(archivedGuestDb().existsSync(), isTrue);
      expect(await archivedGuestDb().readAsBytes(), before);
    });

    test('the guest database still opens and still holds its own paths after '
        'the promotion', () async {
      await seedGuestDatabase();
      await promote();

      final db = openTestDatabaseAt(archivedGuestDb());
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
      expect(await archivedGuestDb().readAsBytes(), guestBytes);
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

      final finalized = await withAccountDatabase(
          (db) => service.finalizePromotion(_userId, db));
      expect(finalized.pathsRewritten, 0);
      expect(finalized.absorbedAnything, isFalse);

      await withAccountDatabase((db) async {
        expect((await db.select(db.worlds).get()).length, 1);
        expect((await db.select(db.worldEntities).get()).length, 1);
      });
    });

    test('an account that already has a database here keeps it — and gets the '
        'guest rows merged into it', () async {
      // **O5, the bug this group used to enshrine.** Signing in once creates
      // and seeds this file, so "the account already has a database" is the
      // normal state of a returning user, and refusing the whole-file copy used
      // to mean the guest\'s world was simply dropped. It is still not
      // overwritten; the rows come in through it.
      await seedGuestDatabase();
      await Directory(p.dirname(accountDb().path)).create(recursive: true);
      await withAccountDatabase((db) async {
        await db.into(db.worlds).insert(
              WorldsCompanion.insert(id: 'w-own', worldName: 'Their Own World'),
            );
      });

      final report = await service.copyIntoAccount(_userId);
      expect(report.outcome, GuestPromotionOutcome.mergedIntoAccountDatabase);
      expect(report.databaseCopied, isFalse);
      expect(report.databaseMergePending, isTrue);

      final finalized = await withAccountDatabase(
          (db) => service.finalizePromotion(_userId, db));
      expect(finalized.rowsMerged, greaterThan(0));
      expect(finalized.absorbedAnything, isTrue);

      await withAccountDatabase((db) async {
        final worlds = await db.select(db.worlds).get();
        expect(worlds.map((w) => w.id), containsAll(['w-own', 'w1']));
        expect((await db.select(db.worldCharacters).get()).single.id, 'c1');
        // The merged rows went through the path rewrite with everything else.
        final entity = (await db.select(db.worldEntities).get()).single;
        expect(entity.imagePath, startsWith(accountWorldsDir()));
      });

      // Absorbed means spent: the tree is claimed and parked in the archive.
      expect(service.isPromoted(_userId), isTrue);
      expect(guestDb().existsSync(), isFalse);
      expect(archivedGuestDb().existsSync(), isTrue);
    });

    test('a collision on the same primary key leaves the account\'s own row '
        'alone', () async {
      await seedGuestDatabase();
      await Directory(p.dirname(accountDb().path)).create(recursive: true);
      await withAccountDatabase((db) async {
        await db.into(db.worlds).insert(
              WorldsCompanion.insert(id: 'w1', worldName: 'Account Barrowmoor'),
            );
      });

      await service.copyIntoAccount(_userId);
      await withAccountDatabase((db) => service.finalizePromotion(_userId, db));

      await withAccountDatabase((db) async {
        final world = (await db.select(db.worlds).get()).single;
        expect(world.worldName, 'Account Barrowmoor');
      });
    });

    test('a completion marker that names nothing is not a promotion — the '
        'next sign-in retries', () async {
      // The shipped cut wrote this marker after every finalize, including the
      // one that absorbed nothing, and the account was then blocked forever.
      // Devices already carrying such a marker heal on the next sign-in.
      await seedGuestDatabase();
      final marker =
          File(p.join(root.path, 'users', _userId, '.promoted_from_guest'));
      await marker.parent.create(recursive: true);
      await marker.writeAsString(
          jsonEncode({'promotedAt': 'whenever', 'pathsRewritten': 0}));

      expect(service.isPromoted(_userId), isFalse);
      expect(service.canPromote(_userId), isTrue);

      await promote();
      await withAccountDatabase((db) async {
        expect((await db.select(db.worlds).get()).single.id, 'w1');
      });
      expect(service.isPromoted(_userId), isTrue);
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

  /// **Audit phase O6.** O4's claim was written at the guest root and never
  /// removed, which turned "this content has been spent" into "this device may
  /// hand over once, ever". The reporter hit it the moment the feature started
  /// working: promote, sign out, build a second world offline, sign back in —
  /// and nothing at all happened, because a claim stamped over a database that
  /// had since been archived and rebuilt was still lying there.
  group('a second life', () {
    File claimFile() =>
        File(p.join(root.path, GuestPromotionService.claimFileName));
    File generationFile() =>
        File(p.join(root.path, GuestPromotionService.generationFileName));

    /// A fresh guest workspace with one world in it, as a signed-out session
    /// leaves behind.
    Future<void> seedGuestWorld(String id, String name) async {
      await Directory(p.dirname(guestDb().path)).create(recursive: true);
      final db = openTestDatabaseAt(guestDb());
      await db
          .into(db.worlds)
          .insert(WorldsCompanion.insert(id: id, worldName: name));
      await db.close();
    }

    test('a guest workspace rebuilt after a handover can hand over again',
        () async {
      await seedGuestWorld('w1', 'Barrowmoor');
      await promote();
      expect(guestDb().existsSync(), isFalse, reason: 'first tree retired');

      // Signing out lands in an empty workspace; the user builds in it.
      await seedGuestWorld('w2', 'Second Barrow');

      expect(service.readClaim(), isNull,
          reason: 'the old claim described bytes that are in the archive now');
      expect(service.isPromoted(_userId), isFalse);
      expect(service.canPromote(_userId), isTrue);

      final report = await service.copyIntoAccount(_userId);
      expect(report.outcome, GuestPromotionOutcome.mergedIntoAccountDatabase);
      final finalized = await withAccountDatabase(
          (db) => service.finalizePromotion(_userId, db));
      expect(finalized.rowsMerged, greaterThan(0));

      await withAccountDatabase((db) async {
        final worlds = await db.select(db.worlds).get();
        expect(worlds.map((w) => w.id), containsAll(['w1', 'w2']));
      });
    });

    test('retirement drops the claim and the generation with the content',
        () async {
      await seedGuestWorld('w1', 'Barrowmoor');
      final before = service.currentGeneration();
      await promote();

      expect(claimFile().existsSync(), isFalse);
      expect(generationFile().existsSync(), isFalse);
      // The next ask mints a new one, which is what unblocks everything else.
      expect(service.currentGeneration(), isNot(before));
    });

    test('a claim over content that is still here still blocks', () async {
      await seedGuestWorld('w1', 'Barrowmoor');
      // Someone else spent this workspace and the archive move never ran.
      await claimFile().writeAsString(jsonEncode({
        'claimedBy': 'someone-else',
        'claimedAt': DateTime.now().toUtc().toIso8601String(),
        'generation': service.currentGeneration(),
        'database': true,
        'media': <String>[],
      }));

      expect(service.readClaim()?.claimedBy, 'someone-else');
      expect(service.canPromote(_userId), isFalse);
      final report = await service.copyIntoAccount(_userId);
      expect(report.outcome, GuestPromotionOutcome.guestAlreadyClaimed);
    });

    test('a pre-O6 claim does not block a workspace rebuilt after it',
        () async {
      // The exact state the reporter's device was stuck in: a claim written by
      // the shipped build (no generation), the database it named archived, and
      // a new guest database built in the empty workspace afterwards. Existence
      // alone cannot tell the two files apart, so the claim's own timestamp is
      // what settles it.
      await claimFile().writeAsString(jsonEncode({
        'claimedBy': 'someone-else',
        'claimedAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'database': true,
        'media': <String>[],
      }));
      await seedGuestWorld('w9', 'Rebuilt');

      expect(service.readClaim(), isNull);
      expect(service.canPromote(_userId), isTrue);
    });

    test('a pre-O6 claim over the database it actually named still blocks',
        () async {
      await seedGuestWorld('w1', 'Barrowmoor');
      await claimFile().writeAsString(jsonEncode({
        'claimedBy': 'someone-else',
        'claimedAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 1))
            .toIso8601String(),
        'database': true,
        'media': <String>[],
      }));

      expect(service.readClaim()?.claimedBy, 'someone-else');
      expect(service.canPromote(_userId), isFalse);
    });
  });

  /// **Audit phase O7.** The built-in SRD package is bootstrapped separately
  /// into every database with a *random* package id, while the rows inside it
  /// carry ids derived from `slug:name` and are therefore identical in both.
  /// `package_entities` keys on that id alone, so a plain `INSERT OR IGNORE`
  /// took the guest's package row (new id, no collision) and dropped every one
  /// of its entities (all colliding) - leaving the promoted world pointing at a
  /// package that existed and was empty. Reported as "the world came over but
  /// the built-in package content did not".
  group('packages that exist on both sides', () {
    /// One package plus one entity in it, in the given database.
    Future<void> seedPackage(
      File file, {
      required String packageId,
      required String name,
      required List<String> entityIds,
      String? worldId,
    }) async {
      await Directory(p.dirname(file.path)).create(recursive: true);
      final db = openTestDatabaseAt(file);
      await db.into(db.packages).insert(
            PackagesCompanion.insert(id: packageId, name: name),
          );
      for (final id in entityIds) {
        await db.into(db.packageEntities).insert(
              PackageEntitiesCompanion.insert(
                id: id,
                packageId: packageId,
                categorySlug: 'spell',
                name: id,
              ),
            );
      }
      if (worldId != null) {
        await db.into(db.worlds).insert(
              WorldsCompanion.insert(id: worldId, worldName: 'Barrowmoor'),
            );
        await db.into(db.installedPackages).insert(
              InstalledPackagesCompanion.insert(
                worldId: worldId,
                packageId: packageId,
              ),
            );
      }
      await db.close();
    }

    test('the promoted world points at a package that still has content',
        () async {
      // Same pack, two databases, two random ids - and the entity ids inside
      // are the same on both sides, exactly as `srdStableEntityId` makes them.
      await seedPackage(
        guestDb(),
        packageId: 'guest-srd',
        name: 'SRD 5.2.1 Core',
        entityIds: ['srd-fireball', 'srd-shield'],
        worldId: 'w1',
      );
      await seedPackage(
        accountDb(),
        packageId: 'account-srd',
        name: 'SRD 5.2.1 Core',
        entityIds: ['srd-fireball', 'srd-shield'],
      );

      final report = await service.copyIntoAccount(_userId);
      expect(report.outcome, GuestPromotionOutcome.mergedIntoAccountDatabase);
      await withAccountDatabase((db) => service.finalizePromotion(_userId, db));

      await withAccountDatabase((db) async {
        final packages = await db.select(db.packages).get();
        expect(packages.map((e) => e.id), ['account-srd'],
            reason: 'no empty duplicate of a package the account already has');

        final installed = await db.select(db.installedPackages).get();
        expect(installed, hasLength(1));
        expect(installed.single.worldId, 'w1');
        expect(installed.single.packageId, 'account-srd',
            reason: 'the world was re-pointed at the surviving package');

        final entities = await (db.select(db.packageEntities)
              ..where((t) => t.packageId.equals('account-srd')))
            .get();
        expect(entities.map((e) => e.id),
            containsAll(['srd-fireball', 'srd-shield']));
      });
    });

    test('a package the account does not have comes over whole', () async {
      await seedPackage(
        guestDb(),
        packageId: 'guest-homebrew',
        name: 'Barrowmoor Homebrew',
        entityIds: ['hb-1'],
        worldId: 'w1',
      );
      await seedPackage(
        accountDb(),
        packageId: 'account-srd',
        name: 'SRD 5.2.1 Core',
        entityIds: ['srd-fireball'],
      );

      await service.copyIntoAccount(_userId);
      await withAccountDatabase((db) => service.finalizePromotion(_userId, db));

      await withAccountDatabase((db) async {
        final entities = await (db.select(db.packageEntities)
              ..where((t) => t.packageId.equals('guest-homebrew')))
            .get();
        expect(entities.map((e) => e.id), ['hb-1']);
        final installed = await db.select(db.installedPackages).get();
        expect(installed.single.packageId, 'guest-homebrew');
      });
    });

    test('two different packages that merely share a name both survive',
        () async {
      // No shared entity id, so nothing would have been swallowed and there is
      // nothing to repair: collapsing these would be the data loss, not the fix.
      await seedPackage(
        guestDb(),
        packageId: 'guest-notes',
        name: 'Notes',
        entityIds: ['guest-note-1'],
        worldId: 'w1',
      );
      await seedPackage(
        accountDb(),
        packageId: 'account-notes',
        name: 'Notes',
        entityIds: ['account-note-1'],
      );

      await service.copyIntoAccount(_userId);
      await withAccountDatabase((db) => service.finalizePromotion(_userId, db));

      await withAccountDatabase((db) async {
        final packages = await db.select(db.packages).get();
        expect(packages.map((e) => e.id),
            containsAll(['guest-notes', 'account-notes']));
        final installed = await db.select(db.installedPackages).get();
        expect(installed.single.packageId, 'guest-notes');
      });
    });
  });
}
