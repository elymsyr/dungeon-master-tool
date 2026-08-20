import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/config/app_paths.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../providers/campaign_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/package_provider.dart';
import '../../providers/ui_state_provider.dart';
import '../content_store.dart';
import '../srd_core_package_bootstrap.dart';
import 'lan_sync_protocol.dart';

/// LAN sync'in yerel yarısı: manifest üretimi, item okuma, item uygulama.
///
/// Taşıma katmanından ([LanSyncServer] / [LanSyncClient]) tamamen bağımsızdır —
/// her iki taraf da aynı [LanSyncSession]'ı kullanır, biri sunucu içinden biri
/// istemci içinden.
///
/// Yazımlar `campaign/package/character` repository'leri üzerinden gider.
/// `lib/data/repositories/` içinde tek bir `enqueue`/`syncEngine` çağrısı
/// yoktur, dolayısıyla LAN'dan gelen içerik **Supabase outbox'ına düşmez** —
/// kullanıcının istediği "yerel eşleme bulutu atlar" davranışı budur.
class LanSyncSession {
  LanSyncSession(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  /// Kullanıcıya özel veri kökü — `{dataRoot}` ya da `{dataRoot}/users/{uid}`.
  /// Medya yolları buna göre relatif taşınır, böylece iki cihazın profil
  /// klasörleri farklı olsa da yollar eşleşir.
  static String get userBase => p.dirname(AppPaths.worldsDir);

  // ── Manifest ──────────────────────────────────────────────────────────

  /// Bu cihazdaki bütün senkronize edilebilir içeriğin kimlik listesi.
  ///
  /// Built-in SRD paketi dışarıda: her açılışta koddan yeniden üretiliyor,
  /// taşınması anlamsız (`PackageRepositoryImpl.save` de onu no-op'luyor).
  Future<List<LanItemRef>> buildManifest() async {
    final out = <LanItemRef>[];

    final ui = _ref.read(uiStateProvider);
    for (final w in await _db.worldsDao.getAll()) {
      final touched = ui.viewTouchedByWorld[w.worldName];
      out.add(LanItemRef(
        type: LanItemType.world,
        id: w.id,
        name: w.worldName,
        updatedAt: w.updatedAt,
        viewUpdatedAt: touched == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(touched, isUtc: true),
      ));
    }

    for (final pkg in await _db.packagesDao.getAll()) {
      if (pkg.name == srdCorePackageName) continue;
      out.add(LanItemRef(
        type: LanItemType.package,
        id: pkg.id,
        name: pkg.name,
        updatedAt: pkg.updatedAt,
      ));
    }

    for (final c in await _db.worldCharactersDao.getAllChars()) {
      out.add(LanItemRef(
        type: LanItemType.character,
        id: c.id,
        name: c.templateName,
        updatedAt: c.updatedAt,
      ));
    }

    return out;
  }

  // ── Okuma ─────────────────────────────────────────────────────────────

  /// Bir item'ı tel formatına çevirir: blob + medya listesi + veri kökü.
  /// Item bulunamazsa null.
  Future<LanItemPayload?> loadItem(LanItemRef ref) async {
    final Map<String, dynamic> payload;
    var extras = const <String, dynamic>{};
    switch (ref.type) {
      case LanItemType.world:
        final row = await _db.worldsDao.getById(ref.id);
        if (row == null) return null;
        payload = await _ref
            .read(campaignRepositoryProvider)
            .load(row.worldName);
        extras = await _worldExtras(row.id, row.worldName);
      case LanItemType.package:
        final row = await _db.packagesDao.getById(ref.id);
        if (row == null) return null;
        payload = await _ref.read(packageRepositoryProvider).load(row.name);
      case LanItemType.character:
        final row = await _db.worldCharactersDao.getById(ref.id);
        if (row == null) return null;
        payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    }

    return LanItemPayload(
      ref: ref,
      payload: payload,
      dataRoot: userBase,
      media: await _mediaFor(ref, [payload, extras]),
      extras: extras,
    );
  }

  /// Dünyaya ait olup `campaignRepository.load` blob'unda **bulunmayan**
  /// parçalar. Blob cloud-backup kontratı olduğu için genişletilmiyor.
  ///
  /// - `installed_packages`: dünya ↔ paket bağlantıları. Bunlar taşınmazsa
  ///   karşı cihaz dünyayı paketlerinden kopuk görüyor (built-in SRD
  ///   sentezi ve paket kartları boş kalıyor); paketlerin kendisi zaten
  ///   ayrı item olarak eşleniyor.
  /// - `ui_view`: "o an ne açıktı" — açık kartlar, panel filtreleri, açık
  ///   PDF sekmeleri, sağ sidebar (PDF / Soundpad / karakterler), session
  ///   sekmesi. Bkz. [exportWorldUiView].
  Future<Map<String, dynamic>> _worldExtras(
    String worldId,
    String worldName,
  ) async {
    final links = await _db.installedPackagesDao.getByWorld(worldId);
    return {
      'installed_packages': [
        for (final l in links)
          {
            'id': l.packageId,
            'name': l.packageName,
            'version': l.packageVersion,
          },
      ],
      'ui_view': exportWorldUiView(_ref.read(uiStateProvider), worldName),
    };
  }

  /// Bir medya dosyasını relatif yolundan okur. Yol `userBase` dışına
  /// çıkıyorsa null — path traversal koruması (sunucu bunu doğrudan servis
  /// ettiği için güvenlik sınırı).
  Future<File?> openMedia(String relativePath) async {
    final file = resolveMedia(relativePath);
    if (file == null || !await file.exists()) return null;
    return file;
  }

  /// [relativePath]'i `userBase` altına çözer; kaçış denemesinde null döner.
  static File? resolveMedia(String relativePath) {
    if (relativePath.isEmpty) return null;
    final base = p.normalize(userBase);
    final target = p.normalize(p.joinAll([base, ...relativePath.split('/')]));
    if (!p.isWithin(base, target)) return null;
    return File(target);
  }

  // ── Uygulama ──────────────────────────────────────────────────────────

  /// Peer'dan gelen item'ı yerel'e yazar.
  ///
  /// Medya dosyaları çağıran tarafından önceden indirilip [writeMedia] ile
  /// yerleştirilmiş olmalıdır; burada yalnız payload içindeki yollar
  /// gönderenin kökünden bizimkine çevrilir.
  Future<void> applyItem(LanItemPayload item) async {
    final payload = rewriteRoots(item.payload, item.dataRoot, userBase)
        as Map<String, dynamic>;
    final extras = rewriteRoots(item.extras, item.dataRoot, userBase)
        as Map<String, dynamic>;

    switch (item.ref.type) {
      case LanItemType.world:
        await _applyWorld(item.ref, payload, extras);
      case LanItemType.package:
        await _applyPackage(item.ref, payload);
      case LanItemType.character:
        await _applyCharacter(item.ref, payload);
    }
  }

  Future<void> _applyWorld(
    LanItemRef ref,
    Map<String, dynamic> payload,
    Map<String, dynamic> extras,
  ) async {
    final existing = await _db.worldsDao.getById(ref.id);
    // ponytail: yeniden adlandırma taşınmıyor — yerel ad kazanır, içerik
    // eşitlenir. Ad senkronu istenirse manifest'e `renamed_at` eklenir.
    var name = existing?.worldName ?? ref.name;
    if (existing == null && await _db.worldsDao.getByName(name) != null) {
      name = await _uniqueName(
        name,
        (n) async => await _db.worldsDao.getByName(n) != null,
      );
    }
    payload['world_id'] = ref.id;
    await _ref.read(campaignRepositoryProvider).save(name, payload);
    await _db.worldsDao.setUpdatedAt(ref.id, ref.updatedAt);
    await _applyWorldExtras(ref, name, extras);
    // Dunya su an acik ise bellekteki kopya bayat: bir sonraki otomatik
    // kayit senkronize edilen icerigi geri ezerdi ve kullanici hicbir sey
    // gelmemis gibi gorurdu. Cloud restore'un "acik dunyanin icine geri
    // yukle" yolunun aynisi.
    if (_ref.read(activeCampaignProvider) == name) {
      await _ref.read(activeCampaignProvider.notifier).reload();
    }
    _ref.invalidate(campaignListProvider);
    _ref.invalidate(campaignInfoListProvider);
  }

  /// [_worldExtras]'ın karşılığı. Silme yayılmadığı için burada da yalnız
  /// ekleme/güncelleme var: peer'da olmayan bir paket bağlantısı yerelde
  /// kalır.
  Future<void> _applyWorldExtras(
    LanItemRef ref,
    String worldName,
    Map<String, dynamic> extras,
  ) async {
    final links = extras['installed_packages'];
    if (links is List) {
      for (final raw in links) {
        if (raw is! Map) continue;
        final packageId = raw['id'];
        if (packageId is! String || packageId.isEmpty) continue;
        await _db.installedPackagesDao.upsert(
          InstalledPackagesCompanion.insert(
            worldId: ref.id,
            packageId: packageId,
            packageName: Value('${raw['name'] ?? ''}'),
            packageVersion: Value('${raw['version'] ?? ''}'),
          ),
        );
      }
    }

    final view = extras['ui_view'];
    if (view is! Map) return;
    final viewMap = view.cast<String, dynamic>();
    final isActive = _ref.read(activeCampaignProvider) == worldName;
    _ref.read(uiStateProvider.notifier).update((s) {
      var next = importWorldUiView(s, worldName, viewMap);
      // Açık dünyada global alanlar (sağ sidebar, açık PDF'ler, session
      // sekmesi) o dünyanın görünümü demek — LWW'yi orada da uygula, yoksa
      // bir sonraki kayıt yerel ekranı peer'ın üzerine geri yazardı.
      if (isActive) {
        next = WorldViewState.stored(next, worldName)?.applyTo(next) ?? next;
      }
      final viewTs = ref.viewUpdatedAt;
      if (viewTs != null) {
        next = next.copyWith(viewTouchedByWorld: {
          ...next.viewTouchedByWorld,
          worldName: viewTs.millisecondsSinceEpoch,
        });
      }
      return next;
    });
  }

  Future<void> _applyPackage(
    LanItemRef ref,
    Map<String, dynamic> payload,
  ) async {
    if (ref.name == srdCorePackageName) return;
    final existing = await _db.packagesDao.getById(ref.id);
    var name = existing?.name ?? ref.name;
    if (existing == null && await _db.packagesDao.getByName(name) != null) {
      name = await _uniqueName(
        name,
        (n) async => await _db.packagesDao.getByName(n) != null,
      );
    }
    payload['package_id'] = ref.id;
    await _ref.read(packageRepositoryProvider).save(name, payload);
    await _db.packagesDao.setUpdatedAt(ref.id, ref.updatedAt);
    _ref.invalidate(packageListProvider);
  }

  Future<void> _applyCharacter(
    LanItemRef ref,
    Map<String, dynamic> payload,
  ) async {
    // Karakterin `updatedAt`'i payload'ın kendisinde taşınıyor ve
    // `CharacterRepository` onu olduğu gibi yazıyor — restamp gerekmez.
    final character = Character.fromJson({...payload, 'id': ref.id});
    await _ref.read(characterRepositoryProvider).save(character);
    await _ref.read(characterListProvider.notifier).refresh();
  }

  Future<String> _uniqueName(
    String base,
    Future<bool> Function(String) taken,
  ) async {
    for (var i = 2; i < 1000; i++) {
      final candidate = '$base ($i)';
      if (!await taken(candidate)) return candidate;
    }
    return '$base (${DateTime.now().millisecondsSinceEpoch})';
  }

  // ── Medya ─────────────────────────────────────────────────────────────

  /// Item'a ait medya dizinindeki dosyaları relatif yol + sha256 ile listeler.
  ///
  /// ponytail: yalnız veri kökü altındaki dosyalar taşınır. Kullanıcının
  /// Downloads'ından seçtiği mutlak yollu bir resim kapsam dışı —
  /// `RawPathMigrator` da ham yolları zaten legacy sayıyor.
  Future<List<LanMediaEntry>> _mediaFor(
    LanItemRef ref,
    List<Object?> payloadTrees,
  ) async {
    final entries = <LanMediaEntry>[];
    switch (ref.type) {
      case LanItemType.world:
        final row = await _db.worldsDao.getById(ref.id);
        if (row == null) return entries;
        await _collectDir(
          Directory(p.join(AppPaths.worldsDir, row.worldName)),
          entries,
        );
      case LanItemType.package:
        final row = await _db.packagesDao.getById(ref.id);
        if (row == null) return entries;
        await _collectDir(
          Directory(p.join(AppPaths.packagesDir, row.name)),
          entries,
        );
      case LanItemType.character:
        // Karakter medyası düz dizinde, `{id}_*` adlandırmasıyla duruyor.
        await _collectDir(
          Directory(AppPaths.charactersDir),
          entries,
          nameFilter: (f) => p.basename(f).startsWith('${ref.id}_'),
        );
    }
    await _collectContentBlobs(payloadTrees, entries);
    return entries;
  }

  /// Payload'daki bulut ref'lerinin (`dmt-asset://`, `dmt-public://`,
  /// `dmt-transient://`) **baytlarını** da eşlemeye katar.
  ///
  /// Bunlar dünya klasöründe durmuyor: bir resim yüklendiği anda R2/Storage'a
  /// gidiyor ve yerelde yalnız içerik-adresli önbellekte
  /// (`cache/content/{sha}.bin`) kalıyor. Ref'in kendisi cihazdan bağımsız
  /// olduğu için [rewriteRoots] ona dokunmuyordu — ama baytlar taşınmayınca
  /// karşı cihaz resmi ancak internete çıkıp indirebiliyordu, LAN eşlemesinin
  /// vaadi ise tam tersi. Blob'ları da taşıyınca resim karşı tarafta
  /// çevrimdışı açılıyor.
  ///
  /// Blob içerik-adresli olduğu için dosyayı yeniden hash'lemeye gerek yok:
  /// dosya adındaki sha zaten içeriğin hash'i.
  Future<void> _collectContentBlobs(
    List<Object?> trees,
    List<LanMediaEntry> out,
  ) async {
    final shas = <String>{};
    for (final tree in trees) {
      _collectAssetShas(tree, shas);
    }
    if (shas.isEmpty) return;
    final store = _ref.read(contentStoreProvider);
    for (final sha in shas) {
      final file = store.binFor(sha);
      if (!await file.exists()) continue;
      out.add(LanMediaEntry(
        path: _relToBase(file.path),
        sha256: sha,
        size: (await file.stat()).size,
      ));
    }
  }

  /// JSON ağacındaki şema'lı asset ref'lerinin sha'larını toplar.
  static void _collectAssetShas(Object? node, Set<String> out) {
    if (node is String) {
      final ref = AssetRef(node);
      if (ref.isLocal) return;
      final sha = ref.contentSha;
      if (sha != null) out.add(sha);
    } else if (node is List) {
      for (final v in node) {
        _collectAssetShas(v, out);
      }
    } else if (node is Map) {
      for (final v in node.values) {
        _collectAssetShas(v, out);
      }
    }
  }

  Future<void> _collectDir(
    Directory dir,
    List<LanMediaEntry> out, {
    bool Function(String path)? nameFilter,
  }) async {
    if (!await dir.exists()) return;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      if (nameFilter != null && !nameFilter(e.path)) continue;
      try {
        final stat = await e.stat();
        out.add(LanMediaEntry(
          path: _relToBase(e.path),
          sha256: await fileSha256(e),
          size: stat.size,
        ));
      } catch (err) {
        debugPrint('[LanSync] medya atlandı ${e.path}: $err');
      }
    }
  }

