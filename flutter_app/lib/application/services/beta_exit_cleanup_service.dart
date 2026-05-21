import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

/// Beta'dan çıkan kullanıcının tüm Storage object'lerini siler.
///
/// `leave_beta()` RPC'si DB satırlarını (worlds, marketplace_listings,
/// free_media_assets, community_assets, …) temizler ama Supabase RLS plpgsql
/// içinden `storage.objects` DELETE'ine izin vermez — binary object'ler bu
/// servis tarafından client'tan silinir.
///
/// Best-effort: her bucket kendi `try` bloğunda izole; hata fırlatmaz,
/// `leaveBeta()` akışını bloklamaz.
class BetaExitCleanupService {
  BetaExitCleanupService(this._client);

  final SupabaseClient _client;

  /// Beta içeriği barındıran tüm bucket'larda kullanıcının object'lerini siler.
  Future<void> wipeUserStorage(String userId) async {
    await _wipeFlat('campaign-backups', userId); // {uid}/{type}s/*.json.gz
    await _wipeFlat('free-media', userId); //       {uid}/{sha}.{ext}
    await _wipeRecursive('shared-payloads', userId); // {uid}/{itemType}/*.gz
  }

  /// Tek seviyeli bucket — `{uid}/` altındaki dosyaları doğrudan siler.
  Future<void> _wipeFlat(String bucket, String userId) async {
    try {
      final storage = _client.storage.from(bucket);
      final objs = await storage.list(path: userId);
      final paths = <String>[
        for (final o in objs)
          if (o.id != null) '$userId/${o.name}', // klasör değil, dosya
      ];
      if (paths.isNotEmpty) await storage.remove(paths);
    } catch (e) {
      debugPrint('beta exit cleanup: $bucket wipe warning: $e');
    }
  }

  /// İki seviyeli bucket — `{uid}/{altKlasör}/dosya`. Önce `{uid}` altındaki
  /// alt klasörleri listeler, her birinin içindeki dosyaları toplar, tek
  /// `remove()` çağrısında siler.
  Future<void> _wipeRecursive(String bucket, String userId) async {
    try {
      final storage = _client.storage.from(bucket);
      final top = await storage.list(path: userId);
      final paths = <String>[];
      for (final entry in top) {
        if (entry.id != null) {
          // {uid} kökünde duran dosya (beklenmez ama yine de sil).
          paths.add('$userId/${entry.name}');
          continue;
        }
        // Alt klasör → içindeki dosyaları listele.
        final sub = '$userId/${entry.name}';
        final inner = await storage.list(path: sub);
        for (final f in inner) {
          if (f.id != null) paths.add('$sub/${f.name}');
        }
      }
      if (paths.isNotEmpty) await storage.remove(paths);
    } catch (e) {
      debugPrint('beta exit cleanup: $bucket wipe warning: $e');
    }
  }
}

/// Supabase konfigüre değilse null döner — çağıranlar no-op yapar.
final betaExitCleanupServiceProvider =
    Provider<BetaExitCleanupService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return BetaExitCleanupService(Supabase.instance.client);
});
