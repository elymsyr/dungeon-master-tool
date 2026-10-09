import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../data/services/asset_importer.dart';
import '../../domain/value_objects/asset_ref.dart';
import 'mention_text.dart';

/// Ham dosya yollarını **veri kökünün içine** alan yerel taşıyıcı.
///
/// [RawPathMigrator]'ın çevrimdışı karşılığı: bulut servisi gerektirmez,
/// ref'e çevirmez — dosyayı `{worldsDir}/{worldId}/media/` (ya da paketler
/// için `{packagesDir}/{ad}/media/`) altına kopyalar, o kadar.
///
/// **Kural: seçilen her dosya kopyalanır** — bulut yüklemesi başarılı olsa da
/// olmasa da, ham yol hiçbir zaman saklanmaz. Kopya eskiden yalnız yükleme
/// atlandığında/başarısız olduğunda alınıyordu; bu, ham yolun sızabildiği bir
/// sürü yol bırakıyordu. Ham yol (`C:\Users\...\Downloads\map.png`):
///   * `.dmtz`'de taşınmıyor — `_mediaFor` yalnız veri kökü altını tarar,
///   * kaynak dosya taşınır/silinirse resim tamamen kayboluyor,
///   * ikinci cihazda zaten hiçbir zaman çözülemiyor.
///
/// `AssetImporter.importOne` idempotent (aynı ad + aynı boyut yeniden
/// kopyalanmaz, kaynak zaten hedef klasördeyse aynen döner), dolayısıyla bu
/// fonksiyon her seçimde ve her eşlemede güvenle çağrılabilir.
class LocalMediaLocalizer {
  const LocalMediaLocalizer._();

  /// Medya alt klasörü — [AssetImporter.importImages] ile aynı.
  static const String mediaSubDir = 'media';

  /// Resim olmayan ekler (entity `file` / `pdf` alanları) buraya gider.
  /// PDF kütüphanesinin `pdfs/` klasörüne karışmasın diye ayrı.
  static const String filesSubDir = 'files';

  /// Dünya içeriğinin kendi klasörü — **dünya id'si ile** anahtarlı.
  ///
  /// İsimle değil, çünkü isim değişebilir ve benzersiz değil: iki dünya aynı
  /// adı taşıyabildiği anda aynı klasörü paylaşırlardı ve [UnusedMediaSweeper]
  /// birini açıp kapatmak diğerinin dosyalarını referanssız sayıp silerdi.
  /// id'yle anahtarlı olduğu için yeniden adlandırma da klasöre dokunmuyor.
  static String worldDir(String worldId) =>
      p.join(AppPaths.worldsDir, dirSafe(worldId));

  /// Paket içeriğinin kendi klasörü.
  static String packageDir(String packageName) =>
      p.join(AppPaths.packagesDir, dirSafe(packageName));

  /// Ad → klasör adı. Windows'ta `\ / : * ? " < > |`, kontrol karakterleri,
  /// sondaki nokta/boşluk ve `CON`/`NUL`/`COM1`… aygıt adları yol adında
  /// yasak; sanitize edilmezse `Directory.exists` bile ERROR_INVALID_NAME
  /// (123) fırlatır ve o dünyada her medya işlemi hataya düşer. Linux ve
  /// Android hepsini kabul ettiği için hata yalnız Windows'ta görünür —
  /// ör. `Aegis — Meridia: Birinci Perde`.
  ///
  /// Temiz adlarda birim fonksiyon: var olan klasörler yerinde kalır.
  static String dirSafe(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();
    if (cleaned.isEmpty) return '_';
    return _winReserved.hasMatch(cleaned) ? '_$cleaned' : cleaned;
  }

