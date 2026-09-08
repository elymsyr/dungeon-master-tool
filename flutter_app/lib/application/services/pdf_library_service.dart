import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../data/services/asset_importer.dart';

/// World'ün PDF kütüphanesi: `{worldsDir}/{worldName}/pdfs/` klasörü.
///
/// **Tamamen yerel** (Phase D — sayılan katman kaldırıldı). Liste kaynağı
/// klasörün kendisi; buluta yükleme, manifest ve oyuncu indirmesi yok. PDF'ler
/// cihazdan cihaza LAN sync ile taşınır — veri kökü altında oldukları için
/// `LanSyncSession._mediaFor` onları zaten kapsıyor.
class PdfLibraryService {
  const PdfLibraryService();

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

  /// Kütüphaneden siler.
  Future<void> remove(String worldName, String fileName) async {
    final file = File(p.join(libraryDir(worldName), fileName));
    if (await file.exists()) await file.delete();
  }
}

final pdfLibraryServiceProvider =
    Provider<PdfLibraryService>((ref) => const PdfLibraryService());
