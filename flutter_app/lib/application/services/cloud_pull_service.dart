import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_format.dart';
import '../../data/database/app_database.dart';
import '../../domain/value_objects/asset_ref.dart';
import 'cloud_mirror_tables.dart';
import 'content_ref_index.dart';

/// Faz 5a — bulut aynasındaki satırları yerele geri okur. [CloudPushService]'in
/// tersi ve aynı bildirimi (`cloud_mirror_tables.dart`) ters yönde okuyor.
///
/// **CDC yok** (§2.3). İstemci `get_world_delta(world, since, limit)` çağırır;
/// sunucu o revizyondan sonra değişen satırları ve aynı pencerenin
/// tombstone'larını tek pakette döner. Damga `worlds.cloud_revision`.
///
/// **Sıra önemli: önce push, sonra pull.** Pull satırı bulutun `updated_at`'i
/// ile yazıyor; o zaman push damgasından büyük kalırsa push aynı satırı geri
/// gönderir. Push'un damgası tur başında `now()`'a çekildiği için, ondan önce
/// düzenlenmiş her uzak satır bu tuzağa düşmez. Düşen (saat kayması) olursa da
/// zararsız: 096'nın echo guard'ı aynı içeriğin revizyonu artırmasını
/// engelliyor, dolayısıyla karşı cihaz yeniden uyanmaz.
///
/// **Çatışma: son düzenleyen kazanır** (§2.8). Karşılaştırma varış zamanıyla
/// değil düzenleme zamanıyla: yerel satırın `updated_at`'i buluttan büyük ya
/// da eşitse gelen satır **atılır**. Aynısı silme için de geçerli — tombstone'un
/// `deleted_at`'i yerel düzenlemeden eskiyse satır silinmez, bir sonraki push
/// onu buluta geri koyar.
class CloudPullService {
  CloudPullService({
    required AppDatabase db,
    required SupabaseClient client,
    this.index,
  })  : _db = db,
        _client = client;

  final AppDatabase _db;
  final SupabaseClient _client;

  /// `dmt-content://{sha}` → bu cihazdaki dosya (Faz 3.5). Verilmezse ref'ler
  /// olduğu gibi yazılır — `AssetRefResolver` onları zaten çözebiliyor.
  final ContentRefIndex? index;

  /// Sunucudan tek çağrıda istenen tablo başına satır sayısı.
  static const int _page = 500;

  /// Bir `pullWorld` çağrısındaki en fazla tur. Sunucu `complete` demeyi
  /// beceremezse (beklenmez) sonsuz döngü olmasın diye.
  static const int _maxRounds = 200;

  /// [worldId]'nin bulut aynasını yerele çeker.
  ///
  /// [full] true ise damga yok sayılır ve dünyanın tamamı istenir — yeni
  /// cihazda ilk senkron ya da "yeniden çek".
  Future<CloudPullResult> pullWorld(String worldId, {bool full = false}) async {
    final world = await _db.worldsDao.getById(worldId);
    if (world == null || !world.isOnline) {
      return const CloudPullResult(skipped: true);
    }
    return _pullFrom(worldId, full ? 0 : world.cloudRevision);
  }

  /// Sayfa döngüsü; dünyada ve pakette aynı. [onProgress] 0–1 arası: inen
  /// revizyon / bulut başı.
  Future<CloudPullResult> _pullFrom(
    String scopeId,
    int since, {
    bool package = false,
    void Function(double progress)? onProgress,
  }) async {
    var applied = 0;
    var removed = 0;
    try {
      for (var round = 0; round < _maxRounds; round++) {
        final raw = await _client.rpc(
          package ? 'get_package_delta' : 'get_world_delta',
          params: {
            package ? 'p_package' : 'p_world': scopeId,
            'p_since': since,
            'p_limit': _page,
          },
        );
        final delta = CloudDelta.fromJson(raw as Map<String, dynamic>);
        // Sunucu ilerlemediyse (damga zaten başta) tur biter.
        if (delta.revision <= since && delta.complete) break;
        final res = await apply(scopeId, delta, package: package);
        applied += res.applied;
        removed += res.removed;
        since = delta.revision;
        if (delta.head > 0) onProgress?.call(since / delta.head);
        if (delta.complete) break;
      }
    } catch (e) {
      // Ağ / oturum hatası: damga uygulanan sayfaya kadar ilerledi, kalanı
      // bir sonraki tur getirir.
      debugPrint('CloudPullService pull($scopeId) aborted: '
          '${isOfflineError(e) ? 'offline' : e}');
      return CloudPullResult(
          applied: applied, removed: removed, revision: since, error: e);
    }
    return CloudPullResult(applied: applied, removed: removed, revision: since);
  }

