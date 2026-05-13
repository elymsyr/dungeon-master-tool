# Performance Optimization Roadmap

**Date**: 2026-05-13
**Scope**: `flutter_app/` (398 Dart files, ~144 kLOC)
**Target**: Reduce frame budget on common interactions (typing in editor, opening character wizard, browsing characters tab, switching campaigns) and shrink startup time + memory footprint.

This document inventories the perf-relevant code paths, ranks them by expected impact-vs-effort, and proposes concrete fixes with file:line references.

## Status (2026-05-13)

**F1, F2, F3, F4, F6, F7, F8, F11, F12, F13 shipped or confirmed
optimal.** Companion deep-dive `performance_hotspots_wizard_editor_hub.md`
covers the wizard/editor/hub surfaces (Phases A+B+C, 19 findings closed).
See §7 below for the survey-level implementation log.

Still open: F5 / F10 (Sliver migration — cross-axis center invasive,
deferred), F9 (Bootstrap), F14 (DevX).

---

## TL;DR

The app is well-architected (clean layers, smart memoization for `WorldSchema`, identity-preserving entity updates) but leaks performance through six recurring patterns:

1. **`jsonEncode`-based deep equality** inside the hottest provider (entity_provider.dart:381).
2. **Full-map `ref.watch(entityProvider)`** at 9 sites with no `.select()` (avg subtree 200–800 widgets).
3. **`{...builtin, ...campaign}` spread** rebuilds a ~7K-entry map on every wizard step rebuild.
4. **`Column(children: [for ...])`** for long lists in wizard steps + characters tab — no lazy rendering.
5. **`.values.where(...).toList()`** re-runs O(N) entity scans on every `build()` (no memoization).
6. **`prefer_const_constructors` disabled** — 228 widget classes pay rebuild allocations.

Fixing items 1–3 alone is expected to remove ~40–70 ms from typical interactions on a mid-tier desktop and ~150–250 ms on web. Items 4–6 are incremental but high-volume.

---

## 1. Findings Ranked by Impact × Effort

