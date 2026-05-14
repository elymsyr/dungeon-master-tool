import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/online/world_role.dart';
import 'auth_provider.dart';
import 'builtin_package_provider.dart';
import 'entity_provider.dart';
import 'entity_share_provider.dart';
import 'role_provider.dart';

/// Aktif worlddeki entity'lerin, current user'a görünür olanlarını döner.
///
/// Kurallar:
///   - DM (veya online olmayan/role=none): tüm entity'ler görünür.
///   - Player:
///       1) Built-in pack'e linked entity'ler otomatik görünür (SRD core).
///       2) entity_shares'te (shared_with=me VEYA NULL) kaydı olanlar görünür.
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

    final allowedIds = <String>{};
    for (final s in shares) {
      if (s.sharedWith == null || s.sharedWith == auth.uid) {
        allowedIds.add(s.entityId);
      }
    }
    // Built-in entity'leri otomatik allow et.
    if (builtinPackId != null) {
      for (final entry in all.entries) {
        final e = entry.value;
        if (e.linked && e.packageId == builtinPackId) {
          allowedIds.add(entry.key);
        }
      }
    }
    if (allowedIds.isEmpty) return const <String, Entity>{};

    return {
      for (final e in all.entries)
        if (allowedIds.contains(e.key)) e.key: e.value,
    };
  },
);
