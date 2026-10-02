import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/online/world_role.dart';
import 'auth_provider.dart';
import 'builtin_package_provider.dart';
import 'entity_provider.dart';
import 'entity_share_provider.dart';
import 'installed_packages_provider.dart';
import 'role_provider.dart';

/// Aktif worlddeki entity'lerin, current user'a görünür olanlarını döner.
///
/// Kurallar:
///   - DM (veya online olmayan/role=none): tüm entity'ler görünür.
///   - Player:
///       1) Bu world'e kurulu HERHANGİ bir package'a linked entity'ler otomatik
///          görünür (built-in SRD + custom/official add-on packages).
///       2) entity_shares'te (shared_with=me VEYA NULL) kaydı olan homebrew
///          (linked=false) entity'ler görünür.
///       3) Paylaşımı geri çekilmiş ama gövdesi cihazda duran kartlar
///          ([revokedSharedEntityIdsProvider]) — gri gösterilir (§2.5).
///     (Character'a referans gönderen entity'ler de görünmeli ama
///     referenced_entity_ids tracking PR-O6.5'te eklenecek.)
///
/// Liste UI ve database tab bu provider'ı tüketmeli; entityProvider raw
/// kalır ve mirror push DM-only path'inde kullanılır.
final visibleEntityProvider = Provider<Map<String, Entity>>(
  dependencies: [
    entityProvider,
    currentWorldRoleProvider,
    activeCampaignIdProvider,
    builtinPackageIdProvider,
    installedWorldPackageIdsProvider,
    revokedSharedEntityIdsProvider,
  ],
  (ref) {
    final all = ref.watch(entityProvider);
    final role =
        ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;
    if (role != WorldRole.player) return all;

    // Player: shares set'ini al, filtrele.
    final auth = ref.watch(authProvider);
    if (auth == null) return const <String, Entity>{};

    // Active campaign id senkron alınmadığı için entity_shares watch'i için
    // ref.watch(activeCampaignIdProvider).valueOrNull kullan.
    final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
    if (worldId == null) return const <String, Entity>{};

    final sharesAsync = ref.watch(worldEntitySharesProvider(worldId));
    final shares = sharesAsync.valueOrNull ?? const [];
    final builtinPackId = ref.watch(builtinPackageIdProvider).valueOrNull;
    final installedPackageIds =
        ref.watch(installedWorldPackageIdsProvider(worldId)).valueOrNull ??
            const <String>{};

    final allowedIds = <String>{...ref.watch(revokedSharedEntityIdsProvider)};
    // Homebrew (linked == false) yalnızca entity_shares ile görünür.
    for (final s in shares) {
      if (s.sharedWith == null || s.sharedWith == auth.uid) {
        allowedIds.add(s.entityId);
      }
    }
    // Bu world'e kurulu herhangi bir package'ın linked entity'lerini otomatik
    // allow et (built-in SRD + custom/official add-on packages). builtinPackId
    // ekstra güvence: pack link'i best-effort kurulduğu için ayrıca tutulur.
    for (final entry in all.entries) {
      final e = entry.value;
      if (!e.linked || e.packageId == null) continue;
      if (e.packageId == builtinPackId ||
          installedPackageIds.contains(e.packageId)) {
        allowedIds.add(entry.key);
      }
    }
    if (allowedIds.isEmpty) return const <String, Entity>{};

    return {
      for (final e in all.entries)
        if (allowedIds.contains(e.key)) e.key: e.value,
    };
  },
);

/// Faz 5.5b — oyuncunun cihazında gövdesi duran ama DM'in artık paylaşmadığı
/// kartlar. Oyuncunun blob'undaki her homebrew (linked=false) kart bir
/// paylaşımdan geldi; listede yoksa paylaşım geri çekilmiştir. Gövde
/// silinmez, kart gri ve etiketli görünür (§2.5).
///
/// Paylaşım listesi yüklenmeden boş: yoksa açılışta her kart bir an gri olur.
/// Gövdeler bellekte ([WorldMirrorApplier]); dünya yeniden açılınca geri
/// çekilen kart hiç inmez, gri kart yalnız o oturumda görünür.
final revokedSharedEntityIdsProvider = Provider<Set<String>>(
  dependencies: [
    entityProvider,
    currentWorldRoleProvider,
    activeCampaignIdProvider,
  ],
  (ref) {
    final role =
        ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;
    if (role != WorldRole.player) return const <String>{};
    final uid = ref.watch(authProvider)?.uid;
    final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
    if (uid == null || worldId == null) return const <String>{};
    final shares = ref.watch(worldEntitySharesProvider(worldId)).valueOrNull;
    if (shares == null) return const <String>{};
    final shared = {
      for (final s in shares)
        if (s.sharedWith == null || s.sharedWith == uid) s.entityId,
    };
    return {
      for (final e in ref.watch(entityProvider).entries)
        if (!e.value.linked && !shared.contains(e.key)) e.key,
    };
  },
);
