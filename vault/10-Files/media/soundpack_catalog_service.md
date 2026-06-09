---
type: file-note
domain: media
path: flutter_app/lib/data/services/soundpack_catalog_service.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `soundpack_catalog_service.dart`

> [!abstract] Primary Purpose
> Fetches the curated soundpack catalog manifest (from GitHub / a CDN) and downloads soundpack files into the local soundpad root. Uses the native `dart:io` `HttpClient` (no `http`/`dio` dependency), mirroring `AssetService`/`FreeMediaService`. Handles two pack kinds — self-contained **themes** and shared-root **libraries** — with atomic writes, path-traversal guards, rollback on failure, and offline-collapsing error semantics.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: optional `HttpClient` (defaults to `HttpClient()`).
- Reads: manifest URL `soundpackManifestUrl` (from `core/constants.dart`); per-file URLs `${entry.baseUrl}${rel}`. Local FS to check `isInstalled` (theme dir exists).
- Supabase / CDC subscribed: none.
- Events consumed: none.
- Triggers: invoked from the soundpack browser/install UI.

**Outputs**
- Providers / public API exposed: `fetchManifest()` → `List<SoundpackCatalogEntry>`; `isInstalled(entry, root)`; `downloadPack(entry, root, {onProgress})` → `(bool ok, String message)`.
- Writes (Drift tables): none — writes audio files to disk under `soundpadRoot`.
- Supabase pushed / RPC called: none.
- Events emitted: none.

## Dependencies & Links
- Depends on: [[soundpad_loader]] (`SoundpadLoader.mergeLibraryEntries` for library packs), `domain/entities/audio/soundpack_catalog.dart` (`SoundpackCatalogEntry`, `SoundpackKind`), `core/constants.dart` (`soundpackManifestUrl`), `core/utils/error_format.dart` (`OfflineException`, `isOfflineError`)
- Used by: soundpack catalog UI; downloaded library entries feed [[soundpad_loader]] / [[soundpad_engine]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Audio-SoLoud]]

## Key Logic / Variables
- **Manifest fetch.** GETs JSON, expects `{ "packs": [...] }`, maps each to `SoundpackCatalogEntry.fromJson`, keeps `isValid` ones. A **404 manifest → returns empty list** (catalog not published yet, not an error).
- **Two install layouts** keyed on `entry.kind`:
  - `SoundpackKind.theme` → installs under a per-pack dir `{root}/{id}/`; the bundled `theme.yaml` is auto-discovered later by `loadAllThemes`.
  - `SoundpackKind.library` → files land at declared paths directly under `{root}/`, then `entry.entries` (ambience/sfx) are merged into `soundpad_library.yaml` via `SoundpadLoader.mergeLibraryEntries`.
- **Atomic per-file write:** download bytes → write `{dest}.tmp` (flush) → `rename` to final. `onProgress(done, total)` reported per file.
- **Path-traversal guard:** `p.isWithin(destRoot, destPath)` must hold or it throws — a malformed manifest cannot escape the install dir.
- **Rollback on failure (`_cleanup`):** theme packs own their dir → delete it wholesale; library packs share root → only delete the files actually written.
- **Offline semantics:** `_get` maps `SocketException`/`HandshakeException`/`TimeoutException` → `OfflineException`; any other non-200 throws `SoundpackCatalogException(statusCode, url)` — deliberately NOT `HttpException`, so `isOfflineError` will not mislabel a 404 as "you're offline". `_timeout = 20 s`.

## Notes
- Result-tuple convention `(bool, String)` matches the soundpad loader API.
- `OfflineException` propagates so the UI collapses it into the single "You're offline" state (see [[free_media_service]] / offline-guard pattern).
