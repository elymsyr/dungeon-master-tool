---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/services/beta_enter_gate.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `beta_enter_gate.dart`

> [!abstract] Primary Purpose
> Per-user, per-device sentinel (stored in SharedPreferences) recording whether the first beta-enter local→cloud merge has run successfully. Cloud→local sync appliers consult it to avoid clobbering pre-beta offline content with stale cloud rows before the initial reconciliation.

## Inputs / Outputs
**Inputs**
- Reads: SharedPreferences key `beta_first_enter_completed_at:<uid>`.
- In-memory `Map<String,bool>` cache per uid.

**Outputs**
- Provider exposed: `betaEnterGateProvider` → `Provider<BetaEnterGate>`.
- Public API: `isCompleted(uid)`, `markCompleted(uid)`, `clear(uid)`.
- Writes: SharedPreferences (sets ISO-8601 UTC timestamp on `markCompleted`; removes on `clear`).

## Dependencies & Links
- Depends on: `shared_preferences`
- Used by: `BetaEnterMergeService`, [[world_reconciler]], [[cloud_catchup_service]] (`_pullPackages`), `PersonalMirrorApplier.bootstrap`, `BetaNotifier.leaveBeta`
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[Sync-and-Realtime]], [[CDC-Sync-Flow]]

## Key Logic / Variables
- Key prefix: `'beta_first_enter_completed_at:'`; full key is prefix + uid.
- `isCompleted(uid)`: cache → SharedPreferences; "completed" = stored string is non-null & non-empty.
- `markCompleted(uid)`: stores `DateTime.now().toUtc().toIso8601String()`; caches `true`.
- `clear(uid)`: removes key; caches `false`.
- **Invariant (the whole point)**: while NOT completed, cloud→local appliers must not overwrite locally-existing rows — otherwise the user's pre-beta offline content is wiped when stale cloud rows are pulled.
- **Lifecycle**: unset on fresh install / after `clear`; set by `BetaEnterMergeService.merge()` on success (PR-B2); cleared by `BetaNotifier.leaveBeta()` so a re-enter re-runs the local-wins merge against possibly-new local content.

## Notes
- Per-device, not synced — each device runs its own first-enter merge once. Part of the Beta Data-Loss Fix (May 26) work.
