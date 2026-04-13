import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/config/app_paths.dart';
import '../../data/datasources/local/campaign_local_ds.dart';
import '../../domain/repositories/campaign_repository.dart';

final _log = Logger(printer: SimplePrinter());
const _uuid = Uuid();

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

        // Entity ID'lerini yeniden üret — `entities` tablosunun PK'sı
        // global `id` olduğu için aynı world'ü ikinci kez import edince
        // veya iki ayrı world aynı UUID'yi kullanırsa UNIQUE constraint
        // failure alıyoruz. Yeniden üretim cross-reference'ları da
        // (location_id, pin entity_id, combatant eid, mind map nodes,
        // timeline entity_ids) günceller.
        await _regenerateEntityIds(targetPath);

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

  /// Kampanya verisini oku, tüm görsel referanslarını (entity'ler,
  /// map_data, encounter battle map'leri, mind map image node'ları)
  /// [imageMap] ile yeni absolute path'lere yeniden yaz, geri kaydet.
  ///
  /// Bu adım `SchemaMigration.migrate()`'den ÖNCE çalışıyor, bu yüzden
  /// Python key isimlerini (snake_case) kullanıyoruz. Migration sonradan
  /// bu path'leri camelCase alanlara taşıyacak.
  Future<void> _rewriteCampaignImageRefs(
    String worldPath,
    Map<String, String> imageMap,
  ) async {
    final data = await _localDs.load(worldPath);
    var rewrittenCount = 0;

    // 1. Entities
    final entities = data['entities'];
    if (entities is Map) {
      for (final entry in entities.entries) {
        final entity = entry.value;
        if (entity is! Map) continue;
        rewrittenCount += _rewriteEntityImages(entity, imageMap);
      }
    }

    // 2. map_data.image_path (world map) + epochs
    final mapData = data['map_data'];
    if (mapData is Map) {
      rewrittenCount += _rewriteSingleKey(mapData, 'image_path', imageMap);
      rewrittenCount += _rewriteSingleKey(mapData, 'imagePath', imageMap);
      // Epochs (eski kayıtlarda varsa)
      final epochs = mapData['epochs'];
      if (epochs is List) {
        for (final epoch in epochs) {
          if (epoch is Map) {
            rewrittenCount += _rewriteSingleKey(epoch, 'image_path', imageMap);
            rewrittenCount += _rewriteSingleKey(epoch, 'imagePath', imageMap);
          }
        }
      }
    }

    // 3. sessions[*].encounters[*].map_path (battle map'ler).
    // Hem List hem Map şekli destekleniyor (iki Python format da var).
    final sessions = data['sessions'];
    if (sessions is List) {
      for (final session in sessions) {
        if (session is! Map) continue;
        final encounters = session['encounters'];
        if (encounters is List) {
          for (final enc in encounters) {
            if (enc is Map) {
              rewrittenCount += _rewriteSingleKey(enc, 'map_path', imageMap);
              rewrittenCount += _rewriteSingleKey(enc, 'mapPath', imageMap);
            }
          }
        } else if (encounters is Map) {
          for (final enc in encounters.values) {
            if (enc is Map) {
              rewrittenCount += _rewriteSingleKey(enc, 'map_path', imageMap);
              rewrittenCount += _rewriteSingleKey(enc, 'mapPath', imageMap);
            }
          }
        }
      }
    }

    // 4. mind_maps[*].nodes[*].extra.path (image node'lar)
    final mindMaps = data['mind_maps'];
    if (mindMaps is Map) {
      for (final mm in mindMaps.values) {
        if (mm is! Map) continue;
        final nodes = mm['nodes'];
        if (nodes is! List) continue;
        for (final node in nodes) {
          if (node is! Map) continue;
          final extra = node['extra'];
          if (extra is Map) {
            rewrittenCount += _rewriteSingleKey(extra, 'path', imageMap);
          }
          // Zaten camelCase imageUrl ile gelmişse de dene.
          rewrittenCount += _rewriteSingleKey(node, 'imageUrl', imageMap);
        }
      }
    }

    if (rewrittenCount > 0) {
      await _localDs.save(worldPath, Map<String, dynamic>.from(data));
      _log.i('Rewrote $rewrittenCount image reference(s) in $worldPath');
    }
  }

  /// Entity seviyesindeki image alanlarını yeniden yazar.
  /// Dönen değer: yeniden yazılan referans sayısı.
  int _rewriteEntityImages(Map entity, Map<String, String> imageMap) {
    var count = 0;

    // images: List<String>
    final images = entity['images'];
    if (images is List) {
      final newImages = <dynamic>[];
      for (final img in images) {
        if (img is String) {
          final mapped = _lookupImage(imageMap, img);
          if (mapped != null) {
            newImages.add(mapped);
            count++;
          } else {
            newImages.add(img);
          }
        } else {
          newImages.add(img);
        }
      }
      entity['images'] = newImages;
    }

    // image_path: legacy tekil görsel
    count += _rewriteSingleKey(entity, 'image_path', imageMap);

    // battlemaps: Python location entity'lerinde battle map listesi
    final battlemaps = entity['battlemaps'];
    if (battlemaps is List) {
      final newBms = <dynamic>[];
      for (final bm in battlemaps) {
        if (bm is String) {
          final mapped = _lookupImage(imageMap, bm);
          if (mapped != null) {
            newBms.add(mapped);
            count++;
          } else {
            newBms.add(bm);
          }
        } else {
          newBms.add(bm);
        }
      }
      entity['battlemaps'] = newBms;
    }

    return count;
  }

  /// [container][key] bir String image referansıysa, [imageMap] üzerinden
  /// çevir. Çevrilenlerin sayısını döner (0 veya 1).
  int _rewriteSingleKey(
    Map container,
    String key,
    Map<String, String> imageMap,
  ) {
    final value = container[key];
    if (value is! String || value.isEmpty) return 0;
    final mapped = _lookupImage(imageMap, value);
    if (mapped == null) return 0;
    container[key] = mapped;
    return 1;
  }

  /// Entity UUID'lerini baştan üretir ve tüm cross-reference'ları günceller.
  /// `entities` tablosunun global `id` PK'sı nedeniyle aynı legacy world'ün
  /// tekrar tekrar import'u veya iki ayrı world'ün aynı UUID'yi kullanması
  /// UNIQUE constraint ihlaline yol açıyor. Bu metod raw data.dat'ı okur,
  /// her entity için yeni UUID üretir, bilinen tüm referans alanlarını
  /// yeniden haritalar ve dosyayı geri yazar.
  Future<void> _regenerateEntityIds(String worldPath) async {
    final data = await _localDs.load(worldPath);
    final entities = data['entities'];
    if (entities is! Map || entities.isEmpty) return;

    // 1. Eski → yeni mapping.
    final idMap = <String, String>{};
    for (final key in entities.keys) {
      idMap[key.toString()] = _uuid.v4();
    }

    // 2. Entities map'ini yeni key'lerle yeniden inşa et.
    final newEntities = <String, dynamic>{};
    for (final entry in entities.entries) {
      final oldId = entry.key.toString();
      final newId = idMap[oldId]!;
      final entity = entry.value;
      if (entity is Map) {
        final m = Map<String, dynamic>.from(entity);
        // `id` alanını da tut (bazı yerlerde direkt olarak okunuyor olabilir).
        m['id'] = newId;
        // location_id: başka bir entity'ye işaret ediyorsa re-map.
        final locId = m['location_id'];
        if (locId is String && idMap.containsKey(locId)) {
          m['location_id'] = idMap[locId];
        }
        newEntities[newId] = m;
      } else {
        newEntities[newId] = entity;
      }
    }
    data['entities'] = newEntities;

    // 3. map_data.pins[*].entity_id / entityId
    final mapData = data['map_data'];
    if (mapData is Map) {
      final pins = mapData['pins'];
      if (pins is List) {
        for (final pin in pins) {
          if (pin is Map) {
            _remapId(pin, 'entity_id', idMap);
            _remapId(pin, 'entityId', idMap);
          }
        }
      }
      // map_data.timeline[*].entity_ids / entityIds (liste)
      final timeline = mapData['timeline'];
      if (timeline is List) {
        for (final t in timeline) {
          if (t is Map) {
            _remapIdList(t, 'entity_ids', idMap);
            _remapIdList(t, 'entityIds', idMap);
          }
        }
      }
    }

    // 4. sessions[*].(encounters|combatants) içinde combatant eid/entityId
    final sessions = data['sessions'];
    if (sessions is List) {
      for (final s in sessions) {
        if (s is! Map) continue;
        // Session-level (legacy) combatants
        _remapCombatants(s['combatants'], idMap);

        // encounters List veya Map
        final enc = s['encounters'];
        if (enc is List) {
          for (final e in enc) {
            if (e is Map) _remapCombatants(e['combatants'], idMap);
          }
        } else if (enc is Map) {
          for (final e in enc.values) {
            if (e is Map) _remapCombatants(e['combatants'], idMap);
          }
        }
      }
    }

    // 5. mind_maps[*].nodes[*].extra.eid / entityId
    final mindMaps = data['mind_maps'];
    if (mindMaps is Map) {
      for (final mm in mindMaps.values) {
        if (mm is! Map) continue;
        final nodes = mm['nodes'];
        if (nodes is! List) continue;
        for (final n in nodes) {
          if (n is! Map) continue;
          _remapId(n, 'entityId', idMap);
          final extra = n['extra'];
          if (extra is Map) {
            _remapId(extra, 'eid', idMap);
            _remapId(extra, 'entityId', idMap);
          }
        }
      }
    }

    await _localDs.save(worldPath, Map<String, dynamic>.from(data));
    _log.i('Regenerated ${idMap.length} entity ID(s) in $worldPath');
  }

  void _remapId(Map m, String key, Map<String, String> idMap) {
    final v = m[key];
    if (v is String && idMap.containsKey(v)) {
      m[key] = idMap[v];
    }
  }

  void _remapIdList(Map m, String key, Map<String, String> idMap) {
    final v = m[key];
    if (v is! List) return;
    final newList = <dynamic>[];
    for (final item in v) {
      if (item is String && idMap.containsKey(item)) {
        newList.add(idMap[item]);
      } else {
        newList.add(item);
      }
    }
    m[key] = newList;
  }

  void _remapCombatants(dynamic combatants, Map<String, String> idMap) {
    if (combatants is! List) return;
    for (final c in combatants) {
      if (c is! Map) continue;
      _remapId(c, 'eid', idMap);
      _remapId(c, 'entityId', idMap);
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
