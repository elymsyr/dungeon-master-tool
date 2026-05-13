import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/network/no_op_world_membership_service.dart';
import '../../data/network/supabase_world_membership_service.dart';
import '../../data/network/world_membership_service.dart';
import '../../domain/entities/online/world_invite.dart';
import '../../domain/entities/online/world_member.dart';
import 'auth_provider.dart';

/// WorldMembershipService — Supabase yapılandırılmış + auth varsa
/// gerçek implementasyon; aksi halde NoOp.
final worldMembershipServiceProvider =
    Provider<WorldMembershipService>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return const NoOpWorldMembershipService();
  }
  final auth = ref.watch(authProvider);
  if (auth == null) return const NoOpWorldMembershipService();
  return SupabaseWorldMembershipService(Supabase.instance.client);
});

/// Aktif world'ün üyeleri (DM hub'ında üye listesini gösteren UI tüketir).
final worldMembersProvider =
    FutureProvider.family<List<WorldMember>, String>((ref, worldId) async {
  final svc = ref.watch(worldMembershipServiceProvider);
  if (svc is NoOpWorldMembershipService) return const [];
  return svc.listMembers(worldId);
});

/// Aktif world'ün aktif davet kodları (DM görür).
final worldInvitesProvider =
    FutureProvider.family<List<WorldInvite>, String>((ref, worldId) async {
  final svc = ref.watch(worldMembershipServiceProvider);
  if (svc is NoOpWorldMembershipService) return const [];
  return svc.listInvites(worldId);
});

/// World için tek paylaşılabilir davet kodu. İlk çağrıda oluşturur,
/// sonraki çağrılarda aynı kodu döner. Regenerate sonrası invalidate
/// edilmeli.
final worldActiveInviteCodeProvider =
    FutureProvider.family<String?, String>((ref, worldId) async {
  final svc = ref.watch(worldMembershipServiceProvider);
  if (svc is NoOpWorldMembershipService) return null;
  try {
    return await svc.ensureInvite(worldId);
  } catch (_) {
    return null;
  }
});
