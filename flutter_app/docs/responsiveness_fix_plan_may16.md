# Responsiveness Fix Plan — Mayıs 16, 2026

**Kapsam**: Kullanıcı raporları, üç somut sıkıntı:

1. **Ana ekran tab geçişleri yavaş** — cloud sync yükü tab açılışını blokluyor.
2. **Database arama klavyesi mobilde geç açılıyor** — search field'a tıklayınca klavye animasyonu kasıyor.
3. **Karakter kartı (editor) içi etkileşim hafif kasıyor** — field düzenleme + tab geçişi smooth değil.

Önceki audit'lerden ([mobile_performance_audit_may15.md](mobile_performance_audit_may15.md)) Faz 1 fixleri shipped. Bu doküman üç spesifik kullanıcı şikayetine net root-cause + fix planı.

---

## 1. Tab Geçişi Cloud-Sync Tarafından Blokluyor

### Tespit

**Dosya**: [main_screen.dart:389-392](../lib/presentation/screens/main_screen.dart#L389)

```dart
ref.watch(activeCampaignSyncProvider);       // ← FutureProvider, BLOKLUYOR
ref.watch(worldSyncAutoSubscribeProvider);   // ← çağrıldığında activeCampaignIdProvider'i bekliyor
```

`MainScreen.build()` her tab değişiminde çağrılır (`_tabIndex` setState'i). Build yukarıdaki iki `ref.watch`'a girer:

- **`activeCampaignSyncProvider`** ([package_provider.dart:48-123](../lib/application/providers/package_provider.dart#L48)) bir `FutureProvider<int>`. İçeride:
  - `srdCorePackageBootstrapProvider.future` await
  - `activeCampaignProvider` read
  - `installedPackageDao.listForCampaign(...)` DB sorgusu × 2
  - Orphan migration loop + `installedPackageDao.upsert` per orphan
  - `tier0Index` build için tüm Tier-0 entity'leri fetch
  - `PackageSyncService.sync(...)` her installed paket için (potansiyel N ağ + DB çağrısı)
  - `notifier.reload()` (full campaign disk reload)

- **`worldSyncAutoSubscribeProvider`** ([world_mirror_provider.dart:35-51](../lib/application/providers/world_mirror_provider.dart#L35)) `activeCampaignIdProvider` (FutureProvider) await ediyor → `applyInitialState(campaignId)` çağırıyor (remote snapshot → local seed, async).

### Niye Tab Kasıyor

Riverpod `ref.watch` bir `FutureProvider`a girerse build'i suspend etmez gerçekten, ama bu provider'lar **`Provider`/`FutureProvider` karışımı**. Build sırasında `ref.watch(activeCampaignSyncProvider)` Future state'ini izler — initial state `AsyncLoading`, sonradan `AsyncData`. Sorun: provider invalidate/restart tetiklendiğinde (campaign switch, paket yükleme) provider'in dependency'leri zincirleme bütün hub'ı tutuyor. Aktif fetch bittiğinde `ref.watch` sonucu değişiyor → MainScreen rebuild → tab body builders yeniden iniyor.

Asıl darboğaz: tab switch → setState → build → provider zinciri reevaluate → yeni `AsyncLoading` → build content boşalmıyor ama internal IndexedStack'in yeniden mount/dispose döngüsü tetiklenebiliyor (Lazy guard'lar varsa o da invalidate oluyor).

### Fix — F-T1: Cloud Sync'i Tab Path'inden Çıkar

**Adım 1**: `activeCampaignSyncProvider` `ref.watch`'ten `ref.listen`'a düş. Build sonucunu etkilemiyor; sadece side-effect olarak çalışsın.

```dart
@override
Widget build(BuildContext context) {
  final l10n = L10n.of(context)!;
  final palette = Theme.of(context).extension<DmToolColors>()!;
  final campaignName = ref.read(activeCampaignProvider) ?? '';

  // Side-effect only — build her döndüğünde provider'ı tetikler ama
  // suspend ETMEZ. Tab geçişi cloud sync bitmesini beklemez.
  ref.listen(activeCampaignSyncProvider, (_, _) {});
  ref.listen(worldSyncAutoSubscribeProvider, (_, _) {});
  ...
}
```

`ref.listen` provider'ı subscribe eder ama build sırasında onun state'ine bakmaz; bu yüzden provider'in `AsyncLoading → AsyncData` geçişi MainScreen'i rebuild etmez. Tab body builders tek seferde mount edilir.

**Adım 2**: `activeCampaignSyncProvider` içinde "fast path" guard ekle — eğer hiç orphan ve install yoksa, hiçbir sync çalıştırma:

```dart
final activeCampaignSyncProvider = FutureProvider<int>((ref) async {
  await ref.watch(srdCorePackageBootstrapProvider.future);
  final campaign = ref.watch(activeCampaignProvider);
  if (campaign == null) return 0;
  final db = ref.read(appDatabaseProvider);
  final notifier = ref.read(activeCampaignProvider.notifier);
  final campaignId = notifier.data?['world_id'] as String?;
  if (campaignId == null) return 0;

  // FAST PATH: hızlı varlık kontrolü — installed list boşsa ve orphan
  // entity yoksa, hiçbir sync yapma. 99% session bu path'i izleyecek.
  final installedNow =
      await db.installedPackageDao.listForCampaign(campaignId);
  if (installedNow.isEmpty) {
    // Orphan tarama hala lazım ama O(1) hızlı sorgu — bir entity bile
    // packageId not null ise gerçek path'e in.
    final hasOrphan = await (db.select(db.entities)
          ..where((t) =>
              t.campaignId.equals(campaignId) & t.packageId.isNotNull())
          ..limit(1))
        .get();
    if (hasOrphan.isEmpty) return 0;
  }
  // … existing slow path …
});
```

**Adım 3**: `applyInitialState`'i fire-and-forget kıl. `worldSyncAutoSubscribeProvider` zaten void provider — sadece subscribe + initial state. Initial state'i `unawaited` ile arka plana at:

```dart
final worldSyncAutoSubscribeProvider = Provider<void>((ref) {
  final svc = ref.watch(worldSyncServiceProvider);
  if (svc == null) return;
  final applier = ref.watch(worldMirrorApplierProvider);
  final campaignId = ref.watch(activeCampaignIdProvider).valueOrNull;
  final role =
      ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;

  if (campaignId == null || role == WorldRole.none) {
    unawaited(svc.unsubscribeAll());
    return;
  }
  if (!svc.isSubscribed(campaignId)) {
    unawaited(svc.subscribe(campaignId));
    // applyInitialState arka planda — UI'yi blok etmez. Drift'e mirror
    // satırları geldikçe entity_provider notifier'ları tetiklenir.
    if (applier != null) {
      unawaited(applier.applyInitialState(campaignId));
    }
  }
});
```

**Adım 4 (UI feedback)**: Cloud sync devam ederken topbar / tab corner'a küçük spinner. `activeCampaignSyncProvider.select((s) => s.isLoading)` ile granular watch:

```dart
final cloudBusy = ref.watch(
  activeCampaignSyncProvider.select((s) => s.isLoading),
);
// AppBar action'lara `if (cloudBusy) const _MiniSpinner()` ekle.
```

**Effort**: M | **Impact**: A+ (kullanıcının doğrudan şikayeti)

---

## 2. Database Arama Klavyesi Yavaş

### Tespit

**Dosya**: [entity_sidebar.dart:158-173](../lib/presentation/widgets/entity_sidebar.dart#L158) + filter loop [225-294](../lib/presentation/widgets/entity_sidebar.dart#L225)

Search TextField sol sidebar içinde. Kullanıcı tap edince klavye açılmaya çalışır → MediaQuery.viewInsets değişir → Scaffold relayout → sidebar rebuild → bu rebuild sırasında **~7000 entity'lik tuple list materialize ediliyor**.

```dart
final summaries = ref.watch(
  visibleEntityProvider.select(
    (map) => map.values
        .map((e) => (
              id: e.id, name: e.name, categorySlug: e.categorySlug,
              source: e.source, tags: e.tags, packageId: e.packageId,
              linked: e.linked,
            ))
        .toList(),
  ),
);
```

**Sorun**: `.select(...)` her invocation'da **yeni bir List** allocate ediyor. Riverpod default `==` ile karşılaştırır; `List` value equality yok → her zaman farklı sayar → rebuild her zaman tetiklenir. `.select` burada faydasız. 7000 record allocate + iterate her klavye event'inde.

Devamında [225-294](../lib/presentation/widgets/entity_sidebar.dart#L225) filter+search+sort pass'leri build içinde inline çalışıyor — yine 7K iter per rebuild.

### Niye Klavye Geç Açılıyor

Android klavye animasyonu ~150–250 ms. Her frame Flutter UI thread'i meşgulse animasyon stutter eder. Search field'a focus → ilk insertion → her viewInsets değişimi (kademe kademe geliyor klavye) → Scaffold relayout → sidebar rebuild → 7K entity iter → frame skip → klavye animasyonu beklemeye girer.

### Fix — F-T2.a: Summaries'i Memoize Et (Provider Tarafında)

`visibleEntityProvider`'in yanına bir **sidebar summary provider** koy. Sadece entity map shape değiştiğinde rebuild olsun, içerik aynıysa aynı liste referansı dönsün.

```dart
// lib/application/providers/entity_sidebar_provider.dart (yeni)
class _EntitySummary {
  final String id, name, categorySlug, source;
  final List<String> tags;
  final String? packageId;
  final bool linked;
  const _EntitySummary({
    required this.id, required this.name, required this.categorySlug,
    required this.source, required this.tags, required this.packageId,
    required this.linked,
  });
}

final entitySummaryListProvider = Provider<List<_EntitySummary>>((ref) {
  final map = ref.watch(visibleEntityProvider);
  return [
    for (final e in map.values)
      _EntitySummary(
        id: e.id, name: e.name, categorySlug: e.categorySlug,
        source: e.source, tags: e.tags, packageId: e.packageId,
        linked: e.linked,
      ),
  ];
});
```

Bu provider'ı sidebar `ref.watch` etsin — referans değişmediği sürece (entity map identity aynı) yeniden hesaplanmaz.

### Fix — F-T2.b: Filter+Sort'u Build Dışına Çıkar

Filter/sort/search pass'leri pure fonksiyon — `useMemoized` benzeri pattern lazım. `flutter_hooks` yoksa state field cache yeterli:

```dart
List<_EntitySummary>? _filteredCache;
int _filterSig = 0; // selectedSlugs + sources + shareModes + searchQuery hash

List<_EntitySummary> _computeFiltered(List<_EntitySummary> summaries) {
  final sig = Object.hash(
    Object.hashAll(_selectedSlugs),
    Object.hashAll(_selectedSources),
    Object.hashAll(_selectedShareModes),
    _searchQuery, _sortMode, summaries.length,
  );
  if (_filteredCache != null && sig == _filterSig) return _filteredCache!;
  // … filter+sort pass …
  _filterSig = sig;
  _filteredCache = result;
  return result;
}
```

Build'de `_computeFiltered(summaries)` çağır. Klavye viewInsets her değiştiğinde rebuild olsa bile cache hit edip 0ms döner.

### Fix — F-T2.c: Search Field'i Sidebar'dan Çıkar (opsiyonel ama büyük kazanç)

Database screen üst bar'a search field'i taşı. Sidebar'ın layout'una bağlı olmasın. Klavye açılması Scaffold ana iskeletini relayout eder ama 7K entity list rebuild'ini tetiklemez.

### Fix — F-T2.d: SliverList + AutomaticKeepAlive

Sidebar `ListView.builder` zaten kullanıyor ama içindeki tile state'lerini KeepAlive ile ayağa tut. Ekstra: `cacheExtent: 0` yaparak viewport dışı build'leri kes.

**Effort**: M (a+b kritik, c opsiyonel) | **Impact**: A

---

## 3. Karakter Kartı (Editor) Kasıyor

### Tespit

**Dosya**: [character_editor_screen.dart:2108-2119](../lib/presentation/screens/characters/character_editor_screen.dart#L2108)

```dart
Map<String, Entity> _readEntitiesFor(Character character) {
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  if (character.worldId == null) return builtin;
  final activeWorldId = ref.watch(activeCampaignIdProvider).valueOrNull;
  if (activeWorldId != character.worldId) return builtin;
  final campaign = ref.watch(entityProvider);   // ← FULL MAP WATCH
  if (campaign.isEmpty) return builtin;
  return UnmodifiableMapView<String, Entity>(
    CombinedMapView<String, Entity>([campaign, builtin]),
  );
}
```

`_readEntitiesFor` her `_fieldTile` build'inde çağrılıyor (~20 field × build). Her çağrı `ref.watch(entityProvider)` (campaign'in tüm entity map'i) → herhangi bir entity değişiminde **tüm field tile'lar** rebuild oluyor.

**Daha kötü**: birden çok `ref.watch` per field çağrılınca (line 204, 216, 871, 2109, 2114), tek bir keystroke 40+ provider subscription rebuild kaskadını tetikliyor.

### Fix — F-T3.a: Entities'i Bir Kere Oku, Aşağıya Geçir

```dart
@override
Widget build(BuildContext context) {
  final character = ref.watch(characterByIdProvider(widget.characterId));
  // … existing setup …

  // ONE-SHOT: build'in en üstünde tek `ref.watch`. Aşağıdaki tüm field
  // tile builder'lar bu map'i parametre olarak alır.
  final entities = _readEntitiesFor(character);
  final templates = ref.watch(allTemplatesProvider);

  return _buildBody(context, character, entities, templates);
}

// _fieldTile(...) signature'una `Map<String, Entity> entities` eklendi.
```

### Fix — F-T3.b: `_readEntitiesFor`'da `entityProvider.select`

Çoğu field tile sadece "bu spesifik entity id'yi" arar. Full map'i `watch` etmek aşırı geniş. Hot field tile'lar için `entityProvider.select((m) => m[id])` kullan; sadece o entity değişince rebuild olsun.

Veya: `_readEntitiesFor` global rebuild trigger'ı `entityProvider.select((m) => m.length)` ile sınırla — sadece ekleme/silmede rebuild olsun. Map identity check yetersiz çünkü içerik mutate olabilir; ama length stable bir invariant.

```dart
Map<String, Entity> _readEntitiesFor(Character character) {
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  if (character.worldId == null) return builtin;
  final activeWorldId = ref.watch(activeCampaignIdProvider).valueOrNull;
  if (activeWorldId != character.worldId) return builtin;
  // Sadece add/remove'da rebuild (length değişimi). Field-level edit
  // bu helper'ı tetiklemez; field tile içinde gerekirse spesifik id
  // için select edilir.
  ref.watch(entityProvider.select((m) => m.length));
  final campaign = ref.read(entityProvider);
  if (campaign.isEmpty) return builtin;
  return UnmodifiableMapView<String, Entity>(
    CombinedMapView<String, Entity>([campaign, builtin]),
  );
}
```

**Trade-off**: Linked entity'lerin alanları değiştiğinde editor görünür eski değeri tutacak. Eğer hot reload gerekiyorsa ilgili field tile'da `ref.watch(entityProvider.select((m) => m[linkedId]))` ile per-tile incremental subscribe.

### Fix — F-T3.c: Tab'ları Lazy Yap

Editor'da sheet tabları DefaultTabController + TabBarView mı kullanıyor? TabBarView default'ta visible olmayan tab'ı build etmez, ama child Riverpod listener'ları offstage'da bile invalidate'e yanıt verir. Eğer eager construct varsa, `LazyIndexedStack` ile değiştir veya tab content'i `AutomaticKeepAliveClientMixin`'siz tut.

### Fix — F-T3.d: ConstrainedBox Mobile Breakpoint

[character_editor_screen.dart:508-509](../lib/presentation/screens/characters/character_editor_screen.dart#L508) — `BoxConstraints(maxWidth: 760)` hard-coded. 600px ekranda content yatay sıkışıyor → multi-pass layout. `LayoutBuilder` ile mobile single-column:

```dart
LayoutBuilder(builder: (ctx, c) {
  final isPhone = c.maxWidth < 600;
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: isPhone ? c.maxWidth : 760),
    child: isPhone ? _phoneColumnLayout() : _wideLayout(),
  );
});
```

### Fix — F-T3.e: Undo/Save Timer Coalesce

[character_editor_screen.dart:131](../lib/presentation/screens/characters/character_editor_screen.dart#L131) (400ms undo idle) + [194](../lib/presentation/screens/characters/character_editor_screen.dart#L194) (1.2s autosave) — her keystroke iki timer reset eder. 400ms idle'da `setState(() {})` çağrılırsa ([140](../lib/presentation/screens/characters/character_editor_screen.dart#L140)) full editor rebuild. Çözüm:

```dart
// Undo snapshot için setState gerekmez — sadece undo stack'i push.
// UI'in undo butonu zaten Riverpod provider üzerinden state izliyorsa
// setState gereksiz. Eğer button enable/disable lokal state ise
// ValueNotifier'a çevir; sadece o widget rebuild olsun.
```

**Effort**: M (a kritik + d kritik mobile, b/c/e iteratif) | **Impact**: A

---

## Faz Planı

### Acil (1 gün) — Kullanıcının doğrudan şikayetleri
- [ ] **F-T1**: `MainScreen` cloud sync `ref.watch` → `ref.listen`, applyInitialState `unawaited`, fast-path guard
- [ ] **F-T3.a**: `_readEntitiesFor` build üstüne çıkar + entities param olarak geçir
- [ ] **F-T2.a**: `entitySummaryListProvider` ekle, sidebar bu provider'ı watch etsin

### Hafta içi
- [ ] **F-T2.b**: Sidebar filter+sort memoize (state cache)
- [ ] **F-T3.b**: `entityProvider.select((m) => m.length)` veya per-id select
- [ ] **F-T3.d**: Char editor mobile LayoutBuilder
- [ ] **F-T1 UI**: AppBar cloud-busy mini spinner

### Sonra
- [ ] **F-T2.c**: Search field'i sidebar'dan üst bar'a taşı
- [ ] **F-T2.d**: Sidebar ListView cacheExtent + KeepAlive
- [ ] **F-T3.c**: Editor tab'lar lazy
- [ ] **F-T3.e**: Undo timer ValueNotifier'a çevir

---

## Ölçüm

Her fix öncesi/sonrası:

1. **Tab switch latency**: `flutter run --profile`, DevTools Timeline → tap from tab1 to tab2, measure "Build" + "Layout" frame budget. Hedef < 50 ms.
2. **Keyboard open latency**: Android `adb shell dumpsys input_method` veya manual stopwatch (focus → klavye fully visible). Hedef < 200 ms.
3. **Char editor field typing**: TextField'a hızlı yaz, jank frames sayısı DevTools Performance > "Frame Times". Hedef 0 dropped frame at 60 fps.
4. **Cloud sync impact**: F-T1 sonrası tab switch latency cloud-busy state'inde de aynı kalmalı (artık blok etmiyor).

---

## Tek Satır Aksiyonlar

```
F-T1   main_screen.dart:389-392 — ref.watch → ref.listen + applyInitialState unawaited + fast-path
F-T2.a entity_sidebar_provider.dart (yeni) — entitySummaryListProvider memoized
F-T2.b entity_sidebar.dart — _computeFiltered cached (sig hash)
F-T2.c database_screen.dart — search field topbar'a taşı
F-T2.d entity_sidebar.dart — ListView cacheExtent + KeepAlive
F-T3.a character_editor_screen.dart — entities param top-of-build
F-T3.b character_editor_screen.dart:2108 — entityProvider.select((m) => m.length)
F-T3.c character_editor_screen.dart — sheet tabs lazy
F-T3.d character_editor_screen.dart:508 — LayoutBuilder mobile breakpoint
F-T3.e character_editor_screen.dart:131,194 — undo timer ValueNotifier
```