  // ── Faz 5c — bu cihazda olmayan dünya ────────────────────────────────────

  /// Bu kullanıcının bulutta olup bu cihazda olmayan dünyaları.
  ///
  /// Sayacı 0 olan dünya listelenmez: aynası hiç yazılmamış (Faz 4'ten önce
  /// yalnız multiplayer için yayınlanmış) bir dünyayı indirmek boş bir kabuk
  /// verirdi.
  Future<List<CloudWorld>> listCloudOnlyWorlds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('worlds')
        .select('id, world_name, template_id, template_hash, '
            'world_revisions(revision)')
        .eq('owner_id', uid);
    final local = {for (final w in await _db.worldsDao.getAll()) w.id};
    return [
      for (final r in rows)
        if (!local.contains(r['id']) && _revisionOf(r['world_revisions']) > 0)
          (
            id: r['id'] as String,
            name: r['world_name'] as String? ?? '',
            templateId: r['template_id'] as String?,
            templateHash: r['template_hash'] as String?,
          ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Bulutta olup bu cihazda olmayan dünyayı indirir.
  ///
  /// **`worlds` satırı en son yazılır.** Satırlar sayfa sayfa iniyor; kabuk
  /// yokken dünya hiçbir listede görünmüyor, dolayısıyla yarım inmiş bir
  /// dünya açılamıyor. Açılabilseydi varsayılan ayarlarını "şimdi" damgasıyla
  /// kaydeder, LWW'yi kazanır ve buluttaki gerçek ayarları (şema, mind map)
  /// ezerdi. Yarıda kalan indirme yerelde iz bırakmaz — bir sonraki deneme
  /// baştan.
  ///
  /// Push damgası indirmenin başlangıcına çekilir: inen satırlar ondan eski,
  /// ilk açılışta buluta geri gönderilmezler.
  Future<CloudPullResult> downloadWorld(
    CloudWorld world, {
    void Function(double progress)? onProgress,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || await _db.worldsDao.getById(world.id) != null) {
      return const CloudPullResult(skipped: true);
    }
    final cutoff = DateTime.now();
    final sw = Stopwatch()..start();
    var res = await _pullFrom(world.id, 0, onProgress: onProgress);
    debugPrint('CloudSync: indirme ${world.id} +${res.applied} '
        '${sw.elapsedMilliseconds} ms${res.error != null ? ' hata=${res.error}' : ''}');
    // Dünya görünmüyorsa (başka hesap, arada silinmiş) RPC hata atmıyor, boş
    // ve "tamam" bir delta dönüyor — kabuk yazılsa boş bir dünya doğardı.
    if (res.ok && res.revision == 0) {
      res = CloudPullResult(error: StateError('World not found: ${world.id}'));
    }
    if (!res.ok) {
      await _discard(world.id);
      return res;
    }
    await _db.worldsDao.upsert(WorldsCompanion.insert(
      id: world.id,
      worldName: world.name,
      ownerId: Value(uid),
      templateId: Value(world.templateId),
      templateHash: Value(world.templateHash),
      isOnline: const Value(true),
      cloudRevision: Value(res.revision),
      lastCloudPushAt: Value(cutoff),
    ));
    return res;
  }

  /// Yarım inmiş dünyanın satırlarını siler. DAO'lardan **geçmez**: DAO
  /// silmesi `sync_tombstones` bırakır ve bir sonraki push buluttaki gerçek
  /// satırları silerdi.
  Future<void> _discard(String worldId) async {
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM combat_conditions WHERE combatant_id IN '
        '(SELECT c.id FROM combatants c JOIN encounters e '
        'ON e.id = c.encounter_id WHERE e.world_id = ?)',
        [worldId],
      );
      await _db.customStatement(
        'DELETE FROM combatants WHERE encounter_id IN '
        '(SELECT id FROM encounters WHERE world_id = ?)',
        [worldId],
      );
      for (final t in mirrorTables) {
        await _db.customStatement(
            'DELETE FROM ${t.local} WHERE world_id = ?', [worldId]);
      }
    });
  }

  // ── Faz 5c — paket ───────────────────────────────────────────────────────

  /// [packageId]'nin bulut aynasını yerele çeker — [pullWorld]'ün eşi, damga
  /// `packages.cloud_revision`.
  Future<CloudPullResult> pullPackage(String packageId,
      {bool full = false}) async {
    final pkg = await _db.packagesDao.getById(packageId);
    if (pkg == null || !pkg.isOnline) {
      return const CloudPullResult(skipped: true);
    }
    return _pullFrom(packageId, full ? 0 : pkg.cloudRevision, package: true);
  }

  /// Bu kullanıcının bulutta olup bu cihazda olmayan paketleri.
  Future<List<CloudPackage>> listCloudOnlyPackages() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('user_packages')
        .select('id, name, revision')
        .eq('owner_id', uid);
    final local = {for (final p in await _db.packagesDao.getAll()) p.id};
    return [
      for (final r in rows)
        if (!local.contains(r['id']) && ((r['revision'] as num?) ?? 0) > 0)
          (id: r['id'] as String, name: r['name'] as String? ?? ''),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Bulutta olup bu cihazda olmayan paketi indirir — [downloadWorld]'ün eşi.
  ///
  /// Paketin kendi satırı `get_package_delta`'nın son sayfasında geliyor ve
  /// [apply] onu sayfanın en sonunda yazıyor: yarım inen paket hub'da hiç
  /// görünmez. Yerelde paket adı UNIQUE; aynı adlı başka bir paket varsa
  /// indirme hiç başlamaz ([CloudPackageNameTaken]).
  Future<CloudPullResult> downloadPackage(
    CloudPackage package, {
    void Function(double progress)? onProgress,
  }) async {
    if (_client.auth.currentUser == null ||
        await _db.packagesDao.getById(package.id) != null) {
      return const CloudPullResult(skipped: true);
    }
    if (await _db.packagesDao.getByName(package.name) != null) {
      return CloudPullResult(error: CloudPackageNameTaken(package.name));
    }
    final cutoff = DateTime.now();
    var res = await _pullFrom(package.id, 0,
        package: true, onProgress: onProgress);
    if (res.ok && await _db.packagesDao.getById(package.id) == null) {
      res = CloudPullResult(
          error: StateError('Package not found: ${package.id}'));
    }
    if (!res.ok) {
      await _db.transaction(() async {
        for (final t in packageTables) {
          await _db.customStatement(
              'DELETE FROM ${t.local} WHERE ${t.scope} = ?', [package.id]);
        }
      });
      return res;
    }
    await (_db.update(_db.packages)..where((p) => p.id.equals(package.id)))
        .write(PackagesCompanion(
      isOnline: const Value(true),
      cloudRevision: Value(res.revision),
      lastCloudPushAt: Value(cutoff),
    ));
    return res;
  }

  /// PostgREST bire-bir gömmeyi nesne, bazı sürümler tek elemanlı liste
  /// olarak döndürüyor.
  static int _revisionOf(Object? embed) {
    final row = embed is List ? (embed.isEmpty ? null : embed.first) : embed;
    final v = row is Map ? row['revision'] : null;
    return v is num ? v.toInt() : 0;
  }

  /// Bir delta sayfasını yerele uygular — **ağ yok**, testin girdiği kapı
  /// ([CloudPushService.collect]'in eşi). [package] ise kapsam paket: tablolar
  /// [packageTables], damga `packages.cloud_revision`.
  ///
  /// Sayfa ve damga **tek transaction**: yarıda kalan uygulama damgayı
  /// ilerletmez, aynı sayfa yeniden gelir.
  Future<CloudPullApplied> apply(
    String scopeId,
    CloudDelta delta, {
    bool package = false,
  }) async {
    var applied = 0;
    var removed = 0;
    // Paketin kendi satırı EN SON: çocuklardan önce yazılsaydı yarım inen
    // paket hub listesinde görünürdü (push'ta tersine, FK yüzünden önce).
    final tables = package
        ? [...packageTables.skip(1), packageTables.first]
        : mirrorTables;
    // Medya çözümü ağ değil ama dosya sistemi — transaction dışında yapılıyor
    // ki yazma kilidi disk I/O'su kadar açık kalmasın.
    final prepared = <MirrorTable, List<Map<String, Object?>>>{};
    for (final t in tables) {
      final rows = delta.rowsOf(t.cloud);
      if (rows.isEmpty) continue;
      prepared[t] = [for (final r in rows) await _toLocal(t, r)];
    }
    final combatants =
        package ? const <Map<String, dynamic>>[] : delta.rowsOf('world_combatants');

    await _db.transaction(() async {
      // Silmeler önce: aynı id silinip yeniden yaratıldıysa tazesi kalsın.
      for (final stone in delta.tombstones) {
        if (await _applyTombstone(scopeId, stone)) removed++;
      }
      for (final e in prepared.entries) {
        for (final row in e.value) {
          if (await _write(e.key.local, e.key.key, row)) applied++;
        }
      }
      for (final row in combatants) {
        if (await _writeCombatant(row)) applied++;
      }
      if (package) {
        await (_db.update(_db.packages)..where((p) => p.id.equals(scopeId)))
            .write(PackagesCompanion(cloudRevision: Value(delta.revision)));
      } else {
        await (_db.update(_db.worlds)..where((w) => w.id.equals(scopeId)))
            .write(WorldsCompanion(cloudRevision: Value(delta.revision)));
      }
    });
    return CloudPullApplied(applied: applied, removed: removed);
  }

  // ── Satır yazma ──────────────────────────────────────────────────────────

  /// Bulut satırını yerel kolonlara çevirir. Bilinmeyen kolonlar (`revision`,
  /// `dm_only_keys`, kapsam dışı `owner_id`) düşer — yerel şemada karşılıkları
  /// yok ve pull'un onlara ihtiyacı yok.
  Future<Map<String, Object?>> _toLocal(
      MirrorTable t, Map<String, dynamic> cloud) async {
    final out = <String, Object?>{};
    for (final c in [...t.cols, ...t.dateCols]) {
      // `owner_id` yerel satırda yoksa (mind map, paket tabloları) atlanır.
      if (c == 'owner_id' && t.owner != MirrorOwner.own) continue;
      final cloudCol = t.rename[c] ?? c;
      if (!cloud.containsKey(cloudCol)) continue;
      var v = cloud[cloudCol];
      if (t.dateCols.contains(c)) {
        v = _unixOf(v);
      } else if (t.boolCols.contains(c)) {
        v = (v == true) ? 1 : 0;
      } else if (t.jsonCols.contains(c)) {
        v = v == null ? '' : jsonEncode(v);
      }
      if (v is String && t.mediaCols.contains(c)) {
        v = await _localPaths(v);
      }
      out[c] = v;
    }
    return out;
  }

  /// Yerele yazar — **son düzenleyen kazanır**. Yereldeki satır aynı ya da
  /// daha yeniyse dokunulmaz.
  ///
  /// `INSERT ... ON CONFLICT DO UPDATE` kullanılıyor, `INSERT OR REPLACE`
  /// değil: ikincisi satırın tamamını değiştirir ve aynalanmayan yerel
  /// kolonları (`world_characters.is_online` gibi) varsayılana düşürürdü.
  Future<bool> _write(
      String table, List<String> key, Map<String, Object?> row) async {
    final incoming = row['updated_at'];
    if (incoming is int) {
      final where = [for (final k in key) '$k = ?'].join(' AND ');
      final hit = await _db.customSelect(
        'SELECT updated_at FROM $table WHERE $where',
        variables: [for (final k in key) Variable<String>(row[k] as String)],
      ).getSingleOrNull();
      final local = hit?.data['updated_at'];
      if (local is int && local >= incoming) return false;
    }
    final cols = row.keys.toList();
    final sets = [
      for (final c in cols)
        if (!key.contains(c)) '$c = excluded.$c',
    ];
    await _db.customStatement(
      'INSERT INTO $table (${cols.join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')}) '
      'ON CONFLICT (${key.join(', ')}) DO UPDATE SET ${sets.join(', ')}',
      [for (final c in cols) row[c]],
    );
    return true;
  }

  /// Savaşçı: bulutta durum etkileri ayrı satır değil `conditions_json`
  /// kolonu (094 BÖLÜM C). Yerelde ayrı tablo ve PK autoincrement — o yüzden
  /// eşleme yok, savaşçının etkileri silinip yeniden yazılıyor.
  ///
  /// Yerel `combatants`'ta `world_id` yok, encounter üzerinden geliyor; gelen
  /// satırdaki `world_id` düşer.
  Future<bool> _writeCombatant(Map<String, dynamic> cloud) async {
    final row = <String, Object?>{
      for (final c in const [
        'id', 'encounter_id', 'entity_id', 'name', 'init', 'ac', 'hp',
        'max_hp', 'token_id', 'sort_order',
      ])
        if (cloud.containsKey(c)) c: cloud[c],
      'updated_at': _unixOf(cloud['updated_at']),
    };
    if (!await _write('combatants', const ['id'], row)) return false;

    final id = cloud['id'] as String;
    await _db.customStatement(
        'DELETE FROM combat_conditions WHERE combatant_id = ?', [id]);
    for (final c in _decodeList(cloud['conditions_json'])) {
      await _db.customStatement(
        'INSERT INTO combat_conditions '
        '(combatant_id, name, duration, initial_duration, entity_id) '
        'VALUES (?, ?, ?, ?, ?)',
        [id, c['name'], c['duration'], c['initial_duration'], c['entity_id']],
      );
    }
    return true;
  }

  // ── Silmeler ─────────────────────────────────────────────────────────────

  /// Tombstone'u uygular. Yerel satır tombstone'dan **sonra** düzenlenmişse
  /// silinmez (§2.8): o düzenleme bir sonraki push'ta buluta geri gider.
  ///
  /// Silme yerel DAO'lardan geçmiyor, dolayısıyla `sync_tombstones`'a kayıt
  /// düşmüyor — düşseydi push aynı silmeyi buluta geri göndermeye çalışırdı.
  Future<bool> _applyTombstone(String worldId, CloudTombstone stone) async {
    final t = _tableOf[stone.table];
    final table = stone.table == 'world_combatants' ? 'combatants' : t?.local;
    if (table == null) return false;
    // Anahtar bildirimden geliyor. `installed_packages` bileşik: tombstone
    // yalnız `package_id` taşır, dünya kapsamdan gelir.
    final key = <String, Object?>{
      for (final k in t?.key ?? const ['id']) k: stone.rowId,
      if (t != null && t.key.length > 1) 'world_id': worldId,
    };
    final where = [for (final k in key.keys) '$k = ?'].join(' AND ');
    final args = [for (final v in key.values) v];

    final hit = await _db.customSelect(
      'SELECT updated_at FROM $table WHERE $where',
      variables: [for (final a in args) Variable<String>(a as String)],
    ).getSingleOrNull();
    if (hit == null) return false;
    final local = hit.data['updated_at'];
    if (local is int && local > stone.deletedAt) return false;

    // FK'lar kapalı (app_database `foreign_keys = OFF`), cascade yok: çocuk
    // satırları elle düşüyoruz, yoksa hayalet savaşçı kalır.
    if (table == 'encounters') {
      await _db.customStatement(
        'DELETE FROM combat_conditions WHERE combatant_id IN '
        '(SELECT id FROM combatants WHERE encounter_id = ?)',
        [stone.rowId],
      );
      await _db.customStatement(
          'DELETE FROM combatants WHERE encounter_id = ?', [stone.rowId]);
    } else if (table == 'combatants') {
      await _db.customStatement(
          'DELETE FROM combat_conditions WHERE combatant_id = ?', [stone.rowId]);
    }
    await _db.customStatement('DELETE FROM $table WHERE $where', args);
    return true;
  }

  // ── Medya ────────────────────────────────────────────────────────────────

  /// Gövdedeki `dmt-content://{sha}` ref'lerini bu cihazdaki dosya yoluna
  /// çevirir. Bayt burada yoksa ref **olduğu gibi kalır** — `AssetRefResolver`
  /// onu dünyanın bulut medyasından indiriyor (Faz 5d).
  Future<String> _localPaths(String raw) async {
    final idx = index;
    if (idx == null || raw.isEmpty) return raw;
    if (!raw.startsWith('{') && !raw.startsWith('[')) {
      return await _resolve(raw, idx) ?? raw;
    }
    try {
      return jsonEncode(await _walk(jsonDecode(raw), idx));
    } catch (_) {
      return raw;
    }
  }

  Future<Object?> _walk(Object? node, ContentRefIndex idx) async {
    if (node is String) return await _resolve(node, idx) ?? node;
    if (node is Map) {
      return {for (final e in node.entries) e.key: await _walk(e.value, idx)};
    }
    if (node is List) return [for (final v in node) await _walk(v, idx)];
    return node;
  }

  Future<String?> _resolve(String value, ContentRefIndex idx) async {
    final ref = AssetRef(value);
    if (!ref.isContent) return null;
    final sha = ref.contentSha;
    if (sha == null) return null;
    return (await idx.fileForSha(sha))?.path;
  }

  // ── Dönüşümler ───────────────────────────────────────────────────────────

  /// Postgres ISO → Drift `dateTime()` unix **saniye**si.
  static int? _unixOf(Object? v) => v is String
      ? DateTime.parse(v).millisecondsSinceEpoch ~/ 1000
      : (v is int ? v : null);

  static List<Map<String, dynamic>> _decodeList(Object? raw) {
    if (raw is List) return [for (final e in raw) Map<String, dynamic>.from(e as Map)];
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final d = jsonDecode(raw);
      return d is List
          ? [for (final e in d) Map<String, dynamic>.from(e as Map)]
          : const [];
    } catch (_) {
      return const [];
    }
  }
}

