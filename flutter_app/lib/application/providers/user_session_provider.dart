import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_paths.dart';
import '../../data/database/database_provider.dart';
import '../services/guest_promotion_service.dart';
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
  ///
  /// **O3 — misafir terfisi burada olur.** Sıra kritiktir: veritabanı
  /// *kapalıyken* kopyalanır, kopya bittikten sonra path'ler kullanıcıya
  /// çevrilir, sentinel ise yeni DB açılıp yollar yeniden yazıldıktan sonra
  /// atılır. Landing bu Future'ı `/hub`'a gitmeden önce await ettiği için,
  /// `startup_sync_gate`'in çalıştırdığı ilk-giriş merge'i satırları yerinde
  /// bulur.
  Future<void> activate(String userId) async {
    final promotion = GuestPromotionService(dataRoot: AppPaths.dataRoot);
    final promoting = !promotion.isPromoted(userId) && promotion.hasGuestData();

    if (promoting) {
      try {
        // WAL modunda açık bir bağlantının kopyası yarım sayfa yakalayabilir.
        // Misafir DB'si burada kapatılır; kaynak dosyaya bir daha yazılmaz.
        await _ref.read(appDatabaseProvider).close();
        final report = await promotion.copyIntoAccount(userId);
        debugPrint('Guest promotion (copy): $report');
      } catch (e, st) {
        // Kopya yarıda kaldı: misafir ağacı olduğu gibi duruyor, sentinel
        // atılmadı, bir sonraki girişte baştan denenir.
        debugPrint('Guest promotion copy failed: $e\n$st');
      }
    }

    await AppPaths.setUser(userId);
    _ref.read(activeUserIdProvider.notifier).state = userId;

    if (promoting) {
      try {
        final rewritten = await promotion.finalizePromotion(
          userId,
          _ref.read(appDatabaseProvider),
        );
        debugPrint('Guest promotion (finalize): $rewritten path(s) rewritten');
      } catch (e, st) {
        debugPrint('Guest promotion finalize failed: $e\n$st');
      }
    }

    // Downstream provider'ları invalidate et.
    _invalidateAll();
    state = true;
  }

  /// Kullanıcı oturumunu sonlandır — global path'lere dön.
  Future<void> deactivate() async {
    await AppPaths.setUser(null);
    _ref.read(activeUserIdProvider.notifier).state = null;
    _invalidateAll();
    state = false;
  }

  void _invalidateAll() {
    _ref.invalidate(campaignListProvider);
    _ref.invalidate(campaignInfoListProvider);
    _ref.invalidate(cloudBackupListProvider);
    _ref.invalidate(allTemplatesProvider);
  }
}

final userSessionProvider =
    StateNotifierProvider<UserSessionNotifier, bool>(
  (ref) => UserSessionNotifier(ref),
);
