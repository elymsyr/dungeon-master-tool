import '../../domain/entities/online/world_invite.dart';
import '../../domain/entities/online/world_member.dart';
import 'world_membership_service.dart';

/// Offline default — Supabase yapılandırılmadığında veya kullanıcı oturum
/// açmadığında kullanılır. Her şey [UnsupportedError] fırlatır; UI bu
/// servisi yalnızca online context'te (auth + SupabaseConfig.isConfigured)
/// çağırmalı.
class NoOpWorldMembershipService implements WorldMembershipService {
  const NoOpWorldMembershipService();

  Never _offline() =>
      throw UnsupportedError('Online features require Supabase + auth');

  @override
  Future<void> publishWorld({
    required String worldId,
    required String worldName,
    String? templateId,
    String? templateHash,
    required String stateJson,
  }) async =>
      _offline();

  @override
  Future<void> unpublishWorld(String worldId) async => _offline();

  @override
  Future<String> createInvite({
    required String worldId,
    int? expiresSeconds,
    int uses = 1,
  }) async =>
      _offline();

  @override
  Future<String> ensureInvite(String worldId) async => _offline();

  @override
  Future<String> regenerateInvite(String worldId) async => _offline();

  @override
  Future<({String worldId, String worldName})> redeemInvite(String code) async =>
      _offline();

  @override
  Future<List<WorldMember>> listMembers(String worldId) async => const [];

  @override
  Future<List<WorldInvite>> listInvites(String worldId) async => const [];

  @override
  Future<void> removeMember(
          {required String worldId, required String userId}) async =>
      _offline();

  @override
  Future<void> leaveWorld(String worldId) async => _offline();

  @override
  Future<void> revokeInvite(String code) async => _offline();
}