/// Bulut tablosu → bildirimi. Tombstone yalnız tablo adı taşıyor; yerel adı ve
/// anahtarı buradan çıkıyor.
final Map<String, MirrorTable> _tableOf = {
  for (final t in mirrorTables) t.cloud: t,
  for (final t in packageTables) t.cloud: t,
};

/// `get_world_delta`'nın döndürdüğü tek sayfa.
class CloudDelta {
  const CloudDelta({
    required this.revision,
    this.head = 0,
    required this.complete,
    required this.tables,
    required this.tombstones,
  });

  factory CloudDelta.fromJson(Map<String, dynamic> json) => CloudDelta(
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        head: (json['head'] as num?)?.toInt() ?? 0,
        complete: json['complete'] as bool? ?? true,
        tables: {
          for (final e in (json['tables'] as Map? ?? const {}).entries)
            e.key as String: [
              for (final r in (e.value as List? ?? const []))
                Map<String, dynamic>.from(r as Map),
            ],
        },
        tombstones: [
          for (final r in (json['tombstones'] as List? ?? const []))
            CloudTombstone.fromJson(Map<String, dynamic>.from(r as Map)),
        ],
      );

  /// Bu sayfanın kapsadığı en son revizyon — yeni damga.
  final int revision;

  /// Bulutun o anki sayacı — ilerleme göstergesinin paydası.
  final int head;

