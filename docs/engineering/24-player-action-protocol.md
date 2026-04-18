# 24 — Player Action Protocol

> **For Claude.** Player declares spell/action via visual marker on battlemap. DM resolves manually (MVP).
> **Source:** [12-spell-system-spec](./12-spell-system-spec.md), [21-realtime-protocol](./21-realtime-protocol.md)
> **Target:** `flutter_app/lib/application/online/player_action/`

## Action Types Supported (MVP)

```dart
enum PlayerActionType {
  spellCast,          // player declares casting a spell with AoE preview
  attackDeclared,     // player declares attacking a target (no auto-roll)
  movementDeclared,   // player declares moving a token (no auto-apply)
  aoeMarker,          // pure visual marker (e.g., "I'd cast Fireball here if I could")
  conditionUsed,      // player toggles their own condition (e.g., Rage active)
}
```

**MVP excludes:**
- Auto-roll attack/damage.
- Auto-decrement spell slot.
- Auto-apply damage to enemies.

These are placeholder TODO blocks for the auto-combat phase.

## Payload Shapes

```dart
sealed class PlayerActionPayload {}

class SpellCastPayload extends PlayerActionPayload {
  final String spellId;
  final int slotLevelChosen;
  final GridCell origin;
  final GridDirection? direction;       // for Cone/Line/Cube
  final List<String> manuallyPickedTargetIds;   // optional
  final String? notes;
}

class AttackDeclaredPayload extends PlayerActionPayload {
  final String? weaponId;
  final String? attackName;             // for monster-style listed attacks
  final String targetCombatantId;
  final String? notes;
}

class MovementDeclaredPayload extends PlayerActionPayload {
  final String tokenId;
  final TokenPosition fromPos;
  final TokenPosition toPos;
  final double distanceFt;
  final List<TokenPosition> waypoints;  // if path-drawn
}

class AoEMarkerPayload extends PlayerActionPayload {
  final AoEShape shape;                 // serialized AoE
  final GridCell origin;
  final GridDirection? direction;
  final String label;                   // e.g., "If we get cornered, fireball here"
  final int? autoExpiresAfterRounds;    // optional countdown
}

class ConditionUsedPayload extends PlayerActionPayload {
  final String conditionEffectId;       // 'barbarian:rage'
  final bool activate;                  // true=on, false=off
}
```

All payloads serialize to `player_actions.payload_json`.

## Player UI: Cast Flow

`presentation/screens/dnd5e/character/spell_cast_dialog.dart`

```
Player taps spell from spellbook → "Cast" dialog opens:

┌────────────────────────────────────────┐
│  Cast: Fireball                         │
│  Level 3 Evocation, 1 action            │
│  Range: 150 ft                          │
│  Components: V, S, M (bat guano)        │
│  Effect: 8d6 fire, DEX save half        │
├────────────────────────────────────────┤
│  Slot to use:  [ Level 3 ▼ ]            │
│      (4 of 4 remaining at L3)            │
│                                          │
│  ☐ Cast as ritual                        │
│                                          │
│  Notes: [optional]                       │
│                                          │
│  [ Place AoE on Battlemap → ]           │
└────────────────────────────────────────┘
```

