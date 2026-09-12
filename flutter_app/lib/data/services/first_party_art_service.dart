import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart'
    show InputFileStream, OutputFileStream, ZipDecoder;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../database/app_database.dart';
import 'first_party_catalog_service.dart';

/// `dmt-art://{uuid}.webp` ref'lerini diskteki bir dosyaya çözer — built-in ve
/// resmî paketlerin `tool/art_gen` üretimi kart görselleri.
///
/// İki kaynak, bu sırayla:
///  1. **App bundle** — `assets/art/srd/{uuid}.webp`. Built-in SRD 5.2.1
///     paketinin 1247 görseli (webp q50, ~51 MB) build'e gömülüdür, yani
///     çevrimdışı ve hesapsız çalışır.
///  2. **Kurulum cache'i** — `cacheDir/art/{uuid}.webp`. Geri kalan resmî
///     paketlerin görselleri paket kurulurken [prefetchBundle] ile tek zip
///     hâlinde inip buraya açılır; okuma anında ağa çıkılmaz.
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

  /// Artık hiçbir kartın göstermediği cache'lenmiş kart görsellerini siler.
  ///
  /// Paket / dünya silindikten SONRA çağrılır: [prefetchBundle] paketin bütün
  /// görsellerini `cacheDir/art/` altına açıyor ve silme yolu DB satırlarını
  /// düşürüyordu, baytlar kalıyordu (bir paket ~50 MB). Refcount tutmak yerine
  /// tek tarama: diskteki dosya, **hâlâ canlı olan hiçbir referansta** geçmiyorsa
  /// gider. Referans kaynakları: `package_entities` + `world_entities`
  /// `image_path`, `trash_items` ve `world_characters` payload'ları. Böylece
  /// aynı görseli iki paket/dünya kullansa ya da dünya kopyalanmış olsa
  /// doğru kalır, eski sürümlerden birikmiş çöp de aynı geçişte temizlenir.
  ///
  /// Çöp 30 günde bir purge edilir ve o purge sweep tetiklemez — çöpten düşen
  /// görseller bir sonraki silmede gider, kasıtlı.
  ///
  /// Silinen dosya kayıp değil: yeniden kurulumda zip'ten, bundle'daki görsel
  /// ise [resolve] ile anında geri gelir.
  static Future<int> sweepUnreferenced(AppDatabase db) async {
    final dir = Directory(p.join(AppPaths.cacheDir, 'art'));
    if (!await dir.exists()) return 0;

    final rows = await db.customSelect(
      "SELECT DISTINCT image_path AS v FROM package_entities "
      "WHERE image_path LIKE 'dmt-art://%' "
      "UNION SELECT DISTINCT image_path AS v FROM world_entities "
      "WHERE image_path LIKE 'dmt-art://%' "
      // Silme soft-delete: paket/dünya 30 gün `trash_items`'ta durur ve
      // "Geri al" payload'dan geri yazar — görselleri şimdi silersek restore
      // kartsız gelir ve düzeltme yolu yoktur (restore zip'i yeniden
      // indirmez). Karakter payload'ı da kart blob'u taşıyabilir. İkisi de
      // opak JSON, o yüzden kolon değil metin taranır.
      "UNION SELECT DISTINCT payload_json AS v FROM trash_items "
      "WHERE payload_json LIKE '%dmt-art://%' "
      "UNION SELECT DISTINCT payload_json AS v FROM world_characters "
      "WHERE payload_json LIKE '%dmt-art://%'",
    ).get();
    final keep = <String>{};
    final artRef = RegExp(r'dmt-art://([A-Za-z0-9._-]+)');
    for (final r in rows) {
      for (final m in artRef.allMatches(r.read<String>('v'))) {
        keep.add(m.group(1)!);
      }
    }

    var removed = 0;
    await for (final f in dir.list(followLinks: false)) {
      if (f is! File) continue;
      final name = p.basename(f.path);
      // `.slug@ver.zip` gibi yarım kalmış indirmeler de gitsin.
      if (keep.contains(name)) continue;
      try {
        await f.delete();
        removed++;
      } catch (e) {
        debugPrint('[art] sweep delete failed $name: $e');
      }
    }
    return removed;
  }

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

    // Catalog'dan tek tek indirme yok: R2'de sadece paket başına zip duruyor
    // ve o kurulumda açılıyor. Burada kalan tek kaynak app bundle'ı.
    final bytes = await _loadBundled(name);
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

  /// Bir paketin bütün kart görsellerini **tek** istekte indirir: R2'de her
  /// paket için hazır duran zip (`catalog/art-bundle/{slug}@{ver}.zip`).
  ///
  /// Neden zip: tek tek indirmede 1000+ görsel, worker'ın public catalog
  /// rate limit'ini (300 istek/dk/IP) aşıyor ve kalanlar sessizce 429 yiyip
  /// düşüyordu — kullanıcıya "art'lar gelmiyor" diye görünen buydu. Zip tek
  /// istek, diske stream'lenir, kurulumda bir kez açılır.
  ///
  /// Zip yoksa (404) ya da bozuksa görseller gelmez — tek tek indirme yolu
  /// yok, R2'de `catalog/art/*` objeleri tutulmuyor. Dönen değer diskte hazır
  /// olan görsel sayısı.
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
    final tmpZip = File(p.join(AppPaths.cacheDir, 'art',
        '.${bundleKey.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.zip'));
    // Doğrudan diske stream'lenir: en büyük arşiv ~100 MB, tamamını belleğe
    // almak mobilde OOM demek.
    if (await _catalog.downloadCatalogTo(bundleKey, tmpZip)) {
      try {
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
      debugPrint('[art] bundle download failed $bundleKey');
    }

    var ok = 0;
    for (final n in names) {
      if (await File(p.join(AppPaths.cacheDir, 'art', n)).exists()) ok++;
    }
    onProgress?.call(names.length, names.length);
    return ok;
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
