import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';

/// Aktif kullanıcının "Make Online" yaptığı karakter id'lerinin set'i.
///
/// Pattern `OnlineWorldIdsNotifier` ile aynı: auth değişikliğinde Supabase'den
/// refresh; `add`/`remove` UI handler'ları için. Mirror push hook'ları bu
/// set'i kontrol eder — online değilse RLS gürültüsü olmasın diye hiç
/// push denemez.
class PersonalOnlineCharIdsNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  PersonalOnlineCharIdsNotifier(this._ref) : super(const <String>{}) {
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
          .from('personal_characters')
          .select('id')
          .eq('owner_id', auth.uid);
      final ids = <String>{};
      for (final row in (rows as List)) {
        final id = (row as Map)['id'];
        if (id is String) ids.add(id);
      }
      state = ids;
    } catch (e) {
      debugPrint('personalOnlineCharIds refresh error: $e');
    }
  }

  void add(String id) {
    if (state.contains(id)) return;
    state = {...state, id};
  }

  void remove(String id) {
    if (!state.contains(id)) return;
    state = state.where((x) => x != id).toSet();
  }
}

final personalOnlineCharIdsProvider =
    StateNotifierProvider<PersonalOnlineCharIdsNotifier, Set<String>>(
        (ref) => PersonalOnlineCharIdsNotifier(ref));

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
