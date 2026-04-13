# Dungeon Master Tool — beta-v4.1.0

Release tag: `beta-v4.1.0`
Previous: `beta-v4.0.1`

## Highlights

- **In-app update indicator** — Hub artık açıldığında GitHub'dan en son release'i çekiyor. AppBar'da versiyon rozeti var; yeni sürüm varsa turuncu `arrow_circle_up` ikonu ve tıklanınca release notes + **Download** butonlu bir dialog açılıyor. Ağa ulaşılamazsa sessizce geri düşüyor — hub asla bloklanmaz.
- **Mobilde Mind Map kontrolü yenilendi** — Notların içinde parmakla kaydırma artık metni gerçekten kaydırıyor (eskiden node'u hareket ettiriyordu). Taşı / Yeniden Boyutlandır işlemleri için uzun basınca çıkan menüye **Move** ve **Resize** eklendi; bir SnackBar ile "Done" butonu üzerinden moddan çıkılıyor.
- **Profile & Social sekmeleri yeni pill bar** — Profile ekranındaki Posts/Items seçici artık Social'daki Feed / Marketplace / Messages barı ile aynı görsele sahip. Mobilde her iki bar da ana BottomNavigationBar'ın hemen üzerine konumlanıyor; desktop'ta üstte kalıyor.
- **"Quit" butonu** — Desktop/tablet sidebar ve mobil popup menüsündeki *Switch World* eylemi artık **Quit** olarak adlandırılıyor (`exit_to_app` ikonu, tooltip: "Quit to hub"). Save → backup-check → hub navigation akışı korundu.

## UI Fixes

- Hub ilk açılışında **Worlds / Templates / Packages / Settings** sekmelerinin bazen dikey ortada görünüp tab değiştirince düzelmesi sorunu giderildi. Tüm hub tab'ları artık `Align(topCenter)` + `mainAxisSize: min` kullanıyor — içerik ilk frame'de üstten hizalı render ediliyor.
- Social pill bar mobilde bottom-center'da, ana NavigationBar'ın hemen üzerinde. Desktop'ta eski yerinde (üst bar).
- Profile ekranı `DefaultTabController` + Material `TabBar` bağımlılığından kurtuldu; yerine paylaşılan `PillTabBar` + `IndexedStack` kullanılıyor.

## Internal / Refactoring

- Yeni paylaşılan `PillTabBar<T>` widget'ı `presentation/widgets/pill_tab_bar.dart` altına eklendi. Social'daki `_PillBar` buradan import ediliyor.
- Yeni `ReleaseCheckService` (`data/network/release_check_service.dart`) — GitHub Releases API'sinden `tag_name`, `html_url`, `body` çekiyor. `<process>-v<semver>` formatında tag parse'ı ve `isNewerThan()` karşılaştırması içeriyor. Mevcut `dart:io HttpClient` desenini tekrar kullanıyor (yeni bağımlılık yok).
- `latestReleaseProvider` — session başına bir kez fetch eden `FutureProvider<ReleaseInfo?>`.
- `appVersion` constant'ı `4.1.0`'a çıkarıldı; `appProcess = 'beta'` eklendi ve `appReleaseTag` getter'ı (`'$appProcess-v$appVersion'`) üzerinden `beta-v4.1.0` üretiliyor. `pubspec.yaml` versiyonu eşitlendi.

## Deferred

- **Latency audit** — DevTools profiling pass (button tap hitch'leri, cast/animation frame drop'ları, rebuild storm'lar, main-isolate sync iş) ayrı bir session'a bırakıldı. Bu release'in içinde yok.

## Verification Checklist

- [ ] Hub açıldığında AppBar'da `beta-v4.1.0` rozeti görünüyor; GitHub'da yeni sürüm yoksa muted renkte. Yeni sürüm yayınlanırsa rozet turuncuya dönüp tıklanabilir hâle geliyor ve Download dialog'u açılıyor.
- [ ] Airplane mode'da hub sorunsuz açılıyor, hata banner'ı yok.
- [ ] Desktop sidebar'da "Quit to hub" butonu `exit_to_app` ikonu ile görünüyor; tıklayınca save → backup confirm → hub.
- [ ] Mobile popup menüde "Quit" entry'si aynı akışı çalıştırıyor.
- [ ] Cold start: Worlds / Templates / Packages / Settings içerikleri ilk frame'de üstten hizalı.
- [ ] Social ekranı mobilde: pill bar bottom-center'da, ana nav'ın hemen üzerinde.
- [ ] Profile ekranı: Posts / Items pill bar Social ile aynı görselde; içerik `IndexedStack` ile anında geçiş yapıyor.
- [ ] Mind map note (mobilde): uzun metin içeren bir note açıp parmakla kaydırınca metin kayıyor, node hareket etmiyor.
- [ ] Mind map note (mobilde): long-press → menüde **Move** ve **Resize** var. Move → SnackBar açılıyor, drag node'u taşıyor, drag end'de mod otomatik kapanıyor. Resize → corner handle'lar görünüyor, handle drag'i node'u yeniden boyutlandırıyor, commit sonrası mod kapanıyor.
- [ ] Mind map (desktop): node drag + hover resize handle davranışı değişmemiş.

## Files Changed

```
flutter_app/lib/core/constants.dart
flutter_app/lib/presentation/screens/hub/hub_screen.dart
flutter_app/lib/presentation/screens/hub/worlds_tab.dart
flutter_app/lib/presentation/screens/hub/templates_tab.dart
flutter_app/lib/presentation/screens/hub/packages_tab.dart
flutter_app/lib/presentation/screens/hub/settings_tab.dart
flutter_app/lib/presentation/screens/main_screen.dart
flutter_app/lib/presentation/screens/mind_map/mind_map_node_widget.dart
flutter_app/lib/presentation/screens/profile/profile_screen.dart
flutter_app/lib/presentation/screens/social/social_shell.dart
flutter_app/lib/presentation/screens/landing/landing_screen.dart
flutter_app/pubspec.yaml

# New
flutter_app/lib/data/network/release_check_service.dart
flutter_app/lib/application/providers/release_check_provider.dart
flutter_app/lib/presentation/widgets/pill_tab_bar.dart
flutter_app/lib/presentation/widgets/version_indicator_button.dart
```
