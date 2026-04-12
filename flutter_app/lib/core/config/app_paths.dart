import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Python config.py'daki resolve_data_root() karşılığı.
///
/// Per-user isolation: `setUser(userId)` çağrıldığında tüm path'ler
/// `{dataRoot}/users/{userId}/` altına taşınır. Offline modda (userId null)
/// mevcut global path'ler kullanılır.
class AppPaths {
  static late String dataRoot;
  static late String worldsDir;
  static late String packagesDir;
  static late String cacheDir;
  static late String trashDir;
  static late String soundpadRoot;

  /// Aktif kullanıcı ID'si. null = offline / guest mode.
  static String? currentUserId;

  static Future<void> initialize() async {
    dataRoot = await _resolveDataRoot();
    _setPathsForUser(null);

    soundpadRoot = await _resolveSoundpadRoot();

    await Directory(worldsDir).create(recursive: true);
    await Directory(packagesDir).create(recursive: true);
    await Directory(cacheDir).create(recursive: true);
    await Directory(trashDir).create(recursive: true);
    await Directory(soundpadRoot).create(recursive: true);

    // 30 günden eski trash öğelerini temizle
    await _cleanupTrash();
  }

  /// Kullanıcı değiştiğinde path'leri güncelle.
  /// [userId] null ise global (offline) path'lere döner.
  static Future<void> setUser(String? userId) async {
    currentUserId = userId;
    _setPathsForUser(userId);

    await Directory(worldsDir).create(recursive: true);
    await Directory(packagesDir).create(recursive: true);
    await Directory(cacheDir).create(recursive: true);
    await Directory(trashDir).create(recursive: true);

    await _cleanupTrash();
  }

  static void _setPathsForUser(String? userId) {
    final base = userId != null ? p.join(dataRoot, 'users', userId) : dataRoot;
    worldsDir = p.join(base, 'worlds');
    packagesDir = p.join(base, 'packages');
    cacheDir = p.join(base, 'cache');
    trashDir = p.join(base, '.trash');
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

  /// Python config.py'daki SOUNDPAD_ROOT karşılığı.
  /// SOUNDPAD_ROOT = os.path.join(ASSETS_DIR, "soundpad")
  static Future<String> _resolveSoundpadRoot() async {
    // 1) Env override
    final override = Platform.environment['SOUNDPAD_ROOT']?.trim();
    if (override != null && override.isNotEmpty && await Directory(override).exists()) {
      return override;
    }

    // 2) cwd tabanlı arama (flutter run cwd = flutter_app/, ../assets/soundpad/)
    final cwd = Directory.current.path;
    for (final candidate in [
      p.join(cwd, 'assets', 'soundpad'),
      p.join(cwd, '..', 'assets', 'soundpad'),
      p.join(cwd, '..', '..', 'assets', 'soundpad'),
    ]) {
      final normalized = p.normalize(candidate);
      if (await Directory(normalized).exists()) return normalized;
    }

    // 3) Exe tabanlı arama (portable / release build)
    final exeDir = p.dirname(Platform.resolvedExecutable);
    for (var i = 0; i <= 6; i++) {
      final ups = List.filled(i, '..').join('/');
      final candidate = p.normalize(p.join(exeDir, ups, 'assets', 'soundpad'));
      if (await Directory(candidate).exists()) return candidate;
    }

    // 4) Fallback: dataRoot altında
    return p.join(dataRoot, 'soundpad');
  }

  /// 30 günden eski trash öğelerini sil.
  static Future<void> _cleanupTrash() async {
    final dir = Directory(trashDir);
    if (!await dir.exists()) return;
    final now = DateTime.now();
    await for (final entry in dir.list()) {
      try {
        final stat = await entry.stat();
        if (now.difference(stat.modified).inDays >= 30) {
          await entry.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Relatif yolu kampanya bazlı absolute yola çevir.
  static String resolve(String relativePath, String campaignPath) {
    if (p.isAbsolute(relativePath)) return relativePath;
    return p.normalize(p.join(campaignPath, relativePath.replaceAll('\\', '/')));
  }
}
