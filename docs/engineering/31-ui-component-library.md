# 31 — UI Component Library (D&D 5e Specific)

> **For Claude.** Reusable widgets specific to D&D 5e mechanics.
> **Target:** `flutter_app/lib/presentation/widgets/dnd5e/`

## Component List

### 1. `AbilityScoreInput`

Edit a single ability score with constraints (point-buy cost shown, standard array slot, raw entry).

```dart
class AbilityScoreInput extends StatelessWidget {
  final Ability ability;
  final int currentScore;
  final ValueChanged<int> onChanged;
  final AbilityScoreInputMode mode;        // standardArray | pointBuy | freeEntry
  final List<int>? availableValues;        // for standardArray mode
  final int? pointBuyRemainingPoints;
  // ...
}

enum AbilityScoreInputMode { standardArray, pointBuy, freeEntry, fixed }
```

- **standardArray:** dropdown of remaining unused values from [15,14,13,12,10,8].
- **pointBuy:** +/- buttons; disabled if can't afford / score out of [8,15].
- **freeEntry:** integer text field; validate [1,30].
- **fixed:** read-only display + computed modifier badge.

Display: `STR: 16 (+3)` style with mod auto-calculated.

### 2. `DiceRoller`

```dart
class DiceRoller extends StatefulWidget {
  final DiceExpression expression;
  final String? label;
  final ValueChanged<DiceRollResult>? onRoll;
  final bool showHistory;
  final AdvantageState? advantageState;
}
```

- Tap → roll → animate + show result.
- Long-press → set advantage/disadvantage modifier.
- Context menu: re-roll, copy result, export to chat.
- Optional history strip (last N rolls).

### 3. `SpellSlotTracker`

```dart
class SpellSlotTracker extends StatelessWidget {
  final SpellSlots slots;                  // current/max per level 1-9
  final PactMagicSlots? pactSlots;
  final void Function(int level)? onSpend;
  final void Function(int level)? onRestore;
  final bool readOnly;                     // true for player viewing other PC
}
```

Layout: 9 boxes per level, filled = current, empty = spent. Tap to spend; long-press to restore one.

Pact magic shown as separate row.

### 4. `HpTracker`

```dart
class HpTracker extends StatelessWidget {
  final int current;
  final int max;
  final int temp;
  final VoidCallback? onApplyDamage;
  final VoidCallback? onApplyHealing;
  final bool bloodied;        // current ≤ max/2
  final bool unconscious;
  final bool dead;
  final DeathSaves? deathSaves;
}
```

Visual:
```
[████████████░░░░░░░] 35/50  (+8 temp)
                                Bloodied indicator (small heart icon when current ≤ max/2)
                                Death saves: ●○○ ✕✕○ (if at 0 HP)
```

### 5. `ConditionBadge`

```dart
class ConditionBadge extends StatelessWidget {
  final Condition condition;
  final int? remainingRounds;
  final int? exhaustionLevel;     // for Exhaustion only
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
}
```

Color-coded chip with icon, condition name, optional duration. Tap → tooltip with full effect description.

### 6. `ConditionPicker`

```dart
class ConditionPicker extends StatelessWidget {
  final Set<Condition> active;
  final ValueChanged<Condition> onAdd;
  final ValueChanged<Condition> onRemove;
}
```

Grid of all 15 conditions. Active ones highlighted. For Exhaustion: prompt for level (1-6) on add.

### 7. `StatBlockCard`

```dart
class StatBlockCard extends StatelessWidget {
  final Monster monster;            // or Character
  final ViewerRole viewerRole;       // dm sees full; player sees redacted
  final bool compact;                // mobile mode
}
```

Renders standard SRD stat block layout:
- Header: name, size, type, alignment
- AC, Initiative, HP, Speed
- Ability score grid (6 boxes)
- Skills, resistances, immunities, senses, languages, CR
- Traits (collapsible)
- Actions (collapsible)
- Bonus Actions, Reactions, Legendary Actions

Compact mode (mobile): tabs for sections.

### 8. `AoEMarkerOverlay`

```dart
class AoEMarkerOverlay extends StatelessWidget {
  final AreaOfEffect aoe;
  final GridCell origin;
  final GridDirection direction;
  final Color color;
  final double opacity;
  final String? label;
}
```

Render translucent shape over battlemap canvas. Used in spell preview + committed markers.

### 9. `WeaponMasteryChip`

```dart
class WeaponMasteryChip extends StatelessWidget {
  final WeaponMastery mastery;
  final bool active;        // does combatant have Weapon Mastery feature?
}
```

Small badge showing mastery name with tooltip describing effect (Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex).

### 10. `RestPanel`

```dart
class RestPanel extends StatelessWidget {
  final Character character;
  final VoidCallback onShortRest;
  final VoidCallback onLongRest;
}
```

Two big buttons: "Short Rest" and "Long Rest." On Short Rest: prompt to spend Hit Dice (interactive). On Long Rest: confirmation dialog showing what will be restored.

### 11. `InitiativeOrderList`

```dart
class InitiativeOrderList extends StatelessWidget {
  final List<Combatant> combatants;
  final int activeIndex;
  final void Function(int index) onCombatantTap;
  final VoidCallback? onAddCombatant;
}
```

Vertical list ordered by initiative desc. Active turn highlighted with arrow + accent border. Each row: portrait/icon, name, init, HP bar, condition icons.

