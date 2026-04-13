import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../domain/repositories/campaign_repository.dart';

final _log = Logger(printer: SimplePrinter());

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
/// Kopyalama bittikten sonra mevcut `CampaignRepositoryImpl.load()`
/// pipeline'ı (legacy MsgPack → `SchemaMigration.migrate()` → SQLite)
/// kendi başına devralır. Bu yüzden bu servis sadece dosya işlemi yapar,
/// schema çevirisi yapmaz.
class CampaignImportService {
  final CampaignRepository _repo;

  CampaignImportService(this._repo);

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
}
