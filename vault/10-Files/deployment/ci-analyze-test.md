---
type: file-note
domain: deployment
path: .github/workflows/analyze-test.yml
layer: backend
language: yaml
status: stable
updated: 2026-09-14
tags: [file]
---

# `ci-analyze-test.yml`

> [!abstract] Primary Purpose
> Manual-only GitHub Actions workflow that runs `flutter analyze` and `flutter test` on the `flutter_app` package and typechecks the Cloudflare worker, uploading the Flutter logs as artifacts. It is never triggered automatically — it only runs via the Actions "Run workflow" button (`workflow_dispatch`), with two boolean toggles to selectively skip analyze and/or test. A red result fails the run.

## Inputs / Outputs
**Inputs**
- Triggers: `workflow_dispatch` only (manual). Inputs `run_analyze` (default true), `run_tests` (default true), both `boolean`.
- Env: `FLUTTER_VERSION: "3.41.6"`, `WORKING_DIR: flutter_app`.
- Reads: the `flutter_app` package source and `cloudflare/` (checked out via `actions/checkout@v4`).

**Outputs**
- Artifact `analyze-log` → `flutter_app/analyze.log` (30-day retention).
- Artifact `test-results` → `flutter_app/test-results/` containing `test.json` (`--file-reporter=json:`) and `test.log` (`--reporter=expanded`), 30-day retention.
- Job status: fails on analyzer errors/warnings, any failing test, or a worker type error.

## Dependencies & Links
- Depends on: [[pubspec]], [[analysis_options]]
- Used by: [[ci-build]]
- Domain map: [[Deployment-and-Ops]]
- System flow:
- Spec / reference: `docs/KNOWN_ISSUES.md`

## Key Logic / Variables
- Three jobs, all on `ubuntu-22.04`. `analyze` and `test` are gated by `if: ${{ inputs.run_analyze }}` / `if: ${{ inputs.run_tests }}`; `worker` always runs.
- Shared Flutter setup: `subosito/flutter-action@v2` (version `3.41.6`, channel `stable`, `cache: true`) → `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` (codegen MUST run before analyze/test because freezed/drift/riverpod outputs are gitignored).
- Analyze: `flutter analyze --no-fatal-infos` — errors and warnings fail the job; the ~30 info-level lints do not. `set -o pipefail` keeps `tee` from masking the exit code.
- Test: installs `libsqlite3-dev` first (Drift tests load `libsqlite3.so`, which the runtime-only package lacks), then a single `flutter test --reporter=expanded --file-reporter=json:test-results/test.json | tee test.log`.
- Logs upload with `if: always()`, so a failing run still leaves them for review.
- Worker: `actions/setup-node@v4` (Node 22, npm cache keyed on `cloudflare/package-lock.json`) → `npm ci` → `npm run typecheck` (`tsc --noEmit`).

## Notes
- Gating was added 2026-09-14 after the 12 September audit found 60 failures that had accumulated unnoticed while the steps used `continue-on-error: true` and `|| true`. Push/PR triggers were deliberately left off.
