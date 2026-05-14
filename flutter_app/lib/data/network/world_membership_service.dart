import '../../domain/entities/online/world_invite.dart';
import '../../domain/entities/online/world_member.dart';

/// Online (paylaşılan) worldlerin üyelik + davet operasyonları.
///
/// Offline: [NoOpWorldMembershipService]. Online: Supabase RPC + RLS-korumalı
/// tablolarla çalışan [SupabaseWorldMembershipService].
abstract class WorldMembershipService {
  /// Worldü "online" yapar — Supabase'e [worlds] satırı upsert eder; trigger
  /// DM'yi otomatik member olarak ekler.
  Future<void> publishWorld({
    required String worldId,
    required String worldName,
    String? templateId,
    String? templateHash,
    required String stateJson,
  });

  /// Worldü "offline" yapar — Supabase'den siler (cascade tüm mirror data).
  Future<void> unpublishWorld(String worldId);

  /// Yeni davet kodu üretir (DM). Eski API — tek-kullanım/N-uses ile.
  /// Tek paylaşılabilir kod için [ensureInvite] kullan.
  Future<String> createInvite({
    required String worldId,
    int? expiresSeconds,
    int uses = 1,
  });

  /// World için aktif tek davet kodu varsa onu döner; yoksa yeni üretir.
  /// Idempotent: DM her çağrıda aynı kodu görür. Tüm oyuncular bu kodu
  /// kullanır.
  Future<String> ensureInvite(String worldId);

  /// Mevcut davet kodunu sil ve yeni kod üret (DM). Eski kod artık
  /// kullanılamaz.
  Future<String> regenerateInvite(String worldId);

  /// Davet kodunu kullanır (player). World adı ile worldId döner.
  Future<({String worldId, String worldName})> redeemInvite(String code);

  /// World üyelerini listeler (member görünür).
  Future<List<WorldMember>> listMembers(String worldId);

  /// Aktif davet kodlarını listeler (DM).
  Future<List<WorldInvite>> listInvites(String worldId);

  /// Bir üyeyi kovar (DM). [userId] = hedef üye.
  Future<void> removeMember({required String worldId, required String userId});

  /// Worldden ayrıl (kendi rolü 'dm' değilse). DM bağlantısını koparmak için
  /// önce [unpublishWorld] çağırmalı.
  Future<void> leaveWorld(String worldId);

  /// Davetiyeyi iptal eder (DM).
  Future<void> revokeInvite(String code);
}
