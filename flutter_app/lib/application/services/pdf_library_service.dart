import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'dart:convert';

import '../../core/config/app_paths.dart';
import '../../data/database/database_provider.dart';
import '../../data/network/network_providers.dart';
import '../../data/services/asset_importer.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';
import '../providers/campaign_provider.dart';

/// World'ün PDF kütüphanesi: `{worldsDir}/{worldName}/pdfs/` klasörü + online
/// dünyalar için `world_settings.settings_json['pdf_library']` manifest'i.
///
/// Liste kaynağı **klasörün kendisi**; manifest yalnızca paylaşım içindir —
/// oyuncu, local karşılığı olmayan girdileri talep üzerine indirir. Ayrı bir
/// Drift tablosu yok: `saveSettingsPatch` zaten DM-gate + outbox + CDC
/// taşıyor (bkz. `campaign_provider.dart` `saveSettingsPatch`).
class PdfLibraryService {
  PdfLibraryService(this._ref);

  final Ref _ref;

  /// `settings_json` içindeki manifest anahtarı. `world_mirror_applier` bu
  /// anahtarı fetch-queue'dan hariç tutar — PDF'ler eager indirilmez.
  static const String manifestKey = 'pdf_library';

  static String libraryDir(String worldName) =>
      p.join(AppPaths.worldsDir, worldName, AssetImporter.pdfSubDir);

