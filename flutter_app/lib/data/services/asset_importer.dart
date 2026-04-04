import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Campaign asset import utility.
/// Copies files into the campaign's assets directory with UUID-prefixed names.
class AssetImporter {
  /// Import image files into campaign assets.
  /// Returns list of relative paths (relative to [campaignPath]).
  static Future<List<String>> importImages(
    String campaignPath,
    List<String> sourcePaths,
  ) async {
    return _importFiles(campaignPath, 'assets/images', sourcePaths);
  }

  /// Import PDF/document files into campaign assets.
  static Future<List<String>> importFiles(
    String campaignPath,
    List<String> sourcePaths,
  ) async {
    return _importFiles(campaignPath, 'assets/pdfs', sourcePaths);
  }

  static Future<List<String>> _importFiles(
    String campaignPath,
    String subDir,
    List<String> sourcePaths,
  ) async {
    final targetDir = Directory(p.join(campaignPath, subDir));
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    final relativePaths = <String>[];
    for (final src in sourcePaths) {
      final sourceFile = File(src);
      if (!sourceFile.existsSync()) continue;
      final ext = p.extension(src);
      final baseName = p.basenameWithoutExtension(src);
      final uniqueName = '${_uuid.v4().substring(0, 8)}_$baseName$ext';
      final targetPath = p.join(targetDir.path, uniqueName);
      await sourceFile.copy(targetPath);
      relativePaths.add(p.join(subDir, uniqueName));
    }
    return relativePaths;
  }
}
