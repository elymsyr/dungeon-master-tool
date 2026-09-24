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
import '../../../domain/value_objects/world_section_stamps.dart';
import '../../providers/campaign_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/package_provider.dart';
import '../../providers/ui_state_provider.dart';
import '../content_store.dart';
import '../local_media_localizer.dart';
import '../pending_write_buffer.dart';
import '../srd_core_package_bootstrap.dart';
import 'content_item.dart';
import 'world_merge.dart';

/// İçerik aktarımının yerel yarısı: manifest üretimi, item okuma, item
/// uygulama.
///
/// **Taşıma katmanını bilmez.** `.dmtz` zip export/import'u buradan okuyup
/// buraya yazar.
///
/// Yazımlar `campaign/package/character` repository'leri üzerinden gider.
/// `lib/data/repositories/` içinde tek bir `enqueue`/`syncEngine` çağrısı
/// yoktur, dolayısıyla buradan gelen içerik **Supabase outbox'ına düşmez** —
/// aktarım buluta sızmaz.
class ContentCodec {
  ContentCodec(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  /// Kullanıcıya özel veri kökü — `{dataRoot}` ya da `{dataRoot}/users/{uid}`.
  /// Medya yolları buna göre relatif taşınır, böylece iki cihazın profil
  /// klasörleri farklı olsa da yollar eşleşir.
  static String get userBase => p.dirname(AppPaths.worldsDir);

  /// Debounce kuyruğunu boşalt — manifest / payload okumadan ve gelen item'ı
  /// uygulamadan önce.
  ///
  /// `combat_state` 500 ms, `mind_maps` 1000 ms, viewport 2000 ms gecikmeyle
  /// yazılıyor ([PendingWriteBuffer]). Bunlar beklerken eşleme başlarsa hem
  /// payload hem `worlds.updatedAt` bayat okunuyordu: karşı cihaz "ben daha
  /// yeniyim" deyip **taze veriyi eziyordu**. Uygulama tarafında da gerekli —
  /// yoksa bekleyen yerel yazım apply'dan sonra fire edip geleni geri yazar.
  /// Bekleyen yazım yoksa bedava.
  Future<void> _flushPending() =>
      _ref.read(pendingWriteBufferProvider).flush();

  // ── Manifest ──────────────────────────────────────────────────────────

  /// Bu cihazdaki bütün senkronize edilebilir içeriğin kimlik listesi.
  ///
  /// Built-in SRD paketi dışarıda: her açılışta koddan yeniden üretiliyor,
  /// taşınması anlamsız (`PackageRepositoryImpl.save` de onu no-op'luyor).
  Future<List<ContentItemRef>> buildManifest() async {
    await _flushPending();
    final out = <ContentItemRef>[];

    final ui = _ref.read(uiStateProvider);
    for (final w in await _db.worldsDao.getAll()) {
      final touched = ui.viewTouchedByWorld[w.id];
      out.add(ContentItemRef(
        type: ContentItemType.world,
        id: w.id,
        name: w.worldName,
        updatedAt: w.updatedAt,
        viewUpdatedAt: touched == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(touched, isUtc: true),
        renamedAt: w.renamedAt,
      ));
    }

    for (final pkg in await _db.packagesDao.getAll()) {
      if (pkg.name == srdCorePackageName) continue;
      out.add(ContentItemRef(
        type: ContentItemType.package,
        id: pkg.id,
        name: pkg.name,
        updatedAt: pkg.updatedAt,
        renamedAt: pkg.renamedAt,
      ));
    }

    for (final c in await _db.worldCharactersDao.getAllChars()) {
      out.add(ContentItemRef(
        type: ContentItemType.character,
        id: c.id,
        name: c.templateName,
        updatedAt: c.updatedAt,
        renamedAt: c.renamedAt,
      ));
    }

    return out;
  }

  // ── Okuma ─────────────────────────────────────────────────────────────

  /// Bir item'ı tel formatına çevirir: blob + medya listesi + veri kökü.
  /// Item bulunamazsa null.
  Future<ContentItemPayload?> loadItem(ContentItemRef ref) async {
    await _flushPending();
    final Map<String, dynamic> payload;
    var extras = const <String, dynamic>{};
    switch (ref.type) {
      case ContentItemType.world:
        final row = await _db.worldsDao.getById(ref.id);
        if (row == null) return null;
        payload =
            await _ref.read(campaignRepositoryProvider).load(row.id);
        // Veri kökünün dışında kalmış ham yollar (eski sürümde seçilmiş
        // battle map / mindmap resimleri) burada dünya klasörüne alınır —
        // aksi hâlde `_mediaFor` onları göremiyor ve karşı cihazda resim hiç
        // açılmıyor. Kalıcı olsun diye dünyayı da geri yazıyoruz.
        if (await LocalMediaLocalizer.localizeWorldPayload(payload, row.id)) {
          await _ref.read(campaignRepositoryProvider).save(row.id, payload);
        }
        extras = await _worldExtras(row.id);
      case ContentItemType.package:
        final row = await _db.packagesDao.getById(ref.id);
        if (row == null) return null;
        payload = await _ref.read(packageRepositoryProvider).load(row.name);
        if (await LocalMediaLocalizer.localizePackagePayload(
          payload,
          row.name,
        )) {
          await _ref.read(packageRepositoryProvider).save(row.name, payload);
        }
      case ContentItemType.character:
        final row = await _db.worldCharactersDao.getById(ref.id);
        if (row == null) return null;
        payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    }

    return ContentItemPayload(
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
  Future<Map<String, dynamic>> _worldExtras(String worldId) async {
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
      'ui_view': exportWorldUiView(_ref.read(uiStateProvider), worldId),
      'section_stamps': (await _sectionStamps(worldId)).toJson(),
    };
  }

  /// Dünyanın bölüm bazlı son-değişim damgaları — [mergeWorldPayloads] bunlarla
  /// karar veriyor. entity/session/map_data damgaları granüler tabloların kendi
  /// `updated_at` sütunlarından, settings damgaları blob içindeki
  /// [kSectionStampsKey] haritasından geliyor.
  Future<WorldSectionStamps> _sectionStamps(String worldId) async {
    final entities = await _db.worldEntitiesDao.getByWorld(worldId);
    final sessions = await _db.worldSessionsDao.getByWorld(worldId);
    final mapRow = await _db.worldMapDataDao.get(worldId);
    final settingsRow = await _db.worldSettingsDao.get(worldId);

    var settings = const <String, DateTime>{};
    if (settingsRow != null && settingsRow.settingsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(settingsRow.settingsJson);
        if (decoded is Map) {
          settings = readSectionStamps(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    return WorldSectionStamps(
      entities: {for (final e in entities) e.id: e.updatedAt.toUtc()},
      sessions: {for (final s in sessions) s.id: s.updatedAt.toUtc()},
      mapData: mapRow?.updatedAt.toUtc(),
      settings: settings,
    );
  }

  /// [relativePath]'i `userBase` altına çözer; kaçış denemesinde null döner
  /// (path traversal koruması — zip'teki yol dışarıdan gelir).
  static File? resolveMedia(String relativePath) {
    if (relativePath.isEmpty) return null;
    final base = p.normalize(userBase);
    final target = p.normalize(p.joinAll([base, ...relativePath.split('/')]));
    if (!p.isWithin(base, target)) return null;
    return File(target);
  }

  // ── Uygulama ──────────────────────────────────────────────────────────

  /// Zip'ten gelen item'ı yerel'e yazar.
  ///
  /// Medya dosyaları çağıran tarafından önceden diske açılmış olmalıdır;
  /// burada yalnız payload içindeki yollar gönderenin kökünden bizimkine
  /// çevrilir.
  Future<void> applyItem(ContentItemPayload item) async {
    await _flushPending();
    final payload = rewriteRoots(item.payload, item.dataRoot, userBase)
        as Map<String, dynamic>;
    final extras = rewriteRoots(item.extras, item.dataRoot, userBase)
        as Map<String, dynamic>;

    switch (item.ref.type) {
      case ContentItemType.world:
        await _applyWorld(item.ref, payload, extras);
      case ContentItemType.package:
        await _applyPackage(item.ref, payload);
      case ContentItemType.character:
        await _applyCharacter(item.ref, payload);
    }
  }

  Future<void> _applyWorld(
    ContentItemRef ref,
    Map<String, dynamic> payload,
    Map<String, dynamic> extras,
  ) async {
    final existing = await _db.worldsDao.getById(ref.id);
    var name = existing?.worldName ?? ref.name;

    // Yeniden adlandırma senkronizasyonu: peer'ın `renamedAt`'i local'den
    // daha yeniyse etiketi güncelle. Medya klasörü id ile anahtarlı olduğu
    // için diskte taşınacak bir şey yok; isim çakışması da sorun değil.
    if (existing != null &&
        ref.renamedAt != null &&
        (existing.renamedAt == null ||
            ref.renamedAt!.isAfter(existing.renamedAt!))) {
      await (_db.update(_db.worlds)..where((t) => t.id.equals(ref.id)))
          .write(WorldsCompanion(
        worldName: Value(ref.name),
        renamedAt: Value(ref.renamedAt),
      ));
      name = ref.name;
    }
    payload['world_id'] = ref.id;
    payload['world_name'] = name;

    // Dünya burada da varsa: tam değiştirme değil, **bölüm bazlı birleştirme**.
    var effectiveUpdatedAt = ref.updatedAt;
    if (existing != null) {
      final localPayload =
          await _ref.read(campaignRepositoryProvider).load(ref.id);
      final localStamps = await _sectionStamps(ref.id);
      final remoteStamps =
          WorldSectionStamps.fromJson(extras['section_stamps']);
      final merged = mergeWorldPayloads(
        local: localPayload,
        remote: payload,
        localStamps: localStamps,
        remoteStamps: remoteStamps,
        localFallback: existing.updatedAt.toUtc(),
        remoteFallback: ref.updatedAt.toUtc(),
      );
      merged['world_id'] = ref.id;
      merged['world_name'] = name;
      await _ref.read(campaignRepositoryProvider).save(ref.id, merged);
      await _restoreSectionStamps(
        ref.id,
        mergeSectionStamps(local: localStamps, remote: remoteStamps),
      );
      if (existing.updatedAt.isAfter(effectiveUpdatedAt)) {
        effectiveUpdatedAt = existing.updatedAt;
      }
    } else {
      await _ref.read(campaignRepositoryProvider).save(ref.id, payload);
    }
    await _db.worldsDao.setUpdatedAt(ref.id, effectiveUpdatedAt);
    await _applyWorldExtras(ref, ref.id, extras);
    if (_ref.read(activeCampaignProvider) == ref.id) {
      await _ref.read(activeCampaignProvider.notifier).reload();
    }
    _ref.invalidate(campaignInfoListProvider);
    _ref.invalidate(campaignMetadataProvider(ref.id));
  }

  /// Birleştirme sonrası granüler satır damgalarını geri yazar.
  /// Yalnız hâlâ var olan satırlara dokunur.
  Future<void> _restoreSectionStamps(
    String worldId,
    WorldSectionStamps stamps,
  ) async {
    for (final row in await _db.worldEntitiesDao.getByWorld(worldId)) {
      final ts = stamps.entities[row.id];
      if (ts != null) await _db.worldEntitiesDao.setUpdatedAt(row.id, ts);
    }
    for (final row in await _db.worldSessionsDao.getByWorld(worldId)) {
      final ts = stamps.sessions[row.id];
      if (ts != null) await _db.worldSessionsDao.setUpdatedAt(row.id, ts);
    }
    final mapTs = stamps.mapData;
    if (mapTs != null && await _db.worldMapDataDao.get(worldId) != null) {
      await _db.worldMapDataDao.setUpdatedAt(worldId, mapTs);
    }
  }

  /// [_worldExtras]'ın karşılığı. Silme yayılmadığı için burada da yalnız
  /// ekleme/güncelleme var: peer'da olmayan bir paket bağlantısı yerelde
  /// kalır.
  /// [worldKey] = dünyanın id'si; `ui_state` dünya görünümlerini bu anahtarla
  /// saklıyor ve `activeCampaignProvider` de aynı anahtarı tutuyor.
  Future<void> _applyWorldExtras(
    ContentItemRef ref,
    String worldKey,
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
    final isActive = _ref.read(activeCampaignProvider) == worldKey;
    _ref.read(uiStateProvider.notifier).update((s) {
      var next = importWorldUiView(s, worldKey, viewMap);
      // Açık dünyada global alanlar (sağ sidebar, açık PDF'ler, session
      // sekmesi) o dünyanın görünümü demek — LWW'yi orada da uygula, yoksa
      // bir sonraki kayıt yerel ekranı peer'ın üzerine geri yazardı.
      if (isActive) {
        next = WorldViewState.stored(next, worldKey)?.applyTo(next) ?? next;
      }
      final viewTs = ref.viewUpdatedAt;
      if (viewTs != null) {
        next = next.copyWith(viewTouchedByWorld: {
          ...next.viewTouchedByWorld,
          worldKey: viewTs.millisecondsSinceEpoch,
        });
      }
      return next;
    });
  }

  Future<void> _applyPackage(
    ContentItemRef ref,
    Map<String, dynamic> payload,
  ) async {
    if (ref.name == srdCorePackageName) return;
    final existing = await _db.packagesDao.getById(ref.id);
    var name = existing?.name ?? ref.name;

    // Yeniden adlandırma senkronizasyonu: peer'ın `renamedAt`'i local'den
    // daha yeniyse ismi güncelle — hem DB'yi hem dosya sistemini.
    if (existing != null && ref.renamedAt != null) {
      final localRenamedAt = existing.renamedAt;
      if (localRenamedAt == null ||
          ref.renamedAt!.isAfter(localRenamedAt)) {
        final oldDir = Directory(p.join(AppPaths.packagesDir, name));
        final newDir = Directory(p.join(AppPaths.packagesDir, ref.name));
        if (await oldDir.exists() && !await newDir.exists()) {
          await oldDir.rename(newDir.path);
        }
        await (_db.update(_db.packages)..where((t) => t.id.equals(ref.id)))
            .write(PackagesCompanion(
          name: Value(ref.name),
          renamedAt: Value(ref.renamedAt),
        ));
        name = ref.name;
      }
    }

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
    ContentItemRef ref,
    Map<String, dynamic> payload,
  ) async {
    // Yeniden adlandırma senkronizasyonu: peer'ın `renamedAt`'i local'den
    // daha yeniyse DB'deki `renamed_at`'i güncelle. Bunu save()'den ÖNCE
    // yapıyoruz çünkü save() mevcut renamedAt'i koruyor.
    if (ref.renamedAt != null) {
      final existing = await _db.worldCharactersDao.getById(ref.id);
      if (existing != null) {
        final localRenamedAt = existing.renamedAt;
        if (localRenamedAt == null ||
            ref.renamedAt!.isAfter(localRenamedAt)) {
          await _db.worldCharactersDao.setRenamedAt(ref.id, ref.renamedAt!);
        }
      }
    }

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
  /// Yalnız veri kökü altındaki dosyalar taşınabilir (yol güvenliği +
  /// alıcıda kök yeniden yazımı buna dayanıyor). Kullanıcının Downloads'ından
  /// seçtiği mutlak yollu resimler bu yüzden [loadItem] içinde
  /// [LocalMediaLocalizer] ile önce dünya klasörüne alınıyor — eskiden
  /// alınmadığı için battle map ve mindmap resimleri karşı cihaza hiç
  /// gitmiyordu.
  Future<List<ContentMediaEntry>> _mediaFor(
    ContentItemRef ref,
    List<Object?> payloadTrees,
  ) async {
    final entries = <ContentMediaEntry>[];
    switch (ref.type) {
      case ContentItemType.world:
        final row = await _db.worldsDao.getById(ref.id);
        if (row == null) return entries;
        await _collectDir(
          Directory(LocalMediaLocalizer.worldDir(row.id)),
          entries,
        );
      case ContentItemType.package:
        final row = await _db.packagesDao.getById(ref.id);
        if (row == null) return entries;
        await _collectDir(
          Directory(LocalMediaLocalizer.packageDir(row.name)),
          entries,
        );
      case ContentItemType.character:
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
  /// `dmt-content://`) **baytlarını** da eşlemeye katar.
  ///
  /// Bunlar dünya klasöründe durmuyor: bir resim yüklendiği anda R2/Storage'a
  /// gidiyor ve yerelde yalnız içerik-adresli önbellekte
  /// (`cache/content/{sha}.bin`) kalıyor. Ref'in kendisi cihazdan bağımsız
  /// olduğu için [rewriteRoots] ona dokunmuyordu — ama baytlar taşınmayınca
  /// karşı cihaz resmi ancak internete çıkıp indirebiliyordu. Blob'ları da
  /// taşıyınca resim karşı tarafta çevrimdışı açılıyor.
  ///
  /// Blob içerik-adresli olduğu için dosyayı yeniden hash'lemeye gerek yok:
  /// dosya adındaki sha zaten içeriğin hash'i.
  Future<void> _collectContentBlobs(
    List<Object?> trees,
    List<ContentMediaEntry> out,
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
      out.add(ContentMediaEntry(
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
    List<ContentMediaEntry> out, {
    bool Function(String path)? nameFilter,
  }) async {
    if (!await dir.exists()) return;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      if (nameFilter != null && !nameFilter(e.path)) continue;
      try {
        final stat = await e.stat();
        out.add(ContentMediaEntry(
          path: _relToBase(e.path),
          sha256: await fileSha256(e),
          size: stat.size,
        ));
      } catch (err) {
        debugPrint('[ContentCodec] medya atlandı ${e.path}: $err');
      }
    }
  }

  static String _relToBase(String absolute) =>
      p.relative(absolute, from: userBase).split(p.separator).join('/');

  /// Dosyanın sha256'sı — akış üzerinden, tamamı belleğe alınmadan.
  static Future<String> fileSha256(File f) async =>
      (await sha256.bind(f.openRead()).first).toString();

  /// Gelen bir medya dosyası bizde zaten aynı içerikle var mı?
  Future<bool> hasMedia(ContentMediaEntry entry) async {
    final file = resolveMedia(entry.path);
    if (file == null || !await file.exists()) return false;
    if ((await file.stat()).size != entry.size) return false;
    return await fileSha256(file) == entry.sha256;
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

final contentCodecProvider =
    Provider<ContentCodec>((ref) => ContentCodec(ref));
