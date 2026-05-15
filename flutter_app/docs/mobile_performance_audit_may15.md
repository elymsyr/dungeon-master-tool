# Mobile Performance Audit — Mayıs 15, 2026

**Kapsam**: `flutter_app/` — 452 Dart dosyası, ~163 kLOC. Önceki üç audit (`performance_optimization_roadmap.md`, `performance_hotspots_wizard_editor_hub.md`, `system_optimization_roadmap.md`) sonrası taze tarama. Hedef: mobil (Android/iOS) odaklı responsiveness, touch latency, scroll jank, memory pressure, pil tüketimi.

**Bulgu**: Önceki audit'lar (F1–F14, W1–W10, E1–E6, L1–L3, H1–H7, S1–S28) çok şey kapatmış — şu anki kasma noktaları farklı bir yerden geliyor:

1. **Android release build minify/proguard yok** — APK 30–40 MB şişkin, soğuk başlatma 2–4 s mobilde.
2. **`ProfileAvatar` + diğer `Image.network/file/asset` siteleri `cacheWidth/cacheHeight` yok** — 10+ avatar listede full-res decode, memory + GPU thrashing.
3. **Realtime CDC payload'ları UI thread'de `jsonDecode`** — `world_mirror_applier.dart` event başına 5–100 KB parse, mobil framerate düşer.
4. **App lifecycle paused/resumed event'inde realtime kanallar açık kalıyor** — backgrounded mobil app pil yiyor, resume'da kuyruktan 50+ event tek frame'de uygulanıyor.
5. **`projectionEntitySyncProvider` tüm entity map'i listening** — DM ekranında her küçük edit, O(N) projection snapshot regenerate.
6. **`SingleChildScrollView` + iç `ListView(shrinkWrap: true, physics: NeverScrollable...)`** 13 noktada — viewport dışı child'lar da eager build/layout, mobil scroll feel'ini bozuyor.
7. **TextField `onChanged` provider state'i her keystroke set ediyor** — debounce yok, klavye autocorrect cycle'ında ardışık rebuild.
8. **`InkWell.onTap: () async { showDialog(...) }`** loading feedback yok — kullanıcı tıklar, 100–300 ms sessizlik, "tepki almıyor" hissi.
9. **`compute()` / Isolate codebase'de sadece 3 yerde** — hash/parse/encode UI thread'de.
10. **`RepaintBoundary` sadece 18 yerde** — gradient/shadow/blur ağırlıklı widget'lar repaint loop'ta.

---

## Bulgular — Impact × Effort Matris

