import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';

// 039+040: `personal_characters` table retired. Per-character "Make Online"
// concept no longer exists — `world_characters` RLS auto-syncs every char
// for the owning user. The former `personalOnlineCharIdsProvider` was
// deleted; UI sites that consulted it now resolve "online" through auth
// state alone.

/// Aktif kullanıcının "Make Online" yaptığı paket adlarının set'i.
class PersonalOnlinePackageNamesNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  PersonalOnlinePackageNamesNotifier(this._ref) : super(const <String>{}) {
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
      final rows = await Supabase.instance.client
          .from('personal_packages')
          .select('package_name')
          .eq('owner_id', auth.uid);
      final names = <String>{};
      for (final row in (rows as List)) {
        final n = (row as Map)['package_name'];
        if (n is String) names.add(n);
      }
      state = names;
    } catch (e) {
      debugPrint('personalOnlinePackageNames refresh error: $e');
    }
  }

  void add(String name) {
    if (state.contains(name)) return;
    state = {...state, name};
  }

  void remove(String name) {
    if (!state.contains(name)) return;
    state = state.where((x) => x != name).toSet();
  }
}

final personalOnlinePackageNamesProvider = StateNotifierProvider<
    PersonalOnlinePackageNamesNotifier, Set<String>>(
        (ref) => PersonalOnlinePackageNamesNotifier(ref));