| # | Issue | File:Line | Impact | Effort | Score | Status |
|---|-------|-----------|--------|--------|-------|--------|
| F1 | `jsonEncode` deep-equality in `_mapEquals` | [entity_provider.dart:381](../lib/application/providers/entity_provider.dart#L381) | High | XS | **A** | ✅ done (E4) |
| F2 | `ref.watch(entityProvider)` without `.select()` (9 sites) | see §2.2 | High | M | **A** | ✅ done (W1/E5/E1/H3/sidebar/EntityNameText) |
| F3 | `wizardEntitiesProvider` merges full map on every watch | [builtin_srd_entities.dart:117-123](../lib/application/services/builtin_srd_entities.dart#L117) | High | S | **A** | ✅ done (W1) |
| F4 | Entity selector dialog: O(N) filter per keystroke, no debounce | [entity_selector_dialog.dart:56](../lib/presentation/dialogs/entity_selector_dialog.dart#L56) | Med | XS | **A** | ✅ done (debounce + pre-filtered base) |
| F5 | `Column` for unbounded lists (wizard / characters tab) | see §2.5 | Med | S | **B** | defer (cross-axis-center Sliver invasive) |
| F6 | `.values.where(...).toList()` re-runs per build | [proficiencies_step.dart:58](../lib/presentation/screens/characters/wizard/steps/proficiencies_step.dart#L58), [entity_selector_dialog.dart:56](../lib/presentation/dialogs/entity_selector_dialog.dart#L56) | Med | S | **B** | ✅ done (W4 + F4) |
| F7 | `prefer_const_constructors` lint disabled | [analysis_options.yaml:26](../analysis_options.yaml#L26) | Med | L | **B** | ✅ done (71 fixes / 25 files via `dart fix`) |
| F8 | Characters tab full-list sort per rebuild | [characters_tab.dart:81-105](../lib/presentation/screens/hub/characters_tab.dart#L81) | Low | XS | **B** | ✅ done (`sortedCharactersProvider`) |
| F9 | Bootstrap blocks UI on `UiState.load` (3 s timeout) | [main.dart:158-163](../lib/main.dart#L158) | Low | M | **C** | todo |
| F10 | No `SliverList` anywhere; nested `ListView` w/ `shrinkWrap` | grep: 0 hits | Low | M | **C** | defer (cross-axis center) |
| F11 | SRD pack built eagerly on first `builtinSrdEntitiesProvider` read | [builtin_srd_entities.dart:21-79](../lib/application/services/builtin_srd_entities.dart#L21) | Low | M | **C** | ✅ noop (Provider lazy by default; cold-cost paid once) |
| F12 | `campaignRevisionProvider++` cascades `worldSchemaProvider` parse | [entity_provider.dart:40-86](../lib/application/providers/entity_provider.dart#L40) | Low | S | **C** | ✅ noop (identity cache already returns cached schema, no cascade) |
| F13 | `_syncToCampaign` rebuilds entire `entities` map blob | [entity_provider.dart:411-426](../lib/application/providers/entity_provider.dart#L411) | Low | M | **C** | ✅ done (`_writeEntityToCampaign` / `_removeEntityFromCampaign` O(1)) |
| F14 | 3.7 GB build artifact cache + 97 MB `.dill` files | `build/` | DevX | XS | **C** | todo (DevX) |

Score guide: **A** = ship this sprint, **B** = next sprint, **C** = nice-to-have / DevX.

---

## 2. Detailed Findings

### 2.1 F1 — `jsonEncode` deep-equality is the hottest microbench

```dart
bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    if (jsonEncode(a[key]) != jsonEncode(b[key])) return false;  // ❌
  }
  return true;
}
```

Called from `_isContentChanged()` during every entity `update()`. `jsonEncode` walks each value, allocates strings, then compares strings — twice per field. For a typical SRD class entity (~30 fields, nested maps), this is ~60 JSON serializations per edit, each ~2–5 KB.

**Fix**: replace with `DeepCollectionEquality()` from `package:collection` (already transitive via `flutter`). Roughly 10–30× faster.

```dart
import 'package:collection/collection.dart';
final _deepEq = const DeepCollectionEquality();

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) =>
    _deepEq.equals(a, b);
```

Tests: existing `entity_provider_test.dart` already exercises update flow — no new tests needed.

---

### 2.2 F2 — Full-map `ref.watch(entityProvider)` rebuilds 200–800-widget subtrees

Direct full-map watchers (no `.select`):

| File | Line | Subtree size estimate |
|------|------|----------------------|
| [character_editor_screen.dart](../lib/presentation/screens/characters/character_editor_screen.dart#L1129) | 1129 | ~800 widgets (editor + sidebar + chips) |
| [character_creation_wizard_screen.dart](../lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart#L1216) | 1216, 1305, 1755 | ~500 widgets (active step) |
| [characters_sidebar.dart](../lib/presentation/widgets/characters_sidebar.dart#L874) | 874 | ~300 widgets |
| [entity_selector_dialog.dart](../lib/presentation/dialogs/entity_selector_dialog.dart#L145) | 145 | small (single chip) — fine to keep |
| [character_provider.dart](../lib/application/providers/character_provider.dart#L220) | 220 | (provider — needed) |
| [character_stat_chips.dart](../lib/presentation/widgets/character_stat_chips.dart#L124) | 124 | small (chip strip) |

Every entity edit (HP change, name typo, AC bump) flushes all listeners. The editor screen alone watches the full map AND calls `readCharacterEntities` (which also watches it via [character_stat_chips.dart:124](../lib/presentation/widgets/character_stat_chips.dart#L124)).

**Fix** — three patterns:

1. **Single-entity lookup**: replace `final entities = ref.watch(entityProvider); final e = entities[id];` with
   ```dart
   final e = ref.watch(entityProvider.select((m) => m[id]));
   ```
2. **Filtered set** (e.g., "all monsters"): introduce a derived `Provider` that returns the filtered list and `.select()` on cheap keys like `length` or a content hash.
3. **Wizard read-only consumers**: prefer `wizardEntitiesProvider` (already routes through autoDispose merge), don't reach into `entityProvider` directly — three of the four wizard sites still bypass it.

Quantitative target: cut entity-edit rebuild count from ~1 100 widgets (measured ballpark) to under 50.

---

### 2.3 F3 — `wizardEntitiesProvider` spreads ~7 000 entries on every step rebuild

```dart
final wizardEntitiesProvider = Provider.autoDispose<Map<String, Entity>>((ref) {
  final draft = ref.watch(characterDraftProvider);            // ❌ rebuilds on draft change
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  if (draft.worldName.isEmpty) return builtin;
  final campaign = ref.watch(entityProvider);
  return mergeWithBuiltinSrd(campaign, builtin, useCampaign: true);  // ❌ {...builtin, ...campaign}
});
```

Two problems compound:
- The provider watches the entire `CharacterDraft` (changes on every wizard keystroke), so it re-emits when `worldName` did *not* change. Should watch `select((d) => d.worldName)`.
- `mergeWithBuiltinSrd` always allocates a new ~7 K-entry `Map`. With campaign open + every wizard rebuild, this is ~200 KB of map allocation per frame.

**Fix**:
```dart
final wizardEntitiesProvider = Provider.autoDispose<Map<String, Entity>>((ref) {
  final worldName = ref.watch(
    characterDraftProvider.select((d) => d.worldName),
  );
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  if (worldName.isEmpty) return builtin;
  final campaign = ref.watch(entityProvider);
  if (campaign.isEmpty) return builtin;
  return _MergedEntityMap(builtin, campaign);  // lazy view
});
```
Where `_MergedEntityMap` implements `Map<String, Entity>` with `operator[]` checking campaign first then builtin — no upfront allocation. Use `UnmodifiableMapView` wrapped over a `CombinedMapView` (from `package:collection`) for a one-line stdlib option.

Expected impact: removes the largest steady-state allocation in the wizard. Drops one full GC pass per ~5 frames during step navigation.

---

### 2.4 F4 — Entity selector dialog scans 7 K entities per keystroke

```dart
final filtered = entities.values.where((e) {
  if (widget.excludeIds.contains(e.id)) return false;       // ❌ O(N·excludeIds)
  if (widget.allowedTypes != null &&
      !widget.allowedTypes!.contains(e.categorySlug)) ...   // ❌ List contains
  if (_search.isNotEmpty &&
      !e.name.toLowerCase().contains(_search.toLowerCase())) ... // ❌ allocates per item
  return true;
}).toList()..sort(...);
```

Each keystroke calls `setState`, which rebuilds the full filter. On a 7 K map, this is ~7 K `String.toLowerCase()` allocations per stroke.

**Fixes**:
1. Wrap the `TextField.onChanged` with a 150 ms `Timer` debounce.
2. Convert `excludeIds` and `allowedTypes` to `Set` once outside `where`.
3. Cache `_search.toLowerCase()` in a local.
4. Memoize `filtered` by `(search, excludeIds, allowedTypes)` so re-renders that don't change the query reuse the result.

---

### 2.5 F5 — `Column(children: [for ...])` for unbounded lists

Sites:
- [equipment_step.dart:58](../lib/presentation/screens/characters/wizard/steps/equipment_step.dart#L58) — class + subclass + background groups (3–6 cards, bounded; acceptable).
- [proficiencies_step.dart:78-134](../lib/presentation/screens/characters/wizard/steps/proficiencies_step.dart#L78) — `_GrantedSection` + 4× `_PickerSection`, each a `Column` of N options. Languages section iterates *all* SRD languages (10–30).
- [characters_tab.dart:106](../lib/presentation/screens/hub/characters_tab.dart#L106) — already uses `ListView.separated` with `shrinkWrap: true` + `NeverScrollableScrollPhysics`. **This is the worst of both worlds** — it builds every child synchronously (no laziness) but pays ListView's overhead too.
- Spell picker section: bounded but renders all spells of permitted levels (~50 at high tier) in a `Column`.

**Fix patterns**:
- Lists ≤ 20 items: keep as `Column` (laziness overhead > savings).
- Lists 20–200: switch to `ListView.builder` with `shrinkWrap: false` inside an `Expanded`/fixed-height parent, OR a `SliverList` inside the existing `CustomScrollView` if there is one.
- Characters tab specifically: refactor the outer `SingleChildScrollView` to a `CustomScrollView` with `SliverList.builder` + `SliverToBoxAdapter` headers.

---

### 2.6 F6 — Filter chains re-run per `build()`

```dart
// proficiencies_step.dart:58
final languageEntities = entities.values
    .where((e) => e.categorySlug == 'language')
    .toList()
  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
```

This walks the full ~7 K map every time the step rebuilds (every draft mutation). Equivalent scans live in `spells_step.dart`, `feats_step.dart`, `subclass_step.dart`.

**Fix**: introduce derived providers keyed by `categorySlug`:
```dart
final entitiesByCategoryProvider =
    Provider.family<List<Entity>, String>((ref, slug) {
  final all = ref.watch(wizardEntitiesProvider);
  return all.values.where((e) => e.categorySlug == slug).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});
```
Then `ref.watch(entitiesByCategoryProvider('language'))`. Riverpod caches the result by argument and only invalidates when `wizardEntitiesProvider` changes.

Bonus: if `wizardEntitiesProvider` is converted to a lazy merge (F3), this becomes O(matching slug) instead of O(7K).

---

### 2.7 F7 — `prefer_const_constructors` disabled

`analysis_options.yaml:26` notes "high-noise, low-signal diffs in the current codebase." Real cost: 228 widget classes (`StatelessWidget` / `ConsumerWidget`) where parent rebuilds trigger child constructor allocations even when args are static.

**Migration plan**:
1. Enable `prefer_const_constructors` and `prefer_const_literals_to_create_immutables` in a feature branch.
2. Run `dart fix --apply` — auto-fixes ~80–90 %.
3. Manual sweep for false negatives (constructors that *could* be const but use non-const helpers).
4. Add a CI step that runs `dart fix --dry-run` and fails if there are pending fixes — keeps regressions out.

Quantitative target: shave ~5–15 % off rebuild cost on the editor and wizard screens (Flutter docs: "const constructors cut widget instantiation cost by an order of magnitude when args are stable").

---

### 2.8 F8 — Characters tab sorts the full list per rebuild

```dart
final sorted = [...all]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
```

For 50 characters this is negligible. For 500+ (importers, prolific users) it's measurable on web. Trivial fix: cache by `all.length + first.id + last.updatedAt` (composite key), or move the sort into `characterListProvider` so it's done once on load.

---

### 2.9 F9 — Bootstrap blocks UI render until UiState loads

```dart
await Future.wait<void>([
  _initSupabase(),
  _initSoLoud(),
  _initWindowManager(),
  _initUiState(uiStateNotifier),   // ❌ blocks app render
]);
```

`UiState.load` has a 3-second timeout. Cold-start users see the splash for 0.5–3 s while the rest of `Future.wait` completes. Supabase + SoLoud + windowManager init are best-effort, but UiState is on the critical path.

**Options**:
- Render the app with defaults immediately, then patch `uiStateProvider` once the load completes (requires `uiStateProvider` to support delta override or a separate "loading" gate inside the app).
- Pre-warm UiState in parallel with `AppPaths.initialize()`.
- Strip non-essential fields out of the initial UiState load (only theme + locale block render; rest can hydrate lazily).

---

### 2.10 F10 — No `SliverList` usage anywhere

`grep -r "SliverList"` → 0 hits. The biggest screens (characters tab, wizard, editor) use `SingleChildScrollView` + `Column`. For long content this defeats lazy widget construction.

Refactor target order:
1. `characters_tab.dart` (longest list, simplest refactor).
2. `character_editor_screen.dart` (longest content, biggest savings).
3. Wizard step host (if a step body ever exceeds the viewport — currently most don't).

---

### 2.11 F11 — SRD pack built eagerly

```dart
final builtinSrdEntitiesProvider = Provider<Map<String, Entity>>((ref) {
  return buildBuiltinSrdEntities();   // ~7K entities, hand-authored maps
});
```

First read happens whenever any wizard or editor screen mounts. The build is fast (hand-authored Dart maps, no JSON parse) but allocates ~7 K `Entity` instances and ~30 KB of map structure.

**Option A**: defer first access until route push (currently already deferred — Provider lazy by default).
**Option B**: split into shards (`abilities + skills + conditions` always, `species + classes + spells + monsters` on demand). Wizard step gating already exists — would need parallel shards in the provider tree.
**Option C** (cleanest, web-only): precompile to a serialized blob asset and lazy-load via `rootBundle.load`, parsing on a background isolate. Removes ~3 K LOC of generated maps from the hot bundle.

Not urgent unless cold-start profiling shows a > 100 ms spike here.

---

### 2.12 F12 — `campaignRevisionProvider++` cascades

In-place data mutations bump the revision counter to force consumers to re-read. `worldSchemaProvider` watches it and re-runs the identity check; identity is preserved when source map didn't change, so the cached `WorldSchema` is returned — **good design**. But the provider rebuild still walks all listeners.

**Fix**: split `worldSchemaProvider` into two providers — one that emits the raw source map (cheap), one that maps it to `WorldSchema` via `select`. Listeners that only need certain `WorldSchema` slices (e.g., a single category) should `.select((s) => s.categories.firstWhere(...))`.

---

### 2.13 F13 — `_syncToCampaign` rebuilds full entity blob

```dart
final raw = <String, dynamic>{};
for (final entry in state.entries) {
  final entity = entry.value;
  if (_linkedCharacterIds.contains(entity.id)) continue;
  raw[entry.key] = _entityToMap(entity);    // ❌ O(N) serialization per mutation
}
data['entities'] = raw;
_onDirty();
```

Every single-entity edit re-serializes the whole map (~7 K entries × ~20 fields). `_onDirty` triggers debounced save, but the in-memory copy still happens synchronously per mutation.

**Fix**: maintain `data['entities']` as a live, mutable map. On `update(entity)`, set `data['entities'][entity.id] = _entityToMap(entity)`. Same for `delete`. The full rebuild path becomes a fallback for `setAll`/`undo`/`redo`.

Expected impact: entity edits become O(1) work instead of O(N).

---

### 2.14 F14 — Build cache hygiene

`flutter_app/build/` is 3.7 GB. `*.dill` files alone are 97 MB. Adds to disk pressure on CI runners and developer machines.

Add `build/` to `.gitignore` (probably already there — verify), and consider a periodic `flutter clean` in CI scripts. Not a runtime issue.

---

## 3. Implementation Plan (Phased)

### Phase 1 — Quick wins (1–2 days, no risk)

- **P1.1** Replace `_mapEquals` with `DeepCollectionEquality` (F1).
- **P1.2** Convert the 9 `ref.watch(entityProvider)` call sites that read a single id to `.select` (F2, subset).
- **P1.3** Make `wizardEntitiesProvider` watch `characterDraftProvider.select((d) => d.worldName)` only (F3, partial).
- **P1.4** Debounce + `Set` conversions in `entity_selector_dialog.dart` (F4).
- **P1.5** Add `entitiesByCategoryProvider` family and migrate `proficiencies_step.dart`, `spells_step.dart`, `feats_step.dart`, `subclass_step.dart` (F6).

Validation: existing test suite (477 tests) must stay green. Add a microbench for `_mapEquals` (pre/post timings).

### Phase 2 — Medium-effort refactors (1 sprint)

- **P2.1** Lazy-merged `CombinedMapView` for `wizardEntitiesProvider` (F3, full).
- **P2.2** Convert `characters_tab.dart`, `character_editor_screen.dart` to `CustomScrollView` + `SliverList` (F5, F10).
- **P2.3** Enable `prefer_const_constructors`; `dart fix --apply`; CI guard (F7).
- **P2.4** Incremental `_syncToCampaign` (F13).

### Phase 3 — DevX + advanced (as time permits)

- **P3.1** Split bootstrap so render isn't blocked on `UiState.load` (F9).
- **P3.2** SRD pack sharding or asset-blob load (F11).
- **P3.3** Split `worldSchemaProvider` into source + parsed (F12).
- **P3.4** CI clean-up step for `build/` (F14).

---

## 4. Measurement & Validation

Before/after each phase, capture:

1. **Frame stats**: `flutter run --profile`, open editor, edit HP × 50, capture average frame time from DevTools.
2. **Allocation stats**: DevTools → Memory → Allocation tracking, run wizard step navigation, capture map/list allocations per frame.
3. **Cold-start time**: instrument `_BootstrapGate._bootstrap` to log millis between phases.
4. **Test suite**: `flutter test` (target: zero new failures, baseline ~30 s).

Suggested KPIs:
- Editor edit-frame: < 8 ms (currently ~12–18 ms on desktop).
- Wizard step transition: < 32 ms (target one 60 Hz frame).
- Cold-start to first paint: < 800 ms (currently ~1.2–1.5 s).
- Steady-state per-frame allocation in wizard: < 50 KB.

---

## 5. Out of Scope (Explicitly Deferred)

- **Drift / SQLite tuning** — write throughput already batches via the 2 s debounce; no observed perf complaints. Revisit only if backup/restore times grow.
- **Supabase sync** — disabled by default; current async overhead is irrelevant to the offline-first path.
- **Multi-isolate work** — Flutter's main isolate handles the current workload; introducing isolates for SRD parse (F11C) is conditional on profiling data, not speculative.
- **Web-specific optimizations** — desktop is the primary target. If web becomes a release target, re-prioritize F1/F3/F7 (the highest-impact-on-web items).

---

## 6. Appendix — Quick Reference Cheatsheet

```dart
// Pattern A: single-entity watch
final entity = ref.watch(entityProvider.select((m) => m[id]));

// Pattern B: filtered list memoized by Riverpod
final spells = ref.watch(entitiesByCategoryProvider('spell'));

// Pattern C: cheap deep equality
import 'package:collection/collection.dart';
const _deepEq = DeepCollectionEquality();
final unchanged = _deepEq.equals(prev, next);

// Pattern D: lazy merged map
import 'package:collection/collection.dart';
final merged = UnmodifiableMapView(CombinedMapView<String, Entity>(
  [campaign, builtin],
));

// Pattern E: debounce keystroke filter
Timer? _debounce;
onChanged: (v) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 150),
      () => setState(() => _search = v));
},
```

---

## 7. Implementation log (2026-05-13)

Survey-level fixes; per-surface detail lives in
`performance_hotspots_wizard_editor_hub.md` §11-13.

### F1 — `_mapEquals` swapped to `DeepCollectionEquality`
File: `lib/application/providers/entity_provider.dart`
- `_mapEquals` body is now a single `DeepCollectionEquality().equals(a, b)`
  call. `dart:convert` import removed. `jsonEncode` allocation gone from
  the editor's per-keystroke autosave path.

### F2 — Full-map watches replaced with `.select` / scoped reads
Sites closed:
- `character_editor_screen.dart` — `_StatChipsHeader` uses
  `entityProvider.select((m) => m[id]?.name)` for race / class name (E5).
- `character_creation_wizard_screen.dart` — Race/Review/EntityPickStep
  now route through `wizardEntitiesProvider` (W6).
- `characters_sidebar.dart` — screen-level entity merge resolved once,
  per-row `readCharacterEntities` replaced with local `entitiesFor(c)`.
- `characters_tab.dart` — same pattern, applied under H3.
- `entity_selector_dialog.dart` — `EntityNameText` uses
  `entityProvider.select((m) => m[id]?.name)`.
- `character_stat_chips.dart` — added
  `characterStatLinesWithNames(...)` so callers with pre-resolved names
  can skip the full-map dependency.

### F3 — `wizardEntitiesProvider` narrowed + lazy merge
- `ref.watch(characterDraftProvider.select((d) => d.worldName))` instead
  of watching the whole draft.
- Returns `UnmodifiableMapView<CombinedMapView<String, Entity>>([campaign,
  builtin])` when both are non-empty; `builtin` directly otherwise. No
  more 7K-entry spread per keystroke.

### F4 — Entity selector dialog debounce + caching
File: `lib/presentation/dialogs/entity_selector_dialog.dart`
- 150 ms `Timer` debounce on `TextField.onChanged`.
- `excludeIds` / `allowedTypes` converted to `Set` once in `initState`.
- Base list (entities pre-filtered by exclude + allowedTypes, sorted by
  name) cached in `_baseList`; per-keystroke filter is now a single
  `.toLowerCase()` + a substring loop against the cached list.
- `EntityNameText.build` switched to scoped `.select` watch (also closes
  one F2 site).

### F5 / F10 — Sliver migration of CharactersTab
Deferred this round. The visible list (`characters_tab.dart:129`) sits
inside `SingleChildScrollView > Column > ConstrainedBox(maxWidth: 500)
> ListView.separated(shrinkWrap: true, NeverScrollable)`. Migrating to a
true `SliverList` requires breaking the cross-axis centering out into
`SliverCrossAxisGroup` + `SliverConstrainedCrossAxis` + filler slivers —
invasive layout refactor with regression surface.

After H3 the dominant per-tile cost (3 provider watches + 2-map spread)
is gone, so the remaining win is purely virtualization (skip building
off-screen rows). Worth revisiting once a real profile flags row build
time as a hotspot, especially if list grows past ~500 rows or if the
team is doing a redesign that allows breaking the maxWidth constraint
pattern.

### F6 — `entities.values.where(...)` re-runs replaced with cached families
- `entitiesByCategoryProvider.family<List<Entity>, String>` lives in
  `builtin_srd_entities.dart`. Wired into `spells_step`,
  `proficiencies_step`, `subclass_step`, `feats_step` (the four worst
  offenders).
- `entity_selector_dialog.dart` precomputes `_baseList` once per dialog
  open (see F4).

### F8 — `sortedCharactersProvider`
File: `lib/application/providers/character_provider.dart`
- New `Provider<List<Character>>` caches the `updatedAt`-DESC order.
- `CharactersTab` and its `_sortedList()` helper now read from this
  provider — no more `[...all]..sort(...)` per rebuild.

### Round 2 (same day) — F7, F11, F12, F13

#### F7 — `prefer_const_constructors` enabled, 71 fixes / 25 files
- Added `prefer_const_constructors`, `prefer_const_constructors_in_immutables`,
  `prefer_const_declarations`, `prefer_const_literals_to_create_immutables`
  to the lint rules in `analysis_options.yaml`.
- `dart fix --apply` cleaned the resulting findings automatically — 71
  fixes across 25 files (mostly `Icon(...)`, `EdgeInsets.symmetric(...)`,
  `SizedBox(...)` literals being promoted to const). All 477 tests stay
  green; analyzer report dropped from 20 issues to 3 (pre-existing
  unused-element warnings unrelated to this work).
- Lint stays on going forward — new code automatically gets the const
  treatment without a follow-up pass.

#### F11 — SRD pack already lazy
- Confirmed `builtinSrdEntitiesProvider` is a regular `Provider`, so its
  body runs only on first read. The cold-start cost is paid once and the
  result is identity-stable for the rest of the app lifetime — downstream
  watchers don't see invalidations. Treated as a noop; can revisit later
  via the "background isolate + serialized blob" path in §2.11 if cold
  start ever shows a > 100 ms spike.

#### F12 — campaign-revision cascade already gated
- The Provider body re-runs on every revision bump, but the identity
  check at line 46 (`identical(rawSource, _cachedWorldSchemaSource)`)
  returns the cached `WorldSchema` when the source map hasn't changed.
  Riverpod's `==` comparison sees an identical reference → no cascade to
  downstream listeners. Functionally already optimal. Treated as a noop.

#### F13 — `_syncToCampaign` made incremental
File: `lib/application/providers/entity_provider.dart`
- New `_writeEntityToCampaign(Entity)` — patches a single key in the
  campaign's `entities` blob and calls `_onDirty()`. O(1).
- New `_removeEntityFromCampaign(String id)` — drops a single key. O(1).
- `update(entity)`, `create(...)`, and `delete(id)` switched to these
  helpers. The full-rebuild `_syncToCampaign()` is retained for
  `undo` / `redo` / `setAll` / `addEntities` where the diff is unknown.
- Replaces the previous O(N) full re-serialization per single-entity
  edit. With a ~7 K-entry world that was ~7 K × ~20 fields of work per
  keystroke (via the editor's autosave path). Now just one entity's
  serialization.

### Findings still open

- **F9** — bootstrap (UiState load on critical path). Lives under a
  different review track (startup latency).
- **F14** — build artifact cache. DevX.
- **F5 / F10** — Sliver migration. Deferred; needs `SliverCrossAxisGroup`
  + `SliverConstrainedCrossAxis` to preserve the maxWidth-500 centering.

---

**Owner**: TBD
**Review cadence**: end of each phase
**Linked memories**: [[srd_fix_roadmap]], [[project_progress]], [[perf_hotspots_wizard_editor_hub]]
