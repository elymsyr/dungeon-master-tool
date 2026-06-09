---
type: file-note
domain: combat-vtt
path: flutter_app/lib/application/services/fog_externalizer.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `fog_externalizer.dart`

> [!abstract] Primary Purpose
> F9 helper that externalizes large fog-of-war PNGs off the sync payload. `Encounter.fogData` normally rides as a base64 PNG string inside `combat_state`. For large fog (>200KB) this helper decodes the base64, uploads the bytes to R2 via `AssetService` as a `dmt-asset://` ref (SHA-deduped — identical fog re-uploads are skipped cloud-side), and returns the ref so the caller can store the small URI instead of the big blob. MVP — caller wiring in `battle_map_notifier` was deferred; the sync engine still pushes `fogData` as base64 by default, with this as an opt-in path.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AssetService? assetService`, `String campaignId`.
- Reads: takes a `fogBase64` string argument (not a DB read).
- Supabase / CDC / Events: none directly — uploads via `AssetService`.
- Triggers: caller-driven; intended to be invoked from `battle_map_notifier` after a fog state update behind a 500ms debounce.

**Outputs**
- Public API: `fogExternalizerProvider` (`Provider.family<FogExternalizer, String campaignId>`). Methods: `externalize(fogBase64) -> Future<String?>`; static `isExternalRef(value) -> bool`.
- Writes: a temporary file in `getTemporaryDirectory()` (`fog_<sha>.png`), deleted in a `finally`; uploads to R2 via `AssetService.uploadAsset(kind: MediaKind.battleMap)`.
- Supabase pushed / RPC: none directly (R2 upload through the asset service).
- Events emitted: none.

## Dependencies & Links
- Depends on: [[entity_image_upload]], [[free_media_service]], [[Media-Storage-Tiers]]
- Used by: [[combat_provider]], [[grid_canvas]]
- Domain map: [[Combat-and-VTT]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Media-Storage-Tiers]]

## Key Logic / Variables
- `sizeThresholdBytes = 200 * 1024` — fog smaller than this stays base64 (round-trip upload isn't worth it); `externalize` returns `null` so the caller leaves it inline.
- `debounceWindow = Duration(milliseconds: 500)` — the value the caller's `_fogUploadDebouncer` is expected to use.
- `externalize` flow: empty input → null; null asset service → null; `base64Decode` (errors caught → null); bytes `< sizeThresholdBytes` → null; else `sha256` of bytes → write temp file `fog_<sha>.png` → `uploadAsset(campaignId, kind: battleMap)` → return `uri.toString()`. Temp file always deleted in `finally`. SHA is the dedupe key (same fog → same asset).
- `isExternalRef(value)`: true if value starts with `AssetRef.scheme` (`dmt-asset://`), `publicScheme`, or `transientScheme` — used to distinguish an already-externalized fog field from a raw base64 blob.

## Notes
- MVP — header states `battle_map_notifier` wiring is a follow-up PR; default sync still pushes fog as base64.
- Provider is `.family` keyed by `campaignId` (the worldId).
