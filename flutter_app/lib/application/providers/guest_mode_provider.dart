import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Audit phase O1 — "I am using this without an account" as a stored choice.**
///
/// Guest mode is not a second offline implementation: it is the state a build
/// without the Supabase defines is already in — `AppPaths.setUser(null)`, the
/// global data root, the local Drift database. This notifier only remembers
/// that the user *chose* it, so the landing page stops asking on every launch.
///
/// The flag is cleared on sign-in (O3 promotes the guest's data into the
/// account) and on sign-out the user is a guest again only if they say so.
class GuestModeNotifier extends StateNotifier<bool> {
  GuestModeNotifier() : super(false);

  static const prefsKey = 'guest_mode';

  /// Read the stored choice. Called once, from the landing page.
  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(prefsKey) ?? false;
    if (mounted) state = stored;
    return stored;
  }

  /// The user picked "continue without an account".
  Future<void> enter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
    if (mounted) state = true;
  }

  /// Signing in ends guest mode — the account, not the guest root, owns the
  /// data from here on.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    if (mounted) state = false;
  }
}

final guestModeProvider =
    StateNotifierProvider<GuestModeNotifier, bool>((ref) => GuestModeNotifier());
