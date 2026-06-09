---
type: file-note
domain: deployment
path: .github/workflows/build.yml
layer: backend
language: yaml
status: stable
updated: 2026-06-09
tags: [file]
---

# `ci-build.yml`

> [!abstract] Primary Purpose
> "Flutter Build and Release" workflow — builds release artifacts for all five platforms (Android APK, Windows, Linux, iOS, macOS) and, on a published GitHub Release, attaches them to that release. On manual dispatch it instead uploads each as a CI artifact. Every build injects backend config via `--dart-define` from repo secrets.

## Inputs / Outputs
**Inputs**
- Triggers: `release` (`types: [published]`) and `workflow_dispatch`.
- `permissions: contents: write` (needed to attach assets to the release).
- Env: `FLUTTER_VERSION: "3.41.6"`, `WORKING_DIR: flutter_app`.
- Secrets consumed: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `DMT_WORKER_URL` (all passed as `--dart-define`); Android signing — `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`; `GITHUB_TOKEN` for release upload.

**Outputs**
- Release assets (on `release`): `DungeonMasterTool-Android.apk`, `-Windows.zip`, `-Linux.zip`, `-iOS.ipa`, `-MacOS.zip`.
- CI artifacts (on `workflow_dispatch`): same names as upload-artifact bundles.

## Dependencies & Links
- Depends on: [[pubspec]], [[dart-define-reference]]
- Used by:
- Domain map: [[Deployment-and-Ops]]
- System flow:
- Spec / reference: [[Platform-Targets]]

## Key Logic / Variables
- Five parallel jobs, each with the same prelude: checkout → `subosito/flutter-action@v2` (3.41.6, stable, cached) → `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs`.
- All `flutter build` invocations append the three `--dart-define` flags (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `DMT_WORKER_URL`) — these compile-time consts are how the app gets its backend config (see [[dart-define-reference]]).
- Per-platform specifics:
  - **build-android** (`ubuntu-22.04`): `setup-java@v4` zulu 17; restores keystore by base64-decoding `ANDROID_KEYSTORE_BASE64` into `android/upload.jks` and writing `android/key.properties`. HARD-FAILS (`exit 1`) if `ANDROID_KEYSTORE_BASE64` is empty, to prevent shipping a debug-signed release. `flutter build apk --release`.
  - **build-windows** (`windows-2022`): `flutter build windows --release`; `Compress-Archive` the `Release/` runner dir.
  - **build-linux** (`ubuntu-22.04`): apt installs `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libasound2-dev` (the last is for `flutter_soloud` audio). `flutter build linux --release`; zips the `bundle` dir.
  - **build-ios** (`macos-14`): `flutter build ios --release --no-codesign`; manually packages `Runner.app` into a `Payload/` and zips to a `.ipa` (unsigned).
  - **build-macos** (`macos-14`): `flutter build macos --release`; zips `Dungeon Master Tool.app`.
- Upload split: `if: github.event_name == 'release'` → `softprops/action-gh-release@v2`; `if: github.event_name == 'workflow_dispatch'` → `actions/upload-artifact@v4`.

## Notes
- The Open5e ~32MB packs are NOT bundled in these release builds (see [[pubspec]] — the `assets/open5e_packs/` line is commented out). Official package banners also are not bundled; they download from R2.