  /// MS-DOS aygıt adları — uzantı eklense bile açılamıyorlar (`CON.txt`).
  static final RegExp _winReserved = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
    caseSensitive: false,
  );

  /// Tek bir yolu veri kökü altına alır; kopyalanamazsa [path] aynen döner.
  ///
  /// [ownerDir] içeriğin kendi klasörü ([worldDir] / [packageDir]).
  /// [imagesOnly] false ise uzantı süzgeci uygulanmaz (ek dosya alanları).
  static Future<String> localize(
    String path, {
    required String ownerDir,
    String subDir = mediaSubDir,
    bool imagesOnly = true,
  }) async {
    if (!await _isLocalizable(path, ownerDir, imagesOnly: imagesOnly)) {
      return path;
    }
    try {
      final copied = await AssetImporter.importOne(ownerDir, subDir, path);
      return copied ?? path;
    } catch (e) {
      debugPrint('LocalMediaLocalizer.localize($path): $e');
      return path;
    }
  }

  /// [localize]'ın liste hâli.
  static Future<List<String>> localizeAll(
    List<String> paths, {
    required String ownerDir,
    String subDir = mediaSubDir,
    bool imagesOnly = true,
  }) async =>
      [
        for (final path in paths)
          await localize(
            path,
            ownerDir: ownerDir,
            subDir: subDir,
            imagesOnly: imagesOnly,
          ),
      ];

  /// Karakter portresi / kapağı — karakter medyası `{charactersDir}` altında
  /// **düz** duruyor ve `ContentCodec._mediaFor` dosyaları `{id}_` önekiyle
  /// ayırt ediyor. Dolayısıyla hem klasör hem ad önemli: doğru klasörde ama
  /// öneksiz duran bir dosya da kopyalanır.
  static Future<String> localizeCharacterImage(
    String path, {
    required String characterId,
  }) async {
    final prefix = '${characterId}_';
    if (!await _isLocalizable(path, null)) return path;
    if (_isUnder(AppPaths.charactersDir, p.normalize(path)) &&
        p.basename(path).startsWith(prefix)) {
      return path;
    }
    try {
      final copied = await AssetImporter.importOne(
        AppPaths.charactersDir,
        '',
        path,
        namePrefix: prefix,
      );
      return copied ?? path;
    } catch (e) {
      debugPrint('LocalMediaLocalizer.localizeCharacterImage($path): $e');
      return path;
    }
  }

  /// Dünya payload'ındaki bütün ham yolları `{worldsDir}/{id}/media/` altına
  /// alır ve ağacı **yerinde** günceller. Bir şey değiştiyse true döner —
  /// çağıran dünyayı kaydetmelidir.
  ///
  /// Tek geçiş bütün bölümleri kapsıyor, çünkü hepsi aynı ağaçta:
  /// `combat_state.encounters[].mapPath` (battle map arka planı),
  /// `mind_maps[].nodes[].imageUrl` (mindmap not resmi), `map_data`,
  /// `entities[].images[]`.
  static Future<bool> localizeWorldPayload(
    Map<String, dynamic> payload,
    String worldId,
  ) =>
      _walk(payload, worldDir(worldId));

  /// Paket payload'ının karşılığı — hedef `{packagesDir}/{ad}`.
  static Future<bool> localizePackagePayload(
    Map<String, dynamic> payload,
    String packageName,
  ) =>
      _walk(payload, packageDir(packageName));

  /// [fromWorldId]'nin klasörünü olduğu gibi [toWorldId]'ninkine kopyalar ve
  /// [payload]'daki yolları yeni klasöre çevirir. Dünya kopyalama için:
  /// `.dmtz` de klasörün tamamını taşıyor, kopya da aynısını alır — resimler,
  /// PDF'ler, ekler, markdown'a gömülü resimler. Referanssız kalanı kopyanın
  /// kendi süpürgesi ([UnusedMediaSweeper]) temizler.
  static Future<Map<String, dynamic>> copyWorldFiles(
    Map<String, dynamic> payload,
    String fromWorldId,
    String toWorldId,
  ) async {
    final from = worldDir(fromWorldId);
    final to = worldDir(toWorldId);
    final src = Directory(from);
    if (await src.exists()) {
      await for (final e in src.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final target = File(p.join(to, p.relative(e.path, from: from)));
        await target.parent.create(recursive: true);
        await e.copy(target.path);
      }
    }
    return rebase(payload, from, to) as Map<String, dynamic>;
  }

  /// Ağaçtaki bütün string'lerde [fromBase] altını gösteren yolları [toBase]
  /// altına taşır — düz yollar ve markdown'a gömülü `dmt-img:` resimleri.
  /// Alan adı bilmez, bu yüzden yeni bir medya alanı eklendiğinde burada
  /// bakım gerekmez. Bulut ref'lerine (`dmt-asset://`, `dmt-public://`)
  /// dokunmaz; onlar zaten cihazdan bağımsız. `.dmtz` import'u gönderenin
  /// veri kökünü bununla kendi köküne çevirir.
  static Object? rebase(Object? node, String fromBase, String toBase) {
    if (fromBase.isEmpty || fromBase == toBase) return node;
    if (node is String) {
      return _rebasePath(node, fromBase, toBase) ??
          mapMarkdownImageRefs(
              node, (ref) => _rebasePath(ref, fromBase, toBase));
    }
    if (node is List) {
      return [for (final v in node) rebase(v, fromBase, toBase)];
    }
    if (node is Map) {
      return <String, dynamic>{
        for (final e in node.entries)
          '${e.key}': rebase(e.value, fromBase, toBase),
      };
    }
    return node;
  }

  /// Windows `\` ve POSIX `/` ayırıcılarını normalize ederek prefix takası.
  static String? _rebasePath(String value, String fromBase, String toBase) {
    final v = value.replaceAll('\\', '/');
    final from = fromBase.replaceAll('\\', '/');
    if (!v.startsWith('$from/')) return null;
    final rel = v.substring(from.length + 1);
    if (rel.isEmpty) return null;
    return p.joinAll([toBase, ...rel.split('/')]);
  }

  static Future<bool> _walk(Object? node, String ownerDir) async {
    if (node is Map) {
      var any = false;
      for (final key in node.keys.toList()) {
        final v = node[key];
        if (v is String) {
          final next = await localize(v, ownerDir: ownerDir);
          if (!identical(next, v) && next != v) {
            node[key] = next;
            any = true;
          }
        } else if (await _walk(v, ownerDir)) {
          any = true;
        }
      }
      return any;
    }
    if (node is List) {
      var any = false;
      for (var i = 0; i < node.length; i++) {
        final v = node[i];
        if (v is String) {
          final next = await localize(v, ownerDir: ownerDir);
          if (next != v) {
            node[i] = next;
            any = true;
          }
        } else if (await _walk(v, ownerDir)) {
          any = true;
        }
      }
      return any;
    }
    return false;
  }

  /// Kopyalanması gereken bir yol mu?
  ///
  /// Hayır ise: boş, şema'lı ref (`dmt-*://`), resim uzantısı taşımayan bir
  /// string, diskte bulunmayan bir yol, ya da zaten taşınabilir bir yerde
  /// duran bir dosya — yani [ownerDir] altında (`.dmtz` item'ın kendi
  /// klasörünü tarıyor) veya içerik-adresli önbellekte (bulut ref'lerinin
  /// baytları oradan ayrıca taşınıyor, bkz.
  /// `ContentCodec._collectContentBlobs`).
  ///
  /// Dikkat: "veri kökünün altında" olmak **yetmez**. Veri kökü altındaki
  /// rastgele bir klasör (ör. `cache/tmp/`) hiçbir item taramasına girmiyor.
  static Future<bool> _isLocalizable(
    String value,
    String? ownerDir, {
    bool imagesOnly = true,
  }) async {
    if (value.isEmpty) return false;
    if (!AssetRef(value).isLocal) return false;
    if (imagesOnly && !_imageExt.hasMatch(value)) return false;
    if (!p.isAbsolute(value)) return false;
    final target = p.normalize(value);
    if (ownerDir != null && _isUnder(ownerDir, target)) return false;
    if (_isUnder(AppPaths.cacheDir, target)) return false;
    return File(value).exists();
  }

  static bool _isUnder(String dir, String target) {
    final base = p.normalize(dir);
    return p.equals(base, target) || p.isWithin(base, target);
  }

  static final RegExp _imageExt =
      RegExp(r'\.(png|jpe?g|webp|gif|bmp)$', caseSensitive: false);
}
