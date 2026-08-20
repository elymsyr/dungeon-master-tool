import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/config/app_paths.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../domain/entities/character.dart';
import '../../providers/campaign_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/package_provider.dart';
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

    for (final w in await _db.worldsDao.getAll()) {
      out.add(LanItemRef(
        type: LanItemType.world,
        id: w.id,
        name: w.worldName,
        updatedAt: w.updatedAt,
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
    switch (ref.type) {
      case LanItemType.world:
        final row = await _db.worldsDao.getById(ref.id);
        if (row == null) return null;
        payload = await _ref
            .read(campaignRepositoryProvider)
            .load(row.worldName);
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
      media: await _mediaFor(ref),
    );
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

    switch (item.ref.type) {
      case LanItemType.world:
        await _applyWorld(item.ref, payload);
      case LanItemType.package:
        await _applyPackage(item.ref, payload);
      case LanItemType.character:
        await _applyCharacter(item.ref, payload);
    }
  }

  Future<void> _applyWorld(LanItemRef ref, Map<String, dynamic> payload) async {
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
    _ref.invalidate(campaignListProvider);
    _ref.invalidate(campaignInfoListProvider);
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
  Future<List<LanMediaEntry>> _mediaFor(LanItemRef ref) async {
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
    return entries;
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
