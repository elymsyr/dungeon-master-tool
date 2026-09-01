import 'dart:convert';
import 'dart:io' show File, Platform, gzip;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/config/app_paths.dart';
import '../../core/utils/unique_name.dart';
import '../../data/repositories/character_repository.dart';
import '../../data/services/first_party_catalog_service.dart';
import '../../domain/entities/catalog/catalog_entry.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/character_ext.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/dnd5e_constants.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../../domain/services/builtin_content_names.dart';
import '../../domain/services/world_blueprint_converter.dart';
import '../providers/character_provider.dart' show kPlayerCategorySlugs;
import '../providers/pinned_entity_provider.dart' show kPinnedEntitiesKey;
import 'pdf_library_service.dart';

/// `assets/worlds/` altındaki paketlenmiş dünyaları kurar / kaldırır.
///
/// Her dünya dizini `manifest.json`, `world-blueprint.json`, `blueprint.json`
/// ve bir `media/` klasörü taşır. Blueprint → entity çevirisi
/// [WorldBlueprintConverter] ile yapılır; bu sınıf sadece I/O yapar:
/// asset okuma, medya çıkarma, repository'ye yazma.
///
/// Üç şey kasıtlı ve kritik:
///
///  1. **Built-in D&D 5e şeması world'e yazılır.** `CampaignRepository.save`
///     yeni bir world'ü şablonsuz açar; şablonsuz world'de `_loadFromDb`'nin
///     SRD self-heal bloğu çalışmaz, dolayısıyla SRD paketi hiç bağlanmaz ve
///     `{slug, name}` soft ref'leri (silah, zırh, büyü, trait…) okuma anında
///     hedefsiz kalıp sessizce düşer. `template_id` + `world_schema`
///     yazıldığında SRD her kurulu dünyada varsayılan olarak bulunur.
///  2. **Medya diske çıkarılır.** `image_path` local ref olarak **mutlak**
///     dosya yolu bekler (bkz. `AssetRef.isLocal`); blueprint'teki
///     `media/Tokens/x.webp` gibi relative yollar `File(...)` ile açılamaz ve
///     resim hiç görünmez.
///  3. **Hata yutulmaz.** Çözülemeyen ref / eksik medya [InstallReport]
///     içinde döner; sessiz kısmi kurulum "içerik doğru geldi mi bilmiyorum"
///     durumunun kaynağıydı.
///  4. **PC'ler entity değil karakter.** `blueprint.json` içindeki oyuncu
///     karakterleri `world_characters`'a **ownersız** (unclaimed) yazılır,
///     yani dünyanın Characters sekmesinde çıkar. World entity'si olarak
///     yazıldıklarında hiçbir yerde görünmüyorlardı: Database sekmesi
///     `player-character` kategorisini listeden çıkarıyor.
/// Where one world file's bytes come from, keyed by its path relative to the
/// world directory (`media/Tokens/x.webp`, `Adventure.pdf`). Null means "not
/// available from this source" — the caller reports it as an issue rather than
/// installing silently incomplete media.
///
/// Two implementations: the asset bundle ([BundledWorldsInstaller.installAll])
/// and the R2 catalog with a bundled fallback
/// ([BundledWorldsInstaller.installFromCatalog]).
typedef WorldFileLoader = Future<Uint8List?> Function(String rel);

class BundledWorldsInstaller {
  BundledWorldsInstaller(this._repo, this._chars);
  final CampaignRepository _repo;
  final CharacterRepository _chars;

  static const _manifestAsset = 'assets/worlds/manifest.json';
  static const _assetDir = 'assets/worlds';

