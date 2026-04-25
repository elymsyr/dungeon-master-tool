import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_paths.dart';
import '../../core/migrations/builtin_dnd5e_v2_seed.dart';
import '../../data/database/database_provider.dart';
import 'campaign_provider.dart';
import 'cloud_backup_provider.dart';
import 'template_provider.dart';

/// Auth değişikliklerini dinleyerek AppPaths ve DB'yi kullanıcıya göre
/// yeniden yapılandırır. Landing screen'de auth sonrası bu provider
/// tetiklenir, SONRA /hub'a navigate edilir.
class UserSessionNotifier extends StateNotifier<bool> {
  final Ref _ref;

  UserSessionNotifier(this._ref) : super(false);

  /// Kullanıcı oturumunu başlat — path'leri ve DB'yi user-scoped yap.
  Future<void> activate(String userId) async {
    await AppPaths.setUser(userId);
    _ref.read(activeUserIdProvider.notifier).state = userId;

    // İlk giriş migration: global path'te veri varsa user path'e kopyala.
    await _migrateGlobalDataIfNeeded(userId);

    // Built-in template'leri user-scoped cache'e seed et (path az önce switch
    // oldu — global path'teki seed buraya gelmedi).
    await seedBuiltinDnd5eV2TemplateIfNeeded();

    // Downstream provider'ları invalidate et.
    _invalidateAll();
    state = true;
  }

  /// Kullanıcı oturumunu sonlandır — global path'lere dön.
  Future<void> deactivate() async {
    await AppPaths.setUser(null);
    _ref.read(activeUserIdProvider.notifier).state = null;
    // Global path'te de built-in template hazır olsun (offline mode için).
    await seedBuiltinDnd5eV2TemplateIfNeeded();
    _invalidateAll();
    state = false;
  }

  void _invalidateAll() {
    _ref.invalidate(campaignListProvider);
    _ref.invalidate(campaignInfoListProvider);
    _ref.invalidate(cloudBackupListProvider);
    _ref.invalidate(allTemplatesProvider);
  }

  /// Global path'te veri varsa ve user path'te yoksa, kopyala (one-time).
  Future<void> _migrateGlobalDataIfNeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'migrated_$userId';
    if (prefs.getBool(key) == true) return;

    try {
      final globalWorlds = Directory(p.join(AppPaths.dataRoot, 'worlds'));
      final globalPackages = Directory(p.join(AppPaths.dataRoot, 'packages'));

      // Global worlds varsa ve user worlds boşsa kopyala.
      if (await globalWorlds.exists()) {
        final userWorlds = Directory(AppPaths.worldsDir);
        if (!await userWorlds.exists() ||
            await userWorlds.list().isEmpty) {
          await _copyDirectory(globalWorlds, userWorlds);
        }
      }

      // Global packages varsa ve user packages boşsa kopyala.
      if (await globalPackages.exists()) {
        final userPackages = Directory(AppPaths.packagesDir);
        if (!await userPackages.exists() ||
            await userPackages.list().isEmpty) {
          await _copyDirectory(globalPackages, userPackages);
        }
      }

      // Global SQLite varsa ve user SQLite yoksa kopyala.
      // Bu, Drift DB'deki tüm verileri (campaigns, entities, vb.) taşır.
      // Global DB path is {appSupportDir}/DungeonMasterTool/dmt.sqlite
      // User DB path is {appSupportDir}/DungeonMasterTool/users/{userId}/dmt.sqlite
      // We can't easily copy here because the DB is managed by Drift.
      // The filesystem worlds/packages migration above is sufficient —
      // campaigns are auto-migrated from MsgPack files on first load.

      await prefs.setBool(key, true);
    } catch (e, st) {
      debugPrint('Global data migration failed: $e\n$st');
      // Non-critical — user can still use the app without legacy data.
    }
  }

  static Future<void> _copyDirectory(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (final entity in src.list(recursive: false)) {
      final newPath = p.join(dst.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}

final userSessionProvider =
    StateNotifierProvider<UserSessionNotifier, bool>(
  (ref) => UserSessionNotifier(ref),
);
