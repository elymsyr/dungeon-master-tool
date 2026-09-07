import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart'
    show InputFileStream, OutputFileStream, ZipDecoder;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import 'first_party_catalog_service.dart';

/// `dmt-art://{uuid}.webp` ref'lerini diskteki bir dosyaya çözer — built-in ve
/// resmî paketlerin `tool/art_gen` üretimi kart görselleri.
///
/// İki kaynak, bu sırayla:
///  1. **App bundle** — `assets/art/srd/{uuid}.webp`. Built-in SRD 5.2.1
///     paketinin 1247 görseli (webp q50, ~51 MB) build'e gömülüdür, yani
///     çevrimdışı ve hesapsız çalışır.
///  2. **R2 catalog** — `{worker}/catalog/art/{uuid}.webp`. Geri kalan resmî
///     paketlerin ~6.2k görseli. Worker'ın public GET route'u; JWT yok, hesap
///     yok, edge'de `immutable` cache'li.
///
/// Hangi görselin nerede olduğu ref'e gömülü DEĞİL: bundle kapsamı değişince
/// (SRD dışı bir paket de gömülür, ya da SRD çıkarılır) veri migrasyonu
/// gerekmesin diye her ref iki kaynağa da sorulur.
///
/// Sonuç `cacheDir/art/` altına yazılır; bundle'dan gelen görsel de kopyalanır
/// (Flutter asset'i `File` olarak açılamaz). Yani en kötü ihtimalle görülen
/// bundle görselleri diskte bir kez daha yer kaplar — cache silinebilir,
/// tekrar üretilir.
class FirstPartyArtService {
  FirstPartyArtService(this._catalog);

  final FirstPartyCatalogService _catalog;

  static const String bundleDir = 'assets/art/srd';

  /// [name] = `{uuid}.webp`. Çözülemeyen her durumda null.
  Future<File?> resolve(String name) async {
    // Ref pack verisinden geliyor — path segmenti olduğunu doğrula, cache
    // dizininin dışına yazılamasın.
    if (name.isEmpty || name.contains('/') || name.contains('\\') ||
        name.contains('..')) {
      return null;
    }

    final file = File(p.join(AppPaths.cacheDir, 'art', name));
    if (await file.exists()) return file;

    final bytes =
        await _loadBundled(name) ?? await _catalog.fetchCatalogBytes('art/$name');
    if (bytes == null) return null;

    try {
      await file.parent.create(recursive: true);
      // tmp + rename: yarıda kalan bir yazma, sonsuza dek servis edilen bozuk
      // bir cache dosyası bırakmasın.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      return file;
    } catch (e) {
      debugPrint('[art] cache write failed $name: $e');
      return null;
    }
  }

  /// Bir paketin bütün kart görsellerini kurulum sırasında indirir — kullanıcı
  /// kartı açtığında bekleme olmasın ve paket boyutu dürüst olsun.
  ///
  /// Düşen görsel kurulumu düşürmez: ref pack'te duruyor, render'da tekrar
  /// denenir. Dönen değer başarıyla çözülen görsel sayısı.
  Future<int> prefetch(
    List<String> names, {
    void Function(int done, int total)? onProgress,
  }) async {
    var done = 0;
    var ok = 0;
    var next = 0;
    // ponytail: sabit 6'lı havuz; adaptif olması gerekirse ölçüp değiştir.
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= names.length) return;
        if (await resolve(names[i]) != null) ok++;
        onProgress?.call(++done, names.length);
      }
    }

    await Future.wait([for (var i = 0; i < 6; i++) worker()]);
    return ok;
  }

  /// Bir paketin bütün kart görsellerini **tek** istekte indirir: R2'de her
  /// paket için hazır duran zip (`catalog/art-bundle/{slug}@{ver}.zip`).
  ///
  /// Neden zip: tek tek indirmede 1000+ görsel, worker'ın public catalog
  /// rate limit'ini (300 istek/dk/IP) aşıyor ve kalanlar sessizce 429 yiyip
  /// düşüyordu — kullanıcıya "art'lar gelmiyor" diye görünen buydu.
  ///
  /// Zip yoksa (404) ya da bozuksa tek tek indirmeye düşer; eksik kalan
  /// görseller için de öyle. Dönen değer diskte hazır olan görsel sayısı.
  Future<int> prefetchBundle(
    String bundleKey,
    List<String> names, {
    void Function(int done, int total)? onProgress,
  }) async {
    final missing = <String>[];
    for (final n in names) {
      // Zip'ten yazarken de geçerli olan path guard — bkz. [resolve].
      if (n.isEmpty || n.contains('/') || n.contains(r'\') ||
          n.contains('..')) {
        continue;
      }
      if (!await File(p.join(AppPaths.cacheDir, 'art', n)).exists()) {
        missing.add(n);
      }
    }
    if (missing.isEmpty) return names.length;

    onProgress?.call(0, names.length);
    final zip = await _catalog.fetchCatalogBytes(bundleKey);
    if (zip != null) {
      final tmpZip = File(p.join(AppPaths.cacheDir, 'art',
          '.${bundleKey.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.zip'));
      try {
        await tmpZip.parent.create(recursive: true);
        await tmpZip.writeAsBytes(zip, flush: true);
        final wanted = missing.toSet();
        // Diskten stream'leyerek açılır: en büyük arşiv ~100 MB, hepsini
        // bellekte açmak mobilde OOM demek.
        final input = InputFileStream(tmpZip.path);
        try {
          for (final f in ZipDecoder().decodeStream(input)) {
            // Ad pack verisinden geliyor — cache dizininin dışına yazmasın.
            if (!f.isFile || !wanted.contains(f.name)) continue;
            final dest = p.join(tmpZip.parent.path, f.name);
            final out = OutputFileStream('$dest.tmp');
            f.writeContent(out);
            await out.close();
            await File('$dest.tmp').rename(dest);
          }
        } finally {
          await input.close();
        }
      } catch (e) {
        debugPrint('[art] bundle extract failed $bundleKey: $e');
      } finally {
        if (await tmpZip.exists()) await tmpZip.delete();
      }
    } else {
      debugPrint('[art] no bundle at $bundleKey, falling back to per-file');
    }

    final left = <String>[];
    for (final n in missing) {
      if (!await File(p.join(AppPaths.cacheDir, 'art', n)).exists()) left.add(n);
    }
    if (left.isEmpty) {
      onProgress?.call(names.length, names.length);
      return names.length;
    }
    final base = names.length - left.length;
    final ok = await prefetch(
      left,
      onProgress: (d, t) => onProgress?.call(base + d, names.length),
    );
    return base + ok;
  }

  Future<Uint8List?> _loadBundled(String name) async {
    try {
      final data = await rootBundle.load('$bundleDir/$name');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null; // bu görsel bundle'da değil → catalog'a düş
    }
  }
}
