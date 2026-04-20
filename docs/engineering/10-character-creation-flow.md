# 10 — Character Creation Flow

> **For Claude.** Step-by-step wizard implementing SRD §16. State machine, validation, UI shape.
> **Source rules:** [00 §16-§22](./00-dnd5e-mechanics-reference.md#16-character-creation-pp-19-22)
> **Target:** `flutter_app/lib/presentation/screens/dnd5e/character_creation/`
> **UI migration:** Replaces the legacy schema-driven `CharacterEditorScreen` form at the "create new character" entry point. See [`50-typed-ui-migration.md`](./50-typed-ui-migration.md) Batch 6 — the wizard is authored on top of typed `Dnd5eCharacter` from day one; no schema-driven transitional form needed. The old "create character" button wiring in `characters_tab.dart` switches from the legacy editor to this wizard.

## Wizard Steps

```
Step 0: Pick Start Mode      (Level 1 OR Higher Level start)
Step 1: Choose Class         (+ subclass choice level info)
Step 2: Choose Origin        (Background + Species + Lineage + Languages)
Step 3: Determine Abilities  (method: Standard Array | Random | Point Buy)
Step 4: Choose Alignment
Step 5: Fill Details         (HP method: roll vs fixed; equipment choice)
Step 6: Review & Save        (preview character sheet, confirm)
```

Multiclass adds optional intermediate step at level-up time, not initial creation.

## State Machine

```dart
// flutter_app/lib/application/dnd5e/character_creation/character_creation_state.dart

class CharacterCreationState {
  final CharacterCreationStep currentStep;
  final CharacterDraft draft;
  final Set<int> completedSteps;
  final Map<int, String> stepValidationErrors;

  bool canAdvance() => stepValidationErrors[currentStep.index] == null;
  bool canGoBack() => currentStep.index > 0;
}

enum CharacterCreationStep {
  startMode, classChoice, origin, abilities, alignment, details, review;
  int get index => CharacterCreationStep.values.indexOf(this);
}

class CharacterDraft {
  final String? name;
  final int? startingLevel;          // 1 typical
  final List<DraftClassLevel> classLevels;     // multi-class supported even at higher start
  final String? speciesId;
  final String? lineageId;            // some species have lineage choice
  final String? backgroundId;
  final List<Language> chosenLanguages;
  final AbilityScoreGenerationMethod? scoreMethod;
  final Map<Ability, int> baseScores; // pre-background-bonus
  final Map<Ability, int> backgroundBonuses;  // +2/+1 OR +1/+1/+1
  final Alignment? alignment;
  final HpMethod hpMethod;            // rolled or fixed
  final int? hpAtLevel1;              // = classBase + CON mod (auto)
  final int? equipmentChoice;         // 0=A, 1=B, 2=C, 3=GP-only
  final List<String> chosenSkills;    // class skill choices
  final List<String> chosenTools;     // background tool choice if any
  final String? chosenSubclassId;     // if starting at level ≥ subclass-choice level
  final List<String> chosenFeats;     // origin feat from background
  ...

  CharacterDraft copyWith({...});
}
```

## Notifier

```dart
// flutter_app/lib/application/dnd5e/character_creation/character_creation_notifier.dart

class CharacterCreationNotifier extends StateNotifier<CharacterCreationState> {
  CharacterCreationNotifier() : super(CharacterCreationState.initial());

  void selectStartMode(int startingLevel) { ... revalidateCurrentStep() ... }
  void selectClass(String classId) { ... }
  void selectSubclass(String subclassId) { ... }
  void chooseClassSkills(List<String> skills) { ... }
  void selectSpecies(String speciesId) { ... }
  void selectLineage(String? lineageId) { ... }
  void selectBackground(String bgId) { ... }
  void chooseLanguages(List<Language> langs) { ... }
  void chooseScoreMethod(AbilityScoreGenerationMethod m) { ... }
  void setBaseScore(Ability a, int score) { ... }
  void applyBackgroundBonus(Map<Ability,int> bonuses) { ... }
  void selectAlignment(Alignment a) { ... }
  void selectHpMethod(HpMethod m) { ... }
  void selectEquipmentOption(int idx) { ... }
  void next();
  void back();
  Future<Character> save() { ... persist via repository ... }

  void _revalidateCurrentStep() { ... }
}

final characterCreationProvider =
  StateNotifierProvider.autoDispose<CharacterCreationNotifier, CharacterCreationState>(
    (ref) => CharacterCreationNotifier());
```

## Validation Rules per Step

### Step 0: Start Mode
- `startingLevel ∈ [1, 20]`.

### Step 1: Class
- `classLevels.isNotEmpty`.
- If `startingLevel ≥ subclassChoiceLevel`: subclass must be picked.
- Class skill choices satisfy required count.

### Step 2: Origin
- `speciesId != null`.
- If species has lineage variants: `lineageId != null`.
- `backgroundId != null`.
- `chosenLanguages.length == 2` (background may grant additional).
- Tool choice if background offers options.

### Step 3: Abilities
- All 6 abilities have a base score.
- Method-specific:
  - **Standard Array:** must use exactly [15,14,13,12,10,8] each once.
  - **Random:** 6 numbers from 4d6-drop-low (any).
  - **Point Buy:** sum costs ≤ 27, each base score ∈ [8,15]. Cost table in [00 §16.6](./00-dnd5e-mechanics-reference.md#16-character-creation-pp-19-22).
- Background bonus applied: total +4 distributed (+2/+1 across 2 of 3 listed; OR +1/+1/+1 across all 3). No score >20 after bonus.

### Step 4: Alignment
- One of 9 alignments. (Unaligned not allowed for PCs unless GM permission — flag, not block.)

### Step 5: Details
- `name.isNotEmpty`.
- HP computed = class L1 base + CON mod.
- Equipment choice selected.
- If higher-level start: per [00 §18.4](./00-dnd5e-mechanics-reference.md#16-character-creation-pp-19-22) bonus equipment + magic items granted (UI lets user pick rarities).

### Step 6: Review
- Always valid if previous steps valid.

## UI Layout

### Stepper Pattern

Use Flutter `Stepper` (vertical on mobile, horizontal on desktop). Per breakpoints in [30](./30-responsive-design-system.md).

```dart
class CharacterCreationScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final state = ref.watch(characterCreationProvider);
    final breakpoint = ResponsiveBreakpoint.of(ctx);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Character')),
      body: breakpoint.isMobile
        ? _MobileWizard(state: state)
        : _DesktopWizard(state: state),
    );
  }
}
```

### Mobile (`<600w`)

- Single full-screen step at a time.
- "Back" / "Next" buttons at bottom.
- Step indicator dots at top (1/7).

### Tablet (`600-1200w`)

- Left: step list (vertical stepper).
- Right: current step content (scrollable).

### Desktop (`>1200w`)

- Top: horizontal stepper progress bar.
- Center: step content + side panel showing "Live Preview" (compiled draft summary).
- Bottom: Back / Save Draft / Next.

### Per-Step Widgets

```
_StartModeStep         — radio: "Level 1" / "Start at higher level (input)"
_ClassChoiceStep       — class card grid; tap to select; sub-panel for subclass + skill chooser
_OriginStep            — 3 sub-tabs: Species / Background / Languages
_AbilitiesStep         — method radio + dynamic editor; live ability mod display; background bonus distributor
_AlignmentStep         — 3x3 grid of alignment cards + descriptions
_DetailsStep           — name input, HP method radio, equipment option chooser
_ReviewStep            — assembled character sheet preview; "Save" CTA
```

## Component Reuse

From [31](./31-ui-component-library.md):
- `AbilityScoreInput` (constrained per method)
- `ClassPickerCard`
- `SpeciesPickerCard`
- `BackgroundPickerCard`
- `AlignmentPickerCard`
- `EquipmentBundleCard`

## Persistence

Save flow:

```dart
Future<Character> save() async {
  if (!state.canAdvance() || state.currentStep != CharacterCreationStep.review) {
    throw StateError('Cannot save incomplete draft');
  }
  final character = _buildCharacter(state.draft);
  await ref.read(characterRepositoryProvider).insert(character);
  return character;
}

Character _buildCharacter(CharacterDraft d) {
  // Apply class lvl 1 features automatically.
  // Apply species traits.
  // Apply background feat + skills + tool.
  // Apply chosen languages.
  // Compute HP, AC, initiative, passive perception, spell slots, prepared spells.
  // Generate UUID.
  return Character( /* ... */ );
}
```

## Auto-derived Fields (Computed at Save)

The user does not fill these directly:

- `hpMax = classBaseAtL1 + conMod` (then per-level for higher-level starts).
- `armorClass` per equipped armor + DEX cap.
- `initiative = dexMod + (alertFeat ? PB : 0)`.
- `passivePerception = 10 + perceptionCheckMod`.
- `proficiencies` aggregated from class + background + species + chosen.
- `spellSlots` + `cantripsKnown` per class table.
- `preparedSpells` initial selection prompted as sub-step within Details if class is caster.

## Higher-Level Start Path

If `startingLevel > 1`:

- Show "Apply class levels" sub-flow:
  - Distribute levels across one or more classes.
  - For each level, apply ASI/feat picks.
  - Apply subclass at appropriate level.
  - HP: roll OR fixed per level.
- Show "Bonus equipment" sub-flow (per tier table):
  - Display granted GP and magic items budget.
  - Let user pick magic items by rarity from catalog (filter by allowed rarity).

## Multiclass at Initial Creation

Allowed (rare). Validate prereq: 13+ in primary ability of every class. Show warning if violated.

## Acceptance

- All 5 SRD species + 4 backgrounds + 12 classes pickable.
- Standard Array / Random / Point Buy methods all working with validation.
- Saved character round-trips: open character sheet, all fields populated correctly.
- Wizard navigable forward AND back; back doesn't lose data.
- Mobile + tablet + desktop layouts all functional.
- `flutter test` covers each step's validation logic.

## Open Questions

1. Should random ability roll be done client-side or display "roll your own"? → **Client-side roll button** with "Re-roll" option (GM permission for re-roll up to GM via session settings; default 1 roll per slot).
2. Allow saving incomplete drafts? → Yes; localStorage / Drift `character_drafts` table. Out of MVP — handle in a follow-up doc.
3. Allow skipping subclass at higher-level start (defer choice)? → No; SRD says subclass chosen at the appropriate level. Force the choice.
