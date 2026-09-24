import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/services/asset_importer.dart';
import 'local_media_localizer.dart';

/// World'ün PDF kütüphanesi: `{worldsDir}/{worldId}/pdfs/` klasörü (id ile).
///
/// **Tamamen yerel** (Phase D — sayılan katman kaldırıldı). Liste kaynağı
/// klasörün kendisi; buluta yükleme, manifest ve oyuncu indirmesi yok. PDF'ler
/// `.dmtz` ile taşınır — veri kökü altında oldukları için
/// `ContentCodec._mediaFor` onları zaten kapsıyor.
class PdfLibraryService {
  const PdfLibraryService();

  static String libraryDir(String worldId) =>
      p.join(LocalMediaLocalizer.worldDir(worldId), AssetImporter.pdfSubDir);

  /// Klasördeki PDF'ler, en son değiştirilen başta.
  static Future<List<File>> localFiles(String worldId) async {
    final dir = Directory(libraryDir(worldId));
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
  Future<String?> import(String worldId, String sourcePath) =>
      AssetImporter.importOne(
        LocalMediaLocalizer.worldDir(worldId),
        AssetImporter.pdfSubDir,
        sourcePath,
      );

  /// Kütüphaneden siler.
  Future<void> remove(String worldId, String fileName) async {
    final file = File(p.join(libraryDir(worldId), fileName));
    if (await file.exists()) await file.delete();
  }
}

final pdfLibraryServiceProvider =
    Provider<PdfLibraryService>((ref) => const PdfLibraryService());
