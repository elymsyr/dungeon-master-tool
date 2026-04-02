import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Python config.py'daki resolve_data_root() karşılığı.
class AppPaths {
  static late String dataRoot;
  static late String worldsDir;
  static late String cacheDir;

  static Future<void> initialize() async {
    dataRoot = await _resolveDataRoot();
    worldsDir = p.join(dataRoot, 'worlds');
    cacheDir = p.join(dataRoot, 'cache');

    await Directory(worldsDir).create(recursive: true);
    await Directory(cacheDir).create(recursive: true);
  }

  static Future<String> _resolveDataRoot() async {
    // 1) Env override
    final override = Platform.environment['DM_DATA_ROOT']?.trim();
    if (override != null && override.isNotEmpty) {
      final dir = Directory(override);
      if (await _isWritable(dir)) return override;
    }

    // 2) Portable mode: exe yanında worlds/ varsa
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final portableWorlds = Directory(p.join(exeDir, 'worlds'));
    if (await portableWorlds.exists() && await _isWritable(Directory(exeDir))) {
      return exeDir;
    }

    // 3) Platform-specific user data
    final appDocDir = await getApplicationDocumentsDirectory();
    final userDataDir = p.join(appDocDir.path, 'DungeonMasterTool');
    return userDataDir;
  }

  static Future<bool> _isWritable(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File(p.join(dir.path, '.dm_write_probe'));
      await probe.writeAsString('ok');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Relatif yolu kampanya bazlı absolute yola çevir.
  static String resolve(String relativePath, String campaignPath) {
    if (p.isAbsolute(relativePath)) return relativePath;
    return p.normalize(p.join(campaignPath, relativePath.replaceAll('\\', '/')));
  }
}
