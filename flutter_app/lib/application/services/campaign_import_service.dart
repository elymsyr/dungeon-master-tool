import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../data/datasources/local/campaign_local_ds.dart';
import '../../domain/repositories/campaign_repository.dart';

final _log = Logger(printer: SimplePrinter());

const _imageExtensions = <String>{
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
};

/// Tek bir import çağrısının sonucu.
class CampaignImportResult {
  /// Hedefe kopyalanmış world adları (kaynak isimlerle).
  final List<String> imported;

  /// Çakışma nedeniyle yeniden adlandırılanlar. Değer: `"eskiAd → yeniAd"`.
  final List<String> renamed;

  /// `data.dat`/`data.json` bulunamadığı için atlanan alt klasörler.
  final List<String> skipped;

  /// Kopyalama sırasında hata oluşan world'ler. Değer: `"ad: hata"`.
  final List<String> errors;

  const CampaignImportResult({
    required this.imported,
    required this.renamed,
    required this.skipped,
    required this.errors,
  });

  int get total => imported.length;
  bool get hasAny => imported.isNotEmpty || renamed.isNotEmpty || errors.isNotEmpty;
}

/// Eski Python (v0.8.4 +) worlds/ klasörlerini Flutter'ın
/// [AppPaths.worldsDir] altına kopyalar.
///
/// Adımlar:
/// 1. World klasör(ler)ini özyinelemeli kopyala.
/// 2. Legacy `assets/` altındaki görselleri Flutter media gallery'nin
///    taradığı `media/` dizinine kopyala.
/// 3. Kopyalanan `data.dat`/`data.json`'u aç, entity image referanslarını
///    medyadaki yeni absolute path'lere yeniden yaz ve geri kaydet.
/// 4. `CampaignRepositoryImpl.load()` çağırarak mevcut
///    `SchemaMigration.migrate()` → SQLite pipeline'ını tetikle.
class CampaignImportService {
  final CampaignRepository _repo;
  final CampaignLocalDataSource _localDs;

  CampaignImportService(this._repo, this._localDs);

  /// [sourceDir] ya (a) tek bir world klasörü (içinde `data.dat`/`data.json`)
  /// ya da (b) birden çok world alt klasörü içeren bir parent klasör olabilir.
  /// Otomatik tespit edilir.
  Future<CampaignImportResult> importFromDirectory(String sourceDir) async {
    final imported = <String>[];
    final renamed = <String>[];
    final skipped = <String>[];
    final errors = <String>[];

    final source = Directory(sourceDir);
    if (!await source.exists()) {
      errors.add('$sourceDir: klasör bulunamadı');
      return CampaignImportResult(
        imported: imported,
        renamed: renamed,
        skipped: skipped,
        errors: errors,
      );
    }

    final worldFolders = await _discoverWorldFolders(source);
    if (worldFolders.isEmpty) {
      skipped.add(p.basename(sourceDir));
      return CampaignImportResult(
        imported: imported,
        renamed: renamed,
        skipped: skipped,
        errors: errors,
      );
    }

    // Mevcut kampanya adları (DB + legacy dosya).
    final existing = (await _repo.getAvailable()).toSet();

    for (final worldDir in worldFolders) {
      final originalName = p.basename(worldDir.path);
      final targetName = _resolveConflictFreeName(originalName, existing);
      final targetPath = p.join(AppPaths.worldsDir, targetName);

      try {
        await _copyDirectory(worldDir, Directory(targetPath));

        // Görselleri media gallery'nin göreceği konuma kopyala ve entity
        // referanslarını yeniden yaz. Bu adımlar `_repo.load()` öncesinde
        // olmalı, çünkü load mevcut path'leri SQLite'a migrate ediyor.
        final imageMap = await _migrateWorldImages(targetPath);
        if (imageMap.isNotEmpty) {
          await _rewriteCampaignImageRefs(targetPath, imageMap);
        }

        // Eager migration: CampaignRepositoryImpl.load() legacy MsgPack
        // dosyasını tespit edip SchemaMigration.migrate() + _migrateToDb()
        // pipeline'ı ile SQLite'a yazar. Bunu yapmazsak kopyalanan world
        // sadece legacy-aware `campaignListProvider`'da görünür;
        // `campaignInfoListProvider` (hub/worlds_tab) sadece SQLite
        // okuduğu için boş kalır.
        await _repo.load(targetName);

        imported.add(targetName);
        existing.add(targetName); // aynı import içindeki sonraki çakışmalar için
        if (targetName != originalName) {
          renamed.add('$originalName → $targetName');
        }
        _log.i('Campaign imported: $originalName → $targetName');
      } catch (e, st) {
        _log.w('Campaign import failed: $originalName', error: e, stackTrace: st);
        errors.add('$originalName: $e');
        // Kısmi kopyayı temizle.
        try {
          final partial = Directory(targetPath);
          if (await partial.exists()) {
            await partial.delete(recursive: true);
          }
        } catch (_) {}
      }
    }

    return CampaignImportResult(
      imported: imported,
      renamed: renamed,
      skipped: skipped,
      errors: errors,
    );
  }

