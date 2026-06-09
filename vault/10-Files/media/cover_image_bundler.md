---
type: file-note
domain: media
path: flutter_app/lib/application/services/cover_image_bundler.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `cover_image_bundler.dart`

> [!abstract] Primary Purpose
> A tiny static helper that embeds a metadata map's `cover_image_path` as base64 inside the cloud backup envelope, and reconstructs it to a local file on restore. Shared across Worlds / Packages / Templates / Characters. This is the **legacy/local-envelope** cover path — when the cover is already a portable ref (`dmt-public://` / `dmt-asset://`) it is left untouched (handled by the storage-tier services instead).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — two `static` methods, mutate the passed metadata map.
- Reads: `metadata['cover_image_path']` (local file) on bundle; `metadata['cover_image_data']` (base64) + `cover_image_ext` on restore.
- Supabase / CDC subscribed: none.
- Events consumed: none.
- Triggers: cloud backup upload (bundle) and restore/import (restore).

**Outputs**
- Public API: `bundle(metadata)` (mutates: adds `cover_image_data` + `cover_image_ext`); `restore({metadata, destDir, itemId})` → `String?` new local path.
- Writes (Drift tables): none — writes `{itemId}_cover{ext}` file under `destDir` on restore.
- Supabase pushed: none (base64 rides inside the backup envelope).
- Events emitted: none.

## Dependencies & Links
- Depends on: `dart:convert` (base64), `dart:io`, `path`
- Used by: world/package/template/character cloud backup + restore flows
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Media-and-Assets]]

## Key Logic / Variables
- **Schema:** `cover_image_path` (local path, pre-upload) ↔ `cover_image_data` (base64, in envelope) + `cover_image_ext` (`.png`/`.jpg`).
- **`bundle`:** if path is empty / not a string → no-op. **If path starts with `dmt-`** → it's a portable ref, leave it in the envelope as-is (no base64). Otherwise read file bytes → `base64Encode` into `cover_image_data`, store extension.
- **`restore`:** decode `cover_image_data` → write to `{destDir}/{itemId}_cover{ext}` → **remove** `cover_image_data`/`cover_image_ext` from metadata and set `cover_image_path` to the new local path; return it. Returns null if no base64 present.
- **Invariant:** everything is wrapped best-effort (`catch (_)`) — cover bundling must never corrupt the main backup.

## Notes
- Comments Turkish. Distinct from [[free_media_service]] cover uploads: this is the offline/local base64 envelope path, used when no portable cloud ref exists.
