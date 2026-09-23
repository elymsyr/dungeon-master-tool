import 'dart:convert';

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, Value, Variable;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_format.dart';
import '../../data/database/app_database.dart';
import '../../domain/value_objects/asset_ref.dart';
import 'cloud_mirror_tables.dart';
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
    final revs = <int>[];
    try {
      deleted = await _sendTombstones(worldId);
      for (final batch in await collect(worldId, since, dmOnlyKeys)) {
        await _upsert(batch.table, batch.rows, rejected, revs);
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
    // Faz 5b — kendi yazdıklarımızın sinyali bize de geliyor. Tur bulutta
    // boşluksuz bir revizyon dizisi bıraktıysa aradaki her yazma bizim ve
    // yerel zaten o halde: pull damgası dizinin sonuna ilerler, sinyal gelince
    // kendi satırlarımızı geri indirmeyiz. Silmenin tombstone revizyonu
    // DELETE'ten dönmüyor — silme varsa dizi bilinemez, pull getirir.
    final end = deleted == 0 ? ownRunEnd(world.cloudRevision, revs) : null;
    if (end != null) {
      // Koşullu: tur sürerken bir pull damgayı ilerlettiyse ona dokunma.
      await (_db.update(_db.worlds)
            ..where((w) =>
                w.id.equals(worldId) &
                w.cloudRevision.equals(world.cloudRevision)))
          .write(WorldsCompanion(cloudRevision: Value(end)));
    }
    return CloudPushResult(
        pushed: pushed, deleted: deleted, rejected: rejected);
  }

  /// Push'un geri aldığı revizyonlar [base]'in hemen ardından boşluksuz bir
  /// dizi mi? Öyleyse dizinin sonu döner, değilse null — araya başka bir yazar
  /// (öteki cihaz, oyuncunun karakteri, paylaşım) girmiş demektir ve onu pull
  /// getirmeli.
  ///
  /// [base]'den küçük revizyonlar echo guard'ın yazmadığı satırlardır (içerik
  /// aynı, sayaç kıpırdamadı); hesaba katılmaz.
  static int? ownRunEnd(int base, Iterable<int> revs) {
    final own = revs.where((r) => r > base).toSet().toList()..sort();
    if (own.isEmpty) return null;
    return own.last - base == own.length ? own.last : null;
  }

  /// [packageId]'nin bulut aynasını günceller — aynı watermark, kapsam dünya
  /// değil **kullanıcı**: satırlar `owner_id`'ye bağlı, revizyon sayacı
  /// paketin kendi satırında (§2.2 BÖLÜM D).
  ///
  /// Pakette `dm_only_keys` yok: paket oyuncuyla paylaşılmıyor, sahibinden
  /// başkası RLS'e takılıyor.
  Future<CloudPushResult> pushPackage(String packageId, {bool full = false}) async {
    final pkg = await _db.packagesDao.getById(packageId);
    final ownerId = _client.auth.currentUser?.id;
    if (pkg == null || !pkg.isOnline || ownerId == null) {
      return const CloudPushResult(skipped: true);
    }
    final cutoff = DateTime.now();
    final since = full
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : (pkg.lastCloudPushAt ?? DateTime.fromMillisecondsSinceEpoch(0));

    // İlk yayında paketin satırı yaratılır; sonrasında yalnız güncellenir.
    // Upsert'le yazılsaydı, öbür cihazın buluttan sildiği (ya da "Yerele al"
    // dediği) paketi bu cihazın ilk turu yeniden yaratırdı.
    final first = full || pkg.lastCloudPushAt == null;

    var pushed = 0;
    var deleted = 0;
    final rejected = <String>[];
    try {
      deleted = await _sendTombstones(packageId);
      for (final batch in await collectPackage(packageId, since, ownerId)) {
        if (batch.table == 'user_packages' && !first) {
          if (!await _updatePackageRow(packageId, batch.rows.single)) {
            // Bulutta yok: diriltme, yerelde offline'a düş. Damga da
            // sıfırlanıyor — yeniden online yapılırsa her şey bir kez daha
            // gider.
            await _db.packagesDao.setOnline(packageId, false);
            return const CloudPushResult(skipped: true);
          }
          pushed++;
          continue;
        }
        await _upsert(batch.table, batch.rows, rejected, []);
        pushed += batch.rows.length;
      }
    } catch (e) {
      debugPrint('CloudPushService.pushPackage($packageId) aborted: '
          '${isOfflineError(e) ? 'offline' : e}');
      return CloudPushResult(
          pushed: pushed, deleted: deleted, rejected: rejected, error: e);
    }
    await _db.packagesDao.setCloudPushAt(packageId, cutoff);
    return CloudPushResult(
        pushed: pushed, deleted: deleted, rejected: rejected);
  }

  /// Paketin bulut satırını yalnız günceller; satır bulutta yoksa false.
  ///
  /// Boş dönüş iki şey olabilir: satır yok, ya da 097'nin LWW guard'ı bu
  /// eski hâli atladı (bulutta daha yeni bir düzenleme var). İkincisi silme
  /// değil — ayırmak için bir okuma daha.
  Future<bool> _updatePackageRow(String id, Map<String, dynamic> row) async {
    final hit = await _client
        .from('user_packages')
        .update(row)
        .eq('id', id)
        .select('id');
    if (hit.isNotEmpty) return true;
    final still = await _client
        .from('user_packages')
        .select('id')
        .eq('id', id)
        .maybeSingle();
    return still != null;
  }

  /// Paketi buluttan kaldırır. Çocuk satırlar `ON DELETE CASCADE` ile gider;
  /// bekleyen tombstone'lar da anlamsızlaştığı için düşer.
  Future<void> unpublishPackage(String packageId) async {
    await _client.from('user_packages').delete().eq('id', packageId);
    await _db.customStatement(
        'DELETE FROM sync_tombstones WHERE world_id = ?', [packageId]);
  }

  // ── Silmeler ─────────────────────────────────────────────────────────────

  /// Bekleyen tombstone'ları buluta uygular ve yerel kaydı düşürür.
  ///
  /// Silmeler upsert'lerden ÖNCE gider: aynı id silinip yeniden yaratıldıysa
  /// (full-replace import yolu) önce bulut satırı düşer, sonra tazesi yazılır.
  Future<int> _sendTombstones(String scopeId) async {
    final rows = await _db.customSelect(
      'SELECT table_name, row_id FROM sync_tombstones WHERE world_id = ?',
      variables: [Variable<String>(scopeId)],
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
      if (await _resurrected(table, id, scopeId)) {
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
            .eq('world_id', scopeId)
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
  Future<bool> _resurrected(String cloudTable, String id, String scopeId) async {
    final local = localTableOf[cloudTable];
    if (local == null) return false;
    final where = cloudTable == 'world_installed_packages'
        ? 'world_id = ? AND package_id = ?'
        : 'id = ?';
    final args = cloudTable == 'world_installed_packages'
        ? <Object?>[scopeId, id]
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
    for (final t in mirrorTables) {
      final rows = await _collectTable(t, worldId, since, dmOnlyKeys);
      if (rows.isNotEmpty) out.add(CloudPushBatch(t.cloud, rows));
    }
    final combatants = await _collectCombatants(worldId, since);
    if (combatants.isNotEmpty) {
      out.add(CloudPushBatch('world_combatants', combatants));
    }
    return out;
  }

  /// Paketin gönderilecek satırları — **ağ yok**, `collect`'in eşi.
  Future<List<CloudPushBatch>> collectPackage(
    String packageId,
    DateTime since,
    String ownerId,
  ) async {
    final out = <CloudPushBatch>[];
    for (final t in packageTables) {
      final rows = await _collectTable(t, packageId, since, const {},
          ownerId: ownerId);
      if (rows.isNotEmpty) out.add(CloudPushBatch(t.cloud, rows));
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _collectTable(
    MirrorTable t,
    String scopeId,
    DateTime since,
    Map<String, List<String>> dmOnlyKeys, {
    String? ownerId,
  }) async {
    final cols = [...t.cols, ...t.dateCols];
    // `sinceAll` tabloyu damgadan bağımsız her tur gönderir: paketin kendi
    // satırı çocuklarının FK hedefi, bulutta yoksa çocuklar reddedilirdi.
    final rows = await _db.customSelect(
      'SELECT ${cols.join(', ')} FROM ${t.local} '
      'WHERE ${t.scope} = ?${t.sinceAll ? '' : ' AND updated_at > ?'}',
      variables: [
        Variable<String>(scopeId),
        if (!t.sinceAll) Variable<int>(since.millisecondsSinceEpoch ~/ 1000),
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
      for (final c in t.jsonCols) {
        // Yerelde TEXT, bulutta jsonb — string gitseydi jsonb'ye tırnaklı
        // bir skaler olarak yazılırdı.
        final v = m[c];
        if (v is String) m[c] = v.isEmpty ? null : jsonDecode(v);
      }
      for (final e in t.rename.entries) {
        if (m.containsKey(e.key)) m[e.value] = m.remove(e.key);
      }
      switch (t.owner) {
        case MirrorOwner.own:
          break;
        // Mind map: DM'in satırında NULL, oyuncununkinde dolu (§2.9).
        case MirrorOwner.nul:
          m['owner_id'] = null;
        // Paket tabloları kullanıcı kapsamlı; RLS tek kolona bakıyor.
        case MirrorOwner.self:
          m['owner_id'] = ownerId;
      }
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
  ///
  /// Yazılan satırların bulut revizyonları [revs]'e eklenir. 097'nin LWW
  /// guard'ının atladığı satır (bulutta daha yeni düzenleme var) dönmez.
  Future<void> _upsert(
    String table,
    List<Map<String, dynamic>> rows,
    List<String> rejected,
    List<int> revs,
  ) async {
    for (var i = 0; i < rows.length; i += _chunk) {
      final slice = rows.sublist(i, (i + _chunk).clamp(0, rows.length));
      try {
        final back = await _client.from(table).upsert(slice).select('revision');
        for (final r in back) {
          final v = r['revision'];
          if (v is num) revs.add(v.toInt());
        }
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
          await _upsert(table, [row], rejected, revs);
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
