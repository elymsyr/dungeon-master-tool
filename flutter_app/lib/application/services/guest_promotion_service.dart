import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../data/database/app_database.dart';

/// **Audit phase O3 — the guest → account handover.**
///
/// O1 made guest mode reachable, so a real amount of work now accumulates under
/// the global data root before anyone signs up: `dataRoot/db/dmt.sqlite` plus
/// the `worlds/` `packages/` `characters/` media subtrees. Signing up moves
/// every path to `dataRoot/users/{id}/`, and until this service existed the
/// handover copied the *media* and left the database behind — the one place
/// where, since the v12 fresh cut, all structured content lives.
///
/// Three rules, in the order they matter:
///
/// 1. **The guest tree is read-only here.** Every operation is a copy. An
///    interrupted promotion can therefore lose nothing: the source is still
///    exactly where it was, still openable, still the thing the app falls back
///    to. There is deliberately no move, no delete and no in-place rename of
///    anything under the guest root.
/// 2. **The database is copied closed.** SQLite runs in WAL mode here
///    (`app_database.dart` `beforeOpen`), so a copy taken while a connection is
///    live can capture a main file whose latest pages are still in the `-wal`.
///    The caller closes the connection first; the copy carries `-wal` and
///    `-shm` alongside the main file for the same reason.
/// 3. **Copy first, flip the sentinel last.** [copyIntoAccount] writes an
///    in-progress marker before it touches anything and the completion marker
///    only exists after [finalizePromotion] has run. A crash between the two
///    leaves an unfinished copy that the next attempt finishes, never a
///    half-state that reads as done.
///
/// What this service does *not* do is push anything to the cloud. Once the rows
/// sit under `users/{id}/`, they are ordinary local rows and
/// The rows stay local; nothing queues them
/// into the sync outbox — it runs from `startup_sync_gate`, i.e. after
/// `landing_screen` has awaited `UserSessionNotifier.activate`. O3 extends that
/// merge by giving it the rows; it does not write a second one.
///
/// ---
///
/// **Audit phase O4 — the policy the guest tree is under afterwards.**
///
/// O3 left an open question: the guest database is still sitting there, still
/// full, after an account has absorbed it. That makes it a scratch space
/// *anyone* can claim — the second account to sign in on the device would copy
/// the first account's work into itself — and it makes signing out a return to
/// a stale duplicate rather than to a clean workspace. The policy is:
///
/// **The guest tree is scratch space that exactly one account may claim, and
/// claiming it consumes it.**
///
/// - **Claimed once.** The account whose promotion *finishes* writes a claim
///   at the guest root ([claimFileName]) naming itself and what it took. No
///   other account ever promotes from that tree again
///   ([GuestPromotionOutcome.guestAlreadyClaimed]).
/// - **Consumed, not deleted.** The claim is followed by
///   [retireClaimedGuestTree], which *moves* the absorbed database and media
///   into `guest_archive/<ts>/` and keeps it 30 days, exactly as the v12 cut
///   keeps `dmt.sqlite.legacy.<ts>`. This is the one place O3's
///   never-move-anything rule is relaxed, and only because the completion
///   marker is proof the same bytes now exist twice: the rule protected a sole
///   copy, and after a finished promotion there is no sole copy left.
/// - **Sign-out lands in a fresh guest space, not in someone's leftovers.**
///   Because the retirement emptied the guest root, `AppPaths.setUser(null)`
///   opens a new, empty database. A shared device does not show the previous
///   account's worlds to whoever picks it up next, and the second account is
///   stopped by construction rather than only by the claim check.
///
/// Retirement is idempotent and is also run from `UserSessionNotifier`'s
/// `deactivate`, so a crash between the claim and the move heals on the next
/// sign-out or offline entry instead of leaving the tree half-retired forever.
///
/// Only what was actually absorbed is claimed and retired: a promotion that hit
/// [GuestPromotionOutcome.accountAlreadyHasData] took no database, so the guest
/// database stays unclaimed and openable.
///
/// ---
///
/// **Audit phase O6 - the guest workspace has more than one life.**
///
/// O4 wrote the claim at the guest *root* and nothing ever removed it, so the
/// policy it encoded quietly hardened from "this content is spent" into "this
/// device may hand over exactly once, ever". Sign out, build a world offline,
/// sign back in: [canPromote] was false because a claim from the previous
/// handover was still lying next to a database that had been rebuilt from
/// scratch since. Measured on the reporter's device - `.guest_claimed` stamped
/// 12:17Z, the guest database it supposedly describes recreated at 12:33Z with
/// new work in it, and every sign-in after that a no-op.
///
/// A claim is a statement about *those bytes*, and [retireClaimedGuestTree]
/// moves those bytes away. So the workspace carries a **generation** id
/// ([generationFileName]): the claim and the account's completion marker both
/// record the generation they were written under, retirement drops the id along
/// with the content it archives, and the next signed-out session mints a fresh
/// one - a generation under which no claim and no marker exists, so the
/// handover is available again. O4's actual guarantee is untouched: within one
/// generation the tree is still claimable exactly once, and the second account
/// on a device still cannot absorb the first one's work, because that work is
/// no longer there to absorb.
class GuestPromotionService {
  GuestPromotionService({required this.dataRoot});

  /// The global data root — which *is* the guest root (`AppPaths.dataRoot`).
  final String dataRoot;

  /// The media subtrees that live next to the database. `cache/` is
  /// deliberately absent: it is reproducible, and copying it would be the
  /// largest and least valuable part of the handover.
  static const mediaSubtrees = <String>['worlds', 'packages', 'characters'];

  static const _completedMarker = '.promoted_from_guest';
  static const _pendingMarker = '.promotion_in_progress';

  /// **O4.** Written at the *guest* root, not under an account: it records that
  /// this scratch space has been spent, and by whom.
  static const claimFileName = '.guest_claimed';

  /// Where a spent guest tree is parked. Same shape and the same 30-day
  /// retention as the v12 cut's `dmt.sqlite.legacy.<ts>`.
  static const archiveDirName = 'guest_archive';

  static const archiveRetention = Duration(days: 30);

  /// **O6.** Identifies the current incarnation of the guest workspace. Written
  /// at the guest root, deleted by [retireClaimedGuestTree] together with the
  /// content it archives.
  static const generationFileName = '.guest_generation';

