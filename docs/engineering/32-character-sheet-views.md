# 32 — Character Sheet Views

> **For Claude.** DM vs player view, public/private fields, mobile/tablet/desktop layouts.
> **Target:** `flutter_app/lib/presentation/screens/dnd5e/character/`
> **Migration:** The legacy `CharacterEditorScreen` (1166 LOC, `FieldSchema`-driven form) is replaced by a typed editor driven by `Dnd5eCharacter` — see [`50-typed-ui-migration.md`](./50-typed-ui-migration.md) Batch 6. The **three-pane layout / tab structure / save-cancel affordance / validation chip placement** from the legacy editor are **preserved verbatim**. Only the form contents change from generic `FieldGroup`s to typed ability-score / combat-stat / inventory / spell-list panels.

## Viewer Roles

```dart
enum ViewerRole {
  owner,        // The PC's player viewing own sheet
  dm,           // GM viewing any sheet
  partyMember,  // Another player viewing this PC
  observer,     // Read-only spectator
}
```

## Field Visibility Matrix

| Field                       | Owner | DM | Party Member | Observer |
|-----------------------------|-------|----|--------------|----------|
| Name, Class, Level, Species | ✓     | ✓  | ✓            | ✓        |
| Ability scores              | ✓     | ✓  | ✓            | ✓        |
| Skills, saves               | ✓     | ✓  | ✓            | ✓        |
| AC, Speed, Initiative       | ✓     | ✓  | ✓            | ✓        |
| HP exact                    | ✓     | ✓  | ✓ (party transparency) | ✗ (Bloodied only) |
| Spell slots                 | ✓     | ✓  | ✓            | ✗        |
| Prepared spells             | ✓     | ✓  | ✓            | ✗        |
| Inventory                   | ✓     | ✓  | ✗            | ✗        |
| Background details          | ✓     | ✓  | partial (name only) | name only |
| Notes (private)             | ✓     | ✓  | ✗            | ✗        |
| Backstory                   | ✓     | ✓  | configurable | ✗        |
| XP                          | ✓     | ✓  | ✓            | ✗        |
| Death saves                 | ✓     | ✓  | ✓            | ✗        |
| Editing rights              | ✓     | ✓  | ✗            | ✗        |

For monsters, default is DM-only; player view shows redacted view per [11-combat-engine-spec](./11-combat-engine-spec.md).

Implemented as a getter:

```dart
class CharacterView {
  final Character character;
  final ViewerRole role;

  bool get canSeeInventory => role == ViewerRole.owner || role == ViewerRole.dm;
  bool get canEdit => role == ViewerRole.owner || role == ViewerRole.dm;
  bool get canSeeExactHp => role != ViewerRole.observer;
  bool get canSeeSpellSlots => role != ViewerRole.observer;
  bool get canSeeNotes => role == ViewerRole.owner || role == ViewerRole.dm;
}
```

## Layouts

### Mobile (`<600w`)

Tabbed single-column layout:

```
┌─────────────────────────────┐
│  ⬅ Aragorn  (Ranger 5)      │
├─────────────────────────────┤
│  [Combat][Skills][Spells][Inv][Notes] │  (scrollable tabs)
├─────────────────────────────┤
│                             │
│  TAB CONTENT                │
│                             │
└─────────────────────────────┘
```

Combat tab top section (always visible during combat):
```
HP bar | AC | Init | Speed
Conditions chips
Action economy toggles
```

### Tablet (`600..1200w`)

Two-pane:

```
┌──────────┬───────────────────────────┐
│ Sidebar  │  Main Content             │
│ - Header │  (tab content from below) │
│ - Stats  │                           │
│ - HP/AC  │                           │
│ - Cond.  │                           │
│ - Tabs:  │                           │
│   Combat │                           │
│   Skills │                           │
│   Spells │                           │
│   Invent │                           │
│   Notes  │                           │
└──────────┴───────────────────────────┘
```

### Desktop (`>1200w`)

Three-pane:

```
┌──────────┬──────────────────┬──────────────┐
│ Sidebar  │  Main             │ Auxiliary    │
│ - Header │  Section          │              │
│ - Stats  │  e.g. Spells:     │ - Quick rolls│
│ - HP/AC  │     all spells    │ - Recent log │
│ - Cond.  │     by level      │ - Companion  │
│ - Tabs   │                   │   notes      │
└──────────┴───────────────────┴──────────────┘
```

## Tabs

### 1. Combat

- HP tracker (large)
- AC, Speed, Initiative
- Conditions
- Action economy toggles
- Quick attacks list (weapon attacks pre-computed with bonus)
- Death save tracker (only if at 0 HP)
- Buttons: Apply Damage, Apply Healing, Add Condition

### 2. Skills

- 6 ability rows with mod
- 18 skill rows: name, mod, proficiency dot
- Saves row (6)
- Passive Perception highlighted
- Tap any → roll dice

### 3. Spells

- Spell slot tracker (top)
- Cantrips section
- Levels 1-9 sections (collapsible)
- Each spell: name, school icon, cast button
- Filter: prepared only / all / by level / by source class
- "Manage Prepared" button (Wizard/Cleric/Druid/Paladin/Ranger)

### 4. Inventory

- Equipment slots view (paper doll on desktop, list on mobile)
- Carried items list (name, qty, weight)
- Total weight + carry capacity
- Currency tracker
- Add item dialog
- Drag to reorder
- Toggle equipped / attuned

### 5. Notes

- Free-text markdown notes (private to viewer)
- Backstory section
- Bonds, Ideals, Flaws fields (per background convention)
- Trinkets

### 6. Features (sub-tab or scroll section)

- Class features (per level, collapsible)
- Species traits
- Background features
- Feats taken
- Resistances/immunities
- Languages

## State Management

```dart
final activeCharacterProvider = StateNotifierProvider.autoDispose
  .family<CharacterNotifier, AsyncValue<Character>, String>((ref, characterId) {
    return CharacterNotifier(
      repo: ref.watch(characterRepositoryProvider),
      characterId: characterId,
    );
  });

class CharacterNotifier extends StateNotifier<AsyncValue<Character>> {
  // load on init
  // applyDamage, applyHealing, addCondition, ...
  // optimistic local update + persist
}
```

In online mode: also subscribes to `combat_state_broadcasts` for own combatant updates from DM.

## Edit Mode

When `canEdit`:
- Field labels become tappable.
- Tap → inline edit (number stepper, text field, dropdown).
- Save on blur or explicit confirm.
- Validation per [10](./10-character-creation-flow.md).

## Print / Export

Owner can export character sheet as:
- PDF (single-page summary; multi-page detailed).
- Plain text (for sharing in chat).
- Image (for social media).

Use `pdf` Dart package for PDF generation.

## Acceptance

- Owner sees all fields editable on mobile, tablet, desktop.
- Party member sees inventory hidden but HP visible.
- Observer sees Bloodied only, no spells/inventory/notes.
- Tablet sidebar always visible; tabs switch right pane.
- Desktop three-pane fully functional.
- Print-to-PDF button generates readable single-page summary.
- All 6 tabs functional with golden tests for stability.

## Open Questions

1. Allow DM to edit player character? → Yes, with confirmation dialog "Editing as DM."
2. Live edit conflict if player edits while DM edits? → Last-write-wins; no conflict resolution UI in MVP.
3. Stat block view shared with Monster card? → No; different shape. Common widgets only (HP tracker, conditions).