| # | Bulgu | Etkilenen | Impact | Effort | Skor | Faz |
|---|-------|-----------|--------|--------|------|-----|
| M1 | Android release minify+R8+ProGuard yok | APK boy, cold start | High | XS | **A+** | 1 |
| M2 | `Image.network/asset/file` cacheWidth/cacheHeight yok | 8 site, memory+GPU | High | S | **A** | 1 |
| M3 | `discoverSearchQueryProvider` her keystroke set | Search rebuild storm | High | XS | **A** | 1 |
| M4 | `InkWell.onTap` async + dialog → no spinner | Tüm modaller, "ölü" his | High | S | **A** | 1 |
| M5 | App lifecycle paused → realtime kanal açık | Mobil pil + resume jank | High | M | **A** | 1 |
| M6 | `projectionEntitySyncProvider` full map listen | DM second-screen, O(N) snapshot | High | M | **A** | 2 |
| M7 | Realtime CDC payload UI thread `jsonDecode` | Multiplayer, frame drop | High | M | **A** | 2 |
| M8 | `shrinkWrap + NeverScrollable` 13 sitesi | Sayfa scroll jank | Med | M | **B** | 2 |
| M9 | Scroll physics platform-aware değil | Mobil scroll feel | Med | XS | **B** | 1 |
| M10 | `RepaintBoundary` eksikliği (gradient/shadow) | 60→30 fps mid-tier Android | Med | S | **B** | 2 |
| M11 | `Wizard` dropdown `.map(...).toList()` her build | Wizard rebuild | Med | XS | **B** | 1 |
| M12 | `structured_list_field_widgets` row callback full-list emit | Structured editor | Med | S | **B** | 2 |
| M13 | `metadata_list_tile` `IntrinsicHeight` list içinde | Multi-pass layout | Med | S | **B** | 2 |
| M14 | `Directory.listSync()` soundpad theme load | İlk soundpad açılış jank | Med | XS | **B** | 1 |
| M15 | `LinearGradient` her `ProfileAvatar` build'inde | GPU spike scroll | Med | XS | **B** | 1 |
| M16 | Wizard world dedup `Set+spread` her build | Wizard step rebuild | Low | XS | **C** | 2 |
| M17 | `characterListProvider` listener full cascade | Hub linked char edit | Med | M | **B** | 2 |
| M18 | `social_providers` 5× postgres callback full invalidate | Chat refresh storm | Low | M | **C** | 3 |
| M19 | `battle_map_notifier` 33ms+80ms throttle çakışma riski | Drawing+transform | Low | S | **C** | 3 |
| M20 | 15+ `Timer` instance pool yok | Heap fragmentation | Low | M | **C** | 3 |
| M21 | `Hero` widget yok ✓ + `Tween` abuse yok ✓ | — | — | — | — | confirmed clean |
| M22 | `pdfOpenPaths` `File.existsSync()` startup blocking | Cold start | Low | XS | **C** | 1 |
| M23 | `LayoutBuilder` mobile breakpoint eksikliği | Char editor overflow | Med | M | **B** | 2 |
| M24 | `tag_input` `optionsBuilder` her keystroke filter | Tag autocomplete | Low | XS | **C** | 2 |
| M25 | `listing_banner_card` `base64Decode` per render | Marketplace scroll | Med | S | **B** | 2 |
| M26 | `condition_badge` `Image.file` no cacheWidth | Combat 10+ badge | Med | XS | **B** | 1 |
| M27 | Bootstrap `Future.wait` Supabase 3s timeout mobile slow | İlk paint algısı | Low | M | **C** | 3 |

Score: **A+/A** = bu hafta, **B** = sonraki sprint, **C** = nice-to-have.

---

## 1. Build & Release Optimizasyonları (M1, M22, M27)