  /// [source] bir world klasörü mü (içinde `data.dat`/`data.json`) yoksa
  /// bir parent klasör mü? Otomatik tespit ederek world klasörlerinin
  /// listesini döner.
  Future<List<Directory>> _discoverWorldFolders(Directory source) async {
    if (await _isWorldFolder(source)) {
      return [source];
    }

    final result = <Directory>[];
    await for (final entry in source.list(followLinks: false)) {
      if (entry is Directory && await _isWorldFolder(entry)) {
        result.add(entry);
      }
    }
    return result;
  }

  Future<bool> _isWorldFolder(Directory dir) async {
    final dat = File(p.join(dir.path, 'data.dat'));
    if (await dat.exists()) return true;
    final json = File(p.join(dir.path, 'data.json'));
    return json.exists();
  }

  String _resolveConflictFreeName(String original, Set<String> existing) {
    if (!existing.contains(original) &&
        !Directory(p.join(AppPaths.worldsDir, original)).existsSync()) {
      return original;
    }
    var i = 2;
    while (true) {
      final candidate = '$original ($i)';
      if (!existing.contains(candidate) &&
          !Directory(p.join(AppPaths.worldsDir, candidate)).existsSync()) {
        return candidate;
      }
      i++;
    }
  }

  /// [source]'un tüm içeriğini [target]'a özyinelemeli kopyalar.
  /// Symlink'leri takip etmez.
  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entry in source.list(recursive: false, followLinks: false)) {
      final newPath = p.join(target.path, p.basename(entry.path));
      if (entry is Directory) {
        await _copyDirectory(entry, Directory(newPath));
      } else if (entry is File) {
        await entry.copy(newPath);
      }
      // Link: atlanır.
    }
  }

  /// Legacy `assets/` altındaki tüm görselleri [worldPath]`/media/`'e
  /// kopyalar. Dönen map, entity içindeki muhtemel referansları (relative
  /// veya basename) yeni absolute path'e eşler.
  ///
  /// Aynı dosya assets/ altında birden fazla yerde ise tek bir kopya
  /// yeterli; çakışma olduğunda media içinde sayaç ile ayrıştırır.
  /// Büyük/küçük harf duyarsız anahtarlar kullanılır (Windows<->Linux
  /// migration'larında bu yaygın bir sorun).
  Future<Map<String, String>> _migrateWorldImages(String worldPath) async {
    final assetsDir = Directory(p.join(worldPath, 'assets'));
    if (!await assetsDir.exists()) return const {};

    final mediaDir = Directory(p.join(worldPath, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    // Mevcut media dosya adları (collision detection).
    final usedNames = <String>{};
    await for (final entry in mediaDir.list(followLinks: false)) {
      if (entry is File) usedNames.add(p.basename(entry.path));
    }

    // Dosya içeriği hash'i yerine (source, target) eşlemesi:
    // aynı absolute source iki kez görünürse tek copy yapılır.
    final copiedByAbsSource = <String, String>{};
    final result = <String, String>{};

    await for (final entry
        in assetsDir.list(recursive: true, followLinks: false)) {
      if (entry is! File) continue;
      final ext = p.extension(entry.path).toLowerCase();
      if (!_imageExtensions.contains(ext)) continue;

      final absSource = p.normalize(entry.absolute.path);
      String targetAbs;
      if (copiedByAbsSource.containsKey(absSource)) {
        targetAbs = copiedByAbsSource[absSource]!;
      } else {
        final uniqueName = _uniqueMediaName(p.basename(entry.path), usedNames);
        usedNames.add(uniqueName);
        targetAbs = p.join(mediaDir.path, uniqueName);
        try {
          await entry.copy(targetAbs);
        } catch (e) {
          _log.w('Media copy failed: ${entry.path}', error: e);
          continue;
        }
        copiedByAbsSource[absSource] = targetAbs;
      }

      // Entity referanslarında dosya şu şekillerde görülebilir:
      //   - "assets/foo.png"           (world köküne göre relative)
      //   - "assets/subdir/foo.png"    (derin relative)
      //   - "foo.png"                  (sadece basename)
      //   - Windows backslash'li varyantlar
      //   - Orijinal absolute path (Python _fix_absolute_paths öncesi)
      final relFromWorld =
          p.relative(entry.path, from: worldPath).replaceAll('\\', '/');
      final basename = p.basename(entry.path);
      _addKey(result, relFromWorld, targetAbs);
      _addKey(result, relFromWorld.replaceAll('/', '\\'), targetAbs);
      _addKey(result, basename, targetAbs);
      _addKey(result, absSource, targetAbs);
    }

    _log.i(
      'Media migration: ${copiedByAbsSource.length} file(s) → ${mediaDir.path}',
    );
    return result;
  }

  void _addKey(Map<String, String> map, String key, String value) {
    if (key.isEmpty) return;
    map[key] = value;
    map[key.toLowerCase()] = value;
  }

  String _uniqueMediaName(String basename, Set<String> used) {
    if (!used.contains(basename)) return basename;
    final stem = p.basenameWithoutExtension(basename);
    final ext = p.extension(basename);
    var i = 2;
    while (true) {
      final candidate = '${stem}_$i$ext';
      if (!used.contains(candidate)) return candidate;
      i++;
    }
  }

  /// Kampanya verisini oku, `entities[*].images` ve `image_path`
  /// referanslarını [imageMap] ile yeni absolute path'lere yeniden yaz,
  /// geri kaydet. `_repo.load()` bu düzeltilmiş veriyi SQLite'a alacak.
  Future<void> _rewriteCampaignImageRefs(
    String worldPath,
    Map<String, String> imageMap,
  ) async {
    final data = await _localDs.load(worldPath);
    final entities = data['entities'];
    if (entities is! Map) return;

    var rewrittenCount = 0;
    for (final entry in entities.entries) {
      final entity = entry.value;
      if (entity is! Map) continue;

      // images: List<String>
      final images = entity['images'];
      if (images is List) {
        final newImages = <dynamic>[];
        for (final img in images) {
          if (img is String) {
            final mapped = _lookupImage(imageMap, img);
            if (mapped != null) {
              newImages.add(mapped);
              rewrittenCount++;
            } else {
              newImages.add(img);
            }
          } else {
            newImages.add(img);
          }
        }
        entity['images'] = newImages;
      }

      // image_path: legacy single image
      final imagePath = entity['image_path'];
      if (imagePath is String && imagePath.isNotEmpty) {
        final mapped = _lookupImage(imageMap, imagePath);
        if (mapped != null) {
          entity['image_path'] = mapped;
          rewrittenCount++;
        }
      }
    }

    if (rewrittenCount > 0) {
      await _localDs.save(worldPath, Map<String, dynamic>.from(data));
      _log.i('Rewrote $rewrittenCount image reference(s) in $worldPath');
    }
  }

  String? _lookupImage(Map<String, String> map, String ref) {
    // Doğrudan, ters-slash çevrilmiş ve lowercase varyantları dene.
    if (map.containsKey(ref)) return map[ref];
    final forward = ref.replaceAll('\\', '/');
    if (map.containsKey(forward)) return map[forward];
    final lower = forward.toLowerCase();
    if (map.containsKey(lower)) return map[lower];
    // Sadece basename'e de bak.
    final base = p.basename(forward);
    if (map.containsKey(base)) return map[base];
    if (map.containsKey(base.toLowerCase())) return map[base.toLowerCase()];
    return null;
  }
}
