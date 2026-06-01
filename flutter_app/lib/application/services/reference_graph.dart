import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';

/// AssetRef → owner satır grafı.
///
/// Tablo: `asset_refs(uri, owner_table, owner_id, owner_field, world_id,
/// last_seen_at)` — kompozit PK + uri INDEX. Şema [_sideTablesDDL] içinde
/// AppDatabase.beforeOpen tarafından idempotent kurulur.
///
/// Kullanım:
/// - [ReferenceIndexer] (F3) her DAO write'ından sonra
///   [reindexOwner] çağırarak owner için tüm ref'leri eski snapshot ile diff'ler.
/// - [EntityMediaCleanupService] / [EvictionSweeper] [isReferenced] ile O(1)
///   orphan tespiti yapar.
class ReferenceGraph {
  ReferenceGraph(this._db);

  final AppDatabase _db;

  /// Belirli owner için TÜM mevcut ref'leri al (owner_field bazlı).
  Future<List<AssetRefRow>> refsForOwner(
    String ownerTable,
    String ownerId,
  ) async {
    final rows = await _db.customSelect(
      'SELECT uri, owner_field, world_id, last_seen_at FROM asset_refs '
      'WHERE owner_table = ? AND owner_id = ?',
      variables: [Variable<String>(ownerTable), Variable<String>(ownerId)],
    ).get();
    return rows
        .map((r) => AssetRefRow(
              uri: r.read<String>('uri'),
              ownerTable: ownerTable,
              ownerId: ownerId,
              ownerField: r.read<String>('owner_field'),
              worldId: r.readNullable<String>('world_id'),
              lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('last_seen_at'),
              ),
            ))
        .toList();
  }

  /// Belirli URI'ye referans veren tüm owner'lar.
  Future<List<AssetRefRow>> refsForUri(String uri) async {
    final rows = await _db.customSelect(
      'SELECT owner_table, owner_id, owner_field, world_id, last_seen_at '
      'FROM asset_refs WHERE uri = ?',
      variables: [Variable<String>(uri)],
    ).get();
    return rows
        .map((r) => AssetRefRow(
              uri: uri,
              ownerTable: r.read<String>('owner_table'),
              ownerId: r.read<String>('owner_id'),
              ownerField: r.read<String>('owner_field'),
              worldId: r.readNullable<String>('world_id'),
              lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('last_seen_at'),
              ),
            ))
        .toList();
  }

  /// URI'ye referans var mı (O(1) — INDEX).
  Future<bool> isReferenced(String uri) async {
    final rows = await _db.customSelect(
      'SELECT 1 FROM asset_refs WHERE uri = ? LIMIT 1',
      variables: [Variable<String>(uri)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Owner'a yeni ref ekle / güncelle. Aynı kompozit PK varsa
  /// last_seen_at güncellenir (upsert).
  Future<void> addRef({
    required String uri,
    required String ownerTable,
    required String ownerId,
    String ownerField = '',
    String? worldId,
    DateTime? at,
  }) async {
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT INTO asset_refs (uri, owner_table, owner_id, owner_field, '
      'world_id, last_seen_at) VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(uri, owner_table, owner_id, owner_field) '
      'DO UPDATE SET last_seen_at = excluded.last_seen_at, '
      'world_id = excluded.world_id',
      [uri, ownerTable, ownerId, ownerField, worldId, ts],
    );
  }

  /// Belirli owner için tüm ref'leri sil (entity/character delete sonrası).
  /// Dönen list: silinen URI'ler — caller orphan check yapabilir.
  Future<List<String>> removeRefsForOwner(
    String ownerTable,
    String ownerId,
  ) async {
    final existing = await refsForOwner(ownerTable, ownerId);
    await _db.customStatement(
      'DELETE FROM asset_refs WHERE owner_table = ? AND owner_id = ?',
      [ownerTable, ownerId],
    );
    return existing.map((e) => e.uri).toSet().toList();
  }

  /// Sadece belirli (owner, field) tuple'ı için ref'leri sil — diff sırasında.
  Future<void> removeRef({
    required String uri,
    required String ownerTable,
    required String ownerId,
    String ownerField = '',
  }) async {
    await _db.customStatement(
      'DELETE FROM asset_refs WHERE uri = ? AND owner_table = ? '
      'AND owner_id = ? AND owner_field = ?',
      [uri, ownerTable, ownerId, ownerField],
    );
  }

  /// Bir owner'ın eski ref set'ini yeni set ile değiştir (diff).
  /// `[ReferenceIndexer]` bunu kullanır.
  ///
  /// Dönen [DiffResult]: eklenen + kaldırılan URI'ler. Kaldırılanlar için
  /// caller [isReferenced] ile orphan check yapar.
  Future<DiffResult> replaceRefsForOwner({
    required String ownerTable,
    required String ownerId,
    required Iterable<RefSlot> newRefs,
    String? worldId,
  }) async {
    // SS-6 fast path: the new snapshot carries no asset refs — the common case
    // for text-only entities/characters on every debounced save + inbound CDC.
    // Skip the diff transaction + per-row upsert loop; just clear any refs the
    // owner previously had (removeRefsForOwner is a single SELECT + DELETE and
    // returns the removed URIs for the orphan check).
    if (newRefs.isEmpty) {
      final removed = await removeRefsForOwner(ownerTable, ownerId);
      return DiffResult(added: const {}, removed: removed.toSet());
    }
    final old = await refsForOwner(ownerTable, ownerId);
    final oldSet = {
      for (final r in old) '${r.uri}|${r.ownerField}': r,
    };
    final newSet = <String, RefSlot>{
      for (final r in newRefs) '${r.uri}|${r.ownerField}': r,
    };

    final added = <String>{};
    final removed = <String>{};

    final now = DateTime.now();
    await _db.transaction(() async {
      // Insert/update new
      for (final entry in newSet.entries) {
        final slot = entry.value;
        await addRef(
          uri: slot.uri,
          ownerTable: ownerTable,
          ownerId: ownerId,
          ownerField: slot.ownerField,
          worldId: worldId,
          at: now,
        );
        if (!oldSet.containsKey(entry.key)) added.add(slot.uri);
      }
      // Delete vanished
      for (final entry in oldSet.entries) {
        if (!newSet.containsKey(entry.key)) {
          await removeRef(
            uri: entry.value.uri,
            ownerTable: ownerTable,
            ownerId: ownerId,
            ownerField: entry.value.ownerField,
          );
          removed.add(entry.value.uri);
        }
      }
    });

    return DiffResult(added: added, removed: removed);
  }

  /// Bir world'ün tüm ref'lerini sil (world leave / delete).
  Future<List<String>> removeRefsForWorld(String worldId) async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT uri FROM asset_refs WHERE world_id = ?',
      variables: [Variable<String>(worldId)],
    ).get();
    final uris = rows.map((r) => r.read<String>('uri')).toList();
    await _db.customStatement(
      'DELETE FROM asset_refs WHERE world_id = ?',
      [worldId],
    );
    return uris;
  }

  /// Toplam kayıt sayısı — istatistik için.
  Future<int> count() async {
    final rows = await _db
        .customSelect('SELECT COUNT(*) AS n FROM asset_refs')
        .get();
    if (rows.isEmpty) return 0;
    return rows.first.read<int>('n');
  }

  /// Tüm grafı sil — testler ve "Reset cache" için.
  Future<void> clearAll() async {
    await _db.customStatement('DELETE FROM asset_refs');
  }
}

/// Bir tek owner+field slot'undaki URI.
class RefSlot {
  const RefSlot({required this.uri, this.ownerField = ''});
  final String uri;
  final String ownerField;
}

/// Diff sonucu.
class DiffResult {
  DiffResult({required this.added, required this.removed});
  final Set<String> added;
  final Set<String> removed;
}

class AssetRefRow {
  AssetRefRow({
    required this.uri,
    required this.ownerTable,
    required this.ownerId,
    required this.ownerField,
    required this.worldId,
    required this.lastSeenAt,
  });

  final String uri;
  final String ownerTable;
  final String ownerId;
  final String ownerField;
  final String? worldId;
  final DateTime lastSeenAt;
}

final referenceGraphProvider = Provider<ReferenceGraph>((ref) {
  return ReferenceGraph(ref.watch(appDatabaseProvider));
});