  /// Bu build'de paketlenmiş dünya var mı. Mobilde asla: `assets/worlds/`
  /// build'e girmiyor (bkz. pubspec.yaml) ve telefonda dünyalar yalnız
  /// marketplace'ten kuruluyor — admin toggle'ı orada hiç görünmesin.
  Future<bool> isAvailable() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) return false;
    return (await _tryLoad(_manifestAsset)) != null;
  }

  /// Her paketlenmiş dünyayı kurar. Idempotent — isme göre upsert.
  Future<InstallReport> installAll() async {
    final report = InstallReport();
    final raw = await _tryLoad(_manifestAsset);
    if (raw == null) return report;
    final worlds = (jsonDecode(raw) as Map)['worlds'];
    if (worlds is! List) return report;

    for (final w in worlds.whereType<Map>()) {
      final dir = w['dir'] as String?;
      if (dir == null) continue;
      final base = '$_assetDir/$dir';
      try {
        final manifestRaw = await _tryLoad('$base/manifest.json');
        if (manifestRaw == null) {
          report.failures.add('$dir: manifest.json not found');
          continue;
        }
        await _installWorld(
          dir: dir,
          manifest: jsonDecode(manifestRaw) as Map<String, dynamic>,
          worldBlueprint: await _tryLoadJson('$base/world-blueprint.json'),
          characterBlueprint: await _tryLoadJson('$base/blueprint.json'),
          loadMedia: (rel) => _loadAssetBytes('$base/$rel'),
          report: report,
          installedFrom: 'assets',
        );
      } catch (e, st) {
        report.failures.add('$dir: $e\n$st');
      }
    }
    return report;
  }

  /// Kataloğun `world` girdisini kurar: payload zarfı R2'den (başarısızsa
  /// bundle'dan), medya R2'den (başarısızsa bundle'dan), barındırmadığımız
  /// dosyalar (PDF) bundle'dan ya da yayıncının linkinden.
  ///
  /// Bundle her zaman fallback — dünya uygulamayla birlikte geliyor, R2
  /// güncellenebilir kaynak.
  Future<InstallReport> installFromCatalog(
    CatalogEntry entry,
    FirstPartyCatalogService svc,
  ) async {
    final report = InstallReport();
    final base = entry.bundledDir; // '' olabilir: sadece-R2 bir dünya
    final dir = base.isEmpty ? entry.slug : p.posix.split(base).last;

    final envelope = await _fetchEnvelope(entry, svc, base);
    if (envelope == null) {
      report.failures.add('${entry.slug}: payload unavailable');
      return report;
    }
    final manifest = envelope['manifest'];
    if (manifest is! Map) {
      report.failures.add('${entry.slug}: envelope has no manifest');
      return report;
    }

    final byRel = {for (final m in entry.media) m.rel: m};
    final externalByRel = {for (final f in entry.externalFiles) f.rel: f};

    Future<Uint8List?> loadMedia(String rel) async {
      // R2 taze kaynak, bundle fallback.
      final m = byRel[rel];
      if (m != null) {
        final bytes = await svc.fetchCatalogBytes(m.r2Key);
        if (bytes != null) return bytes;
      }
      if (base.isNotEmpty) {
        final bundled = await _loadAssetBytes('$base/$rel');
        if (bundled != null) return bundled;
      }
      // Barındırmadığımız dosya (PDF): bundle'da yoksa yayıncıdan indir.
      final ext = externalByRel[rel];
      if (ext != null && ext.url.isNotEmpty) {
        return svc.fetchExternal(Uri.parse(ext.url));
      }
      return null;
    }

    try {
      await _installWorld(
        dir: dir,
        manifest: manifest.cast<String, dynamic>(),
        worldBlueprint:
            (envelope['world_blueprint'] as Map?)?.cast<String, dynamic>(),
        characterBlueprint:
            (envelope['character_blueprint'] as Map?)?.cast<String, dynamic>(),
        loadMedia: loadMedia,
        report: report,
        installedFrom: 'official',
        catalogVersion: entry.version,
        asCopy: true,
      );
    } catch (e, st) {
      report.failures.add('${entry.slug}: $e\n$st');
    }
    return report;
  }

  /// Dünya zarfı: R2 `r2_path` (gzip JSON) → bundle'daki üç dosya.
  Future<Map<String, dynamic>?> _fetchEnvelope(
    CatalogEntry entry,
    FirstPartyCatalogService svc,
    String base,
  ) async {
    if (entry.r2Path.isNotEmpty) {
      final gz = await svc.fetchCatalogBytes(entry.r2Path);
      if (gz != null) {
        try {
          return jsonDecode(utf8.decode(gzip.decode(gz)))
              as Map<String, dynamic>;
        } catch (_) {
          // bozuk obje → bundle'a düş
        }
      }
    }
    if (base.isEmpty) return null;
    final manifest = await _tryLoadJson('$base/manifest.json');
    if (manifest == null) return null;
    final world = await _tryLoadJson('$base/world-blueprint.json');
    final character = await _tryLoadJson('$base/blueprint.json');
    if (world == null && character == null) return null;
    return <String, dynamic>{
      'manifest': manifest,
      if (world != null) 'world_blueprint': world,
      if (character != null) 'character_blueprint': character,
    };
  }

  /// `metadata.installed_from == 'assets'` damgalı her dünyayı kaldırır.
  Future<int> uninstallAll() async {
    final names = await _repo.getAvailable();
    var n = 0;
    for (final name in names) {
      try {
        final data = await _repo.load(name);
        final meta = data['metadata'];
        // Katalogdan kurulan dünya da bu toggle'la kalkabilmeli — aynı içerik,
        // sadece farklı kaynak.
        final from = meta is Map ? meta['installed_from'] : null;
        if (from != 'assets' && from != 'official') continue;
        // `_purgeWorld` world_characters'a dokunmuyor (karakterler normalde
        // dünyayı sağ kurtarır). Buradakiler kurulum artığı — dünya gidince
        // ölü bir world id'ye bakan karakter kalmasın.
        final worldId = data['world_id'];
        if (worldId is String) {
          for (final c in await _chars.loadAll()) {
            if (c.worldId == worldId) await _chars.dropLocal(c.id);
          }
        }
        await _repo.delete(name);
        n++;
      } catch (_) {
        // best-effort
      }
    }
    return n;
  }

  // ── Tek dünya kurulumu ───────────────────────────────────────────────

  Future<void> _installWorld({
    required String dir,
    required Map<String, dynamic> manifest,
    required Map<String, dynamic>? worldBlueprint,
    required Map<String, dynamic>? characterBlueprint,
    required WorldFileLoader loadMedia,
    required InstallReport report,
    required String installedFrom,
    String? catalogVersion,
    bool asCopy = false,
  }) async {
    var worldName = manifest['title'] as String;
    // Katalogdan elle indirme her seferinde yeni bir dünya açsın; silinip
    // tekrar indirilen ya da ikinci kez indirilen dünya üstüne yazmasın.
    if (asCopy) {
      worldName =
          uniqueCopyName(worldName, (await _repo.getAvailable()).toSet());
    }

    if (worldBlueprint == null && characterBlueprint == null) {
      report.failures.add('$dir: no blueprint files');
      return;
    }

    // Medyayı önce diske çıkar — converter mutlak yolları yazabilsin.
    final mediaRoot = await _extractMedia(dir, manifest, report,
        worldName: worldName, loadMedia: loadMedia);

    final converter = WorldBlueprintConverter(
      packageName: manifest['slug'] as String? ?? dir,
      sourceTitle: '$worldName, ${manifest['system']}',
      tier0Slugs: blueprintTier0Slugs(),
      contentSlugs: blueprintContentSlugs(),
      knownNames: builtinContentNames(),
      fieldKeys: blueprintFieldKeys(),
      relationTargets: blueprintRelationTargets(),
      mediaResolver: (rel) {
        final f = _mediaTarget(mediaRoot, worldName, rel);
        return f.existsSync() ? f.path : null;
      },
    );

    final pinRefs = worldBlueprint?['pinned'];
    final pins = <String>[
      if (pinRefs is List)
        for (final r in pinRefs)
          if (r is String && r.contains('/'))
            converter.entityId(
                r.substring(0, r.indexOf('/')), r.substring(r.indexOf('/') + 1)),
    ];

    final result = converter.convert(
      worldBlueprint: worldBlueprint,
      characterBlueprint: characterBlueprint,
    );
    report.issues.addAll(result.issues.map((i) => '$worldName · $i'));

    // Built-in D&D 5e şeması — SRD paketi bu world'de varsayılan olsun.
    final build = generateBuiltinDnd5eV2Schema();
    final schemaHash = computeWorldSchemaContentHash(build.schema);

    final worldData = <String, dynamic>{
      'entities': Map<String, dynamic>.from(result.entities),
      'template_id': build.schema.schemaId,
      'template_hash': schemaHash,
      'template_original_hash': builtinDnd5eV2OriginalHash,
      'world_schema': build.schema.toJson(),
      'metadata': {
        'title': manifest['title'],
        'publisher': manifest['publisher'],
        'license': manifest['license'],
        'attribution': manifest['attribution'],
        'game_system': manifest['system'],
        'source': manifest['title'],
        'pack_version': manifest['version'],
        'installed_from': installedFrom,
        if (catalogVersion != null) 'catalog_version': catalogVersion,
        if (manifest['description'] != null)
          'description': manifest['description'],
        if (_coverPath(mediaRoot, manifest) != null)
          'cover_image_path': _coverPath(mediaRoot, manifest),
      },
      // Blueprint'in `pinned` listesi (`kategori/isim`) → entity id'leri.
      // Non-typed top-level key olduğu için `world_settings.settings_json`
      // blob'una düşüyor; sidebar oradan okuyor (kPinnedEntitiesKey).
      if (pins.isNotEmpty) kPinnedEntitiesKey: pins,
    };

    // Var olan dünyanın kullanıcı tarafından eklenmiş satırlarını koru —
    // `_saveToDb` entities için full-replace uyguluyor.
    final existing = await _repo.getAvailable();
    String? worldId;
    if (existing.contains(worldName)) {
      try {
        final prev = await _repo.load(worldName);
        worldId = prev['world_id'] as String?;
        final prevEntities = prev['entities'];
        if (prevEntities is Map) {
          worldData['entities'] = <String, dynamic>{
            for (final e in prevEntities.cast<String, dynamic>().entries)
              // Eski kurulumun PC entity'leri: artık karakter olarak
              // yazılıyorlar, entity kopyası hiçbir ekranda görünmeyen ölü
              // satır. Yeniden kurulum bunu temizlesin.
              if ((e.value is! Map) ||
                  (e.value as Map)['type'] != 'player-character')
                e.key: e.value,
            ...result.entities,
          };
        }
      } catch (_) {
        // yüklenemiyorsa üstüne yaz
      }
    }

    await _repo.save(worldName, worldData);
    // `save` yeni dünya açarken ürettiği id'yi map'e geri yazıyor; var olan
    // dünyada yazmıyor, o yüzden yukarıdaki `load`'dan alındı.
    worldId ??= worldData['world_id'] as String?;
    await _installCharacters(worldId, result.characters, build, report,
        worldName: worldName, freshIds: asCopy);
    report.installed.add(worldName);
  }

  // ── Oyuncu karakterleri ──────────────────────────────────────────────

  /// Blueprint'in PC'lerini dünyanın Characters sekmesine, **ownersız**
  /// yazar. Id'ler blueprint'ten deterministik (uuidv5) geliyor; zaten var
  /// olan satıra dokunulmaz, yoksa ikinci kurulum DM'in level-up'ını siler.
  Future<void> _installCharacters(
    String? worldId,
    List<Map<String, dynamic>> characters,
    BuiltinDnd5eV2Build build,
    InstallReport report, {
    required String worldName,
    bool freshIds = false,
  }) async {
    if (characters.isEmpty) return;
    if (worldId == null) {
      report.issues.add('$worldName · characters: world id unresolved — '
          '${characters.length} character(s) not installed');
      return;
    }
    // Blueprint PC'leri proficiency tablolarini kisa yazar (yalniz proficient
    // satirlar). Tablonun tamamini burada tamamla: hem sheet tam gorunsun hem
    // de sonraki "skill sec" akislari var olan satiri bulup isaretleyebilsin.
    final profDefaults = <String, Object?>{
      for (final c in build.schema.categories)
        if (kPlayerCategorySlugs.contains(c.slug))
          for (final f in c.fields)
            if (f.fieldType == FieldType.proficiencyTable)
              f.fieldKey: f.defaultValue,
    };

    final now = DateTime.now().toUtc().toIso8601String();
    for (var json in characters) {
      var id = json['id'] as String;
      final fields = json['fields'];
      if (fields is Map && profDefaults.isNotEmpty) {
        json = {
          ...json,
          'fields': <String, dynamic>{
            ...fields.cast<String, dynamic>(),
            for (final e in profDefaults.entries)
              e.key: mergeProficiencyRows(e.value, fields[e.key]),
          },
        };
      }
      try {
        if (await _chars.exists(id)) {
          // Blueprint id'leri deterministik: aynı dünyayı ikinci kez kurmak
          // DM'in level-up'ını ezmesin diye var olan satıra dokunulmuyor.
          // Ama katalogdan indirme yeni bir dünya kopyası açıyor; oradaki
          // karakterler o kopyaya ait yeni id'lerle gitmeli, yoksa kopya
          // karaktersiz kalır.
          if (!freshIds) continue;
          id = const Uuid().v4();
          json = {...json, 'id': id};
        }
        await _chars.save(Character(
          id: id,
          templateId: build.schema.schemaId,
          templateName: build.schema.name,
          entity: Entity.fromJson(json),
          worldId: worldId,
          // Sahipsiz: dünyayı açan DM dağıtana / bir oyuncu claim edene dek
          // "Available to Claim" bölümünde durur. Guest için `null` = "benim"
          // demek olduğundan marker yazılır; yoksa kurulan dünyanın tüm PC'leri
          // hesapsız kullanıcının hub'ına düşerdi (claim edilmeden).
          ownerId: kGuestReleasedOwnerId,
          createdAt: now,
          updatedAt: now,
        ));
      } catch (e) {
        report.issues.add('$worldName · character ${json['name']}: $e');
      }
    }
  }

  // ── Medya çıkarımı ───────────────────────────────────────────────────

  /// Manifest'in `files` bloğundaki her dosyayı asset bundle'dan
  /// `AppPaths.worldsDir/_bundled/<dir>/` altına yazar ve o kökü döner.
  /// Zaten yazılmış dosyalar atlanır (idempotent, ikinci kurulum ucuz).
  Future<String> _extractMedia(
    String dir,
    Map<String, dynamic> manifest,
    InstallReport report, {
    required String worldName,
    required WorldFileLoader loadMedia,
  }) async {
    final root = p.join(AppPaths.worldsDir, '_bundled', dir);
    final files = _mediaPaths(manifest['files']);
    if (files.isEmpty) return root;

    for (final rel in files) {
      final target = _mediaTarget(root, worldName, rel);
      if (await target.exists()) continue;
      try {
        final bytes = await loadMedia(rel);
        if (bytes == null) {
          report.issues.add('$dir · media: unavailable $rel');
          continue;
        }
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes);
      } catch (e) {
        report.issues.add('$dir · media: cannot extract $rel ($e)');
      }
    }
    return root;
  }

  /// Paketlenmiş bir medya yolunun diskteki karşılığı. PDF'ler `_bundled/`
  /// altına değil dünyanın PDF kütüphanesine (`{world}/pdfs/`) düşer — PDF
  /// sekmesi listeyi o klasörden okuyor (bkz. `PdfLibraryService`).
  static File _mediaTarget(String root, String worldName, String rel) =>
      p.extension(rel).toLowerCase() == '.pdf'
          ? File(p.join(
              PdfLibraryService.libraryDir(worldName), p.posix.basename(rel)))
          : File(p.join(root, p.joinAll(p.posix.split(rel))));

  /// Manifest'in `files.cover_image` yolunu diske çıkarılmış mutlak yola
  /// çevirir — dünya kartının banner'ı bunu okuyor.
  static String? _coverPath(String mediaRoot, Map<String, dynamic> manifest) {
    final files = manifest['files'];
    final rel = files is Map ? files['cover_image'] : null;
    if (rel is! String || rel.isEmpty) return null;
    final f = File(p.join(mediaRoot, p.joinAll(p.posix.split(rel))));
    return f.existsSync() ? f.path : null;
  }

  /// Manifest `files` bloğundan her string yaprağı toplar (`pdf`,
  /// `cover_image`, `media.maps[]`, `media.tokens[]`, …).
  ///
  /// `pdf_url` hariç: o bir yayıncı indirme linki, dosya yolu değil — medya
  /// yolu sanılırsa her kurulumda "dosya bulunamadı" issue'su üretir.
  static List<String> _mediaPaths(Object? node) {
    final out = <String>[];
    void walk(Object? n, String? key) {
      if (key == 'pdf_url') return;
      if (n is String) {
        if (n.isNotEmpty && !out.contains(n)) out.add(n);
      } else if (n is List) {
        for (final e in n) {
          walk(e, key);
        }
      } else if (n is Map) {
        n.forEach((k, v) => walk(v, k.toString()));
      }
    }

    walk(node, null);
    return out;
  }

  // ── Asset yükleme ────────────────────────────────────────────────────

  /// Asset bundle'dan JSON oku (debug'da dosya sisteminden de dener).
  Future<Map<String, dynamic>?> _tryLoadJson(String asset) async {
    final raw = await _tryLoad(asset);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  }

  /// Asset bundle'dan ham bayt; yoksa null.
  Future<Uint8List?> _loadAssetBytes(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      return data.buffer
          .asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      if (kDebugMode && !kIsWeb) {
        try {
          final f = File(asset);
          if (await f.exists()) return await f.readAsBytes();
        } catch (_) {
          // fall through
        }
      }
      return null;
    }
  }

  Future<String?> _tryLoad(String asset) async {
    try {
      return await rootBundle.loadString(asset);
    } catch (_) {
      if (kDebugMode && !kIsWeb) {
        try {
          final f = File(asset);
          if (await f.exists()) return await f.readAsString();
        } catch (_) {
          // fall through
        }
      }
      return null;
    }
  }
}

/// [BundledWorldsInstaller.installAll] sonucu. `issues` boş değilse dünya
/// kurulmuştur ama içeriğin bir kısmı eksiktir — UI bunu göstermelidir.
class InstallReport {
  final List<String> installed = [];
  final List<String> issues = [];
  final List<String> failures = [];

  int get count => installed.length;
  bool get isClean => issues.isEmpty && failures.isEmpty;

  @override
  String toString() {
    final parts = <String>['${installed.length} world(s) installed'];
    if (issues.isNotEmpty) parts.add('${issues.length} content issue(s)');
    if (failures.isNotEmpty) parts.add('${failures.length} failure(s)');
    return parts.join(', ');
  }
}