  static String _relToBase(String absolute) =>
      p.relative(absolute, from: userBase).split(p.separator).join('/');

  /// Dosyanın sha256'sı — akış üzerinden, tamamı belleğe alınmadan.
  static Future<String> fileSha256(File f) async =>
      (await sha256.bind(f.openRead()).first).toString();

  /// Peer'dan gelen bir medya dosyası bizde zaten aynı içerikle var mı?
  Future<bool> hasMedia(LanMediaEntry entry) async {
    final file = resolveMedia(entry.path);
    if (file == null || !await file.exists()) return false;
    if ((await file.stat()).size != entry.size) return false;
    return await fileSha256(file) == entry.sha256;
  }

  /// İndirilen medya baytlarını kendi veri kökümüze yazar.
  Future<void> writeMedia(LanMediaEntry entry, List<int> bytes) async {
    final file = resolveMedia(entry.path);
    if (file == null) {
      throw ArgumentError('LAN sync: geçersiz medya yolu ${entry.path}');
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  // ── Yol yeniden yazımı ────────────────────────────────────────────────

  /// Payload içindeki bütün string'lerde gönderenin veri kökünü alıcınınkiyle
  /// değiştirir. Alan adı bilmez — bu yüzden yeni bir medya alanı eklendiğinde
  /// burada bakım gerekmez. Bulut ref'lerine (`dmt-asset://`, `dmt-public://`)
  /// dokunmaz; onlar zaten cihazdan bağımsız.
  static Object? rewriteRoots(Object? node, String fromBase, String toBase) {
    if (fromBase.isEmpty || fromBase == toBase) return node;
    if (node is String) return _rewritePath(node, fromBase, toBase) ?? node;
    if (node is List) {
      return [for (final v in node) rewriteRoots(v, fromBase, toBase)];
    }
    if (node is Map) {
      return <String, dynamic>{
        for (final e in node.entries)
          '${e.key}': rewriteRoots(e.value, fromBase, toBase),
      };
    }
    return node;
  }

  /// Windows `\` ve POSIX `/` ayırıcılarını normalize ederek prefix takası.
  static String? _rewritePath(String value, String fromBase, String toBase) {
    final v = value.replaceAll('\\', '/');
    final from = fromBase.replaceAll('\\', '/');
    if (!v.startsWith('$from/')) return null;
    final rel = v.substring(from.length + 1);
    if (rel.isEmpty) return null;
    return p.joinAll([toBase, ...rel.split('/')]);
  }
}

final lanSyncSessionProvider =
    Provider<LanSyncSession>((ref) => LanSyncSession(ref));
