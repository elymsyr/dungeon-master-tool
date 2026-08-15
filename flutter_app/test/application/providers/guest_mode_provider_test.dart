import 'package:dungeon_master_tool/application/providers/guest_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Audit phase O1** — the guest's choice has to survive a relaunch, or the
/// landing page asks for an account every time the app starts and the offline
/// entry is only half reachable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to not-a-guest', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(guestModeProvider), isFalse);
    expect(await container.read(guestModeProvider.notifier).load(), isFalse);
  });

  test('enter() persists, so the next launch reads it back', () async {
    final first = ProviderContainer();
    await first.read(guestModeProvider.notifier).enter();
    expect(first.read(guestModeProvider), isTrue);
    first.dispose();

    // A fresh container is a fresh launch.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(await second.read(guestModeProvider.notifier).load(), isTrue);
    expect(second.read(guestModeProvider), isTrue);
  });

  test('clear() ends guest mode — signing in owns the data from there', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(guestModeProvider.notifier).enter();
    await container.read(guestModeProvider.notifier).clear();
    expect(container.read(guestModeProvider), isFalse);

    final relaunch = ProviderContainer();
    addTearDown(relaunch.dispose);
    expect(await relaunch.read(guestModeProvider.notifier).load(), isFalse);
  });
}
