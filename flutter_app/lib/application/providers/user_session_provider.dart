import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_paths.dart';
import '../../data/database/database_provider.dart';
import '../services/guest_promotion_service.dart';
import 'campaign_provider.dart';
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
    // **O4** folded the three questions into one: not promoted yet, nobody else
    // has spent the guest tree, and there is something in it.
    final promoting = promotion.canPromote(userId);

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
        final finalized = await promotion.finalizePromotion(
          userId,
          _ref.read(appDatabaseProvider),
        );
        debugPrint('Guest promotion (finalize): $finalized');
      } catch (e, st) {
        debugPrint('Guest promotion finalize failed: $e\n$st');
      }
    }

    // Downstream provider'ları invalidate et.
    _invalidateAll();
    state = true;
  }

  /// Kullanıcı oturumunu sonlandır — global path'lere dön.
  ///
  /// **O4 — çıkış temiz bir misafir alanına iner.** Global kök, terfi edilmiş
  /// misafir ağacının ta kendisi; hiçbir şey yapılmazsa çıkan kullanıcı kendi
  /// hesabının bayat bir kopyasına düşer (ve o cihazı sonra kim açarsa onun
  /// dünyalarını görür). Yollar kullanıcıdan çıkmadan **önce** hak sahibi
  /// işaretlenmiş ağaç arşive taşınır; taşıma idempotent olduğu için yarıda
  /// kalmış bir terfi de burada iyileşir. Sıra kritik: `setUser(null)` +
  /// `activeUserIdProvider = null` misafir DB'sini yeniden açar, dolayısıyla
  /// dosyaların o andan önce yerinden alınmış olması gerekir.
  Future<void> deactivate() async {
    try {
      final promotion = GuestPromotionService(dataRoot: AppPaths.dataRoot);
      final report = await promotion.retireClaimedGuestTree();
      if (report.movedAnything) {
        debugPrint('Guest tree retired: $report');
      }
    } catch (e, st) {
      // Arşivleme başarısızsa oturum yine de kapanır — bir sonraki çıkışta
      // tekrar denenir, veri hâlâ hesabın altında duruyor.
      debugPrint('Guest tree retirement failed: $e\n$st');
    }

    await AppPaths.setUser(null);
    _ref.read(activeUserIdProvider.notifier).state = null;
    _invalidateAll();
    state = false;
  }

  void _invalidateAll() {
    _ref.invalidate(campaignListProvider);
    _ref.invalidate(campaignInfoListProvider);
    _ref.invalidate(allTemplatesProvider);
  }
}

final userSessionProvider =
    StateNotifierProvider<UserSessionNotifier, bool>(
  (ref) => UserSessionNotifier(ref),
);
