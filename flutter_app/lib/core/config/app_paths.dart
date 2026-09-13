import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Python config.py'daki resolve_data_root() karşılığı.
///
/// Per-user isolation: `setUser(userId)` çağrıldığında tüm path'ler
/// `{dataRoot}/users/{userId}/` altına taşınır. Offline modda (userId null)
/// mevcut global path'ler kullanılır.
///
/// **v12 (PR-D8)**: `worldsDir` / `packagesDir` / `charactersDir` artık
/// JSON storage **değil** — sadece media (image/PDF) subtree root'u olarak
/// kalır. Tüm structured data Drift'te. Trash da Drift `trash_items`'da;
/// `trashDir` const + FS purge kaldırıldı.
class AppPaths {
  static late String dataRoot;
  static late String worldsDir;
  static late String packagesDir;
  static late String charactersDir;
  static late String cacheDir;
  static late String soundpadRoot;

  /// Aktif kullanıcı ID'si. null = offline / guest mode.
  static String? currentUserId;

  static const String _appDirName = 'DungeonMasterTool';

  /// Kök taşındığında yeni kökün içine bırakılan işaret dosyası; içeriği eski
  /// köktür. Gövdelerde duran **mutlak** medya yolları taşımadan sonra hâlâ
  /// eski kökü gösterir; `AppDatabase.beforeOpen` bu dosyayı görüp her DB'yi
  /// bir kez süpürüyor. Süreç içi bir bayrak yetmez — taşımadan sonra DB hiç
  /// açılmadan çökersek yollar kalıcı olarak ölü kalırdı.
  static const String rootMovedMarker = '.root_moved_from';

  static Future<void> initialize() async {
    dataRoot = await _resolveDataRoot();
    _setPathsForUser(null);

    soundpadRoot = await _resolveSoundpadRoot();

    await Directory(worldsDir).create(recursive: true);
    await Directory(packagesDir).create(recursive: true);
    await Directory(charactersDir).create(recursive: true);
    await Directory(cacheDir).create(recursive: true);
    await Directory(soundpadRoot).create(recursive: true);
  }

  /// Kullanıcı değiştiğinde path'leri güncelle.
  /// [userId] null ise global (offline) path'lere döner.
  static Future<void> setUser(String? userId) async {
    currentUserId = userId;
    _setPathsForUser(userId);

    await Directory(worldsDir).create(recursive: true);
    await Directory(packagesDir).create(recursive: true);
    await Directory(charactersDir).create(recursive: true);
    await Directory(cacheDir).create(recursive: true);
  }

  static void _setPathsForUser(String? userId) {
    final base = userId != null ? p.join(dataRoot, 'users', userId) : dataRoot;
    worldsDir = p.join(base, 'worlds');
    packagesDir = p.join(base, 'packages');
    charactersDir = p.join(base, 'characters');
    cacheDir = p.join(base, 'cache');
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

    // 3) Windows: Documents çoğu makinede OneDrive'a yönlendirilmiş durumda.
    //    SQLite'ın WAL'ı ve medya ağacı orada dururken her yazma senkron
    //    kuyruğuna, her okuma Files-On-Demand hydration'ına takılıyor — 150
    //    dosyalık bir dünya importu makineyi kilitliyordu. LOCALAPPDATA hiç
    //    senkronlanmıyor; veri oraya alınır.
    if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA']?.trim();
      if (local != null && local.isNotEmpty) {
        final target = p.join(local, _appDirName);
        final legacy =
            p.join((await getApplicationDocumentsDirectory()).path, _appDirName);
        if (!await Directory(target).exists() &&
            await Directory(legacy).exists()) {
          try {
            // Aynı volume → rename anlık ve atomik: yarım kopyalanmış ağaç yok.
            await Directory(legacy).rename(target);
            await File(p.join(target, rootMovedMarker)).writeAsString(legacy);
          } catch (e) {
            // OneDrive ya da bir antivirüs dosyayı kilitli tutuyor olabilir.
            // Eski kökte kal — bölünmüş veriden iyidir.
            debugPrint('AppPaths: data root move failed, staying put: $e');
            return legacy;
          }
        }
        if (await _isWritable(Directory(target))) return target;
      }
    }

    // 4) Platform-specific user data
    final appDocDir = await getApplicationDocumentsDirectory();
    final userDataDir = p.join(appDocDir.path, _appDirName);
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
  /// Geçerli kabul edilmek için dizinde `soundpad_library.yaml` olmalı —
  /// `flutter_app/assets/soundpad/` gibi boş kabuk dizinleri atlanır.
  static Future<String> _resolveSoundpadRoot() async {
    // 1) Env override
    final override = Platform.environment['SOUNDPAD_ROOT']?.trim();
    if (override != null && override.isNotEmpty && await Directory(override).exists()) {
      return override;
    }

    Future<bool> hasLibrary(String dir) =>
        File(p.join(dir, 'soundpad_library.yaml')).exists();

    // 2) cwd tabanlı arama (flutter run cwd = flutter_app/, ../assets/soundpad/)
    final cwd = Directory.current.path;
    for (final candidate in [
      p.join(cwd, 'assets', 'soundpad'),
      p.join(cwd, '..', 'assets', 'soundpad'),
      p.join(cwd, '..', '..', 'assets', 'soundpad'),
    ]) {
      final normalized = p.normalize(candidate);
      if (await hasLibrary(normalized)) return normalized;
    }

    // 3) Exe tabanlı arama (portable / release build)
    final exeDir = p.dirname(Platform.resolvedExecutable);
    for (var i = 0; i <= 6; i++) {
      final ups = List.filled(i, '..').join('/');
      final candidate = p.normalize(p.join(exeDir, ups, 'assets', 'soundpad'));
      if (await hasLibrary(candidate)) return candidate;
    }

    // 3b) Dizin var ama library.yaml yoksa yine de döndür (eski davranış)
    for (final candidate in [
      p.join(cwd, 'assets', 'soundpad'),
      p.join(cwd, '..', 'assets', 'soundpad'),
      p.join(cwd, '..', '..', 'assets', 'soundpad'),
    ]) {
      final normalized = p.normalize(candidate);
      if (await Directory(normalized).exists()) return normalized;
    }

    // 4) Fallback: dataRoot altında
    return p.join(dataRoot, 'soundpad');
  }

  /// Relatif yolu kampanya bazlı absolute yola çevir.
  static String resolve(String relativePath, String campaignPath) {
    if (p.isAbsolute(relativePath)) return relativePath;
    return p.normalize(p.join(campaignPath, relativePath.replaceAll('\\', '/')));
  }
}