After "Place AoE":
- Battlemap tab opens.
- Cursor switches to AoE placement mode.
- Tap origin → AoE preview overlay (per [12 §AoE](./12-spell-system-spec.md#aoe-geometry)).
- Drag direction handle if Cone/Line.
- "Confirm" button at bottom.

On Confirm:
1. Insert `player_actions` row.
2. Realtime broadcast → DM screen shows notification.
3. Local UI: spell slot **NOT** decremented (MVP — DM controls).
4. Marker visible to all players + DM until DM acks.

## DM UI: Action Resolution

DM sees pending actions in a side panel:

```
┌──── Pending Player Actions ──────┐
│  Aragorn: Cast Fireball (L3)      │
│   AoE: 20 ft sphere @ (15, 22)    │
│   Affects: 3 goblins              │
│   [ Acknowledge ] [ Reject ]      │
│                                    │
│  Legolas: Attack Goblin Boss      │
│   Weapon: Longbow                 │
│   [ Acknowledge ] [ Reject ]      │
└────────────────────────────────────┘
```

**Acknowledge:** DM rolls attack/save/damage manually using combat tracker. Updates `player_actions.status = 'acknowledged'`. Marker stays visible until resolved.

**Resolve:** after applying mechanical effects, DM clicks "Resolve" → `status = 'resolved'`. Marker fades out.

**Reject:** DM disagrees with the declaration (e.g., out of range). `status = 'rejected'`. Player gets toast.

## Marker Rendering on Battlemap

Pending markers overlay the battlemap with author label + AoE shape:

```
[colored translucent AoE shape]
  ╲
   "Aragorn → Fireball"  (player username + spell)
```

Color per author (consistent within session).

Markers fade out at status transitions:
- `pending`: fully visible.
- `acknowledged`: 75% opacity + checkmark badge.
- `resolved`: fade out over 2 seconds.
- `rejected`: red flash + immediate fade.

## Movement Declaration

Player drags own token:
1. Live preview path with snake-line + ft counter.
2. Snap to grid.
3. On release: insert `player_actions` of type `movement_declared`.
4. DM sees notification with "Aragorn moves 30 ft (Speed: 30/30 used)".
5. DM acknowledges → DM updates token position in canonical battlemap state → broadcast.

**Self-validation client-side:**
- Distance ≤ remaining movement.
- Path doesn't cross walls (if grid has barrier metadata).
- Difficult terrain doubles cost.

If client-side check fails → don't send action; show inline error.

## Condition Self-Toggle

Player can toggle their own condition states (e.g., Rage on/off, Patient Defense activate). Independent of DM:

```dart
Future<void> toggleCondition(String effectId, bool active) async {
  // 1. Update local Combatant state.
  // 2. Broadcast via player_actions for transparency.
  await supabase.from('player_actions').insert({
    'session_id': sessionId,
    'author_user_id': userId,
    'encounter_id': encounterId,
    'action_type': 'condition_used',
    'payload_json': ConditionUsedPayload(conditionEffectId: effectId, activate: active).toJson(),
    'status': 'resolved',     // self-resolving
  });
}
```

DM sees notification: "Aragorn entered Rage." but doesn't need to act.

## Status Workflow

```
Insert (status=pending)
   ↓
DM views in panel
   ↓
DM clicks Acknowledge → status=acknowledged
   ↓
DM resolves mechanically (rolls dice, applies HP change, decrements player slot via combat tracker)
   ↓
DM clicks Resolve → status=resolved
   ↓
Marker fades; row stays in DB for session log
```

Or:
```
DM clicks Reject → status=rejected → player toast → marker red-fade
```

## Player Notification of Resolution

Player subscribes to own `player_actions` rows:

```dart
class PlayerActionsNotifier extends StateNotifier<List<PlayerActionRow>> {
  // Subscribe to player_actions where author_user_id = self.id
  // On status change to 'resolved' or 'rejected': trigger toast + marker fade.
}
```

## Manual DM-Side Effect Application

When DM acknowledges a Spell Cast:
1. DM opens combat tracker.
2. Selects affected combatants (DM's choice, perhaps influenced by AoE marker).
3. Applies damage / saves via existing damage resolver pipeline ([13](./13-damage-resolver-spec.md)).
4. Optionally decrements player's spell slot via player's character sheet (DM has edit access).

**No automatic linkage** in MVP. DM's discretion.

## Future: Auto-Resolve

Out of MVP. Will require:
- Auto-decrement spell slot on player commit.
- Auto-roll attack/save/damage.
- Auto-apply HP changes to affected combatants.
- Sync mechanical state (HP, slots) back to player view.
- Anti-cheat: server-side dice rolling? Or trust + audit log?

Spec for that lives in a future doc once auto-combat scope is decided.

## Acceptance

- Player casts Fireball → AoE preview appears on player's battlemap → confirm → marker broadcasts to DM + 7 other players within 500 ms.
- DM sees pending action in side panel.
- DM acknowledges → marker shows checkmark badge.
- DM resolves → marker fades.
- Spell slot NOT decremented automatically (verified in player's spellbook).
- Player drags own token → declared movement broadcast → DM accepts → token moves on all clients.
- Player toggles Rage → broadcast immediately resolved (no DM action needed).

## Open Questions

1. Should there be a "DM auto-acknowledge" toggle? → **No (MVP).** Force DM intent. Can add later.
2. Action history persisted as session log for review? → **Yes.** All `player_actions` rows kept until session closed; queryable for log view.
3. Player-vs-player actions (e.g., Bardic Inspiration on ally)? → Same flow; payload includes `recipientCombatantId`. DM acknowledges as usual.