  /// Klasördeki PDF'ler, en son değiştirilen başta.
  static Future<List<File>> localFiles(String worldName) async {
    final dir = Directory(libraryDir(worldName));
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entry in dir.list()) {
      if (entry is File && p.extension(entry.path).toLowerCase() == '.pdf') {
        files.add(entry);
      }
    }
    final stats = <String, DateTime>{
      for (final f in files) f.path: (await f.stat()).modified,
    };
    files.sort((a, b) => stats[b.path]!.compareTo(stats[a.path]!));
    return files;
  }

  /// Bir PDF'i kütüphaneye kopyalar (idempotent) ve kopyanın yolunu döndürür.
  Future<String?> import(String worldName, String sourcePath) =>
      AssetImporter.importOne(
        p.join(AppPaths.worldsDir, worldName),
        AssetImporter.pdfSubDir,
        sourcePath,
      );

  /// Aktif dünyanın manifest'i. Paylaşılmamışsa boş liste.
  List<PdfLibraryEntry> manifest() =>
      _parseManifest(_ref.read(activeCampaignProvider.notifier).data);

  /// Herhangi bir dünyanın manifest'i — hub'dan publish akışı için (dünya
  /// açık değil, notifier'ın `_data`'sı başka dünyaya ait olabilir).
  Future<List<PdfLibraryEntry>> manifestOf(String worldId) async {
    final row = await _ref.read(appDatabaseProvider).worldSettingsDao.get(worldId);
    if (row == null || row.settingsJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(row.settingsJson);
      return decoded is Map
          ? _parseManifest(decoded.cast<String, dynamic>())
          : const [];
    } catch (_) {
      return const [];
    }
  }

  static List<PdfLibraryEntry> _parseManifest(Map<String, dynamic>? data) {
    final raw = data?[manifestKey];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => PdfLibraryEntry.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Tek bir PDF'i R2'ye yükler ve manifest'e ekler. Dünya online değilse ya
  /// da upload başarısızsa `null` döner — kütüphane local olarak çalışmaya
  /// devam eder.
  Future<PdfLibraryEntry?> share(
    File pdf, {
    required String worldName,
    required String worldId,
  }) async {
    final svc = _ref.read(assetServiceProvider);
    if (svc == null) return null;
    final uri = await svc.uploadAsset(
      pdf,
      campaignId: worldId,
      kind: MediaKind.worldPdf,
    );
    final entry = PdfLibraryEntry(
      name: p.basename(pdf.path),
      sizeBytes: await pdf.length(),
      uri: uri.toString(),
    );
    await _writeManifest(
      worldName,
      worldId,
      [...await manifestOf(worldId).then((m) => m.where((e) => e.name != entry.name)), entry],
    );
    return entry;
  }

  /// Kütüphanedeki her PDF'i yükler. Tek dosya hatası akışı kesmez; başarısız
  /// olanlar döndürülür (çağıran isterse kullanıcıya gösterir).
  Future<List<PdfShareFailure>> shareAll({
    required String worldName,
    required String worldId,
  }) async {
    final svc = _ref.read(assetServiceProvider);
    if (svc == null) return const [];
    final failures = <PdfShareFailure>[];
    final entries = <PdfLibraryEntry>[];
    for (final file in await localFiles(worldName)) {
      try {
        final uri = await svc.uploadAsset(
          file,
          campaignId: worldId,
          kind: MediaKind.worldPdf,
        );
        entries.add(PdfLibraryEntry(
          name: p.basename(file.path),
          sizeBytes: await file.length(),
          uri: uri.toString(),
        ));
      } catch (e) {
        failures.add(PdfShareFailure(p.basename(file.path), '$e'));
      }
    }
    if (entries.isNotEmpty) {
      // Yüklenemeyenlerin eski manifest girdileri korunur.
      final names = entries.map((e) => e.name).toSet();
      final previous = await manifestOf(worldId);
      await _writeManifest(worldName, worldId, [
        ...previous.where((e) => !names.contains(e.name)),
        ...entries,
      ]);
    }
    return failures;
  }

  /// Paylaşılan bir PDF'i kütüphane klasörüne indirir ve local yolunu döndürür.
  Future<String> download(PdfLibraryEntry entry, String worldName) async {
    final svc = _ref.read(assetServiceProvider);
    if (svc == null) {
      throw StateError('offline');
    }
    final key = AssetRef(entry.uri).r2Key;
    if (key == null) throw StateError('bad_ref');
    // Cache-first + SHA doğrulamalı; ContentStore'da varsa sıfır transfer.
    final cached = await svc.downloadAsset(key);
    final dir = Directory(libraryDir(worldName));
    if (!await dir.exists()) await dir.create(recursive: true);
    final target = p.join(dir.path, entry.name);
    await cached.copy(target);
    return target;
  }

  /// Kütüphaneden siler: local dosya + (DM ise) manifest girdisi.
  ///
  /// R2 nesnesi bilerek silinmez — manifest'ten düşen `dmt-asset://` ref'i
  /// `ReferenceIndexer` `asset_refs`'ten çıkarır, orphan'ı `EvictionSweeper`
  /// toplar.
  Future<void> remove(String worldName, String fileName) async {
    final file = File(p.join(libraryDir(worldName), fileName));
    if (await file.exists()) await file.delete();
    final worldId =
        _ref.read(activeCampaignProvider.notifier).data?['world_id'] as String?;
    if (worldId == null) return;
    // Drift'ten oku — `_data` aynası patch'lerle güncellenmiyor, stale liste
    // silinen dosyayı "paylaşılmış, henüz inmemiş" satır olarak geri getirirdi.
    final current = await manifestOf(worldId);
    final rest = current.where((e) => e.name != fileName).toList();
    if (rest.length == current.length) return;
    await _writeManifest(worldName, worldId, rest);
  }

  /// Manifest'i `world_settings.settings_json`'a yazar.
  ///
  /// Dünya açıksa `saveSettingsPatch` kullanılır — in-memory `_data`'yı da
  /// tazeler, DM gate'i uygular ve outbox'a koyar. Hub'dan publish edilen
  /// (açık olmayan) bir dünyada o yol yanlış dünyaya yazardı; orada repo'ya
  /// doğrudan yazıp merge sonrası tam blob'u outbox'a koyuyoruz — cloud satırı
  /// full overwrite olduğu için yalnızca patch'i göndermek diğer ayarları
  /// silerdi.
  Future<void> _writeManifest(
    String worldName,
    String worldId,
    List<PdfLibraryEntry> entries,
  ) async {
    final json = entries.map((e) => e.toJson()).toList();
    final patch = {manifestKey: json};
    if (_ref.read(activeCampaignProvider) == worldName) {
      await _ref.read(activeCampaignProvider.notifier).saveSettingsPatch(patch);
      // `saveSettingsPatch` Drift + cloud'a yazar ama in-memory `_data`'ya
      // dokunmaz (doc: "Caller keeps the in-memory mirror in sync") — diğer
      // çağıranların kendi notifier state'i var, bizim tek aynamız bu.
      // Güncellemezsek [manifest] stale kalır ve silinen PDF listeye
      // "paylaşılmış" satır olarak geri döner.
      _ref.read(activeCampaignProvider.notifier).data?[manifestKey] = json;
      return;
    }
    await _ref.read(campaignRepositoryProvider).saveSettingsPatch(worldName, patch);
  }
}

/// Manifest satırı — `world_settings.settings_json['pdf_library'][i]`.
class PdfLibraryEntry {
  const PdfLibraryEntry({
    required this.name,
    required this.sizeBytes,
    required this.uri,
  });

  final String name;
  final int sizeBytes;

  /// `dmt-asset://{uploader}/{worldId}/{sha}.pdf`
  final String uri;

  factory PdfLibraryEntry.fromJson(Map<String, dynamic> json) =>
      PdfLibraryEntry(
        name: json['name'] as String? ?? '',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        uri: json['uri'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'size_bytes': sizeBytes,
        'uri': uri,
      };
}

class PdfShareFailure {
  const PdfShareFailure(this.name, this.error);
  final String name;
  final String error;
}

final pdfLibraryServiceProvider =
    Provider<PdfLibraryService>((ref) => PdfLibraryService(ref));
