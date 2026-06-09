---
type: file-note
domain: deployment
path: .github/workflows/analyze-test.yml
layer: backend
language: yaml
status: stable
updated: 2026-06-09
tags: [file]
---

# `ci-analyze-test.yml`

> [!abstract] Primary Purpose
> Manual-only GitHub Actions workflow that runs `flutter analyze` and `flutter test` on the `flutter_app` package, uploading the logs as artifacts. It is never triggered automatically — it only runs via the Actions "Run workflow" button (`workflow_dispatch`), with two boolean toggles to selectively skip analyze and/or test.

## Inputs / Outputs
**Inputs**
- Triggers: `workflow_dispatch` only (manual). Inputs `run_analyze` (default true), `run_tests` (default true), both `boolean`.
- Env: `FLUTTER_VERSION: "3.41.6"`, `WORKING_DIR: flutter_app`.
- Reads: the `flutter_app` package source (checked out via `actions/checkout@v4`).

**Outputs**
- Artifact `analyze-log` → `flutter_app/analyze.log` (30-day retention).
- Artifact `test-results` → `flutter_app/test-results/` containing `test.json` (`--machine`) and `test.log` (`--reporter=expanded`), 30-day retention.

## Dependencies & Links
- Depends on: [[pubspec]], [[analysis_options]]
- Used by: [[ci-build]]
- Domain map: [[Deployment-and-Ops]]
- System flow:
- Spec / reference:

## Key Logic / Variables
- Two independent jobs, both on `ubuntu-22.04`, each gated by `if: ${{ inputs.run_analyze }}` / `if: ${{ inputs.run_tests }}`.
- Shared setup in both jobs: `subosito/flutter-action@v2` (version `3.41.6`, channel `stable`, `cache: true`) → `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` (codegen MUST run before analyze/test because freezed/drift/riverpod outputs are gitignored).
- Both the analyze and test steps use `continue-on-error: true` + `set -o pipefail` + `tee` — the workflow NEVER fails on lint/test failures; it always uploads the logs (`if: always()`) for human review. This is a "capture the output" workflow, not a gate.
- Test step: `flutter test --machine > test.json || true` then a second `flutter test --reporter=expanded | tee test.log`. (Note: tests are run twice.)

## Notes
- Per project memory, the user routinely skips `flutter test` and relies on the analyzer; this workflow's manual trigger + non-blocking design matches that.
