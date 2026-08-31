---
type: file-note
domain: content-pipeline
path: flutter_app/tool/content/convert_blueprint.dart
layer: tool
language: dart
status: stable
updated: 2026-08-31
tags: [file]
---

# `convert_blueprint.dart`

> [!abstract] Primary Purpose
> Offline CLI that validates a bundled world's blueprints and emits its `.pkg.json`.
> Moved from `tool/content/` to `flutter_app/tool/content/` on 2026-08-31 so it can
> import the app package — which is what lets it check every ref against the real
> SRD 5.2.1 pack instead of guessing.

## Inputs / Outputs
**Inputs**
- `--dir <world dir>` (required), `--out <file>`, `--check` (validate only).
- `<dir>/manifest.json`, `world-blueprint.json`, `blueprint.json`, and the media files on disk.

**Outputs**
- Issue report on stderr, entity counts on stdout.
- `<dir>/<slug>.pkg.json` unless `--check`.
- **Exit 1 on any error**, 64 on bad usage, 66 on a missing manifest.

## Dependencies & Links
- Depends on: [[world_blueprint_converter]], [[builtin_content_names]]
- Sibling install path: [[bundled_worlds_installer]]
- Domain map: [[Content-Pipeline]]
- Authoring rules: `tool/content/README.md`, `tool/content/WORLD_CONTENT_ORDER.md`

## Key Logic / Variables
- Run from `flutter_app/`: `dart run tool/content/convert_blueprint.dart --dir assets/worlds/<dir> --check`.
- `mediaResolver` returns the path unchanged when the file exists — pkg/zip paths must stay relative; the check is presence only.
- Non-zero exit is the point: an unresolved soft ref is dropped silently at read time, so the build is the only place the failure can surface. Mirrors `build_packs`'s `_ref` gate.

## Notes
- `test/domain/services/bundled_worlds_blueprint_test.dart` runs the same validation in CI for every world in `assets/worlds/manifest.json`.
