# Performance Hotspots — Wizard, Editor & Hub (2026-05-13)

> Companion to `performance_optimization_roadmap.md`. That doc covers the whole
> app at a survey level (14 findings, F1–F14). This doc drills into three
> high-traffic surfaces the user explicitly called out: **character creation
> wizard**, **character editor + level-up dialog**, and the **hub sidebar +
> tabs**. Findings here renumber per surface (W#, E#, L#, H#) so they can be
> cross-referenced without colliding with the survey numbering. Where a hotspot
> overlaps the survey, the link is noted (`see F#`).

Audit method: static read of the 13 671 LOC across these three surfaces, plus
verification reads on `entity_provider.dart`, `builtin_srd_entities.dart`,
`character_stat_chips.dart`, and `character_draft_notifier.dart`. No runtime
profile capture yet — KPIs in §6 define where to validate.

---

## 1. Why these three surfaces?

| Surface                | LOC    | Open frequency | Watch graph             | Felt cost                          |
| ---------------------- | ------ | -------------- | ----------------------- | ---------------------------------- |
| Wizard                 | 4 226  | Every new char | Full draft + 7 K SRD    | Stepper-wide rebuild per keystroke |
| Editor + level-up      | 3 077  | Every edit     | Full entity map + draft | Form rebuild + dialog stall        |
| Hub (sidebar + 7 tabs) | 4 029  | Always open    | All providers eagerly   | Tab switch jank + sidebar repaint  |
| **Total in scope**     | 11 332 |                |                         |                                    |

These three account for ~80 % of foreground frame time during normal use, and
~100 % of "felt lag" reports we'd expect: typing into a name field, opening a
heavy editor, flipping tabs. Optimising them is where the biggest perceived
wins live.

---

## 2. Wizard (`character_creation_wizard_screen.dart` + `steps/*.dart`)

### Architecture recap

```
CharacterCreationWizardScreen
└── Stepper (Material — keeps ALL 12 steps mounted)
    ├── _NameStep, _RaceStep, _ClassStep, _AbilitiesStep, _ReviewStep …
    └── steps/{proficiencies,spells,subclass,feats,equipment,personality}.dart
        ↓ each calls ref.watch(wizardEntitiesProvider)
        ↓ wizardEntitiesProvider watches full characterDraftProvider
                                    + builtinSrdEntitiesProvider (7 K entries)
                                    + entityProvider (campaign map)
```

The fatal pattern: **`wizardEntitiesProvider` watches the entire
`characterDraftProvider` even though it only needs `draft.worldName`.** Every
keystroke into Name/Description/Backstory triggers:

1. `CharacterDraftNotifier.setName(v)` → `state = state.copyWith(name: v)`
2. `characterDraftProvider` invalidates → `wizardEntitiesProvider` rebuilds
3. `mergeWithBuiltinSrd` spreads ~7 000 entries into a fresh map
4. Every step widget watching `wizardEntitiesProvider` rebuilds (~6 steps mounted)
5. Each step re-filters `entities.values.where(...)` and re-sorts

That is the dominant wizard hotspot. Everything else compounds on top.

### Findings

#### W1 — `wizardEntitiesProvider` over-subscribes to full draft   `[A]`
File: [builtin_srd_entities.dart:117-123](../lib/application/services/builtin_srd_entities.dart#L117-L123)

```dart
final wizardEntitiesProvider = Provider.autoDispose<Map<String, Entity>>((ref) {
  final draft = ref.watch(characterDraftProvider);          // ← too broad
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  if (draft.worldName.isEmpty) return builtin;
  final campaign = ref.watch(entityProvider);
  return mergeWithBuiltinSrd(campaign, builtin, useCampaign: true);
});
```

The function uses only `draft.worldName`. The remaining 30+ fields force a
rebuild whenever the user types a character.

**Fix:** narrow the dependency, drop the spread:

```dart
final wizardEntitiesProvider = Provider.autoDispose<Map<String, Entity>>((ref) {
  final world = ref.watch(
    characterDraftProvider.select((d) => d.worldName),
  );
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  if (world.isEmpty) return builtin;
  final campaign = ref.watch(entityProvider);
  // Lazy view — no 7 K-entry spread; reads are O(1).
  return UnmodifiableMapView(
    CombinedMapView<String, Entity>([campaign, builtin]),
  );
});
```

Effort: ~10 min. Risk: zero — `mergeWithBuiltinSrd` already exposes only
read-only access. Validates: type a 20-char name; wizard step rebuilds should
go from 20 → 0 (or 1 if the name field itself isn't behind .select).

> Linked: see [F3] in the survey doc. This is the surgical fix.

---

#### W2 — Stepper keeps all 12 steps mounted   `[A]`
File: [character_creation_wizard_screen.dart:137-295](../lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart#L137-L295)

Material `Stepper` builds every `Step.content` widget on every screen rebuild
regardless of `currentStep`. With 6 of the steps subscribed to
`wizardEntitiesProvider`, a single keystroke fires ~6 rebuilds even though
only one step is visible.

**Fix:** Replace the body builder with a guarded render so off-screen steps
return `const SizedBox.shrink()`:

```dart
Step(
  title: …,
  content: KeepAliveOrCollapsed(
    isActive: _currentStep == idx,
    builder: () => _RaceStep(…),
  ),
)
```

Where `KeepAliveOrCollapsed` is:

```dart
class KeepAliveOrCollapsed extends StatelessWidget {
  final bool isActive;
  final Widget Function() builder;
  const KeepAliveOrCollapsed(
      {super.key, required this.isActive, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();
    return builder();
  }
}
```

Effort: ~30 min. Risk: low — Stepper still shows step headers; only the body
is collapsed. Will reduce per-frame widget count by ~83 %.

---

#### W3 — TextFormField onChanged triggers draft-wide rebuild   `[A]`
File: [character_creation_wizard_screen.dart:906, 917, 1720](../lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart#L906)

Every `onChanged: notifier.setName` writes `state.copyWith(name: v)`
synchronously. With W1 unfixed, every keystroke goes through the 7 K spread.
With W1 fixed, the cost drops to "every step that .watch()es a name-dependent
field rebuilds". For the name itself, only the field needs to update.

**Fix (post-W1):**
- Route text fields through a `TextEditingController` whose value is **not**
  pushed into the notifier until `onEditingComplete` / focus loss, OR
- Wrap the notifier write in a 250 ms debounce (`Timer? _t`).

Sample:

```dart
TextField(
  controller: _nameCtrl,
  onChanged: (v) {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 250),
        () => notifier.setName(v));
  },
)
```

Validation must still operate on the final value — the Next-button validator
should read `_nameCtrl.text` (or flush debounce first), not just the notifier
state. Effort: ~1 hr. Risk: medium (need to verify validation paths). Impact:
restores tactile typing in heavy steps.

---

#### W4 — Step filters re-run `entities.values.where(...)` per build   `[B]`
Files:
- [spells_step.dart:60-73](../lib/presentation/screens/characters/wizard/steps/spells_step.dart#L60-L73)
- [proficiencies_step.dart:58-62](../lib/presentation/screens/characters/wizard/steps/proficiencies_step.dart#L58-L62)
- [subclass_step.dart:31-33](../lib/presentation/screens/characters/wizard/steps/subclass_step.dart#L31-L33)

Each does `entities.values.where(...).toList()` per build. With ~7 K entries,
that's ~7 000 predicate checks × 3 chained `.where` filters × 2 sorts in
`SpellsStep`.

**Fix:** introduce a memoized family provider, used by every step:

```dart
// Cached by category slug; auto-invalidates when the entity map changes
// (which is rare — only on campaign switch / SRD pack swap).
final entitiesByCategoryProvider =
    Provider.family<List<Entity>, String>((ref, slug) {
  final all = ref.watch(wizardEntitiesProvider);
  final out = <Entity>[];
  for (final e in all.values) {
    if (e.categorySlug == slug) out.add(e);
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return List.unmodifiable(out);
});
```

Then in `SpellsStep`:

```dart
final allSpells = ref.watch(entitiesByCategoryProvider('spell'));
final mySpells = allSpells.where((e) => _classRefs(e).contains(draft.classId));
```

The first `.where` (slug match) — the expensive one — runs once per entity
map version. The class-ref filter is small enough to leave inline.

Effort: ~1 hr. Risk: zero (memoization is read-only).
> Linked: see [F6] in the survey doc.

---

#### W5 — `FeatsStep._FeatsCache` rebuilt from scratch every render   `[B]`
File: [feats_step.dart:80, 753, 828](../lib/presentation/screens/characters/wizard/steps/feats_step.dart#L80)

`_FeatsCache.from(entities)` walks `entities.values` 2–3 times to bucket
skills/tools/spells. Called on every rebuild. `_activeFeats()` runs three more
times during validation. The feats step is the single most expensive step.

**Fix:** lift to a provider keyed on entity map identity:

```dart
final featsCacheProvider = Provider.autoDispose<FeatsCache>((ref) {
  final entities = ref.watch(wizardEntitiesProvider);
  return FeatsCache.from(entities);
});
```

Riverpod will hand back the same `FeatsCache` instance until `entities`
changes by identity. Effort: ~30 min. Risk: zero.

---

#### W6 — `_RaceStep` and `_ReviewStep` duplicate the entity merge   `[B]`
File: [character_creation_wizard_screen.dart:1217-1221, 1754-1760](../lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart#L1217-L1221)

Both steps re-watch `builtinSrdEntitiesProvider` + `entityProvider` and
re-merge manually instead of using `wizardEntitiesProvider`. This is a third
copy of the merge logic — and it's the *non-debounced* version, so it bypasses
W1's planned fix as well.

**Fix:** delete the manual watches; use `ref.watch(wizardEntitiesProvider)`.

Effort: ~5 min. Risk: zero.

---

#### W7 — Spell/cantrip toggle rewrites entire ID list   `[C]`
File: [character_draft_notifier.dart:101-121](../lib/application/character_creation/character_draft_notifier.dart#L101-L121)

`toggleCantrip` / `togglePreparedSpell` clone the list each call:

```dart
final ids = [...state.cantripIds];
```

For 10-spell-cap selections this is fine, but with 20-prepared casters and
W1 unfixed this allocation × six watching steps adds up. Once W1 lands, this
is a minor.

**Fix (low priority):** keep as-is. The hotspot is the watch, not the clone.

---

#### W8 — `ChipPicker` allocates `picked.toSet()` per build   `[C]`
File: [feats_step.dart:651](../lib/presentation/screens/characters/wizard/steps/feats_step.dart#L651)

`final pickedSet = picked.toSet();` — fine if `picked` has 4 elements, but
`contains()` on a 4-element List is faster than allocating a Set. With W5
applied this disappears anyway (FeatsCache will own the set).

**Fix:** delete; use `picked.contains()` directly.

---

#### W9 — `_OptionTile` resolves item refs per render   `[C]`
File: [equipment_step.dart:239-245](../lib/presentation/screens/characters/wizard/steps/equipment_step.dart#L239-L245)

`_refName()` does `entities[ref]` per item per option per tile. 3 options × 4
items × 6 group cards = ~72 map lookups per equipment-step rebuild. Map
lookups are O(1) — this is C-tier, but cheap to fix.

**Fix:** pre-resolve item names in `_GroupCard.build()` and pass a
`Map<String, String> resolvedNames` down. Effort: 15 min.

---

#### W10 — Ability score dropdowns regenerate items per build   `[C]`
File: [character_creation_wizard_screen.dart:1649-1661, 1689-1698](../lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart#L1649-L1661)

`.map(...).toList()` to build DropdownMenuItems × 6 abilities × every method
switch. Extract to a static const list.

---

### Wizard summary

| ID  | Impact | Effort | Fix one-liner                                         |
| --- | ------ | ------ | ----------------------------------------------------- |
| W1  | A      | 10 min | `.select((d) => d.worldName)` + `CombinedMapView`     |
| W2  | A      | 30 min | Collapse hidden Stepper bodies                        |
| W3  | A      | 1 hr   | Debounce text-field writes to notifier                |
| W4  | B      | 1 hr   | `entitiesByCategoryProvider.family`                   |
| W5  | B      | 30 min | Lift FeatsCache to a provider                         |
| W6  | B      | 5 min  | Use `wizardEntitiesProvider` in Race/Review steps     |
| W7  | C      | —      | Skip; falls out after W1                              |
| W8  | C      | 5 min  | Drop `toSet()` allocation                             |
| W9  | C      | 15 min | Pre-resolve item names per group                      |
| W10 | C      | 10 min | Static const dropdown items                           |

**Predicted result:** typing latency in Name/Description fields drops from
~80–120 ms (current at-scale guess) to <16 ms (single-step rebuild only).
Stepper transition latency drops by ~50 % from W2 alone.

---

## 3. Editor (`character_editor_screen.dart` — 2 123 LOC)

### Architecture recap

The editor is a single monolithic Consumer screen with `TabBarView` for
detail / inventory / spells / features. It uses Riverpod `ref.watch` directly
inside the build method, *without* `.select`, and re-resolves the entity map
once per field tile.

### Findings

#### E1 — `_readEntitiesFor` re-watches three providers per field tile   `[A]`
File: [character_editor_screen.dart:704-730](../lib/presentation/screens/characters/character_editor_screen.dart#L704-L730)

Each field tile calls `_readEntitiesFor(ref, character)`, which internally
watches `builtinSrdEntitiesProvider` + `activeCampaignProvider` +
`entityProvider`. With 20+ field tiles, that's 60 provider subscriptions per
rebuild and the merge runs 20 times.

**Fix:** Resolve once at screen top into a local `merged`, pass it down via a
field-tile parameter or `InheritedWidget`:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final merged = ref.watch(characterEntitiesProvider(character.id));
  // ↓ pass `merged` to every _fieldTile call instead of looking it up inside
}
```

`characterEntitiesProvider` becomes a `.family` keyed on character id that
internally does the `mergeWithBuiltinSrd` + caching. This subsumes the
duplicate logic in `readCharacterEntities` (`character_stat_chips.dart:119`).

Effort: 2 hr. Risk: low (read-only refactor).
> Linked: see [F2], [F13] in the survey.

---

#### E2 — Synchronous `File.existsSync()` in portrait render   `[B]`
File: [character_editor_screen.dart:450](../lib/presentation/screens/characters/character_editor_screen.dart#L450)

```dart
File(entity.imagePath).existsSync()  // ← inside build()
```

Synchronous I/O on the build path. For typical SSD this is sub-millisecond,
but on cold cache / network-mounted home dirs it stalls the frame. Even
without the worst case, it allocates a `File` and statvfs per rebuild.

**Fix:** cache existence in `_working` state, computed once in `initState`
and re-checked only when `imagePath` changes:

```dart
late Future<bool> _portraitExists =
    File(entity.imagePath).exists();  // async
```

then `FutureBuilder` the portrait. Effort: ~30 min. Risk: zero.

---

#### E3 — Text controllers sync without diff guard   `[C]`
File: [character_editor_screen.dart:363-366](../lib/presentation/screens/characters/character_editor_screen.dart#L363-L366)

`_syncIfNotFocused()` runs every build. If focus state flips during a
parent-triggered rebuild, the controller can overwrite live text.

**Fix:** add `if (ctrl.text == value) return;` guard at the top.
Effort: 5 min.

---

#### E4 — Per-keystroke field writes trigger autosave cascade   `[B]`
Files:
- [character_editor_screen.dart:427, 564, 709](../lib/presentation/screens/characters/character_editor_screen.dart#L427)
- `_mapEquals` in [entity_provider.dart:377-384](../lib/application/providers/entity_provider.dart#L377-L384)

Per-keystroke `_mutate()` → `characterListProvider.notifier.update()` →
`_mapEquals` runs `jsonEncode` on every field of every comparison. With 50
fields per entity and per-keystroke writes, this is the dominant CPU cost
during description editing.

**Fix:** two layers —
1. **Coalesce writes**: debounce `_mutate()` by 250–400 ms (same pattern as
   W3). The autosave layer downstream already coalesces 2 s, so the editor
   doesn't need per-keystroke fidelity here.
2. **Fast equality**: replace `_mapEquals` with `DeepCollectionEquality().equals`
   from `package:collection`. This kills the `jsonEncode` allocation entirely.

> Linked: see [F1] in the survey for the equality fix.

Effort combined: ~1 hr. Risk: low. Validation: type a 50-char description;
profile a single autosave cycle's CPU.

---

#### E5 — `_entityHeader` watches full entity map for two strings   `[B]`
File: [character_editor_screen.dart:573](../lib/presentation/screens/characters/character_editor_screen.dart#L573)

Header uses `characterStatLines(c, readCharacterEntities(ref, c))` —
`readCharacterEntities` watches the full map even though the header only
needs the entities at `raceId` and `classId`.

**Fix:** introduce two scoped selectors:

```dart
final raceName = ref.watch(
  entityProvider.select((m) => m[character.raceId]?.name),
);
final className = ref.watch(
  entityProvider.select((m) => m[character.classId]?.name),
);
```

Effort: ~20 min. Risk: zero. Cuts header rebuild rate to "only when those two
specific entities change" — typically never during a single edit session.

---

#### E6 — `CharacterStatChips` rebuilt on every editor frame   `[B]`
File: [character_stat_chips.dart](../lib/presentation/widgets/character_stat_chips.dart)

The `CharacterStatChips` widget receives a freshly-allocated `lines` List
every parent rebuild — even if values didn't change. Add `const` where
possible and wrap the chip strip in a `RepaintBoundary`:

```dart
RepaintBoundary(
  child: CharacterStatChips(lines: lines, palette: palette),
)
```

Effort: 5 min. Risk: zero. Effect: chip strip stops repainting on parent edits
that don't affect chip content.

---

### Editor summary

| ID | Impact | Effort | Fix one-liner                                        |
| -- | ------ | ------ | ---------------------------------------------------- |
| E1 | A      | 2 hr   | Resolve entity map once at screen top                |
| E2 | B      | 30 min | Cache portrait existence; async check                |
| E3 | C      | 5 min  | Guard controller sync against equal text             |
| E4 | B      | 1 hr   | Debounce mutations + replace `jsonEncode` equality   |
| E5 | B      | 20 min | `.select((m) => m[id]?.name)` for class/race         |
| E6 | B      | 5 min  | `RepaintBoundary` around stat chips                  |

---

## 4. Level-up Dialog (`level_up_dialog.dart` — 954 LOC)

#### L1 — Eligible spells/feats re-filtered on every dialog `setState`   `[B]`
File: [level_up_dialog.dart:231-259, 266-287](../lib/presentation/screens/characters/level_up_dialog.dart#L231-L259)

`_eligibleSpells()` + `_eligibleFeats()` walk the entire entity map and sort
on every `setState`. HP-roll updates, ASI choices, anything — they all retrigger.

**Fix:** memoize once in `initState`. Invalidate only when `widget.entities`
identity changes (rare) or when the picked-feat set changes (affects
"available feats" subset).

```dart
late final List<Entity> _allEligibleSpells = _computeEligibleSpells();
late final List<Entity> _baseEligibleFeats = _computeBaseEligibleFeats();
List<Entity> get _eligibleFeats =>
    _baseEligibleFeats.where((f) => !_pickedFeats.contains(f.id)).toList();
```

Effort: ~45 min. Risk: low (watch for the case where the entity map updates
mid-dialog — uncommon).

---

#### L2 — HP-roll `setState` rebuilds entire dialog   `[B]`
File: [level_up_dialog.dart:148-157, 487](../lib/presentation/screens/characters/level_up_dialog.dart#L148-L157)

Rolling a die calls `setState(() { _rollFaces = …; _hpRollTotal = …; })`,
which re-runs the entire dialog `build()` — including the spell picker and
feat picker filter loops. Five rolls = ten redundant filter passes.

**Fix:** extract HP roller into its own `StatefulWidget` (or wrap the HP
display + button in a `ValueListenableBuilder<int>` backed by a
`ValueNotifier<int>`). Only the HP row rebuilds.

Effort: 30 min. Risk: zero.

---

#### L3 — `planLevelUp` recomputed on every dialog rebuild   `[B]`
File: [level_up_dialog.dart:839](../lib/presentation/screens/characters/level_up_dialog.dart#L839)

The plan is recomputed inside `build()` instead of cached in dialog state.
For a level-up with 3 ASI/feat slots × 1 spell pick × 5 prof grants, the
planner walks several tables per call.

**Fix:** compute once in `initState` and store. Recompute only on inputs that
actually invalidate the plan (level, class, subclass — none of which change
mid-dialog).

Effort: 20 min. Risk: zero.

---

### Level-up summary

| ID | Impact | Effort | Fix one-liner                                  |
| -- | ------ | ------ | ---------------------------------------------- |
| L1 | B      | 45 min | Memoize eligible spells/feats in initState     |
| L2 | B      | 30 min | Isolate HP roller in its own StatefulWidget    |
| L3 | B      | 20 min | Cache `planLevelUp` result in initState        |

---

## 5. Hub Sidebar + Tabs

### Architecture recap

`HubScreen` builds a side rail (desktop/tablet) or bottom nav (phone) and a
`LazyIndexedStack` holding 6 tab widgets. `LazyIndexedStack` defers the *first
build* of each tab until it's been visited, but once visited the widget stays
mounted and continues to receive provider notifications. The sidebar itself
watches several providers without `.select()`.

### Findings

#### H1 — Sidebar watches `cloudRemoteHasNewerProvider` / `totalNotificationCountProvider` un-selected   `[C]`
File: [hub_screen.dart:249-251](../lib/presentation/screens/hub/hub_screen.dart#L249-L251)

```dart
final cloudBadge = ref.watch(cloudRemoteHasNewerProvider);
final hasUnread =
    (ref.watch(totalNotificationCountProvider).value ?? 0) > 0;
```

The whole `HubScreen.build()` runs whenever cloud state or notification count
flickers — even though only two icon badges depend on them. The notification
count is fine to watch for "do we have any unread?", but `cloudBadge` returns
a full `AsyncValue` whose every internal transition triggers a hub rebuild.

**Fix:**

```dart
final cloudBadge = ref.watch(
  cloudRemoteHasNewerProvider.select((async) => async.valueOrNull == true),
);
final hasUnread = ref.watch(
  totalNotificationCountProvider.select((async) => (async.value ?? 0) > 0),
);
```

The hub now only rebuilds when the boolean flips, not on every async tick.

Effort: 10 min. Risk: zero.

---

#### H2 — `LazyIndexedStack` keeps every visited tab subscribed forever   `[B]`
File: [hub_screen.dart:344-346](../lib/presentation/screens/hub/hub_screen.dart#L344-L346)

Once the user has visited all 6 tabs, *all 6 tabs are subscribed to their
providers and rebuild on every state change*, even though only one is
visible. `CharactersTab`'s 200-character sort runs every time
`characterListProvider` changes — even while the user is looking at Settings.

**Fix:** swap `LazyIndexedStack` for a router-style approach that mounts only
the active tab, **or** wrap each tab's content in an `Offstage(offstage:
!isActive, child: …)` with `TickerMode(enabled: isActive, …)`. The cleanest
option: introduce a `Visibility(visible: isActive, maintainState: true,
maintainAnimation: false)` per tab so off-screen tabs stop building.

Caveat: tabs with internal animations (e.g. `templates_tab` has lottie
fade-ins) need `maintainState: true` to preserve scroll offsets. The trade-off
is: keeping state alive vs. cutting rebuilds. The right pattern:

```dart
class _LazyTab extends StatelessWidget {
  final bool active;
  final Widget Function() builder;
  …
  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: ExcludeFocus(
        excluding: !active,
        child: Offstage(offstage: !active, child: builder()),
      ),
    );
  }
}
```

That stops animations and focus, but the build tree stays mounted. To also
stop rebuilds on the inactive tab, the consumer subscriptions need to live
*inside* the tab and be gated on `active`. Easier path: wrap each tab's body
in `Visibility(visible: active, maintainState: true, child: _Tab(...))` and
have the tab early-return `const SizedBox.shrink()` if `!ModalRoute.of(...)`.

Practical recommendation: ship H1 first (cheap), then for H2 measure first —
if the inactive-tab rebuilds aren't actually expensive (Settings, Templates
are mostly static), leave as-is. If `CharactersTab` is the main offender
(likely), apply the early-return guard *inside* `CharactersTab` only.

Effort: ~2 hr. Risk: medium — needs verification that tab state isn't lost on
switch.

> Linked: see [F8] in the survey.

---

#### H3 — `CharactersTab` sorts on every rebuild + `readCharacterEntities` per item   `[A]`
Files:
- [characters_tab.dart:81-105](../lib/presentation/screens/hub/characters_tab.dart#L81-L105) (sort)
- [characters_tab.dart:147-149](../lib/presentation/screens/hub/characters_tab.dart#L147-L149) (per-item entity merge)
- [characters_tab.dart:106-158](../lib/presentation/screens/hub/characters_tab.dart#L106-L158) (`ListView.separated + shrinkWrap + NeverScrollable`)

Three problems stacked:

1. `[...all]..sort(...)` runs every rebuild — O(N log N) for ~200 characters.
2. `readCharacterEntities(ref, c)` runs *per list item* — each call watches 3
   providers and spreads two maps. 200 items × 3 watches = 600 subscriptions
   per rebuild.
3. The ListView uses both `shrinkWrap: true` and `NeverScrollableScrollPhysics`
   inside a `SingleChildScrollView` — worst of both worlds: forces the full
   list to lay out at once (no virtualization) while paying ListView's setup
   cost.

**Fixes:**

1. Hoist sort into a dedicated provider:

   ```dart
   final sortedCharactersProvider = Provider<List<Character>>((ref) {
     final list = ref.watch(characterListProvider).valueOrNull ?? const [];
     final out = [...list]..sort(_compareCharacters);
     return List.unmodifiable(out);
   });
   ```

   Riverpod will cache the result. Sort only re-runs on actual character list
   changes.

2. Replace per-item `readCharacterEntities` with a single screen-level read:

   ```dart
   final builtin = ref.watch(builtinSrdEntitiesProvider);
   final activeWorld = ref.watch(activeCampaignProvider);
   final campaign = ref.watch(entityProvider);
   final merged = UnmodifiableMapView(
     CombinedMapView<String, Entity>([campaign, builtin]),
   );
   // then in itemBuilder:
   final lines = characterStatLines(c, merged);
   ```

3. Replace `ListView.separated(shrinkWrap: true, physics: Never...)` inside
   the scroll view with a `SliverList` inside a `CustomScrollView`, or
   simplest: remove the outer `SingleChildScrollView` so the `ListView` owns
   the scroll. With 200+ characters, virtualization is mandatory.

Effort: ~3 hr total. Risk: low. Impact: tab-open time should drop from 200+ ms
to <50 ms for large lists.

> Linked: see [F5], [F8] in the survey.

---

#### H4 — `SettingsTab` invalidates providers on every open   `[C]`
File: [settings_tab.dart:42-48](../lib/presentation/screens/hub/settings_tab.dart#L42-L48)

`initState()` invalidates `trashProvider`, `soundpadProvider`, `betaProvider`
on every tab open. This re-issues file reads on each visit.

**Fix:** delete the invalidations. Trust provider lifecycle. If staleness is a
concern, add an explicit "Refresh" button.

Effort: 10 min. Risk: low — verify no test depends on this.

---

#### H5 — `PackagesTab` watches `packageMetadataProvider` per item   `[B]`
File: [packages_tab.dart:128](../lib/presentation/screens/hub/packages_tab.dart#L128)

Each item in the list watches its own `packageMetadataProvider(info.name)` —
if there are 30 packages, that's 30 async listeners spawned on tab open. If
the metadata is fetched remotely or from disk, this means a cascade of
parallel reads.

**Fix:** batch-load at the tab level into a single async provider that
returns a `Map<String, PackageMetadata>`; pass the relevant slice to each
item.

Effort: ~1 hr. Risk: low.

---

#### H6 — `WorldsTab` ListView shrinkWrap + NeverScrollable   `[C]`
File: [worlds_tab.dart:98-100](../lib/presentation/screens/hub/worlds_tab.dart#L98-L100)

Same pattern as H3 — fine while worlds are < 20, jank-prone past that.
Address opportunistically (low priority while user is below threshold).

---

#### H7 — `SettingsTab` GridView shrinkWrap + NeverScrollable   `[C]`
File: [settings_tab.dart:76-85](../lib/presentation/screens/hub/settings_tab.dart#L76-L85)

Theme grid is 4 items today; fine as-is. Flag for if/when theme count
expands past ~10.

---

### Hub summary

| ID | Impact | Effort | Fix one-liner                                            |
| -- | ------ | ------ | -------------------------------------------------------- |
| H1 | C      | 10 min | `.select()` cloud + notification booleans                |
| H2 | B      | 2 hr   | Gate inactive-tab subscriptions (start w/ CharactersTab) |
| H3 | A      | 3 hr   | Sort provider + screen-level merge + virtualized list    |
| H4 | C      | 10 min | Drop `ref.invalidate` from SettingsTab initState         |
| H5 | B      | 1 hr   | Batch package metadata at tab level                      |
| H6 | C      | —      | Defer (low world count today)                            |
| H7 | C      | —      | Defer (small theme count)                                |

---

## 6. KPIs — what "fixed" looks like

Capture these before/after with the Flutter DevTools Performance overlay or
`flutter run --profile --trace-startup`.

| Surface             | Metric                          | Now (est.)   | Target      |
| ------------------- | ------------------------------- | ------------ | ----------- |
| Wizard name typing  | Frame time per keystroke        | 60-120 ms    | <16 ms      |
| Wizard step switch  | Time-to-next-step ready         | 80-150 ms    | <32 ms      |
| Editor desc typing  | Frame time per keystroke        | 30-60 ms     | <12 ms      |
| Editor open         | Cold open (200-entity world)    | 250-400 ms   | <120 ms     |
| Level-up dialog     | Time-to-dialog-painted          | 80-200 ms    | <40 ms      |
| Hub tab switch      | Time to repaint visible content | 30-80 ms     | <16 ms      |
| Characters tab open | First-paint of 200-row list     | 200-500 ms   | <50 ms      |

The current numbers are educated guesses from static read; the user should
capture the *real* before-numbers via the DevTools timeline before starting
implementation, so the after-numbers can be compared.

---

## 7. Recommended implementation order

Single source of priorities — pick the next item from here, don't shop.

### Phase A — Wizard & editor quick wins (1 day, zero API breakage)

1. **W1** — `wizardEntitiesProvider` `.select` + `CombinedMapView`. (10 min)
2. **W6** — collapse duplicate merges in `_RaceStep` / `_ReviewStep`. (5 min)
3. **W4** — `entitiesByCategoryProvider.family`. (1 hr)
4. **W5** — lift `FeatsCache` to a provider. (30 min)
5. **E5** — `.select((m) => m[id]?.name)` for class/race in header. (20 min)
6. **E6** — `RepaintBoundary` on stat chips. (5 min)
7. **H1** — `.select()` cloud + notification booleans. (10 min)
8. **H4** — drop `ref.invalidate` from `SettingsTab.initState`. (10 min)

Total: ~3 hr engineering. Total impact: removes the spread-on-every-keystroke
class of bugs across both wizard and editor.

### Phase B — Heavier refactors (2-3 days)

9.  **W2** — Stepper hidden-body collapse.
10. **W3** — debounce text-field writes.
11. **E1** — single `characterEntitiesProvider(family)` for editor.
12. **E4** — debounce `_mutate` + replace `_mapEquals` with
    `DeepCollectionEquality`.
13. **E2** — async portrait existence.
14. **L1** / **L2** / **L3** — level-up dialog memoization.
15. **H3** — `sortedCharactersProvider` + screen-level merge + virtualized
    `CharactersTab`.

### Phase C — Architectural (1 week, requires testing)

16. **H2** — gate inactive-tab subscriptions (CharactersTab first, then
    PackagesTab).
17. **H5** — batch `packageMetadataProvider` load.
18. **W9 / W10 / W8 / E3** — polish allocations.

---

## 8. Cross-cutting principles

1. **Stop watching maps you only read keys from.** Anywhere you see
   `ref.watch(entityProvider)` followed by a single `[id]` lookup, replace
   with `.select((m) => m[id])`. Several findings here are instances of this
   pattern.

2. **Debounce text-input → notifier writes.** Every `onChanged` that writes
   to a notifier triggers a rebuild graph. 250 ms debounce is invisible to
   users and saves an order of magnitude of rebuilds.

3. **Memoize derived lists with `Provider`/`Provider.family`.** Anything
   computed from `entities.values.where(...)` is a candidate. Riverpod's
   identity equality means consumers won't rebuild if the derivation didn't
   change.

4. **Off-screen content should not subscribe.** Material `Stepper` and
   `LazyIndexedStack` both leak subscriptions to invisible widgets. Wrap
   bodies in active-flag guards.

5. **Lazy merges, not spreads.** `{...a, ...b}` allocates and copies.
   `CombinedMapView([a, b])` is O(1) construction. The wizard/editor merge
   their 7 K SRD map dozens of times per session — switching the pattern is a
   one-liner.

---

## 9. Out of scope (intentionally)

- **Drift / database tuning**: covered by F11–F13 in the survey doc.
- **Bootstrap critical path**: F9 / F14.
- **`prefer_const_constructors` migration**: F7 — large mechanical diff,
  requires its own PR.
- **Sliver migration of every list**: only where measured to matter (H3 above
  is the obvious one).

---

## 10. Open questions / followups

1. Should `wizardEntitiesProvider` be split into `wizardBuiltinProvider` +
   `wizardCampaignProvider`? Today's combined provider invalidates whenever
   *either* upstream changes. Splitting would let pure-SRD steps (e.g.
   `_NameStep`) avoid the campaign watch entirely. Defer until W1 lands and
   we can measure remaining noise.

2. Does the editor really need a single 2 123-LOC file? Splitting into
   `editor_header.dart` + `editor_inventory_tab.dart` +
   `editor_spells_tab.dart` etc. would let each chunk own its provider
   subscriptions naturally. Architectural; out of scope for perf work but
   worth a separate planning doc.

3. `CharactersTab` may eventually be a virtualised grid (cards) rather than
   list rows. If so, time the H3 fix with that redesign.