  String accountRoot(String userId) => p.join(dataRoot, 'users', userId);

  File _completed(String userId) =>
      File(p.join(accountRoot(userId), _completedMarker));

  File _pending(String userId) =>
      File(p.join(accountRoot(userId), _pendingMarker));

  File _claim() => File(p.join(dataRoot, claimFileName));

  File _guestDatabase() => File(p.join(dataRoot, 'db', 'dmt.sqlite'));

  File _generation() => File(p.join(dataRoot, generationFileName));

  /// **O6.** The id of the workspace as it stands right now, minted on first
  /// ask. Minting on read rather than on write is what makes the repair
  /// automatic: a device whose guest tree was retired before this code existed
  /// simply has no id, gets a new one here, and every marker left over from the
  /// spent generation stops matching.
  String currentGeneration() {
    final file = _generation();
    try {
      if (file.existsSync()) {
        final value = file.readAsStringSync().trim();
        if (value.isNotEmpty) return value;
      }
      final minted = DateTime.now().microsecondsSinceEpoch.toString();
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(minted);
      return minted;
    } catch (_) {
      // An unwritable root must not break sign-in. A generation that cannot be
      // persisted is unique per call, which reads as "always a new one" -
      // permissive, and the claim check is not the last line of defence.
      return DateTime.now().microsecondsSinceEpoch.toString();
    }
  }

  File _accountDatabase(String userId) =>
      File(p.join(accountRoot(userId), 'db', 'dmt.sqlite'));