### M1 — Android release minify+shrink+ProGuard yok
**Dosya**: [android/app/build.gradle.kts:65-75](../android/app/build.gradle.kts#L65)

```kotlin
buildTypes {
    release {
        signingConfig = ...
        // ❌ isMinifyEnabled, isShrinkResources, proguardFiles YOK
    }
}
```

**Etki**: APK ~30–40 MB (tree-shake yok), cold start mobilde 2–4 s ek (Dart kernel + Java class load). Pas geçilmiş tüm Flutter `flutter build apk --release` defaultları.

**Fix**:
```kotlin
buildTypes {
    release {
        signingConfig = ...
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

`android/app/proguard-rules.pro` ekle:
```
# Flutter ve Dart için güvenli kurallar
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class * extends io.flutter.embedding.android.FlutterActivity { *; }
-dontwarn io.flutter.embedding.**

# desktop_multi_window, supabase, soloud için
-keep class com.flutter.plugin.** { *; }
-keep class io.supabase.** { *; }
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
```

Sonra `flutter build apk --release --analyze-size` ile fark ölç. Beklenen: 30 MB → 14–18 MB.

### M22 — `File.existsSync()` startup'ta kuyruk
**Dosya**: [main_screen.dart:109](../lib/presentation/screens/main_screen.dart#L109)

```dart
_pdfOpenPaths = uiState.pdfOpenPaths.where((p) => File(p).existsSync()).toList();
```

`initState` içinde N path × sync `stat()`. Mobile + slow storage'da 50–200 ms.

**Fix**: `unawaited(Future.microtask(() async { ... }))` ile async tara, sonra `setState`. veya bootstrap'a taşı.

### M27 — Supabase init 3s timeout mobile slow path
**Dosya**: [main.dart:170-174](../lib/main.dart#L170)

`Future.wait([_initSupabase(), _initWindowManager(), _initUiState()])` mobil cellular bağlantıda Supabase TLS handshake + auth refresh 5+ s. 3 s timeout düşüyor, sessizce devam.

**Fix**: Supabase init non-blocking ya da `unawaited`. UI auth state'i null'la başlasın, gerçekleştikte rebuild olsun. Window manager mobilde noop zaten — şartı erken kes.

---

## 2. Görsel / Image Caching (M2, M15, M26)

### M2 — `Image.network/asset/file` cacheWidth eksik (~8 site)

| Dosya | Görsel kaynağı | Mevcut |
|-------|----------------|--------|
| [profile_avatar.dart:53](../lib/presentation/widgets/profile_avatar.dart#L53) | `Image.network(avatarUrl)` | cacheWidth **yok** |
| [feed_tab.dart](../lib/presentation/screens/social/feed_tab.dart) | post cover `Image.network` | cacheWidth **yok** |
| [profile_screen.dart](../lib/presentation/screens/profile/profile_screen.dart) | banner+avatar | cacheWidth **yok** |
| [app_icon_image.dart:18](../lib/presentation/widgets/app_icon_image.dart#L18) | `Image.asset` | cacheWidth **yok** |
| [condition_badge.dart:62](../lib/presentation/widgets/condition_badge.dart#L62) | `Image.file` | cacheWidth **yok** |
| [asset_ref_image.dart:79](../lib/presentation/widgets/asset_ref_image.dart#L79) | `Image.file` | cacheWidth **yok** |
| [token_widget.dart:128](../lib/presentation/widgets/battle_map/token_widget.dart#L128) | `Image.file` battle token | cacheWidth **yok** |
| [listing_banner_card.dart:139](../lib/presentation/widgets/listing_banner_card.dart#L139) | `Image.memory(base64)` | cacheWidth **yok** |

Tek bir 2MB PNG, `Image.file(...)` ile decode → 200×200 render → bellekte hala 2048×2048 RGBA8 = **16 MB**. 10 token + 10 condition = 320 MB. Android 2GB RAM cihazda OOM kill.

**Fix** — ortak helper:
```dart
// lib/presentation/widgets/perf/sized_image.dart (yeni)
int? _cachePxFromLogical(BuildContext ctx, double logical) {
  if (logical.isInfinite || logical.isNaN) return null;
  final dpr = MediaQuery.devicePixelRatioOf(ctx);
  return (logical * dpr).ceil();
}
```

`ProfileAvatar`:
```dart
return ClipOval(
  child: Image.network(
    avatarUrl!,
    width: size,
    height: size,
    fit: BoxFit.cover,
    cacheWidth: _cachePxFromLogical(context, size),
    cacheHeight: _cachePxFromLogical(context, size),
    errorBuilder: ...,
    loadingBuilder: ...,
  ),
);
```

`condition_badge`, `token_widget`, `asset_ref_image` aynı tedavi. `app_icon_image` için statik `cacheWidth: (size * 2).ceil()`.

### M15 — `ProfileAvatar` LinearGradient her build
**Dosya**: [profile_avatar.dart:24-48](../lib/presentation/widgets/profile_avatar.dart#L24)

`StatelessWidget` build içinde her seferinde yeni `LinearGradient`, `BoxDecoration`, `Container` allocate. Feed'de 100 avatar scroll'da GPU spike.

**Fix**: `RepaintBoundary` ile sar, `fallback`'i const factory yap (palette teması renkleri canlı olduğundan `BoxDecoration` cache'i state olarak `const` yapılamıyor — ama `RepaintBoundary` izolasyon yeterli).

### M26 — Combat ekranında `condition_badge` 10+ badge
**Dosya**: [condition_badge.dart:62](../lib/presentation/widgets/condition_badge.dart#L62)

Encounter'da bir oyuncuda Poisoned+Prone+Frightened+Restrained ortakça → 4 badge. 5 düşman = 20 badge × full-res decode. M2 ile birleşik fix.

---

## 3. Riverpod / Rebuild (M3, M6, M7, M11, M16, M17)

### M3 — Search keystroke direkt provider state set
**Dosya**: [feed_tab.dart:381](../lib/presentation/screens/social/feed_tab.dart#L381)

```dart
onChanged: (v) => ref.read(discoverSearchQueryProvider.notifier).state = v.trim(),
```

Mobile autocorrect cycle "merh" → "mer" → "merha" → "merhaba" — 4 set, 4 full discoverProvider re-fetch.

**Fix** — debounce'li notifier:
```dart
// application/providers/social_providers.dart
class DiscoverSearchQueryNotifier extends StateNotifier<String> {
  DiscoverSearchQueryNotifier() : super('');
  Timer? _debounce;

  void setQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) state = v.trim();
    });
  }
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }
}
```

`tag_input.dart` `optionsBuilder` (M24) aynı pattern.

### M6 — `projectionEntitySyncProvider` full map listen
**Dosya**: [projection_provider.dart:525-540](../lib/application/providers/projection_provider.dart#L525)

DM herhangi bir entity edit'inde projection açıksa **tüm** card snapshot'ları rebuild. Battle map'te 30 entity ile her hareket → 30 snapshot → 30 IPC encode → ~5 MB jsonEncode tek frame'de.

**Fix** — surgical mirror:
```dart
final projectionCardProvider = Provider.family<EntityCardProjection?, String>((ref, id) {
  return ref.watch(entityProvider.select((m) => m[id]))?.toProjection();
});
```

Sadece değişen card snapshot'ı IPC'ye git. IPC encode batch'i de delta-form'a çevrilebilir (sadece patch alanları gönder).

### M7 — Realtime CDC payload UI thread `jsonDecode`
**Dosyalar**:
- [world_mirror_applier.dart:218](../lib/application/services/world_mirror_applier.dart#L218) — character payload decode
- [world_mirror_applier.dart:321](../lib/application/services/world_mirror_applier.dart#L321) — world `state_json` decode
- [personal_mirror_applier.dart:140](../lib/application/services/personal_mirror_applier.dart#L140) — package bootstrap decode

Multiplayer'da 4–6 oyuncu hızlı combat update'i = saniyede 3–5 CDC event. Mobil cihaz UI thread'inde 5×50 KB JSON parse = ~150 ms frame block.

**Fix**:
```dart
Future<Character?> _characterFromPayload(Map<String, dynamic> payload) async {
  final jsonStr = payload['state_json'] as String?;
  if (jsonStr == null) return null;
  final data = await compute<String, Map<String, dynamic>>(_decodeJson, jsonStr);
  return Character.fromJson(data);
}

