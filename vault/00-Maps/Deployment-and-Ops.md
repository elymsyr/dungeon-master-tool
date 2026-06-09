---
type: moc
domain: deployment
updated: 2026-06-09
tags: [moc]
---

# Deployment & Ops — Map of Content

> [!summary] Scope
> Build/release pipeline and runtime config: GitHub Actions CI, multi-platform builds, `--dart-define` secrets, wrangler worker deploy, Supabase migration application, and the Open5e API staging Docker image. The "Deployment / Docker" domain.

## Key Files
- [[ci-analyze-test]] — `.github/workflows/analyze-test.yml` (flutter analyze + test).
- [[ci-build]] — `.github/workflows/build.yml` (Android/iOS/Windows/Linux/macOS on release).
- [[pubspec]] — `flutter_app/pubspec.yaml` (deps, codegen, asset bundling; v12.0.0).
- [[analysis_options]] — lint config + generated-file excludes.
- [[dart-define-reference]] — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `DMT_WORKER_URL` build-time injection.
- [[open5e-api-dockerfile]] — `open5e-api-staging/Dockerfile` (Python 3.11 + Django + gunicorn).
- [[wrangler_config]] — worker deploy config (also in [[Backend-Infra]]).
- [[catalog-publish-ops]] — `dart run publish_catalog` workflow + `upload_banners.sh`.

## Data Flow
Release tag → [[ci-build]] → platform artifacts (signed via Android keystore secrets). Worker: `wrangler deploy`. DB: numbered SQL migrations applied to Supabase. Content: [[publish_catalog]] → R2.

## Related Domains
- [[Backend-Infra]] (worker, migrations) · [[Content-Pipeline]] (catalog publish) · [[Deployment-and-Ops]] config feeds all runtime domains.

## Source Docs
- `supabase/README.md`, root `RELEASE_NOTES.md`, `docs/TEMPLATE_RELEASE_NOTE.md`.