  /// Whether this account has already been through a promotion on this device.
  /// Cheap and synchronous on purpose — it is read on every sign-in.
  ///
  /// **O5 — a marker only counts when it names what it took.** The first cut
  /// wrote this file after *every* finalize, including the one that absorbed
  /// nothing because the account already had a database here. The account was
  /// then marked done forever and the guest work could never be handed over,
  /// on this device, by any later attempt. Markers written by that cut carry no
  /// `absorbed` key, so they are read as "never actually promoted" and the next
  /// sign-in retries — which is what repairs a device already in that state.
  /// **O6 - and only for the guest generation it was written under.** The
  /// account being done with *that* workspace says nothing about the one the
  /// user has built since; a marker from a retired generation is history, not a
  /// gate.
  bool isPromoted(String userId) {
    final file = _completed(userId);
    if (!file.existsSync()) return false;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (!json.containsKey('absorbed')) return false;
      final generation = json['generation'] as String?;
      if (generation == null || generation == currentGeneration()) return true;
      // A marker from a spent generation is history rather than a gate - but
      // only once something has actually replaced that workspace. With nothing
      // in it there is no handover to re-open, and the honest answer to "has
      // this account been through a promotion here" is still yes.
      return !hasGuestData();
    } catch (_) {
      return true;
    }
  }

  /// **O4.** The claim on the guest tree, or null while it is still unspent.
  /// Synchronous and tolerant: an unreadable or malformed claim file still
  /// counts as a claim, because the safe reading of "something went wrong here"
  /// is *do not hand this tree to anyone*.
  /// **O6 - and only over the generation it was written for.** A claim whose
  /// generation is gone describes content that has been archived, so it claims
  /// nothing that is here now. A claim from before O6 carries no generation at
  /// all; that one is honoured only while the content it names is still there
  /// *and older than the claim* — on the reporter's device the claim was
  /// stamped at 12:17Z and the guest database sitting next to it had been
  /// rebuilt at 12:33Z, so mere existence cannot tell the archived file from
  /// its replacement and the timestamp is what settles it.
  GuestClaim? readClaim() {
    final file = _claim();
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final claim = GuestClaim(
        claimedBy: json['claimedBy'] as String?,
        claimedAt: DateTime.tryParse(json['claimedAt'] as String? ?? ''),
        database: json['database'] as bool? ?? false,
        media: (json['media'] as List?)?.cast<String>() ?? const [],
        generation: json['generation'] as String?,
      );
      if (claim.generation != null) {
        return claim.generation == currentGeneration() ? claim : null;
      }
      return _legacyClaimCovers(claim) ? claim : null;
    } catch (_) {
      return const GuestClaim();
    }
  }

  /// Whether anything a claim says it absorbed is still sitting in the guest
  /// root. False once [retireClaimedGuestTree] has done its work — which is
  /// what tells retirement that it may drop the claim.
  bool _claimedContentStillInPlace(GuestClaim claim) {
    if (claim.database && _guestDatabase().existsSync()) return true;
    for (final name in claim.media) {
      if (!mediaSubtrees.contains(name)) continue;
      final dir = Directory(p.join(dataRoot, name));
      if (dir.existsSync() && dir.listSync().isNotEmpty) return true;
    }
    return false;
  }

  /// Whether a pre-O6 claim, which carries no generation, still describes what
  /// is here: the content it named is in place and has not been written since
  /// the claim was made. Anything newer than the claim is by definition not the
  /// thing that was claimed.
  bool _legacyClaimCovers(GuestClaim claim) {
    final at = claim.claimedAt;
    bool covers(FileSystemEntity entity) {
      if (at == null) return true; // unreadable timestamp: stay conservative
      try {
        return !entity.statSync().modified.toUtc().isAfter(at);
      } catch (_) {
        return true;
      }
    }

    if (claim.database) {
      final db = _guestDatabase();
      if (db.existsSync() && covers(db)) return true;
    }
    for (final name in claim.media) {
      if (!mediaSubtrees.contains(name)) continue;
      final dir = Directory(p.join(dataRoot, name));
      if (!dir.existsSync() || dir.listSync().isEmpty) continue;
      if (dir.listSync(recursive: true).whereType<File>().any(covers)) {
        return true;
      }
    }
    return false;
  }

  /// The single predicate `UserSessionNotifier.activate` asks before it closes
  /// anything: is there a handover to do for this account at all.
  bool canPromote(String userId) =>
      !isPromoted(userId) && readClaim() == null && hasGuestData();

  /// Whether there is anything to hand over at all. False on a device that has
  /// never been used offline, which is the common case for a returning user.
  bool hasGuestData() {
    if (_guestDatabase().existsSync()) return true;
    for (final name in mediaSubtrees) {
      final dir = Directory(p.join(dataRoot, name));
      if (dir.existsSync() && dir.listSync().isNotEmpty) return true;
    }
    return false;
  }

  /// Phase 1 — copy the guest tree into the account.
  ///
  /// **The caller must have closed the database before calling this.**
  ///
  /// Returns without copying the database when the account already has one
  /// ([GuestPromotionOutcome.accountAlreadyHasData]): a user signing into an
  /// existing account on a device that also has guest data is a *different*
  /// problem from a guest signing up, and silently overwriting one with the
  /// other is precisely the data loss this phase exists to prevent. Their rows
  /// stay where they are and the cloud merge reconciles them; the guest tree is
  /// left untouched and still readable.
  Future<GuestPromotionReport> copyIntoAccount(String userId) async {
    if (isPromoted(userId)) {
      return const GuestPromotionReport(
        outcome: GuestPromotionOutcome.alreadyPromoted,
      );
    }
    // **O4 — the second account on one device.** Someone has already spent this
    // scratch space; what is left of it is *their* work, not a common pool.
    final claim = readClaim();
    if (claim != null) {
      return GuestPromotionReport(
        outcome: claim.claimedBy == userId
            ? GuestPromotionOutcome.alreadyPromoted
            : GuestPromotionOutcome.guestAlreadyClaimed,
      );
    }
    if (!hasGuestData()) {
      return const GuestPromotionReport(
        outcome: GuestPromotionOutcome.nothingToPromote,
      );
    }

    final root = Directory(accountRoot(userId));
    await root.create(recursive: true);

    // An unfinished earlier attempt: the copy completed but the rewrite did
    // not, so the account database is *ours*, not theirs, and re-copying is
    // safe. Without this flag the check below would read it as a foreign
    // account's data and stop.
    final resuming = _pending(userId).existsSync();
    await _pending(userId).writeAsString(jsonEncode({
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'from': dataRoot,
    }));

    var outcome = GuestPromotionOutcome.promoted;
    var databaseCopied = false;
    var databaseMergePending = false;
    final guestDb = _guestDatabase();
    final accountDb = _accountDatabase(userId);

    if (accountDb.existsSync() && !resuming) {
      // **O5 — the common case, not the edge case.** Signing in once creates
      // and seeds this file (SRD core bootstrap), so "the account already has a
      // database" is true for every returning user and the whole-file copy is
      // refused essentially always. Measured on the reporter's device: a guest
      // world sat in `db/dmt.sqlite` while the account opened with zero worlds.
      // The file still may not be overwritten — it is their data — so the rows
      // are merged into it instead, in [finalizePromotion], where it is open.
      outcome = GuestPromotionOutcome.mergedIntoAccountDatabase;
      databaseMergePending = guestDb.existsSync();
    } else if (guestDb.existsSync()) {
      await Directory(p.dirname(accountDb.path)).create(recursive: true);
      // Main file plus the WAL pair. `.incoming` first, rename after: a
      // `dmt.sqlite` at the destination therefore only ever exists complete.
      final staged = <File, File>{};
      for (final suffix in const ['', '-wal', '-shm']) {
        final src = File('${guestDb.path}$suffix');
        if (!src.existsSync()) continue;
        final dst = File('${accountDb.path}$suffix.incoming');
        if (dst.existsSync()) await dst.delete();
        await src.copy(dst.path);
        staged[dst] = File('${accountDb.path}$suffix');
      }
      for (final entry in staged.entries) {
        if (entry.value.existsSync()) await entry.value.delete();
        await entry.key.rename(entry.value.path);
      }
      databaseCopied = staged.isNotEmpty;

      // **O4 — the promotion's own undoing, found by opening it for real.**
      // `_openConnectionForUser` treats any `dmt.sqlite` in a directory with no
      // `.v12_cut_applied` next to it as a pre-v12 file and renames it to
      // `dmt.sqlite.legacy.<ts>` before Drift creates an empty one. A promoted
      // database arrives in exactly that state, so without this line the whole
      // handover was undone by the first real open: measured, the account came
      // up with zero worlds and the copy sat beside it under a legacy name.
      // The file being copied is a v12 database by construction, so the marker
      // is simply the truth.
      if (databaseCopied) {
        await File(p.join(p.dirname(accountDb.path), '.v12_cut_applied'))
            .writeAsString('promoted from guest');
      }
    }

    // Media. Never-clobber, but **per file** rather than per subtree: an
    // account that has used this device already has a non-empty `worlds/`, and
    // the old all-or-nothing skip dropped every guest map and portrait on the
    // floor for exactly the same reason the database copy was being refused.
    // Entries are keyed by world/character id, so a name that exists on both
    // sides is the same thing twice; the account's copy wins.
    final mediaCopied = <String>[];
    for (final name in mediaSubtrees) {
      final src = Directory(p.join(dataRoot, name));
      if (!src.existsSync() || src.listSync().isEmpty) continue;
      final dst = Directory(p.join(accountRoot(userId), name));
      if (await _copyDirectory(src, dst) > 0) mediaCopied.add(name);
    }

    // Rewrite the in-progress marker with what was actually taken. O4's claim
    // is written by [finalizePromotion], which does not see this report, and
    // recording it here means a resumed promotion claims the same things a
    // straight-through one would.
    await _pending(userId).writeAsString(jsonEncode({
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'from': dataRoot,
      'database': databaseCopied,
      'merge': databaseMergePending,
      'media': mediaCopied,
    }));

    return GuestPromotionReport(
      outcome: outcome,
      databaseCopied: databaseCopied,
      databaseMergePending: databaseMergePending,
      mediaSubtreesCopied: mediaCopied,
    );
  }

  /// Phase 2 — rewrite guest-absolute media paths inside the copied database,
  /// then flip the sentinel.
  ///
  /// [db] must be the account's database, already open. The rewrite has to
  /// happen through it rather than a raw sqlite handle because `package:sqlite3`
  /// is a dev-only dependency here.
  Future<GuestFinalizeReport> finalizePromotion(
      String userId, AppDatabase db) async {
    if (isPromoted(userId)) return const GuestFinalizeReport();
    final pending = _readPending(userId);

    // **O5.** The account's own database could not be overwritten, so the guest
    // rows come in through it instead. Before the path rewrite, so the merged
    // rows are rewritten in the same pass.
    var rowsMerged = 0;
    if (pending?.merge ?? false) {
      rowsMerged = await mergeGuestRows(db);
    }

    // **O8.** Whatever arrived, arrived ownerless - see [claimGuestCharacters].
    final charactersClaimed = (pending?.database ?? false) || rowsMerged > 0
        ? await claimGuestCharacters(
            db,
            userId,
            wholeDatabase: pending?.database ?? false,
          )
        : 0;

    final rewritten = await rewriteGuestPaths(db, userId);
    final tookDatabase = (pending?.database ?? false) || rowsMerged > 0;
    final tookMedia = pending?.media ?? const <String>[];
    final absorbedAnything = tookDatabase || tookMedia.isNotEmpty;

    // A finalize that absorbed nothing is not a promotion and must not be
    // recorded as one — see [isPromoted]. The pending marker is cleared either
    // way: whatever it described has been dealt with.
    if (absorbedAnything) {
      await _completed(userId).writeAsString(jsonEncode({
        'promotedAt': DateTime.now().toUtc().toIso8601String(),
        'generation': currentGeneration(),
        'pathsRewritten': rewritten,
        'absorbed': {
          'database': tookDatabase,
          'rowsMerged': rowsMerged,
          'media': tookMedia,
        },
      }));
    }

    // **O4 — claim before retire, and only for what was taken.** The claim is
    // one small write and it is what stops the next account; the move that
    // follows is the slower, more fallible half, and it is idempotent. An
    // account that got [GuestPromotionOutcome.accountAlreadyHasData] absorbed
    // no database, so it does not get to spend the tree.
    if (absorbedAnything && readClaim() == null) {
      await _claim().writeAsString(jsonEncode({
        'claimedBy': userId,
        'claimedAt': DateTime.now().toUtc().toIso8601String(),
        'generation': currentGeneration(),
        'database': tookDatabase,
        'media': tookMedia,
      }));
    }

    final pendingFile = _pending(userId);
    if (pendingFile.existsSync()) await pendingFile.delete();
    final retirement = await retireClaimedGuestTree();
    return GuestFinalizeReport(
      pathsRewritten: rewritten,
      rowsMerged: rowsMerged,
      charactersClaimed: charactersClaimed,
      absorbedAnything: absorbedAnything,
      retirement: retirement,
    );
  }

  /// **Audit phase O8 - the characters arrived and stayed invisible.**
  ///
  /// A character made without an account has `owner_id IS NULL`, and the hub's
  /// character tab is own-only: `_isOwned` reads a null owner as "mine" exactly
  /// while nobody is signed in, and as somebody else's the moment there is a
  /// `uid`. So every promoted character was in the account's database and on
  /// none of its screens.
  ///
  /// `CharacterListNotifier._backfillWorldlessOwnership` exists for this and
  /// does not cover it: it deliberately skips world-bound rows, because there a
  /// null owner means *deliberately released* by the `release_character` RPC
  /// and re-adopting it would resurrect released characters on every refresh.
  ///
  /// Promotion is the one place where that ambiguity does not exist. These rows
  /// come out of a workspace that had no account at all, so nothing in them was
  /// ever released by anyone - they are unowned only because there was no one
  /// to own them. Claiming them here, rather than loosening the rule the tab
  /// relies on, is what keeps release working.
  ///
  /// [wholeDatabase] says the account's database *is* the promoted guest file,
  /// so every ownerless row in it is guest-born. Otherwise the guest rows were
  /// merged into an existing account database and only those are claimed - an
  /// account's own released characters keep their null owner.
  Future<int> claimGuestCharacters(
    AppDatabase db,
    String userId, {
    required bool wholeDatabase,
  }) async {
    final owner = _sqlString(userId);
    try {
      if (wholeDatabase) {
        return await db.customUpdate(
          'UPDATE world_characters SET owner_id = $owner '
          'WHERE owner_id IS NULL',
          updates: const {},
        );
      }
      final guest = _guestDatabase();
      if (!guest.existsSync()) return 0;
      await db.customStatement('ATTACH DATABASE ? AS guest', [guest.path]);
      try {
        return await db.customUpdate(
          'UPDATE world_characters SET owner_id = $owner '
          'WHERE owner_id IS NULL '
          'AND id IN (SELECT id FROM guest.world_characters)',
          updates: const {},
        );
      } finally {
        await db.customStatement('DETACH DATABASE guest');
      }
    } catch (_) {
      // Ownership is a repair, not the handover itself: a database shaped
      // differently than expected must not cost the user the rows.
      return 0;
    }
  }

  /// [claimGuestCharacters]'ın simetriği: hesap silinirken karakterlerin
  /// sahipliğini düşürür.
  ///
  /// Hub'ın karakter sekmesi own-only: `owner_id == auth.uid` iken kullanıcının,
  /// `owner_id == null` iken **yalnız oturum kapalıyken** kullanıcının sayılır
  /// (`characters_tab._isOwned`). Hesap silinip misafire dönüldüğünde dünyalar
  /// ve paketler geliyor ama karakterler artık var olmayan bir uid'e ait
  /// olduğu için hiçbir ekranda görünmüyordu.
  ///
  /// Serbest bırakma anlamı burada belirsiz değil: sahip hesap yok, dolayısıyla
  /// `release_character` ile karışacak bir durum da yok.
  ///
  /// DB **açıkken** ve demote'tan (dosya taşıma) önce çağrılır.
  Future<int> releaseAccountCharacters(AppDatabase db, String userId) async {
    try {
      return await db.customUpdate(
        'UPDATE world_characters SET owner_id = NULL WHERE owner_id = '
        '${_sqlString(userId)}',
        updates: const {},
      );
    } catch (_) {
      // Sahiplik bir onarım; başarısızlığı silmeyi durdurmamalı.
      return 0;
    }
  }

  /// **O5 — the row-level half of the handover.**
  ///
  /// Attaches the guest database to the already-open account database and
  /// copies every content row across with `INSERT OR IGNORE`, so the account's
  /// own rows always win a primary-key collision. This is the path taken
  /// whenever the account already has a database on this device — the normal
  /// state of any account that has signed in here even once.
  ///
  /// [db] must be the account's database and the guest database must be closed.
  /// The table list is read from the guest file rather than hard-coded, so a
  /// table added later rides along without a second edit here; the deny list is
  /// device-local bookkeeping that means nothing under a different root.
  /// Columns are intersected between the two sides, which keeps the statement
  /// valid even if the two files were written by slightly different builds.
  ///
  /// **O7** rewrites package ids on the way in - see [_guestPackageRemap] for
  /// why a straight copy silently emptied every built-in package.
  ///
  /// Returns the number of rows actually inserted.
  Future<int> mergeGuestRows(AppDatabase db) async {
    final guest = _guestDatabase();
    if (!guest.existsSync()) return 0;

    var inserted = 0;
    await db.customStatement('ATTACH DATABASE ? AS guest', [guest.path]);
    try {
      final remap = await _guestPackageRemap(db);
      // Precompute guest packages whose name already exists in the account —
      // these must be skipped to prevent duplicates (INSERT OR IGNORE only
      // checks PK, not name).
      final nameConflicts = await _computeNameConflicts(db);
      final tables = await db
          .customSelect(
            "SELECT name FROM guest.sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      for (final row in tables) {
        final table = row.read<String>('name');
        if (_noMergeTables.contains(table)) continue;
        final mainColumns = await _columnsOf(db, 'main', table);
        if (mainColumns.isEmpty) continue; // not a table the account has
        final guestColumns = await _columnsOf(db, 'guest', table);
        final shared = mainColumns.where(guestColumns.contains).toList();
        if (shared.isEmpty) continue;
        final list = shared.map((c) => '"$c"').join(', ');

        // The account's copy of a remapped package wins whole: its rows are
        // already here under the ids the guest side would have used, and the
        // guest's package/schema/entity rows would only add an empty duplicate.
        //
        // Name conflict: INSERT OR IGNORE only checks PK, not name. A guest
        // SRD package with a different UUID would slip through and create a
        // duplicate. Exclude guest packages whose name already exists in the
        // account — same effect as INSERT OR IGNORE on a UNIQUE(name) index.
        final skip = _packageOwnedTables.contains(table)
            ? _remapExclusion(table, remap.keys, nameConflicts: nameConflicts)
            : '';
        // Everywhere else the guest rows are kept and merely re-pointed.
        final select = shared
            .map((c) => c == 'package_id' && remap.isNotEmpty
                ? '${_remapCase(remap)} AS "package_id"'
                : '"$c"')
            .join(', ');

        // customUpdate, not customInsert: we want the affected-row count here,
        // not the last inserted rowid.
        inserted += await db.customUpdate(
          'INSERT OR IGNORE INTO main."$table" ($list) '
          'SELECT $select FROM guest."$table"$skip',
          updates: const {},
        );
      }
    } finally {
      await db.customStatement('DETACH DATABASE guest');
    }
    return inserted;
  }

  /// **Audit phase O7 - a promoted world whose packages were empty shells.**
  ///
  /// The built-in SRD package gets a fresh `uuid.v4()` in every database it is
  /// bootstrapped into (`SrdCorePackageBootstrap.ensureInstalled`), while the
  /// rows inside it are keyed by `srdStableEntityId`, a `uuid.v5` of
  /// `slug:name` that is byte-identical everywhere - and `package_entities`
  /// keys on that id *alone*, not on `(package_id, id)`.
  ///
  /// So a straight row copy did the worst possible thing: the guest's package
  /// row carried an id the account had never seen and was inserted, while every
  /// one of its ~2000 entities collided with the account's own copy and was
  /// dropped by `INSERT OR IGNORE`. The promoted world then pointed at a
  /// package that existed and contained nothing. Measured as "the world came
  /// over but the built-in package content did not".
  ///
  /// This maps such a guest package onto the account's equivalent. The test for
  /// "equivalent" is deliberately the corruption condition itself - same name
  /// *and* at least one shared entity id - because that overlap is exactly what
  /// makes the guest's rows unmergeable. Two genuinely different packages that
  /// happen to share a name mint random ids and share nothing, so they are left
  /// alone and both survive.
  Future<Map<String, String>> _guestPackageRemap(AppDatabase db) async {
    final out = <String, String>{};
    try {
      final rows = await db
          .customSelect(
            'SELECT g.id AS guest_id, m.id AS account_id '
            'FROM guest.packages g JOIN main.packages m ON m.name = g.name '
            'WHERE g.id <> m.id AND EXISTS ('
            '  SELECT 1 FROM guest.package_entities ge '
            '  JOIN main.package_entities me ON me.id = ge.id '
            '  WHERE ge.package_id = g.id AND me.package_id = m.id)',
          )
          .get();
      for (final row in rows) {
        // First account row wins if a name is somehow duplicated on this side.
        out.putIfAbsent(
            row.read<String>('guest_id'), () => row.read<String>('account_id'));
      }
    } catch (_) {
      // No packages table on one side, or an older shape: merging without a
      // remap is what shipped before, so fall back to it rather than failing.
      return const {};
    }
    return out;
  }

  /// Tables whose rows *belong to* a package rather than merely referencing
  /// one. For a remapped package these are the account's already.
  static const _packageOwnedTables = <String>{
    'packages',
    'package_schemas',
    'package_entities',
  };

  /// Guest packages whose name already exists in the account — these must be
  /// skipped during merge to prevent name-based duplicates (INSERT OR IGNORE
  /// only checks PK, not name).
  Future<Set<String>> _computeNameConflicts(AppDatabase db) async {
    try {
      final rows = await db.customSelect(
        'SELECT g.name FROM guest.packages g '
        'JOIN main.packages m ON m.name = g.name '
        'WHERE g.id != m.id',
      ).get();
      return {for (final r in rows) r.read<String>('name')};
    } catch (_) {
      return const {};
    }
  }

  String _remapExclusion(String table, Iterable<String> guestIds,
      {Set<String> nameConflicts = const {}}) {
    final conditions = <String>[];
    if (guestIds.isNotEmpty) {
      final column = table == 'packages' ? 'id' : 'package_id';
      final list = guestIds.map(_sqlString).join(', ');
      conditions.add('"$column" NOT IN ($list)');
    }
    // Exclude guest packages whose name already exists in the account —
    // prevents INSERT OR IGNORE from creating name-based duplicates.
    if (nameConflicts.isNotEmpty && table == 'packages') {
      final list = nameConflicts.map(_sqlString).join(', ');
      conditions.add('"name" NOT IN ($list)');
    } else if (nameConflicts.isNotEmpty) {
      // For package_schemas / package_entities: exclude rows whose
      // parent package name already exists in the account.
      final list = nameConflicts.map(_sqlString).join(', ');
      conditions.add(
        '"package_id" NOT IN '
        '(SELECT id FROM main.packages WHERE name IN ($list))',
      );
    }
    if (conditions.isEmpty) return '';
    return ' WHERE ${conditions.join(' AND ')}';
  }

  String _remapCase(Map<String, String> remap) {
    final buffer = StringBuffer('CASE "package_id"');
    remap.forEach((guestId, accountId) {
      buffer.write(' WHEN ${_sqlString(guestId)} THEN ${_sqlString(accountId)}');
    });
    buffer.write(' ELSE "package_id" END');
    return buffer.toString();
  }

  /// Ids are uuids, but they arrive from a file on disk and are inlined into
  /// the statement (a `CASE` cannot take a variadic parameter list cleanly), so
  /// they are quoted properly rather than trusted.
  String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

  /// Device-local bookkeeping: the outbox belongs to the session that queued
  /// it, and telemetry / migration progress describe the guest file rather than
  /// its contents. Everything else is user content and rides along.
  static const _noMergeTables = <String>{
    'sync_outbox',
    'sync_telemetry',
    'migration_progress',
  };

  Future<List<String>> _columnsOf(
      AppDatabase db, String schema, String table) async {
    try {
      final rows =
          await db.customSelect('PRAGMA $schema.table_info("$table")').get();
      return [for (final r in rows) r.read<String>('name')];
    } catch (_) {
      return const [];
    }
  }

  /// **O4 — spend the scratch space.** Moves everything a finished promotion
  /// absorbed out of the guest root and into `guest_archive/<ts>/`, so that the
  /// next signed-out session opens a clean, empty workspace instead of a stale
  /// duplicate of somebody's account.
  ///
  /// Safe to call at any time and as often as you like: without a claim it only
  /// purges expired archives, and with one it moves whatever is still in place.
  /// `UserSessionNotifier.deactivate` calls it on every sign-out and every
  /// offline entry, which is what heals a promotion that died between writing
  /// the claim and finishing the move.
  ///
  /// **The caller must not have the guest database open.** Nothing here
  /// overwrites: every move is into a fresh archive directory, and a target
  /// that somehow already exists is left alone rather than replaced.
  Future<GuestRetirementReport> retireClaimedGuestTree() async {
    await _purgeExpiredArchives();
    final claim = readClaim();
    if (claim == null) return const GuestRetirementReport();

    final stamp = (claim.claimedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final archive = Directory(p.join(dataRoot, archiveDirName, '$stamp'));

    final movedFiles = <String>[];
    final movedSubtrees = <String>[];

    if (claim.database) {
      final guestDb = _guestDatabase();
      for (final suffix in const ['', '-wal', '-shm']) {
        final src = File('${guestDb.path}$suffix');
        if (!src.existsSync()) continue;
        final dst = File(p.join(archive.path, 'db', 'dmt.sqlite$suffix'));
        if (dst.existsSync()) continue;
        await dst.parent.create(recursive: true);
        await src.rename(dst.path);
        movedFiles.add(p.basename(dst.path));
      }
    }

    for (final name in claim.media) {
      if (!mediaSubtrees.contains(name)) continue;
      final src = Directory(p.join(dataRoot, name));
      if (!src.existsSync()) continue;
      final dst = Directory(p.join(archive.path, name));
      if (dst.existsSync()) continue;
      await dst.parent.create(recursive: true);
      await src.rename(dst.path);
      movedSubtrees.add(name);
    }

    // **O6 - the claim dies with the content it claimed.** Everything it named
    // is in the archive now, so what is left here belongs to nobody and the
    // next signed-out session starts a generation of its own. Retiring first
    // and clearing after keeps the crash-safety O4 was built around: a claim
    // outlives any interrupted move and the next sign-out finishes it.
    final retiredCleanly = !_claimedContentStillInPlace(claim);
    if (retiredCleanly) {
      try {
        if (_claim().existsSync()) await _claim().delete();
        if (_generation().existsSync()) await _generation().delete();
      } catch (_) {
        // Best-effort: a claim that survives only costs one more retirement.
      }
    }

    return GuestRetirementReport(
      claim: claim,
      archivePath: (movedFiles.isEmpty && movedSubtrees.isEmpty)
          ? null
          : archive.path,
      filesMoved: movedFiles,
      subtreesMoved: movedSubtrees,
      claimCleared: retiredCleanly,
    );
  }

  /// The archive is a forensic backup of data that provably exists under an
  /// account as well, and it expires on the same 30-day clock the v12 cut's
  /// legacy databases do.
  Future<void> _purgeExpiredArchives() async {
    final root = Directory(p.join(dataRoot, archiveDirName));
    if (!root.existsSync()) return;
    final cutoff =
        DateTime.now().subtract(archiveRetention).millisecondsSinceEpoch;
    try {
      for (final entity in root.listSync()) {
        final stamp = int.tryParse(p.basename(entity.path));
        if (stamp == null || stamp >= cutoff) continue;
        await entity.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort, exactly like the legacy-database purge.
    }
  }

  _PendingPromotion? _readPending(String userId) {
    final file = _pending(userId);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return _PendingPromotion(
        database: json['database'] as bool? ?? false,
        merge: json['merge'] as bool? ?? false,
        media: (json['media'] as List?)?.cast<String>() ?? const [],
      );
    } catch (_) {
      return null;
    }
  }

  /// Rewrites every stored absolute path that points into a guest media subtree
  /// so it points into the account's copy instead. Returns the number of values
  /// changed.
  ///
  /// Scope is deliberately per-subtree (`{root}/worlds` → `{root}/users/{id}/worlds`)
  /// rather than root → account root. Rewriting the bare root would be
  /// self-feeding: the account root *contains* the guest root as a prefix, so a
  /// second pass would produce `.../users/{id}/users/{id}/...`. Anchored on the
  /// subtree the operation is idempotent, because no rewritten value contains
  /// the old prefix any more.
  ///
  /// `asset_refs` needs none of this and is not special-cased: its `uri` values
  /// are scheme URIs (`dmt-asset://`, `dmt-public://`, `dmt-transient://`) and
  /// raw filesystem paths are kept out of that graph on purpose
  /// (`reference_indexer.dart`). What does carry absolute paths is JSON blobs
  /// and columns like `world_entities.image_path` — legacy values the F11
  /// `RawPathMigrator` exists to convert — so the sweep is over every TEXT
  /// column of every table.
  Future<int> rewriteGuestPaths(AppDatabase db, String userId) =>
      _replaceInEveryTextColumn(db, _pathReplacements(userId));

  /// [rewriteGuestPaths]'in tersi: hesap kökündeki medya yollarını misafir
  /// köküne çevirir. Demote dosyaları taşıyor ama gövdelerdeki mutlak yollar
  /// silinen `users/{id}/...` ağacını göstermeye devam ediyordu — portreler,
  /// battle map arka planları ve mindmap resimleri kırık kalıyordu.
  ///
  /// DB **açıkken** ve [demoteAccountToGuest]'ten önce çağrılır.
  Future<int> restoreGuestPaths(AppDatabase db, String userId) =>
      _replaceInEveryTextColumn(
        db,
        [for (final (from, to) in _pathReplacements(userId)) (to, from)],
      );

  Future<int> _replaceInEveryTextColumn(
    AppDatabase db,
    List<(String, String)> replacements,
  ) async {
    if (replacements.isEmpty) return 0;

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();

    var changed = 0;
    for (final row in tables) {
      final table = row.read<String>('name');
      final columns = await db.customSelect('PRAGMA table_info("$table")').get();
      for (final column in columns) {
        final type = (column.read<String?>('type') ?? '').toUpperCase();
        final isText = type.isEmpty ||
            type.contains('CHAR') ||
            type.contains('TEXT') ||
            type.contains('CLOB');
        if (!isText) continue;
        final name = column.read<String>('name');
        for (final (from, to) in replacements) {
          changed += await db.customUpdate(
            'UPDATE "$table" SET "$name" = replace("$name", ?, ?) '
            'WHERE instr("$name", ?) > 0',
            variables: [Variable(from), Variable(to), Variable(from)],
            updates: const {},
          );
        }
      }
    }
    return changed;
  }

  /// Every spelling a stored guest path can have: the platform's own, POSIX
  /// separators, and the doubled backslashes a Windows path picks up once it
  /// has been through `jsonEncode` into a blob column.
  List<(String, String)> _pathReplacements(String userId) {
    final pairs = <(String, String)>[];
    final seen = <String>{};
    for (final subtree in mediaSubtrees) {
      final from = p.join(dataRoot, subtree);
      final to = p.join(accountRoot(userId), subtree);
      for (final variant in <(String, String)>[
        (from, to),
        (from.replaceAll(r'\', '/'), to.replaceAll(r'\', '/')),
        (from.replaceAll(r'\', r'\\'), to.replaceAll(r'\', r'\\')),
      ]) {
        if (seen.add(variant.$1)) pairs.add(variant);
      }
    }
    return pairs;
  }

  /// **Terfinin tersi — hesap silindiğinde ağacı misafire geri verir.**
  ///
  /// Kullanıcı hesabını sildiğinde bulut tarafı gider ama **yerel veri onun
  /// kendi diskinde kalır**: aynı cihazda misafir olarak girip kaldığı yerden
  /// devam edebilmeli. Bu yüzden `users/{id}/` ağacı silinmez, misafir köküne
  /// taşınır.
  ///
  /// Üç adım, sırası kritik:
  ///   1. [retireClaimedGuestTree] — kökte terfiden kalan **bayat** kopya
  ///      varsa arşive alınır ve talep düşer. Talep düşmeden taşırsak
  ///      `deactivate()`'in ikinci emekliliği bu sefer *yeni* taşıdığımız
  ///      veriyi arşivler. (Talep yoksa bu adım zaten no-op.)
  ///   2. `db/` + medya alt ağaçları köke taşınır. `.v12_cut_applied`
  ///      işaretçisi taşınan DB'nin yanında olmak zorunda — yoksa bir sonraki
  ///      açılış onu pre-v12 sanıp `dmt.sqlite.legacy.<ts>`'e alır ve
  ///      kullanıcı yine boş bir çalışma alanı görür.
  ///   3. Geriye kalan hesap kökü (`cache/`, sentinel'ler) silinir.
  ///
  /// Çağrılmadan önce hesabın veritabanı **kapalı** olmalı (WAL çifti de
  /// taşınıyor). Bkz. `finishAccountDeletion`.
  Future<({bool database, List<String> media})> demoteAccountToGuest(
    String userId,
  ) async {
    final retirement = await retireClaimedGuestTree();
    if (retirement.movedAnything) {
      debugPrint('Demotion: stale guest tree retired -> $retirement');
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final archive = Directory(p.join(dataRoot, archiveDirName, '$stamp'));
    final guestDb = _guestDatabase();
    final accountDb = _accountDatabase(userId);

    var database = false;
    if (accountDb.existsSync()) {
      await Directory(p.dirname(guestDb.path)).create(recursive: true);
      for (final suffix in const ['', '-wal', '-shm']) {
        // Kökte hâlâ bir DB duruyorsa (talep edilmemiş, dolayısıyla emekli
        // edilmemiş bir misafir alanı) üzerine yazmak yerine arşive park et.
        final stale = File('${guestDb.path}$suffix');
        if (stale.existsSync()) {
          final parked = File(p.join(archive.path, 'db', 'dmt.sqlite$suffix'));
          await parked.parent.create(recursive: true);
          if (!parked.existsSync()) await stale.rename(parked.path);
        }
        final src = File('${accountDb.path}$suffix');
        if (!src.existsSync()) continue;
        await src.rename('${guestDb.path}$suffix');
        database = true;
      }
      if (database) {
        final marker = File(p.join(p.dirname(guestDb.path), '.v12_cut_applied'));
        if (!marker.existsSync()) await marker.create(recursive: true);
      }
    }

    final media = <String>[];
    for (final name in mediaSubtrees) {
      final src = Directory(p.join(accountRoot(userId), name));
      if (!src.existsSync()) continue;
      final moved = await _moveDirectory(src, Directory(p.join(dataRoot, name)));
      if (moved > 0) media.add(name);
    }

    // Talep/nesil dosyaları: emeklilik bunları düşürmüş olmalı, ama yarıda
    // kalmış bir arşivleme onları bırakabilir. Hesap artık yok, dolayısıyla
    // talebin adını verdiği içeriğin sahibi de yok — kalırlarsa `deactivate()`
    // az önce taşıdığımız veriyi arşivler.
    try {
      if (_claim().existsSync()) await _claim().delete();
      if (_generation().existsSync()) await _generation().delete();
    } catch (_) {
      // Best-effort.
    }

    try {
      final root = Directory(accountRoot(userId));
      if (root.existsSync()) await root.delete(recursive: true);
    } catch (e) {
      debugPrint('Demotion: account root cleanup failed: $e');
    }

    return (database: database, media: media);
  }

  /// Moves [src]'s contents into [dst] without ever overwriting something that
  /// is already there, and returns how many entries it moved. Whatever could
  /// not move stays in [src].
  static Future<int> _moveDirectory(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    var moved = 0;
    await for (final entity in src.list(recursive: false)) {
      final target = p.join(dst.path, p.basename(entity.path));
      if (entity is File) {
        if (File(target).existsSync()) continue;
        await entity.rename(target);
        moved++;
      } else if (entity is Directory) {
        moved += await _moveDirectory(entity, Directory(target));
      }
    }
    return moved;
  }

  /// Copies [src] into [dst] without ever overwriting a file that is already
  /// there, and returns how many files it actually wrote.
  static Future<int> _copyDirectory(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    var copied = 0;
    await for (final entity in src.list(recursive: false)) {
      final target = p.join(dst.path, p.basename(entity.path));
      if (entity is File) {
        if (File(target).existsSync()) continue;
        await entity.copy(target);
        copied++;
      } else if (entity is Directory) {
        copied += await _copyDirectory(entity, Directory(target));
      } else if (entity is Link) {
        // Links are skipped rather than followed — a copy that chases a link
        // out of the data root is not a promotion.
        debugPrint('GuestPromotion: skipping link ${entity.path}');
      }
    }
    return copied;
  }
}

enum GuestPromotionOutcome {
  /// Guest tree copied into the account.
  promoted,

  /// The completion marker was already there — this device has done it.
  alreadyPromoted,

  /// No guest database and no guest media: a device that was never used
  /// offline.
  nothingToPromote,

  /// The account already has a database here, so it is left alone and the
  /// guest rows are merged into it by `finalizePromotion` instead. Media is
  /// copied file by file, never overwriting the account's own.
  mergedIntoAccountDatabase,

  /// **O4.** Another account has already spent this guest tree. Nothing is
  /// copied — what is left of it belongs to them, and a second account
  /// absorbing it would be handing one person's work to another.
  guestAlreadyClaimed,
}

/// **O4.** The record left at the guest root once an account has spent it.
@immutable
class GuestClaim {
  const GuestClaim({
    this.claimedBy,
    this.claimedAt,
    this.database = false,
    this.media = const [],
    this.generation,
  });

  /// Null when the claim file could not be parsed — the tree still counts as
  /// claimed, it is simply no longer known by whom.
  final String? claimedBy;
  final DateTime? claimedAt;

  /// What the promotion actually absorbed, and therefore what may be retired.
  final bool database;
  final List<String> media;

  /// **O6.** The incarnation of the guest workspace this claim was written
  /// over. Null on claims written before O6 existed.
  final String? generation;

  @override
  String toString() =>
      'GuestClaim($claimedBy, db: $database, media: $media, gen: $generation)';
}

@immutable
class GuestRetirementReport {
  const GuestRetirementReport({
    this.claim,
    this.archivePath,
    this.filesMoved = const [],
    this.subtreesMoved = const [],
    this.claimCleared = false,
  });

  final GuestClaim? claim;
  final String? archivePath;
  final List<String> filesMoved;
  final List<String> subtreesMoved;

  /// **O6.** The claimed content is all in the archive, so the claim and the
  /// generation id were dropped: the workspace left behind is free again.
  final bool claimCleared;

  bool get movedAnything => filesMoved.isNotEmpty || subtreesMoved.isNotEmpty;

  @override
  String toString() => 'GuestRetirementReport(claim: $claim, '
      'archive: $archivePath, files: $filesMoved, subtrees: $subtreesMoved, '
      'cleared: $claimCleared)';
}

@immutable
class _PendingPromotion {
  const _PendingPromotion({
    required this.database,
    required this.merge,
    required this.media,
  });

  final bool database;

  /// The account already had a database, so the rows still have to be merged
  /// into it — the work [GuestPromotionService.finalizePromotion] finishes.
  final bool merge;
  final List<String> media;
}

/// What [GuestPromotionService.finalizePromotion] actually did.
@immutable
class GuestFinalizeReport {
  const GuestFinalizeReport({
    this.pathsRewritten = 0,
    this.rowsMerged = 0,
    this.charactersClaimed = 0,
    this.absorbedAnything = false,
    this.retirement,
  });

  final int pathsRewritten;
  final int rowsMerged;

  /// **O8.** Promoted characters whose null owner was turned into this account,
  /// which is what puts them back on the character tab.
  final int charactersClaimed;

  /// What the retirement pass that follows the claim did with the guest tree.
  /// The only place the claim is still observable after the fact: under O6 it
  /// is deleted as soon as the content it named reaches the archive.
  final GuestRetirementReport? retirement;

  /// False when the finalize found nothing to take. No completion marker is
  /// written in that case, so a later attempt may still do the handover.
  final bool absorbedAnything;

  @override
  String toString() => 'GuestFinalizeReport(paths: $pathsRewritten, '
      'rows: $rowsMerged, characters: $charactersClaimed, '
      'absorbed: $absorbedAnything, retired: $retirement)';
}

@immutable
class GuestPromotionReport {
  const GuestPromotionReport({
    required this.outcome,
    this.databaseCopied = false,
    this.databaseMergePending = false,
    this.mediaSubtreesCopied = const [],
  });

  final GuestPromotionOutcome outcome;
  final bool databaseCopied;

  /// The account's own database was kept, so its rows are merged in phase 2.
  final bool databaseMergePending;
  final List<String> mediaSubtreesCopied;

  @override
  String toString() => 'GuestPromotionReport(${outcome.name}, '
      'db: $databaseCopied, merge: $databaseMergePending, '
      'media: $mediaSubtreesCopied)';
}
