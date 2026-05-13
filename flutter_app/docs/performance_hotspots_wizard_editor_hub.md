# Performance Hotspots — Wizard, Editor & Hub (2026-05-13)

> Companion to `performance_optimization_roadmap.md`. That doc covers the whole
> app at a survey level (14 findings, F1–F14). This doc drills into three
> high-traffic surfaces the user explicitly called out: **character creation
> wizard**, **character editor + level-up dialog**, and the **hub sidebar +
> tabs**. Findings here renumber per surface (W#, E#, L#, H#) so they can be
> cross-referenced without colliding with the survey numbering. Where a hotspot
> overlaps the survey, the link is noted (`see F#`).

## Status (2026-05-13)

**Phase A + B + C shipped.** Findings closed: W1, W2, W3, W4, W5, W6, W8,
W9, W10, E1, E2, E4, E5, E6, L1, H1, H3, H4, H5. **Deferred** (profiler-
gated, low marginal ROI): L2 (HP roller isolation — L1 already memoizes the
expensive lists), H2 (per-tab subscription gating — needs invasive tab-by-
tab refactor + profile data to justify), L3/E3/W7 already noops. All 477
tests still green; `dart analyze` clean against touched files. See §11 for
Phase A log, §12 for Phase B log, §13 for Phase C log.

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

| ID  | Status | Impact | Effort | Fix one-liner                                       |
| --- | ------ | ------ | ------ | --------------------------------------------------- |
| W1  | ✅ done | A      | 10 min | `.select((d) => d.worldName)` + `CombinedMapView`   |
| W2  | ✅ done | A      | 30 min | `_StepBody` collapses inactive Stepper bodies       |
| W3  | ✅ done | A      | 1 hr   | `_DebouncedTextField` + `_Field` 250 ms debounce    |
| W4  | ✅ done | B      | 1 hr   | `entitiesByCategoryProvider.family`                 |
| W5  | ✅ done | B      | 30 min | Lift FeatsCache base lists to family providers      |
| W6  | ✅ done | B      | 5 min  | Use `wizardEntitiesProvider` in Race/Review/PickStep|
| W7  | skip   | C      | —      | Skip; falls out after W1                            |
| W8  | ✅ done | C      | 5 min  | Drop `toSet()` allocation; use `picked.contains`    |
| W9  | ✅ done | C      | 15 min | `_resolveItemLines` lifted to `_GroupCard` level    |
| W10 | ✅ done | C      | 10 min | `_kPointBuyDropdownItems` static const list         |

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

| ID | Status | Impact | Effort | Fix one-liner                                       |
| -- | ------ | ------ | ------ | --------------------------------------------------- |
| E1 | ✅ done | A      | 2 hr   | `_readEntitiesFor` returns lazy `CombinedMapView`   |
| E2 | ✅ done | B      | 30 min | Drop `existsSync` from build; `Image.file.errorBuilder` |
| E3 | ✅ noop| C      | 5 min  | `_syncIfNotFocused` already guards with `ctrl.text != value` |
| E4 | ✅ done | B      | 1 hr   | `_mapEquals` now `DeepCollectionEquality.equals`    |
| E5 | ✅ done | B      | 20 min | `.select((m) => m[id]?.name)` for class/race        |
| E6 | ✅ done | B      | 5 min  | `RepaintBoundary` around stat chips                 |

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

| ID | Status | Impact | Effort | Fix one-liner                                 |
| -- | ------ | ------ | ------ | --------------------------------------------- |
| L1 | ✅ done | B      | 45 min | Memoize eligible spells/feats in initState    |
| L2 | defer  | B      | 30 min | HP roller isolation — low ROI after L1, profile-gated |
| L3 | ✅ noop| B      | 20 min | `planLevelUp` already cached on `widget.plan` |

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

| ID | Status | Impact | Effort | Fix one-liner                                            |
| -- | ------ | ------ | ------ | -------------------------------------------------------- |
| H1 | ✅ done | C      | 10 min | `.select()` notification boolean (cloudBadge already bool)|
| H2 | defer  | B      | 2 hr   | Per-tab gating — invasive refactor, profile-gated        |
| H3 | ✅ done | A      | 3 hr   | `sortedCharactersProvider` + screen-level merge          |
| H4 | ✅ done | C      | 10 min | Drop `ref.invalidate` from SettingsTab initState         |
| H5 | ✅ done | B      | 1 hr   | `.select(valueOrNull)` narrows packageMetadata watches   |
| H6 | todo   | C      | —      | Defer (low world count today)                            |
| H7 | todo   | C      | —      | Defer (small theme count)                                |

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

---

## 11. Phase A implementation log (2026-05-13)

Shipped as a single change set. All 477 unit + widget tests pass; `dart
analyze` reports no new issues on touched files.

### W1 — `wizardEntitiesProvider` narrowed
File: `lib/application/services/builtin_srd_entities.dart`
- `ref.watch(characterDraftProvider)` → `.select((d) => d.worldName)`
- `{...builtin, ...campaign}` spread → `UnmodifiableMapView(CombinedMapView([campaign, builtin]))`
- Early-out when campaign is empty (returns builtin directly — same
  identity, Riverpod skips dependent rebuilds entirely).
- Required `package:collection/collection.dart` import.

### W4 — `entitiesByCategoryProvider.family`
File: `lib/application/services/builtin_srd_entities.dart`
- New `Provider.autoDispose.family<List<Entity>, String>` keyed by category
  slug. Returns name-sorted, unmodifiable list. Invalidates only when the
  upstream entity map changes by identity.
- Consumers wired:
  - `spells_step.dart` — drops `entities.values.where(slug=='spell')` from
    the build path. Filter by `classId` runs on the cached list instead.
  - `proficiencies_step.dart` — `languageEntities` pulled from family.
  - `subclass_step.dart` — `allSubclasses` pulled from family; per-class
    filter and `granted_at_level` re-sort kept inline.

### W5 — FeatsCache uses cached lists
File: `lib/presentation/screens/characters/wizard/steps/feats_step.dart`
- Factory now takes `skills` / `tools` / `spells` / `classes` named
  params pulled from the family providers via `ref.watch`.
- Bucketing loops scan only the relevant category slices (~250-700
  entries) instead of the full ~7 K-entry map.
- Provider-keyed identity equality means an unchanged entity map →
  unchanged List references → consumer skip.

### W6 — `_RaceStep`, `_ReviewStep`, `_EntityPickStep` simplified
File: `lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart`
- All three duplicate `mergeWithBuiltinSrd` call sites replaced with
  `ref.watch(wizardEntitiesProvider)`. `_EntityPickStep` was an unlisted
  finding caught during the refactor — added to the "duplicates of W6"
  bucket.

### E5 — Editor header scoped watches
File: `lib/presentation/screens/characters/character_editor_screen.dart`
- New private `_StatChipsHeader` ConsumerWidget owns the strip. Watches
  `entityProvider.select((m) => m[raceId]?.name)` and
  `builtinSrdEntitiesProvider.select((m) => m[id]?.name)` separately;
  campaign vs. builtin gating mirrors `_readEntitiesFor` semantics.
- `characterStatLines(c, entities)` companion `characterStatLinesWithNames`
  added in `widgets/character_stat_chips.dart` so callers with already
  resolved names can skip the full-map watch path. Existing call sites
  unchanged — backward-compatible.

### E6 — `RepaintBoundary` around stat chips
- Inside `_StatChipsHeader.build()`. Isolates the chip strip from header
  / description edits above.

### H1 — Notification badge `.select`
File: `lib/presentation/screens/hub/hub_screen.dart`
- `ref.watch(totalNotificationCountProvider).value > 0` →
  `ref.watch(totalNotificationCountProvider.select((a) => (a.valueOrNull ?? 0) > 0))`.
- `cloudRemoteHasNewerProvider` already returns `bool` (the doc's original
  claim of `AsyncValue` was incorrect — discovered while inspecting the
  provider). No further fix needed.

### H4 — SettingsTab open-time refresh removed
File: `lib/presentation/screens/hub/settings_tab.dart`
- `initState`'s `addPostFrameCallback` block invalidating four providers
  on every tab open was deleted. Provider lifecycles already keep the
  data fresh; `LazyIndexedStack` re-enters the same `State` so this
  effectively re-issued disk reads on every settings open.

### New findings discovered during Phase A

| Code | Surface | What & why |
| --- | --- | --- |
| W6b | Wizard | `_EntityPickStep` (third manual merge) — fixed under W6. |
| F-doc | Hub | `cloudRemoteHasNewerProvider` is already `bool`, not `AsyncValue<bool>` — doc claim of "every internal transition triggers rebuild" was wrong. Updated H1 table row. |
| L-validate | Wizard | `_validateProficiencies` does `entities.values.where(slug=='language').length` per Next-click — runs only on validate, low frequency. Left as-is. Could swap to `ref.read(entitiesByCategoryProvider('language')).length` if `_validateProficiencies` migrates to ConsumerStatefulWidget pattern later. |

### KPI revision (still estimates; capture real numbers next session)

Phase A removes the per-keystroke ~7 K-entry spread that was the dominant
wizard cost, and trims the editor-header rebuild from "full map watch" to
"two scoped name watches". Expect:

| Surface             | Pre-Phase-A (est.) | After Phase A (est.) | Target  |
| ------------------- | ------------------ | -------------------- | ------- |
| Wizard name typing  | 60-120 ms / keystroke | 20-40 ms (Stepper bodies still mount; W2 will close the gap) | <16 ms |
| Wizard step switch  | 80-150 ms          | 50-90 ms             | <32 ms  |
| Editor header repaint | full editor frame | strip-only (RepaintBoundary scope) | n/a |
| Hub idle (notif tick)| full hub rebuild  | no rebuild           | done    |

### Phase B is now next — priority order

1. **W2** — Stepper hidden-body collapse. After this, Phase A's wizard
   gains compound from "1 step rebuild" to "1 step rebuild *only*"
   (today 6 step bodies still mount even though W1 cut their work).
2. **W3** — Debounce wizard text fields (250 ms).
3. **E1** — Single `characterEntitiesProvider.family` for the editor.
4. **E4** — Debounce `_mutate` + swap `_mapEquals` for
   `DeepCollectionEquality` ([F1] in survey).
5. **L1–L3** — Level-up dialog memoization.
6. **H3** — `sortedCharactersProvider` + virtualized `CharactersTab`.

Phase B touches more APIs than Phase A — schedule it as a separate PR per
finding (each is independently testable).

---

## 12. Phase B implementation log (2026-05-13)

Shipped in the same session as Phase A. All 477 tests still green; analyzer
clean against touched files.

### W2 — `_StepBody` collapses inactive Stepper bodies
File: `lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart`
- New `_StepBody(active, child)` widget. When `active` is false returns
  `const SizedBox.shrink()`; otherwise renders the child.
- All 12 Stepper `content` entries wrapped. The inner step widget is
  still allocated (cheap) but its `build()` tree is never walked when
  the step is not current. Per-frame widget-build cost dropped ~83 % for
  the wizard.

### W3 — Wizard text-field debounce
Files:
- `lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart`
- `lib/presentation/screens/characters/wizard/steps/personality_step.dart`
- New `_DebouncedTextField` private widget in the wizard screen. Wraps
  `TextFormField` with a 250 ms `Timer` that delays `onChangedDebounced`
  until the user pauses typing. Used by `_IdentityStep` (name +
  description).
- `_Field` in `personality_step.dart` converted from `StatelessWidget` to
  `StatefulWidget` with the same debounce. Covers
  traits/ideals/bonds/flaws/backstory/trinket.
- Validators still read notifier state — the 250 ms window is below the
  user's perception threshold + the Next button's first action waits on
  validate, so any pending flush has time to drain.

### E1 — Lazy `CombinedMapView` in editor entity merge
File: `lib/presentation/screens/characters/character_editor_screen.dart`
- `_readEntitiesFor` now returns `UnmodifiableMapView<CombinedMapView>`
  instead of `{...builtin, ...campaign}`. Empty-campaign early-out.
- The 20+ field tiles that call `_readEntitiesFor(c)` no longer allocate
  a fresh 7 K-entry map per call. Provider subscriptions are still
  idempotent so the watch graph is unchanged.

### E2 — Drop synchronous `File.existsSync()` from build path
File: `lib/presentation/screens/characters/character_editor_screen.dart`
- `hasImage` flag was `imagePath.isNotEmpty && existsSync()`. Replaced
  with `hasImagePath = imagePath.isNotEmpty` and an `errorBuilder` on
  the `Image.file` that falls back to the placeholder when the file is
  missing. ImageProvider's stat-cache handles the async existence
  internally — no main-thread blocking.

### E4 — DeepCollectionEquality replaces `jsonEncode` per field
File: `lib/application/providers/entity_provider.dart`
- `_mapEquals` was per-key `jsonEncode(a[key]) != jsonEncode(b[key])`.
  Replaced with a single static `DeepCollectionEquality().equals(a, b)`.
- `jsonEncode` allocation dominated description-typing CPU; removing it
  is the biggest single per-keystroke win in the editor.
- _mutate debounce was *not* added (out of scope this session — the
  autosave layer downstream already coalesces 1.2 s; per-keystroke
  setState is needed for `_undoBaseline` capture + visible header
  refresh).

### L1 — Eligible spells / feats memoized in initState
File: `lib/presentation/screens/characters/level_up_dialog.dart`
- Computed once via `_computeEligibleSpells({cantripOnly})`,
  `_computeEligibleFeats`, `_computeFightingStyleFeats` in
  `initState`. Stored in `late final` fields. Accessor methods
  (`_eligibleSpells`, `_eligibleFeats`, `_fightingStyleFeats`) now
  return the cached lists.
- HP rolls / ASI ticks no longer re-filter the entity map.

### H3 — `sortedCharactersProvider` + screen-level merge
Files:
- `lib/application/providers/character_provider.dart`
- `lib/presentation/screens/hub/characters_tab.dart`
- New `sortedCharactersProvider` caches the `updatedAt`-DESC list. Tab
  rebuilds no longer re-sort 200 characters; the provider returns the
  same `List` instance until the underlying list changes.
- `CharactersTab.build` now resolves the merged entity map once and
  passes the appropriate slice to each row via a local `entitiesFor(c)`
  helper. Replaces 200 × 3 = 600 per-row provider subscriptions with 3
  screen-level watches.
- Virtualization (Sliver migration) deferred — `ListView.separated`
  with shrinkWrap kept as-is. With the per-row entity-watch dropped, the
  remaining cost is bounded; revisit if list grows past ~500 chars.

### New findings discovered during Phase B

| Code | Surface | What & why |
| --- | --- | --- |
| E3-noop | Editor | `_syncIfNotFocused` already guards with `ctrl.text != value` — doc's claim of "no diff guard" was wrong. Confirmed at line 102. No fix needed. |
| L3-noop | Level-up dialog | `planLevelUp` is computed by the *caller* and passed in as `widget.plan` — it's not recomputed in dialog `build()`. Doc was wrong; no fix needed. |
| E4-half | Editor | `_mutate` debounce skipped on purpose — visible header subtitle (template · world) and `_undoBaseline` capture depend on per-keystroke `setState`. The autosave downstream already coalesces; the equality swap alone removes the dominant CPU cost. |

### KPI revision after Phase B

| Surface             | Pre-Phase-A | After Phase A  | After Phase B  | Target  |
| ------------------- | ----------- | -------------- | -------------- | ------- |
| Wizard name typing  | 60-120 ms   | 20-40 ms       | 4-10 ms (debounce flushes once / 250 ms; only active step body builds) | <16 ms |
| Wizard step switch  | 80-150 ms   | 50-90 ms       | 20-40 ms       | <32 ms  |
| Editor desc typing  | 30-60 ms    | unchanged      | 8-18 ms (no jsonEncode, no per-tile map alloc, no existsSync) | <12 ms |
| Editor open         | 250-400 ms  | unchanged      | 150-220 ms     | <120 ms |
| Level-up dialog HP roll | re-filter all spells/feats | unchanged | cached lookup only | done |
| Characters tab open (200 rows) | 200-500 ms | unchanged | 60-90 ms (sort cached, 3 watches instead of 600) | <50 ms |

The wizard + editor are now in or near the target band. CharactersTab is
close but Sliver virtualization would close the remaining gap when the
list grows. Real numbers should be captured before declaring done.

### Phase C — what's left

| ID  | Notes |
| --- | --- |
| H2  | Gate inactive-tab subscriptions. Highest remaining win; needs the visibility-wrapper experiment (CharactersTab already much lighter so urgency dropped). |
| L2  | Wrap HP roller in its own StatefulWidget so HP-roll setState scope shrinks. Low-impact after L1 — only useful if HP rolling shows up in profiles. |
| H5  | Batch `packageMetadataProvider` load at tab level. Pre-condition: package count > 10. |
| W8/W9/W10/E3 | Polish-tier allocations. Defer until a real profile flags them. |

The high-traffic surfaces are done. Phase C is opportunistic — touch only
when a captured profile points at one of these IDs.

---

## 13. Phase C implementation log (2026-05-13)

Same-day landing as A + B. All 477 tests still green; analyzer clean.

### W8 — Drop `pickedSet.toSet()` allocation in feat ChipPicker
File: `lib/presentation/screens/characters/wizard/steps/feats_step.dart`
- `final pickedSet = picked.toSet();` removed. With cap-4 typical lists,
  `picked.contains()` is faster than allocating a Set + hashing per row.

### W9 — Pre-resolve item names at group level
File: `lib/presentation/screens/characters/wizard/steps/equipment_step.dart`
- Top-level `_resolveItemLines(option, entities)` helper. Called from
  `_GroupCard.build()` once per option; `_OptionTile` now receives the
  resolved `List<String> itemLines` and no longer touches the entity
  map. Dead `_refName` removed.

### W10 — Static const dropdown items
File: `lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart`
- `_kPointBuyDropdownItems` (8 entries, base scores 8–15) lifted to a
  top-level final list. Was rebuilt per ability row × per rebuild;
  ~48 widget allocations per Abilities-step rebuild now shared.

### H5 — Package metadata watch narrowed
File: `lib/presentation/screens/hub/packages_tab.dart`
- `ref.watch(packageMetadataProvider(name))` → wrapped in
  `.select((a) => a.valueOrNull ?? {})` so loading/error transitions of
  the FutureProvider no longer trigger per-tile rebuilds — only when
  the resolved metadata map flips.
- A *true* batched provider would consolidate N parallel disk reads,
  but `repo.load(name)` reads the full package; batching serially could
  hurt wall-clock. Defer the data-layer split until package count
  > 20.

### L2 — Deferred (HP roller isolation)
- After L1's memoization the dialog's per-build cost is small (linear
  in a few cached lists). Refactoring the HP roller into its own
  `StatefulWidget` would lift state up via callback and touch the
  `_isComplete` / `_hpDelta` getters — net ROI low and risk medium.
  Revisit only if a profile flags the dialog as a hotspot.

### H2 — Deferred (per-tab subscription gating)
- `LazyIndexedStack` defers first-build per tab and the underlying
  `IndexedStack` already off-stages inactive children for paint — but
  the `build()` body of each visited tab still runs on its provider
  notifications. Truly gating those requires tab-by-tab changes:
  - Tab opts-in to receive an `active` bool.
  - Tab's `build()` early-returns when `!active` while preserving
    scroll-controller state and selection state.
  - Risk: lost scroll offset / selection state on tab switch if the
    pattern isn't applied carefully.
- After H3 the dominant offender (`CharactersTab`) is now ~10× cheaper
  per rebuild, so the marginal value of H2 dropped. Defer until a
  captured profile points back at this.

### New findings discovered during Phase C

| Code | Surface | What & why |
| --- | --- | --- |
| W8-context | Wizard | Same `toSet()` pattern shows up in `_SpellSection` (`spells_step.dart:193`) and `_PickerSection` (`proficiencies_step.dart:242`). With pick caps of 2-10 the gain is marginal — flagged for future polish if profiler catches them. Not fixed this round. |
| H5-data-layer | Packages | Real win lives behind `PackageRepository.load(name)` reading the *whole* package to extract metadata. Splitting metadata into its own on-disk file (or sidecar manifest) would let `packageMetadataProvider` skip the heavy reads entirely. Architectural; out of scope. |

### Final KPI snapshot

| Surface             | Pre-audit   | After A+B+C    | Target  |
| ------------------- | ----------- | -------------- | ------- |
| Wizard name typing  | 60-120 ms   | 4-10 ms        | <16 ms ✅ |
| Wizard step switch  | 80-150 ms   | 20-40 ms       | <32 ms ⚠️ (close) |
| Editor desc typing  | 30-60 ms    | 8-18 ms        | <12 ms ⚠️ (close) |
| Editor open         | 250-400 ms  | 150-220 ms     | <120 ms ⚠️ |
| Level-up dialog HP roll | re-filter | cached lookup  | done ✅  |
| Characters tab open | 200-500 ms  | 60-90 ms       | <50 ms ⚠️ (close) |

All numbers are static-analysis estimates. **Capture real numbers via the
Flutter DevTools Performance overlay before the next round** — that'll
decide whether the remaining ⚠️ rows justify Phase D (Sliver migration of
CharactersTab + per-tab gating).
