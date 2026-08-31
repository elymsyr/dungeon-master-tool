import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../../domain/services/builtin_content_names.dart';
import '../../domain/services/world_blueprint_converter.dart';

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
class BundledWorldsInstaller {
  BundledWorldsInstaller(this._repo);
  final CampaignRepository _repo;

  static const _manifestAsset = 'assets/worlds/manifest.json';
  static const _assetDir = 'assets/worlds';

  /// Bu build'de paketlenmiş dünya var mı.
  Future<bool> isAvailable() async => (await _tryLoad(_manifestAsset)) != null;

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
      try {
        await _installWorld(dir, report);
      } catch (e, st) {
        report.failures.add('$dir: $e\n$st');
      }
    }
    return report;
  }

  /// `metadata.installed_from == 'assets'` damgalı her dünyayı kaldırır.
  Future<int> uninstallAll() async {
    final names = await _repo.getAvailable();
    var n = 0;
    for (final name in names) {
      try {
        final data = await _repo.load(name);
        final meta = data['metadata'];
        if (meta is Map && meta['installed_from'] == 'assets') {
          await _repo.delete(name);
          n++;
        }
      } catch (_) {
        // best-effort
      }
    }
    return n;
  }

  // ── Tek dünya kurulumu ───────────────────────────────────────────────

  Future<void> _installWorld(String dir, InstallReport report) async {
    final base = '$_assetDir/$dir';

    final manifestRaw = await _tryLoad('$base/manifest.json');
    if (manifestRaw == null) {
      report.failures.add('$dir: manifest.json not found');
      return;
    }
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final worldName = manifest['title'] as String;

    final worldRaw = await _tryLoad('$base/world-blueprint.json');
    final charRaw = await _tryLoad('$base/blueprint.json');
    if (worldRaw == null && charRaw == null) {
      report.failures.add('$dir: no blueprint files');
      return;
    }

    // Medyayı önce diske çıkar — converter mutlak yolları yazabilsin.
    final mediaRoot = await _extractMedia(dir, base, manifest, report);

    final converter = WorldBlueprintConverter(
      packageName: manifest['slug'] as String? ?? dir,
      sourceTitle: '$worldName, ${manifest['system']}',
      tier0Slugs: blueprintTier0Slugs(),
      contentSlugs: blueprintContentSlugs(),
      knownNames: builtinContentNames(),
      fieldKeys: blueprintFieldKeys(),
      relationTargets: blueprintRelationTargets(),
      mediaResolver: (rel) {
        final f = File(p.join(mediaRoot, p.joinAll(p.posix.split(rel))));
        return f.existsSync() ? f.path : null;
      },
    );

    final result = converter.convert(
      worldBlueprint:
          worldRaw == null ? null : jsonDecode(worldRaw) as Map<String, dynamic>,
      characterBlueprint:
          charRaw == null ? null : jsonDecode(charRaw) as Map<String, dynamic>,
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
        'installed_from': 'assets',
        if (manifest['description'] != null)
          'description': manifest['description'],
      },
    };

    // Var olan dünyanın kullanıcı tarafından eklenmiş satırlarını koru —
    // `_saveToDb` entities için full-replace uyguluyor.
    final existing = await _repo.getAvailable();
    if (existing.contains(worldName)) {
      try {
        final prev = await _repo.load(worldName);
        final prevEntities = prev['entities'];
        if (prevEntities is Map) {
          worldData['entities'] = <String, dynamic>{
            ...prevEntities.cast<String, dynamic>(),
            ...result.entities,
          };
        }
      } catch (_) {
        // yüklenemiyorsa üstüne yaz
      }
    }

    await _repo.save(worldName, worldData);
    report.installed.add(worldName);
  }

  // ── Medya çıkarımı ───────────────────────────────────────────────────

  /// Manifest'in `files` bloğundaki her dosyayı asset bundle'dan
  /// `AppPaths.worldsDir/_bundled/<dir>/` altına yazar ve o kökü döner.
  /// Zaten yazılmış dosyalar atlanır (idempotent, ikinci kurulum ucuz).
  Future<String> _extractMedia(
    String dir,
    String base,
    Map<String, dynamic> manifest,
    InstallReport report,
  ) async {
    final root = p.join(AppPaths.worldsDir, '_bundled', dir);
    final files = _mediaPaths(manifest['files']);
    if (files.isEmpty) return root;

    for (final rel in files) {
      final target = File(p.join(root, p.joinAll(p.posix.split(rel))));
      if (await target.exists()) continue;
      try {
        final bytes = await rootBundle.load('$base/$rel');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes.buffer
            .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      } catch (e) {
        report.issues.add('$dir · media: cannot extract $rel ($e)');
      }
    }
    return root;
  }

  /// Manifest `files` bloğundan her string yaprağı toplar (`pdf`,
  /// `cover_image`, `media.maps[]`, `media.tokens[]`, …).
  static List<String> _mediaPaths(Object? node) {
    final out = <String>[];
    void walk(Object? n) {
      if (n is String) {
        if (n.isNotEmpty) out.add(n);
      } else if (n is List) {
        for (final e in n) {
          walk(e);
        }
      } else if (n is Map) {
        for (final e in n.values) {
          walk(e);
        }
      }
    }

    walk(node);
    return out;
  }

  // ── Asset yükleme ────────────────────────────────────────────────────

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
