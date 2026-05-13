import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/online/world_role.dart';
import 'auth_provider.dart';
import 'role_provider.dart';

/// Aktif kullanıcı için mind map key'i.
///   - DM (veya offline/role=none): `default`
///   - Player: `player_<uid>`
///
/// Mind map UI bu provider'ı tüketerek state'ini doğru slot'tan okur/yazar.
/// Server tarafında RLS (can_access_map) bu konvansiyonu zorlar.
final currentMindMapIdProvider = Provider<String>((ref) {
  final role =
      ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;
  if (role != WorldRole.player) return 'default';
  final auth = ref.watch(authProvider);
  if (auth == null) return 'default';
  return 'player_${auth.uid}';
});
