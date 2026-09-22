import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_format.dart';
import '../../data/database/app_database.dart';
import '../../domain/value_objects/asset_ref.dart';
import 'shared_media_courier.dart';

/// Faz 4 — yereldeki dünya satırlarını bulut aynasına gönderir.
///
/// **Kuyruk yok.** Gönderilecek işin listesi tutulmuyor; her satırın kendi
/// `updated_at`'i ve dünyanın `last_cloud_push_at` damgası yetiyor:
///
/// ```
/// gönder = bu dünyanın satırları, updated_at > last_cloud_push_at
/// ```
///
/// Çevrimdışıyken tur hiç koşmaz, damga ilerlemez, satırlar yerinde birikir;
/// ağ dönünce aynı tarama onları bulur. Yarıda kalan turda damga ilerlemediği
/// için gönderilenler bir kez daha gider — upsert idempotent olduğu için
/// zararsız (bkz. [pushWorld]).
///
/// Silmeler taramada görünmez (satır artık yok), onları `sync_tombstones`
/// hatırlıyor — DAO silme yollarında yazılır (`sync_stamp.dart`).
///
/// Zaman **istemcide** yazılır ve bulutta `now()` ile ezilmez (§2.8): geç
/// gelen çevrimdışı bir yazma, başka cihazın daha yeni verisini ezmesin.
class CloudPushService {
  CloudPushService({
    required AppDatabase db,
    required SupabaseClient client,
    this.courier,
  })  : _db = db,
        _client = client;

  final AppDatabase _db;
  final SupabaseClient _client;

  /// Yerel medya yollarını `dmt-content://{sha}` ref'ine çeviren dönüştürücü
  /// (Faz 3.5). Verilmezse satırlar yollarıyla gider — yalnız test yolu.
  final SharedMediaCourier? courier;

  /// Tek upsert'te giden satır sayısı. Bir parça reddedilirse suçluyu bulmak
  /// için tek tek denenir, o yüzden çok büyük olmamalı.
  static const int _chunk = 200;

  /// [worldId]'nin bulut aynasını günceller.
  ///
  /// [full] true ise damga yok sayılır ve dünyanın tamamı gönderilir — dünya
  /// ilk kez online yapıldığında ya da "yeniden gönder" denildiğinde.
  ///
  /// [dmOnlyKeys]: kategori slug → oyuncudan gizlenecek alan anahtarları
  /// (§2.6). Kararı Dart verir, uygulamayı `get_shared_entities` yapar.
  /// Bir kategori bu haritada **yoksa** buluta `NULL` yazılır ve o kart
  /// oyuncuya hiç dönmez; "sır yok" demek için boş liste gerekir.
  Future<CloudPushResult> pushWorld(
    String worldId, {
    Map<String, List<String>> dmOnlyKeys = const {},
    bool full = false,
  }) async {
    final world = await _db.worldsDao.getById(worldId);
    if (world == null || !world.isOnline) {
      return const CloudPushResult(skipped: true);
    }
    // Damga taramadan ÖNCE alınır: tur sürerken düzenlenen satırın zamanı
    // damgadan büyük olur ve bir sonraki tura kalır. Tersi kaybederdi.
    final cutoff = DateTime.now();
    final since = full
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : (world.lastCloudPushAt ?? DateTime.fromMillisecondsSinceEpoch(0));

    var pushed = 0;
    var deleted = 0;
    final rejected = <String>[];
    try {
      deleted = await _sendTombstones(worldId);
      for (final batch in await collect(worldId, since, dmOnlyKeys)) {
        await _upsert(batch.table, batch.rows, rejected);
        pushed += batch.rows.length;
      }
    } catch (e) {
      // Ağ / oturum hatası: damga ilerlemez, aynı satırlar sonraki turda
      // yeniden denenir.
      debugPrint('CloudPushService.pushWorld($worldId) aborted: '
          '${isOfflineError(e) ? 'offline' : e}');
      return CloudPushResult(
          pushed: pushed, deleted: deleted, rejected: rejected, error: e);
    }
    await _db.worldsDao.setCloudPushAt(worldId, cutoff);
    return CloudPushResult(
        pushed: pushed, deleted: deleted, rejected: rejected);
  }

  // ── Silmeler ─────────────────────────────────────────────────────────────

