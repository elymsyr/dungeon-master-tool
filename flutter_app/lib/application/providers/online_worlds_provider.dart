import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

/// Aktif Supabase user'ı için üye olduğu (online) world id'lerinin set'i.
/// Mirror push hook'ları (campaign + character provider) bu set'i kontrol
/// eder; world online değilse hiç push denemez — RLS hatası gürültüsü
/// (`new row violates row-level security policy`) ortadan kalkar.
///
/// Güncelleme:
/// - Auth değiştiğinde [refresh] otomatik tetiklenir.
/// - Publish/unpublish/join/leave UI handler'ları [add]/[remove] çağırır.
class OnlineWorldIdsNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  OnlineWorldIdsNotifier(this._ref) : super(const <String>{}) {
    refresh();
    _ref.listen<AuthState?>(authProvider, (_, _) => refresh());
  }

  Future<void> refresh() async {
    if (!SupabaseConfig.isConfigured) {
      state = const <String>{};
      return;
    }
    final auth = _ref.read(authProvider);
    if (auth == null) {
      state = const <String>{};
      return;
    }
    try {
      final rows = await guardedNetwork(
        _ref,
        () => Supabase.instance.client
            .from('world_members')
            .select('world_id')
            .eq('user_id', auth.uid),
      );
      final ids = <String>{};
      for (final row in (rows as List)) {
        final id = (row as Map)['world_id'];
        if (id is String) ids.add(id);
      }
      state = ids;
    } catch (e) {
      if (isOfflineError(e)) {
        debugPrint('onlineWorldIds skipped: offline');
      } else {
        debugPrint('onlineWorldIds refresh error: $e');
      }
    }
  }

  void add(String worldId) {
    if (state.contains(worldId)) return;
    state = {...state, worldId};
  }

  void remove(String worldId) {
    if (!state.contains(worldId)) return;
    state = state.where((id) => id != worldId).toSet();
  }
}

final onlineWorldIdsProvider =
    StateNotifierProvider<OnlineWorldIdsNotifier, Set<String>>(
        (ref) => OnlineWorldIdsNotifier(ref));
