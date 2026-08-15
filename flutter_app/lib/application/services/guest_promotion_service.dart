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

  String accountRoot(String userId) => p.join(dataRoot, 'users', userId);

  File _completed(String userId) =>
      File(p.join(accountRoot(userId), _completedMarker));

  File _pending(String userId) =>
      File(p.join(accountRoot(userId), _pendingMarker));

  File _guestDatabase() => File(p.join(dataRoot, 'db', 'dmt.sqlite'));

  File _accountDatabase(String userId) =>
      File(p.join(accountRoot(userId), 'db', 'dmt.sqlite'));

  /// Whether this account has already been through a promotion on this device.
  /// Cheap and synchronous on purpose — it is read on every sign-in.
  bool isPromoted(String userId) => _completed(userId).existsSync();

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
    final rewritten = await rewriteGuestPaths(db, userId);
    await _completed(userId).writeAsString(jsonEncode({
      'promotedAt': DateTime.now().toUtc().toIso8601String(),
      'pathsRewritten': rewritten,
    }));
    final pending = _pending(userId);
    if (pending.existsSync()) await pending.delete();
    return rewritten;
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