  /// Bekleyen tombstone'ları buluta uygular ve yerel kaydı düşürür.
  ///
  /// Silmeler upsert'lerden ÖNCE gider: aynı id silinip yeniden yaratıldıysa
  /// (full-replace import yolu) önce bulut satırı düşer, sonra tazesi yazılır.
  Future<int> _sendTombstones(String worldId) async {
    final rows = await _db.customSelect(
      'SELECT table_name, row_id FROM sync_tombstones WHERE world_id = ?',
      variables: [Variable<String>(worldId)],
    ).get();
    var n = 0;
    for (final r in rows) {
      final table = r.read<String>('table_name');
      final id = r.read<String>('row_id');
      // Satır yerelde geri gelmişse (sil + yeniden yarat: import / full
      // replace) tombstone artık yalan söylüyor. Bulut satırını silmek canlı
      // veriyi öldürürdü; onun yerine kayıt düşülür ve satır **şimdiyle
      // damgalanır** ki bu turun taramasına düşsün. Damgalamadan sadece
      // atlamak yetmez: geri gelen satır eski `updated_at` taşıyor olabilir
      // (LAN restamp, zaman koruyan import) ve taramaya hiç girmezdi.
      if (await _resurrected(table, id, worldId)) {
        await _db.customStatement(
          'DELETE FROM sync_tombstones WHERE table_name = ? AND row_id = ?',
          [table, id],
        );
        continue;
      }
      if (table == 'world_installed_packages') {
        await _client
            .from(table)
            .delete()
            .eq('world_id', worldId)
            .eq('package_id', id);
      } else {
        await _client.from(table).delete().eq('id', id);
      }
      await _db.customStatement(
        'DELETE FROM sync_tombstones WHERE table_name = ? AND row_id = ?',
        [table, id],
      );
      n++;
    }
    return n;
  }

  /// Tombstone yazıldıktan sonra aynı satır yerelde geri geldi mi? Geldiyse
  /// damgası tazelenir ve `true` döner.
  Future<bool> _resurrected(String cloudTable, String id, String worldId) async {
    final local = _localTableOf[cloudTable];
    if (local == null) return false;
    final where = cloudTable == 'world_installed_packages'
        ? 'world_id = ? AND package_id = ?'
        : 'id = ?';
    final args = cloudTable == 'world_installed_packages'
        ? <Object?>[worldId, id]
        : <Object?>[id];
    final hit = await _db
        .customSelect('SELECT 1 FROM $local WHERE $where',
            variables: [for (final a in args) Variable<String>(a as String)])
        .get();
    if (hit.isEmpty) return false;
    await _db.customStatement(
      'UPDATE $local SET updated_at = ? WHERE $where',
      [DateTime.now().millisecondsSinceEpoch ~/ 1000, ...args],
    );
    return true;
  }

  // ── Upsert ───────────────────────────────────────────────────────────────

