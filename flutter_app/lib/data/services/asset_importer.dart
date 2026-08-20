import 'dart:io';
import 'package:path/path.dart' as p;

/// Campaign asset import utility.
/// Copies files into the campaign's asset subtree, preserving the original
/// filename so tab titles / library rows stay readable.
class AssetImporter {
  /// Kütüphane klasörü — PDF paneli aynı dizini listeler.
  static const String pdfSubDir = 'pdfs';

  /// Import image files into `{campaignPath}/media/`.
  static Future<List<String>> importImages(
    String campaignPath,
    List<String> sourcePaths,
  ) =>
      importAll(campaignPath, 'media', sourcePaths);

  /// Import PDF files into `{campaignPath}/pdfs/`.
  static Future<List<String>> importFiles(
    String campaignPath,
    List<String> sourcePaths,
  ) =>
      importAll(campaignPath, pdfSubDir, sourcePaths);

  /// Tek dosya hâli — kopyanın (veya yeniden kullanılan mevcut kopyanın)
  /// mutlak yolunu döndürür; kaynak okunamıyorsa `null`.
  static Future<String?> importOne(
    String campaignPath,
    String subDir,
    String sourcePath,
  ) async {
    final result = await importAll(campaignPath, subDir, [sourcePath]);
    return result.isEmpty ? null : result.first;
  }

  /// Her kaynağı `{campaignPath}/{subDir}/` altına kopyalar ve kopyaların
  /// mutlak yollarını döndürür. Okunamayan kaynaklar atlanır.
  ///
  /// Idempotent: kaynak zaten hedef klasördeyse ya da hedefte aynı ad **ve**
  /// aynı boyutta bir dosya varsa yeni kopya üretmez, mevcut yolu döndürür.
  static Future<List<String>> importAll(
    String campaignPath,
    String subDir,
    List<String> sourcePaths,
  ) async {
    final targetDir = Directory(p.join(campaignPath, subDir));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final imported = <String>[];
    for (final src in sourcePaths) {
      final sourceFile = File(src);
      if (!await sourceFile.exists()) continue;
      if (p.equals(p.dirname(src), targetDir.path)) {
        imported.add(src);
        continue;
      }
      final target = await _resolveTarget(
        targetDir.path,
        p.basename(src),
        await sourceFile.length(),
      );
      if (target.alreadyThere) {
        imported.add(target.path);
        continue;
      }
      await sourceFile.copy(target.path);
      imported.add(target.path);
    }
    return imported;
  }

  /// Hedef klasörde çakışmayan bir yol bulur.
  ///
  /// Aynı ad + aynı boyut = aynı dosya kabul edilir ve yeniden kullanılır.
  /// ponytail: eşitlik testi ad+boyut; sha karşılaştırması 100MB'lık bir PDF'i
  /// baştan sona okumayı gerektirirdi. Aynı ad + aynı boyut + farklı içerik
  /// gerçekten sorun olursa sha256'ya yükselt.
  static Future<_Target> _resolveTarget(
    String dirPath,
    String fileName,
    int sourceLength,
  ) async {
    final base = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    for (var i = 1;; i++) {
      final candidate =
          p.join(dirPath, i == 1 ? fileName : '$base ($i)$ext');
      final existing = File(candidate);
      if (!await existing.exists()) return _Target(candidate, false);
      if (await existing.length() == sourceLength) {
        return _Target(candidate, true);
      }
    }
  }
}

class _Target {
  const _Target(this.path, this.alreadyThere);
  final String path;
  final bool alreadyThere;
}