### 12. `CharacterPortrait`

```dart
class CharacterPortrait extends StatelessWidget {
  final String? imageUrl;
  final String fallbackName;     // for initials
  final double size;
  final bool circular;
}
```

Falls back to initials in colored circle if no image.

### 13. `ActionEconomyToggleRow`

```dart
class ActionEconomyToggleRow extends StatelessWidget {
  final TurnState state;
  final ValueChanged<TurnState> onChanged;
}
```

Three toggles: Action / Bonus / Reaction. Used + auto-reset on turn start.

### 14. `SpellListView`

```dart
class SpellListView extends StatelessWidget {
  final List<Spell> spells;
  final Set<String> preparedIds;
  final void Function(Spell) onCast;
  final void Function(Spell) onTogglePrepared;
  final bool grouped;        // group by level
  final bool compact;
}
```

Searchable, filterable spell list. Tap → spell detail modal. Prepared spells highlighted.

### 15. `SpellDetailModal`

```dart
class SpellDetailModal extends StatelessWidget {
  final Spell spell;
  final SpellCastReadiness? castReadiness;   // for "Cast" button
  final VoidCallback? onCast;
}
```

Full spell info per SRD format: level/school, casting time, range, components, duration, description, "At Higher Levels" section. "Cast" button if available.

### 16. `EquipmentSlotsView`

```dart
class EquipmentSlotsView extends StatelessWidget {
  final Inventory inventory;
  final void Function(InventoryEntry) onToggleEquipped;
  final void Function(InventoryEntry) onToggleAttuned;
}
```

Visual character "paper doll" or list view: head, body (armor), main hand, off hand, etc.

### 17. `XpBar`

```dart
class XpBar extends StatelessWidget {
  final int currentXp;
  final int currentLevel;
}
```

Progress bar showing XP between current and next level threshold.

### 18. `SaveBadge`

```dart
class SaveBadge extends StatelessWidget {
  final Ability ability;
  final int modifier;
  final bool proficient;
  final VoidCallback? onRoll;
}
```

Small chip showing save name + modifier + proficiency dot.

### 19. `SkillRow`

```dart
class SkillRow extends StatelessWidget {
  final Skill skill;
  final int modifier;
  final Proficiency profLevel;     // none | half | full | expertise
  final VoidCallback? onRoll;
}
```

Single row in skill list with proficiency indicator (○ none, ◐ half, ● full, ◉ expertise).

### 20. `LanguageChip`

```dart
class LanguageChip extends StatelessWidget {
  final Language language;
  final bool removable;
}
```

### 21. `BackgroundPickerCard`, `SpeciesPickerCard`, `ClassPickerCard`, `AlignmentPickerCard`, `EquipmentBundleCard`

Used in character creation wizard ([10](./10-character-creation-flow.md)). Each: title, description, key facts, selected state, tap to choose.

### 22. `ConcentrationIndicator`

```dart
class ConcentrationIndicator extends StatelessWidget {
  final Concentration? concentration;
  final VoidCallback? onEnd;
}
```

Small indicator at top of combatant card: "Concentrating: Bless (3 rounds)". Tap → end button.

### 23. `RechargeBadge`

```dart
class RechargeBadge extends StatelessWidget {
  final RechargeRule rule;     // 'X/Day' | 'Recharge X-Y' | 'Short Rest' | 'Long Rest'
  final int? usesRemaining;
  final int? maxUses;
}
```

Small label showing recharge state for monster abilities and feature uses.

### 24. `BattleMapToolbar`

```dart
class BattleMapToolbar extends StatelessWidget {
  final BattleMapTool currentTool;
  final ValueChanged<BattleMapTool> onChange;
  final ViewerRole role;
}
```

Tool palette: pan, draw, erase, measure, fog brush (DM only), AoE preview. Different tool set per role.

## Conventions

- All widgets: `const` constructor where possible.
- Named parameters preferred.
- Required props with `required` keyword.
- Use `ConsumerWidget` from Riverpod when widget needs state.
- Test each component in `test/presentation/widgets/dnd5e/` with at least 1 golden test.

## Theming

Each component reads from `Theme.of(ctx)`. No hardcoded colors. Define D&D-specific extension:

```dart
extension Dnd5eThemeColors on ThemeData {
  Color get bloodiedColor => brightness == Brightness.dark ? Colors.red.shade400 : Colors.red.shade700;
  Color get healingColor  => Colors.green;
  Color get spellSlotFilledColor => colorScheme.primary;
  Color get spellSlotEmptyColor  => colorScheme.outlineVariant;
  Color get conditionBadgeColor(Condition c) => /* per-condition palette */;
}
```

## Acceptance

- All 24 components in `flutter_app/lib/presentation/widgets/dnd5e/`.
- Each compiles standalone with example usage in `examples/` (or in widget tests).
- Each works on mobile + desktop layouts.
- Golden tests for visual stability.

## Open Questions

1. Use `flutter_svg` for icons or Material icons? → MVP: Material icons. Custom icons later.
2. Animation library: Flutter built-in or `flutter_animate`? → Built-in for now; `flutter_animate` if more complex sequences needed.
3. Drag-drop library for inventory rearrange? → Built-in `Draggable`/`DragTarget`. Sufficient.
