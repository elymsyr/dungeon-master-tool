---
type: file-note
domain: projection
path: flutter_app/lib/presentation/screens/player_window/player_window_main.dart
layer: presentation
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `player_window_main.dart`

> [!abstract] Primary Purpose
> Sub-isolate entrypoint for the desktop player second window. Invoked from `main.dart` when launched with `args == ['multi_window', <id>, <payload>]`. Bootstraps the minimal services the player surface needs (AppPaths cache dir, Supabase for cloud asset rendering) and runs `PlayerWindowApp` inside its own `ProviderScope` — the DM owns the truth and pushes state via IPC.

## Inputs / Outputs
**Inputs**
- Args: `List<String> args` — `args[1]` parsed to `windowId` (`int`).
- Reads: `AppPaths.cacheDir` (via ContentStore / `assetServiceProvider`), `SupabaseConfig.url`/`anonKey`/`isConfigured`.
- Supabase / CDC: initializes `Supabase.instance` (anonymous, per-isolate) with a 3s timeout; does not subscribe to CDC here.
- Events / triggers: receives projection state via [[projection_ipc]] inside `PlayerWindowApp`.

**Outputs**
- Public API: `void playerWindowMain(List<String> args)`.
- Writes / Supabase pushed / events: none (read-only player surface).

## Dependencies & Links
- Depends on: `player_window_app.dart`, `app_paths.dart`, `supabase_config.dart` (not in allow-list); receives [[projection_state]] via [[projection_ipc]]
- Used by: `main.dart` (multi-window dispatch); pairs with [[projection_output_window]] on the DM side
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Multi-Window-IPC]]

## Key Logic / Variables
- Lives in its own isolate — no SoLoud, no shared Riverpod state with the DM. Sub-isolates have independent static fields, so `AppPaths.initialize()` MUST run here or `ContentStore` throws `LateInitializationError` when an AssetRef renders.
- Supabase init is required because image projection + battle-map backgrounds resolve AssetRefs through `assetServiceProvider`, which reads `Supabase.instance` at provider-eval time. Without it the window throws "Supabase.instance not initialized" on first cloud asset.
- Auth is per-isolate: the sub-window stays anonymous and uses the public storage URLs the DM has already prepared (via the entity image prepare step).
- Both AppPaths and Supabase init are wrapped in try/catch with `debugPrint` — failures degrade gracefully rather than crash the window.

## Notes
- Compare with [[screencast_main]] (mobile/external-display equivalent that uses a platform channel instead of `desktop_multi_window` IPC).