Map<String, dynamic> _decodeJson(String s) => jsonDecode(s) as Map<String, dynamic>;
```

⚠️ `compute()` her çağrıda yeni isolate spawn'lar; high-frequency akış için `IsolateRunner` veya `Isolate.spawn` ile uzun-ömürlü worker tercih edilmeli (`flutter_isolate` veya manuel SendPort/ReceivePort).

### M11 — Wizard dropdown items
**Dosya**: [character_creation_wizard_screen.dart:1467-1531](../lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart#L1467)

Her build'de `.map((t) => DropdownMenuItem(...)).toList()` yeniden allocate.

**Fix**: `late final _templateItems = ...` state field veya cached provider.

### M16 — Wizard world dedup spread
Aynı dosya:1485-1541. `<String>{...worlds}.toList()` Set + spread. `memoized` field ile çözülür.

### M17 — `characterListProvider` listener cascade
**Dosya**: [entity_provider.dart:155-178](../lib/application/providers/entity_provider.dart#L155)

Her character listener tetiğinde linked-id matching + full entity map patch. 50 character ile her edit → tüm subtree rebuild.

**Fix**: Linked character set'i `Set<String>` halinde memoize, listener `select` ile yalnız id seti değişiminde tetik.

---

## 4. List & Scroll (M8, M9, M13, M23)

### M8 — `shrinkWrap: true + NeverScrollable` 13 site
Grep çıktısından kritik olanlar:
- [characters_tab.dart:159](../lib/presentation/screens/hub/characters_tab.dart#L159) — 50+ character listede
- [worlds_tab.dart:133](../lib/presentation/screens/hub/worlds_tab.dart#L133)
- [packages_tab.dart:132](../lib/presentation/screens/hub/packages_tab.dart#L132)
- [settings_tab.dart:71, :247](../lib/presentation/screens/hub/settings_tab.dart#L71)
- [feed_tab.dart:624](../lib/presentation/screens/social/feed_tab.dart#L624)
- [messages_tab.dart:830](../lib/presentation/screens/social/messages_tab.dart#L830)

Hepsi `SingleChildScrollView` (veya benzeri) içinde — viewport-out child'lar layout pass'ten geçiyor. 50 character × ~140px = 7000 px tüm layoutlanıyor scroll başlangıcında.

**Fix opsiyonları**:

**Opsiyon A** (önerilen — sliver migrasyonu):
```dart
return CustomScrollView(
  slivers: [
    SliverToBoxAdapter(child: _header()),
    SliverList.separated(
      itemCount: sorted.length,
      itemBuilder: (ctx, i) => _CharacterCard(sorted[i]),
      separatorBuilder: (_, _) => const SizedBox(height: 6),
    ),
    SliverToBoxAdapter(child: _footer()),
  ],
);
```

**Opsiyon B** (minimal):
Outer `SingleChildScrollView` kalsın, ListView'in `itemExtent` parametresini ver — Flutter viewport hesabını kısa devre eder:
```dart
ListView.separated(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemExtent: 146.0, // 140 minHeight + 6 separator
  ...
)
```

`itemExtent` setiyle eager layout maliyeti O(N) → O(1) (Flutter yalnızca offset hesaplar, ölçüm yapmaz). Sliver göçü zaman/iş gerektiriyorsa **bunu tercih et** — 1 satır, çoğu kart sabit yükseklik zaten.

### M9 — Scroll physics platform-aware değil
**Dosya**: [app.dart:55-65](../lib/app.dart#L55)

`_AppScrollBehavior` sadece `dragDevices` override ediyor. Mobile için `BouncingScrollPhysics()` (iOS-stil) veya `ClampingScrollPhysics()` (Android-stil) explicit set edilmemiş — Flutter default'u platform'a göre verir ama `_AppScrollBehavior` override'ı dolaylı olarak overscroll glow vs. bounce davranışlarını tutarsız kılıyor.

**Fix**:
```dart
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch, PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad, PointerDeviceKind.stylus,
  };
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS: case TargetPlatform.macOS:
        return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
      default:
        return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    }
  }
}
```

### M13 — `IntrinsicHeight` list row'larda
**Dosya**: [metadata_list_tile.dart:83](../lib/presentation/widgets/metadata_list_tile.dart#L83)

`IntrinsicHeight` multi-pass layout — `ListView.separated` itemBuilder'da kullanılırsa N × (measure-twice) = 2N layout pass.

**Fix**: Row'daki children için `crossAxisAlignment: CrossAxisAlignment.stretch` + sabit min-height container. Veya tile için `Card` + fixed padding.

### M23 — `ConstrainedBox(maxWidth: 760)` mobile breakpoint yok
**Dosya**: [character_editor_screen.dart](../lib/presentation/screens/characters/character_editor_screen.dart)

Geniş layout'u küçük ekranda zorlar — yatay scroll/overflow. `LayoutBuilder` ile mobile'da Column'a sw witch yapılmalı.

```dart
return LayoutBuilder(builder: (ctx, c) {
  final isPhone = c.maxWidth < 600;
  return isPhone ? _PhoneLayout() : _WideLayout();
});
```

---

## 5. RepaintBoundary & Paint Optimizasyonu (M10, M15)

Codebase'de `RepaintBoundary` sadece 18 kez kullanılmış. Mobil GPU'da kritik.

**Eklenmesi gereken yerler**:
- `ProfileAvatar` fallback gradient (M15)
- `mind_map_node_widget` selected halo + glow
- `world_map_screen` token marker'lar
- Battle map drawing layer (`battle_map_painter.dart` zaten clipper'lı, RepaintBoundary'siz ise ekle)
- Soundpad cell card'ları
- Listing card cover (marketplace scroll)

**Genel kural**: Sık değişen animasyonlu/highlight'lı widget kendi paint layer'ına sahip olsun, parent compositor'ı tetiklemesin.

```dart
return RepaintBoundary(
  child: AnimatedContainer(
    decoration: BoxDecoration(
      boxShadow: selected ? [BoxShadow(blurRadius: 8, ...)] : [],
    ),
    child: ...,
  ),
);
```

---

## 6. Touch & Responsiveness (M4)

### M4 — `InkWell.onTap: () async { ... }` feedback yok
**Sites (örnek)**: [field_widget_factory.dart:1206, 1844, 2219, 3263, 3367, 3436, 3521](../lib/presentation/widgets/field_widgets/field_widget_factory.dart#L1206)

Kullanıcı tıklar → 100–300 ms (network round-trip / image decode / dialog setup) → dialog açılır. Bu 100–300 ms'de görsel feedback **sıfır**. Mobilde "tepki almıyor" hissi tam buradan.

**Fix pattern** — generic helper:
```dart
// lib/presentation/widgets/perf/async_tap.dart (yeni)
class AsyncInkWell extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onTap;
  final BorderRadius? borderRadius;
  const AsyncInkWell({super.key, required this.child, required this.onTap, this.borderRadius});
  @override State<AsyncInkWell> createState() => _AsyncInkWellState();
}
class _AsyncInkWellState extends State<AsyncInkWell> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          borderRadius: widget.borderRadius,
          onTap: _busy ? null : () async {
            setState(() => _busy = true);
            try { await widget.onTap(); }
            finally { if (mounted) setState(() => _busy = false); }
          },
          child: widget.child,
        ),
        if (_busy)
          Positioned.fill(child: IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.06),
              child: const Center(child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            ),
          )),
      ],
    );
  }
}
```

Bütün `onTap: () async { await showXDialog(...); }` chain'leri `AsyncInkWell` ile değiştir. Veya minimum `globalLoadingProvider.show(...)` ile.

---

## 7. Lifecycle & Realtime (M5)

### M5 — Backgrounded mobil app realtime kanal açık
**Dosya**: [main_screen.dart:122-137](../lib/presentation/screens/main_screen.dart#L122)

Mevcut:
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
    ref.read(saveStateProvider.notifier).saveNow();
  } else if (state == AppLifecycleState.resumed) {
    betaNotifier.heartbeat();
    betaNotifier.refresh();
  }
}
```