  /// Sunucu dünyanın başına kadar geldi mi. False ise istemci [revision] ile
  /// tekrar çağırır.
  final bool complete;

  final Map<String, List<Map<String, dynamic>>> tables;
  final List<CloudTombstone> tombstones;

  List<Map<String, dynamic>> rowsOf(String table) =>
      tables[table] ?? const <Map<String, dynamic>>[];
}

/// Bulutta silinmiş bir satır (094 A.2).
class CloudTombstone {
  const CloudTombstone({
    required this.table,
    required this.rowId,
    required this.deletedAt,
  });

  factory CloudTombstone.fromJson(Map<String, dynamic> json) => CloudTombstone(
        table: json['table_name'] as String,
        rowId: json['row_id'] as String,
        deletedAt: CloudPullService._unixOf(json['deleted_at']) ?? 0,
      );

  final String table;
  final String rowId;

  /// Unix **saniye** — yerel `updated_at` ile aynı birim.
  final int deletedAt;
}

/// Bir sayfanın uygulanma sonucu.
class CloudPullApplied {
  const CloudPullApplied({this.applied = 0, this.removed = 0});
  final int applied;
  final int removed;
}

/// Bulutta olup bu cihazda olmayan bir dünya (Faz 5c).
typedef CloudWorld = ({
  String id,
  String name,
  String? templateId,
  String? templateHash,
});

/// Bulutta olup bu cihazda olmayan bir paket (Faz 5c).
typedef CloudPackage = ({String id, String name});

/// Yerelde aynı adlı başka bir paket var — paket adı yerelde UNIQUE.
class CloudPackageNameTaken implements Exception {
  const CloudPackageNameTaken(this.name);
  final String name;

  @override
  String toString() => 'Package name taken: $name';
}

/// Bir `pullWorld` turunun sonucu.
class CloudPullResult {
  const CloudPullResult({
    this.applied = 0,
    this.removed = 0,
    this.revision = 0,
    this.skipped = false,
    this.error,
  });

  final int applied;
  final int removed;

  /// Turun ulaştığı bulut revizyonu.
  final int revision;
  final bool skipped;
  final Object? error;

  bool get ok => !skipped && error == null;
}
