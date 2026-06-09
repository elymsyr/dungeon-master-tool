---
type: file-note
domain: deployment
path: flutter_app/pubspec.yaml
layer: core
language: yaml
status: stable
updated: 2026-06-09
tags: [file]
---

# `pubspec.yaml`

> [!abstract] Primary Purpose
> The Flutter package manifest for `dungeon_master_tool` (version `12.0.0`, SDK `^3.11.4`). Declares all runtime/dev dependencies, the codegen toolchain, the bundled asset list, and the launcher-icon config. Notable: the ~32MB Open5e packs are deliberately EXCLUDED from production builds, and official package banners are NOT bundled (they download from R2).

## Inputs / Outputs
**Inputs**
- Consumed by `flutter pub get`, `dart run build_runner build`, and `flutter build` in CI ([[ci-build]], [[ci-analyze-test]]).

**Outputs**
- The dependency closure and generated code that the whole app links against.
- Bundled assets reachable via `rootBundle`.

## Dependencies & Links
- Depends on:
- Used by: [[ci-build]], [[ci-analyze-test]], [[analysis_options]]
- Domain map: [[Deployment-and-Ops]]
- System flow:
- Spec / reference: [[Platform-Targets]], [[Audio-SoLoud]]

## Key Logic / Variables
**Key runtime deps (with their role):**
- State / models: `flutter_riverpod` + `riverpod_annotation`, `freezed_annotation`, `json_annotation`.
- Storage / DB: `drift` + `sqlite3_flutter_libs` (Drift = the Supabase Postgres mirror, see [[drift_database]]), `msgpack_dart`, `shared_preferences`, `path_provider`, `path`.
- Routing: `go_router`. Fonts: `google_fonts`.
- Desktop multi-window (projection second screen): `window_manager`, `desktop_multi_window`, `screen_retriever` (see [[Multi-Window-IPC]]).
- Audio: `flutter_soloud` (gapless game-audio engine; needs `libasound2-dev` on Linux CI — see [[Audio-SoLoud]]). `yaml` parses soundpad theme configs.
- Online: `supabase_flutter` (auth + Postgres + storage), `connectivity_plus` (SyncEngine wake-on-online), `package_info_plus` (runtime app version → admin heartbeat).
- Utility/UI: `uuid`, `crypto`, `intl`, `logger`, `url_launcher`, `collection`, `file_picker`, `flutter_markdown`, `pdfrx`, `cupertino_icons`.

**Codegen toolchain (dev_dependencies):**
- `build_runner` orchestrates: `freezed`, `riverpod_generator`, `json_serializable`, `drift_dev`. `custom_lint` + `riverpod_lint` add lints. Test/mocking: `flutter_test`, `mocktail`. `flutter_lints` ^6.0.0 (base for [[analysis_options]]). `flutter_launcher_icons` generates icons.
- CI MUST run `dart run build_runner build --delete-conflicting-outputs` after `pub get` (generated files are gitignored).

**Asset bundling (`flutter.assets`), with key constants:**
- `generate: true` (l10n), `uses-material-design: true`.
- Always bundled: `assets/app_icon_transparent.png`, `assets/profanity/`, `assets/first_party/` (catalog index = offline fallback for the R2 catalog), and exactly two banners: `assets/first_party/banners/dnd5e-template.jpg` and `dnd5e-package-builtin.jpg`.
- **Deliberately commented out**: `assets/open5e_packs/` — the ~32MB Open5e import packs (BB-1). Only consumer is the hidden admin "Install bundled asset packs" toggle; normal releases ship ~32MB smaller. A maintainer uncomments this line for the dev/admin build.
- Official package banners are NOT bundled — they download from `{worker}/catalog/banners/<slug>.png` (see [[catalog-publish-ops]]).

**Launcher icons:** `flutter_launcher_icons` generates for android/windows(256px)/macos/linux from `assets/app_icon.png`; iOS generation disabled.

## Notes
- Version `12.0.0` aligns with the v12 fresh Drift schema (full Drift migration). `intl: any` is unpinned (resolved by Flutter SDK constraint).