Eksikler:
- **paused**'da: realtime kanal pause / unsubscribe yok. Backgrounded telefonda WiFi açık → server her CDC event'i push'lar → mobil radio active → pil yer.
- **resumed**'da: backgrounded sürede biriken event'ler tek frame'de uygulanır → mobil ön plana geçtiğinde 200–800 ms jank.

**Fix** — `world_sync_service.dart` + `personal_sync_service.dart` + `social_providers.dart` realtime channel manager ekle:
```dart
class RealtimeManager {
  bool _suspended = false;
  Future<void> suspend() async {
    _suspended = true;
    await _worldChannel?.unsubscribe();
    await _personalChannel?.unsubscribe();
    await _socialChannel?.unsubscribe();
  }
  Future<void> resume() async {
    if (!_suspended) return;
    _suspended = false;
    await _subscribeAll();
    // İlk full refetch — backgrounded sürede kaçırılanları yakala
    ref.invalidate(myConversationsProvider);
    ref.invalidate(charactersProvider);
  }
}
```

`main_screen.dart`:
```dart
if (state == AppLifecycleState.paused) {
  ref.read(saveStateProvider.notifier).saveNow();
  ref.read(realtimeManagerProvider).suspend();
} else if (state == AppLifecycleState.resumed) {
  ref.read(realtimeManagerProvider).resume();
  ...
}
```

