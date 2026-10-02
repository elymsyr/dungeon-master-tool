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

    final allowedIds = <String>{};
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