  /// Gönderilecek satırları üretir — **ağ yok**. `pushWorld` bunu çağırıp
  /// sonucu yazar; test aynı çıktıyı doğrular.
  Future<List<CloudPushBatch>> collect(
    String worldId,
    DateTime since,
    Map<String, List<String>> dmOnlyKeys,
  ) async {
    final out = <CloudPushBatch>[];
    for (final t in _mirrorTables) {
      final rows = await _collectTable(t, worldId, since, dmOnlyKeys);
      if (rows.isNotEmpty) out.add(CloudPushBatch(t.cloud, rows));
    }
    final combatants = await _collectCombatants(worldId, since);
    if (combatants.isNotEmpty) {
      out.add(CloudPushBatch('world_combatants', combatants));
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _collectTable(
    _MirrorTable t,
    String worldId,
    DateTime since,
    Map<String, List<String>> dmOnlyKeys,
  ) async {
    final cols = [...t.cols, ...t.dateCols];
    final rows = await _db.customSelect(
      'SELECT ${cols.join(', ')} FROM ${t.local} '
      'WHERE world_id = ? AND updated_at > ?',
      variables: [
        Variable<String>(worldId),
        Variable<int>(since.millisecondsSinceEpoch ~/ 1000),
      ],
    ).get();
    if (rows.isEmpty) return const [];

    final payload = <Map<String, dynamic>>[];
    for (final r in rows) {
      final m = <String, dynamic>{};
      for (final c in t.cols) {
        m[c] = r.data[c];
      }
      for (final c in t.dateCols) {
        final iso = _isoOf(r.data[c]);
        // NOT NULL + DEFAULT now() kolonlara açık null gönderilemez; anahtarı
        // hiç yazmayıp sunucu varsayılanına bırakıyoruz.
        if (iso != null) m[c] = iso;
      }
      for (final c in t.boolCols) {
        // SQLite bool'u 0/1 int tutar, Postgres kolonu boolean.
        final v = m[c];
        if (v is int) m[c] = v != 0;
      }
      for (final c in t.mediaCols) {
        final v = m[c];
        if (v is String && v.isNotEmpty) m[c] = await _contentRefs(v);
      }
      if (t.ownerNull) m['owner_id'] = null;
      if (t.cloud == 'world_entities') {
        final slug = r.data['category_slug'] as String? ?? '';
        m['dm_only_keys'] = dmOnlyKeys[slug];
      }
      payload.add(m);
    }
    return payload;
  }

  /// Combatant'ın dünyası yerelde encounter üzerinden gelir (yerel tabloda
  /// `world_id` yok) ve durum etkileri bulutta ayrı satır değil, kolon.
  Future<List<Map<String, dynamic>>> _collectCombatants(
    String worldId,
    DateTime since,
  ) async {
    final rows = await _db.customSelect(
      'SELECT c.id, c.encounter_id, c.entity_id, c.name, c.init, c.ac, '
      'c.hp, c.max_hp, c.token_id, c.sort_order, c.updated_at '
      'FROM combatants c JOIN encounters e ON e.id = c.encounter_id '
      'WHERE e.world_id = ? AND c.updated_at > ?',
      variables: [
        Variable<String>(worldId),
        Variable<int>(since.millisecondsSinceEpoch ~/ 1000),
      ],
    ).get();
    if (rows.isEmpty) return const [];

    final ids = [for (final r in rows) r.read<String>('id')];
    final conds = <String, List<Map<String, dynamic>>>{};
    final placeholders = List.filled(ids.length, '?').join(', ');
    final condRows = await _db.customSelect(
      'SELECT combatant_id, name, duration, initial_duration, entity_id '
      'FROM combat_conditions WHERE combatant_id IN ($placeholders)',
      variables: [for (final id in ids) Variable<String>(id)],
    ).get();
    for (final c in condRows) {
      (conds[c.read<String>('combatant_id')] ??= []).add({
        'name': c.data['name'],
        'duration': c.data['duration'],
        'initial_duration': c.data['initial_duration'],
        'entity_id': c.data['entity_id'],
      });
    }

    return <Map<String, dynamic>>[
      for (final r in rows)
        {
          for (final e in r.data.entries)
            if (e.key != 'updated_at') e.key: e.value,
          'world_id': worldId,
          'updated_at': _isoOf(r.data['updated_at']),
          'conditions_json':
              jsonEncode(conds[r.read<String>('id')] ?? const []),
        }
    ];
  }

  /// Parçayı yazar. Ağ hatası yukarı çıkar (tur iptal olur, damga ilerlemez);
  /// veri/kota/RLS reddi ise suçlu satır tek tek denenerek bulunur, atlanır ve
  /// [rejected]'e yazılır — **tek bir kart bütün dünyanın senkronunu
  /// kilitlemesin** (§"kota reddi yerel yazmayı durdurmaz").
  Future<void> _upsert(
    String table,
    List<Map<String, dynamic>> rows,
    List<String> rejected,
  ) async {
    for (var i = 0; i < rows.length; i += _chunk) {
      final slice = rows.sublist(i, (i + _chunk).clamp(0, rows.length));
      try {
        await _client.from(table).upsert(slice);
      } catch (e) {
        if (isOfflineError(e) || slice.length == 1 && e is! PostgrestException) {
          rethrow;
        }
        if (slice.length == 1) {
          rejected.add('$table/${slice.first['id'] ?? ''}');
          debugPrint('CloudPushService: satır reddedildi $table '
              '${slice.first['id']}: $e');
          continue;
        }
        for (final row in slice) {
          await _upsert(table, [row], rejected);
        }
      }
    }
  }

  // ── Medya ────────────────────────────────────────────────────────────────

  /// Gövdedeki **yerel** medya yollarını `dmt-content://{sha}{ext}` ile
  /// değiştirir (Faz 3.5). Yerel satır yollarını korur; çeviri yalnız giden
  /// kopyada. Okunamayan dosya olduğu gibi bırakılır.
  Future<String> _contentRefs(String raw) async {
    final c = courier;
    if (c == null) return raw;
    if (!raw.startsWith('{') && !raw.startsWith('[')) {
      return await c.refFor(raw) ?? raw;
    }
    try {
      final decoded = jsonDecode(raw);
      final out = await _walk(decoded, c);
      return jsonEncode(out);
    } catch (_) {
      return raw;
    }
  }

  Future<Object?> _walk(Object? node, SharedMediaCourier c) async {
    if (node is String) {
      if (node.isEmpty || !p.isAbsolute(node) || !AssetRef(node).isLocal) {
        return node;
      }
      return await c.refFor(node) ?? node;
    }
    if (node is Map) {
      return {
        for (final e in node.entries) e.key: await _walk(e.value, c),
      };
    }
    if (node is List) {
      return [for (final v in node) await _walk(v, c)];
    }
    return node;
  }

  /// Drift `dateTime()` kolonları unix **saniye**; Postgres ISO bekliyor.
  static String? _isoOf(Object? v) => v is int
      ? DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true)
          .toIso8601String()
      : null;
}

/// Tek bir bulut tablosuna gidecek satırlar.
class CloudPushBatch {
  const CloudPushBatch(this.table, this.rows);
  final String table;
  final List<Map<String, dynamic>> rows;
}

/// Bir turun sonucu. [rejected] boş değilse o satırlar buluta **çıkmadı** ve
/// damga yine de ilerledi — yeniden düzenlenene kadar bulutta eski hâlleri
/// kalır.
class CloudPushResult {
  const CloudPushResult({
    this.pushed = 0,
    this.deleted = 0,
    this.rejected = const [],
    this.skipped = false,
    this.error,
  });