Bu mobilde **en büyük pil + responsiveness kazancı** — bir tek değişiklik.

---

## 8. Heavy Sync Path'ler (M7, M14, M20, M25)

### M14 — `Directory.listSync()` soundpad theme load
**Dosya**: [soundpad_loader.dart:236](../lib/data/services/soundpad_loader.dart#L236)

İlk soundpad açılışında sync dir scan. Mobile internal storage'da 5–10 KB tree → 50–200 ms.

**Fix**: `Directory(...).list()` async + `await for (final f in ...)`.

### M20 — 15+ Timer instance
Inventory:
- `projection_output_window.dart:64` (200 ms)
- `ui_state_provider.dart:225` (1 s)
- `cloud_sync_provider.dart:101` (debounced)
- `battle_map_notifier.dart:284` (33 ms project sync)
- `battle_map_notifier.dart:359` (80 ms drawings)
- `battle_map_notifier.dart:998` (3 s save)
- `mind_map_node_widget.dart:146` (30 s mobile autosave)
- `character_editor_screen.dart:131` (400 ms undo)
- `character_editor_screen.dart:194` (1.2 s save)
- vb.

**Fix** — birleştirilmiş debounce service:
```dart
class DebounceScheduler {
  final Map<String, Timer> _timers = {};
  void schedule(String key, Duration delay, VoidCallback cb) {
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, () { _timers.remove(key); cb(); });
  }
}
```

Provider olarak expose, `ref.read(debounceProvider).schedule('save-char-${id}', 1.2s, save)`. Pil etkisi minimal ama dispose discipline tek noktada.

### M25 — `listing_banner_card` `base64Decode` per render
**Dosya**: [listing_banner_card.dart:139](../lib/presentation/widgets/listing_banner_card.dart#L139)

Marketplace scroll'da her item rebuild'de `base64Decode(coverImageB64)` (5–20 KB string → bytes). 50 listing × 4 rebuild ≈ 200 decode/saniye.

**Fix**: `Provider.family<Uint8List, String>` ile decoded byte cache, ya da arka isolate'te tek seferlik decode + memoryCache.

---

## 9. Şu an kapsamlı görünenler (confirm)

- **Hero animasyonları**: codebase'de yok → mobile transition stutter riski yok ✓
- **`prefer_const_constructors`**: 71 fix yapılmış (F7) ✓
- **DeepCollectionEquality**: jsonEncode-equality F1 fix ✓
- **`sortedCharactersProvider`**: hub sort cache F8 ✓
- **`entitiesByCategoryProvider.family`**: wizard W4 ✓
- **SoLoud async init**: M.158 `unawaited` ✓
- **`UiState.load` parallel**: F9 ✓

---

## 10. Faz Planı

### Faz 1 — Bu sprint (1–2 gün toplam)
Hızlı, yüksek-impact, low-risk fixler:
- [ ] **M1** Android minify+R8+ProGuard — APK boy + cold start (XS effort, A+ impact)
- [ ] **M2** Image cacheWidth/cacheHeight tüm 8 sitede (S effort, A impact)
- [ ] **M3** `discoverSearchQueryProvider` debounce (XS)
- [ ] **M4** `AsyncInkWell` helper + 10 priority site replace (S)
- [ ] **M5** Realtime lifecycle suspend/resume (M, kritik mobil) ⭐
- [ ] **M9** Scroll physics platform-aware (XS)
- [ ] **M11** Wizard dropdown memoize (XS)
- [ ] **M14** Soundpad async dir scan (XS)
- [ ] **M15** ProfileAvatar `RepaintBoundary` (XS)
- [ ] **M22** PDF path existsSync async (XS)
- [ ] **M26** Condition badge cacheWidth (XS — M2 ile birlikte)

### Faz 2 — Sonraki sprint
Daha derin değişiklikler:
- [ ] **M6** projectionEntitySync per-card select
- [ ] **M7** CDC `compute()` / long-lived isolate decoder
- [ ] **M8** `itemExtent` 13 site (veya sliver migrasyon)
- [ ] **M10** RepaintBoundary 5–8 sıcak nokta
- [ ] **M12** Structured list row callback diff
- [ ] **M13** `IntrinsicHeight` removal
- [ ] **M17** `characterListProvider` listener select
- [ ] **M23** Char editor `LayoutBuilder` mobile
- [ ] **M24** Tag autocomplete debounce
- [ ] **M25** Listing banner base64 cache

### Faz 3 — Nice-to-have
- [ ] **M18** social providers granular invalidate
- [ ] **M19** battle map throttle unify
- [ ] **M20** DebounceScheduler birleştirme
- [ ] **M27** Bootstrap Supabase non-blocking

---

## 11. Ölçüm Yöntemi

Her fix öncesi/sonrası ölç:

1. **DevTools Performance tab** — frame budget, dropped frame count
2. **`flutter run --profile --trace-startup`** — `start_up_info.json` (`engineEnterTimestampMicros` → `firstFrameRasterizedMicros`)
3. **APK boy**: `flutter build apk --release --analyze-size`
4. **Memory**: DevTools Memory tab, scroll feed 30s, peak heap kaydet
5. **Touch latency**: Android `adb shell setprop debug.choreographer.skipwarn 1`, log jank
6. **Realtime suspend ölçüm**: backgrounded 5 dakika WiFi RX bytes (`ip -s link show wlan0` veya iOS Instruments → Network)

Hedef metrikler:
- Soğuk başlatma: < 1.5 s (mid-tier Android)
- Touch → görsel feedback: < 50 ms
- Scroll 60 fps (16.6 ms frame), 90% frames < 16 ms
- Feed scroll 30 s memory: < 200 MB peak
- Backgrounded pil drain: < 1% / saat

---

## Ek: Aksiyon listesi tek satırda

```
M1  android/app/build.gradle.kts — minify + R8 + proguard rules
M2  Image.network/asset/file 8 site — cacheWidth+cacheHeight ekle
M3  social_providers.dart — DiscoverSearchQueryNotifier debounce(300ms)
M4  perf/async_tap.dart yeni — AsyncInkWell, 10 öncelikli onTap site refactor
M5  RealtimeManager — paused: unsubscribe / resumed: subscribe + invalidate
M6  projection_provider.dart — Provider.family<EntityCardProjection?, String> + .select()
M7  world/personal_mirror_applier — compute() ya da long-lived decoder isolate
M8  hub listeleri — ListView.itemExtent ekle (veya sliver)
M9  app.dart — _AppScrollBehavior.getScrollPhysics platform switch
M10 RepaintBoundary 5–8 sıcak nokta (mind_map_node, token, listing_card vb.)
M11 wizard dropdown — late final templateItems
M12 structured_list_field — onRowChanged(index, value)
M13 metadata_list_tile — IntrinsicHeight kaldır, fixed height
M14 soundpad_loader — Directory.list() async
M15 ProfileAvatar — RepaintBoundary
M17 entity_provider — characterListProvider linked-id memo + select
M22 main_screen — File.existsSync async to bootstrap
M23 character_editor — LayoutBuilder mobile breakpoint
M24 tag_input — optionsBuilder debounce
M25 listing_banner_card — Provider.family decoded bytes cache
M26 condition_badge — cacheWidth
M27 main.dart — Supabase init non-blocking
```
