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
/// `BetaEnterMergeService`'s first-enter, local-wins merge is what queues them
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

  String accountRoot(String userId) => p.join(dataRoot, 'users', userId);

  File _completed(String userId) =>
      File(p.join(accountRoot(userId), _completedMarker));

  File _pending(String userId) =>
      File(p.join(accountRoot(userId), _pendingMarker));

  File _claim() => File(p.join(dataRoot, claimFileName));

  File _guestDatabase() => File(p.join(dataRoot, 'db', 'dmt.sqlite'));

  File _accountDatabase(String userId) =>
      File(p.join(accountRoot(userId), 'db', 'dmt.sqlite'));

  /// Whether this account has already been through a promotion on this device.
  /// Cheap and synchronous on purpose — it is read on every sign-in.
  bool isPromoted(String userId) => _completed(userId).existsSync();

  /// **O4.** The claim on the guest tree, or null while it is still unspent.
  /// Synchronous and tolerant: an unreadable or malformed claim file still
  /// counts as a claim, because the safe reading of "something went wrong here"
  /// is *do not hand this tree to anyone*.
  GuestClaim? readClaim() {
    final file = _claim();
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return GuestClaim(
        claimedBy: json['claimedBy'] as String?,
        claimedAt: DateTime.tryParse(json['claimedAt'] as String? ?? ''),
        database: json['database'] as bool? ?? false,
        media: (json['media'] as List?)?.cast<String>() ?? const [],
      );
    } catch (_) {
      return const GuestClaim();
    }
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
    final guestDb = _guestDatabase();
    final accountDb = _accountDatabase(userId);

    if (accountDb.existsSync() && !resuming) {
      outcome = GuestPromotionOutcome.accountAlreadyHasData;
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

    // Media. Each subtree is skipped when the account already has content
    // there — the same never-clobber rule as the database, and the behaviour
    // the previous `_migrateGlobalDataIfNeeded` had for `worlds/` and
    // `packages/`. `characters/` was missing from that list; it is here.
    final mediaCopied = <String>[];
    for (final name in mediaSubtrees) {
      final src = Directory(p.join(dataRoot, name));
      if (!src.existsSync() || src.listSync().isEmpty) continue;
      final dst = Directory(p.join(accountRoot(userId), name));
      if (dst.existsSync() && dst.listSync().isNotEmpty) continue;
      await _copyDirectory(src, dst);
      mediaCopied.add(name);
    }

    // Rewrite the in-progress marker with what was actually taken. O4's claim
    // is written by [finalizePromotion], which does not see this report, and
    // recording it here means a resumed promotion claims the same things a
    // straight-through one would.
    await _pending(userId).writeAsString(jsonEncode({
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'from': dataRoot,
      'database': databaseCopied,
      'media': mediaCopied,
    }));

    return GuestPromotionReport(
      outcome: outcome,
      databaseCopied: databaseCopied,
      mediaSubtreesCopied: mediaCopied,
    );
  }

  /// Phase 2 — rewrite guest-absolute media paths inside the copied database,
  /// then flip the sentinel.
  ///
  /// [db] must be the account's database, already open. The rewrite has to
  /// happen through it rather than a raw sqlite handle because `package:sqlite3`
  /// is a dev-only dependency here.
  Future<int> finalizePromotion(String userId, AppDatabase db) async {
    if (isPromoted(userId)) return 0;
    final absorbed = _readPending(userId);
    final rewritten = await rewriteGuestPaths(db, userId);
    await _completed(userId).writeAsString(jsonEncode({
      'promotedAt': DateTime.now().toUtc().toIso8601String(),
      'pathsRewritten': rewritten,
    }));

    // **O4 — claim before retire, and only for what was taken.** The claim is
    // one small write and it is what stops the next account; the move that
    // follows is the slower, more fallible half, and it is idempotent. An
    // account that got [GuestPromotionOutcome.accountAlreadyHasData] absorbed
    // no database, so it does not get to spend the tree.
    if (absorbed != null &&
        (absorbed.database || absorbed.media.isNotEmpty) &&
        readClaim() == null) {
      await _claim().writeAsString(jsonEncode({
        'claimedBy': userId,
        'claimedAt': DateTime.now().toUtc().toIso8601String(),
        'database': absorbed.database,
        'media': absorbed.media,
      }));
    }

    final pending = _pending(userId);
    if (pending.existsSync()) await pending.delete();
    await retireClaimedGuestTree();
    return rewritten;
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

    return GuestRetirementReport(
      claim: claim,
      archivePath: (movedFiles.isEmpty && movedSubtrees.isEmpty)
          ? null
          : archive.path,
      filesMoved: movedFiles,
      subtreesMoved: movedSubtrees,
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
  Future<int> rewriteGuestPaths(AppDatabase db, String userId) async {
    final replacements = _pathReplacements(userId);
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

  static Future<void> _copyDirectory(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (final entity in src.list(recursive: false)) {
      final target = p.join(dst.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(target);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(target));
      } else if (entity is Link) {
        // Links are skipped rather than followed — a copy that chases a link
        // out of the data root is not a promotion.
        debugPrint('GuestPromotion: skipping link ${entity.path}');
      }
    }
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

  /// The account already has a database here, so the guest database was left
  /// alone. Media subtrees the account does not have are still copied.
  accountAlreadyHasData,

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
  });

  /// Null when the claim file could not be parsed — the tree still counts as
  /// claimed, it is simply no longer known by whom.
  final String? claimedBy;
  final DateTime? claimedAt;

  /// What the promotion actually absorbed, and therefore what may be retired.
  final bool database;
  final List<String> media;

  @override
  String toString() =>
      'GuestClaim($claimedBy, db: $database, media: $media)';
}

@immutable
class GuestRetirementReport {
  const GuestRetirementReport({
    this.claim,
    this.archivePath,
    this.filesMoved = const [],
    this.subtreesMoved = const [],
  });

  final GuestClaim? claim;
  final String? archivePath;
  final List<String> filesMoved;
  final List<String> subtreesMoved;

  bool get movedAnything => filesMoved.isNotEmpty || subtreesMoved.isNotEmpty;

  @override
  String toString() => 'GuestRetirementReport(claim: $claim, '
      'archive: $archivePath, files: $filesMoved, subtrees: $subtreesMoved)';
}

@immutable
class _PendingPromotion {
  const _PendingPromotion({required this.database, required this.media});

  final bool database;
  final List<String> media;
}

@immutable
class GuestPromotionReport {
  const GuestPromotionReport({
    required this.outcome,
    this.databaseCopied = false,
    this.mediaSubtreesCopied = const [],
  });

  final GuestPromotionOutcome outcome;
  final bool databaseCopied;
  final List<String> mediaSubtreesCopied;

  @override
  String toString() => 'GuestPromotionReport(${outcome.name}, '
      'db: $databaseCopied, media: $mediaSubtreesCopied)';
}