  final int pushed;
  final int deleted;
  final List<String> rejected;
  final bool skipped;
  final Object? error;

  bool get ok => !skipped && error == null;
}

/// Yerel tablo → bulut tablosu eşlemesi. Kolon adları iki tarafta da aynı
/// (Drift SQL'i snake_case üretiyor), o yüzden eşleme bir isim listesi.
class _MirrorTable {
  const _MirrorTable(
    this.local,
    this.cloud, {
    required this.cols,
    this.dateCols = const ['updated_at'],
    this.mediaCols = const [],
    this.boolCols = const [],
    this.ownerNull = false,
  });

  final String local;
  final String cloud;
  final List<String> cols;
  final List<String> dateCols;

  /// Yerel yol taşıyabilen kolonlar — gönderilirken içerik ref'ine çevrilir.
  final List<String> mediaCols;

  /// SQLite'ta 0/1 int, Postgres'te `boolean` olan kolonlar.
  final List<String> boolCols;

  /// Mind map: DM'in satırında `owner_id` NULL, oyuncununkinde dolu (§2.9).
  final bool ownerNull;
}

/// Bulut tablosu → yerel tablo. Tombstone'un yalan söyleyip söylemediğini
/// (satır geri geldi mi) sormak için gerekiyor.
final Map<String, String> _localTableOf = {
  for (final t in _mirrorTables) t.cloud: t.local,
  'world_combatants': 'combatants',
};

const List<_MirrorTable> _mirrorTables = [
  _MirrorTable(
    'world_entities',
    'world_entities',
    cols: [
      'id', 'world_id', 'category_slug', 'name', 'source', 'description',
      'image_path', 'images_json', 'tags_json', 'dm_notes', 'pdfs_json',
      'location_id', 'fields_json', 'package_id', 'package_entity_id',
      'linked',
    ],
    dateCols: ['created_at', 'updated_at'],
    mediaCols: ['image_path', 'images_json', 'fields_json'],
    boolCols: ['linked'],
  ),
  _MirrorTable('world_settings', 'world_settings',
      cols: ['world_id', 'settings_json'], mediaCols: ['settings_json']),
  _MirrorTable('world_map_data', 'world_map_data',
      cols: ['world_id', 'data_json'], mediaCols: ['data_json']),
  _MirrorTable('world_sessions', 'world_sessions',
      cols: ['id', 'world_id', 'name', 'data_json', 'is_active', 'sort_order'],
      mediaCols: ['data_json'],
      boolCols: ['is_active']),
  _MirrorTable(
    'world_mind_map_nodes',
    'world_mind_map_nodes',
    cols: [
      'id', 'world_id', 'map_id', 'label', 'node_type', 'x', 'y', 'width',
      'height', 'entity_id', 'image_url', 'content', 'style_json', 'color',
    ],
    mediaCols: ['image_url'],
    ownerNull: true,
  ),
  _MirrorTable(
    'world_mind_map_edges',
    'world_mind_map_edges',
    cols: ['id', 'world_id', 'map_id', 'source_id', 'target_id', 'label',
        'style_json'],
    ownerNull: true,
  ),
  _MirrorTable(
    'encounters',
    'world_encounters',
    cols: [
      'id', 'world_id', 'session_id', 'name', 'map_path', 'token_size',
      'grid_size', 'grid_visible', 'grid_snap', 'feet_per_cell', 'fog_data',
      'annotation_data', 'encounter_layout_id', 'turn_index', 'round',
      'token_positions_json', 'token_size_multipliers_json', 'sort_order',
    ],
    dateCols: ['created_at', 'updated_at'],
    mediaCols: ['map_path'],
    boolCols: ['grid_visible', 'grid_snap'],
  ),
  _MirrorTable('map_pins', 'world_map_pins',
      cols: ['id', 'world_id', 'x', 'y', 'label', 'pin_type', 'entity_id',
          'note', 'color', 'style_json']),
  _MirrorTable('timeline_pins', 'world_timeline_pins',
      cols: ['id', 'world_id', 'x', 'y', 'day', 'note', 'entity_ids_json',
          'session_id', 'parent_ids_json', 'color']),
  _MirrorTable('installed_packages', 'world_installed_packages',
      cols: ['world_id', 'package_id', 'package_name', 'package_version'],
      dateCols: ['installed_at', 'last_synced_at', 'updated_at']),
];
