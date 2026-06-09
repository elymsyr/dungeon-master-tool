---
type: file-note
domain: deployment
path: flutter_app/lib/core/config/supabase_config.dart, flutter_app/lib/data/network/network_providers.dart, flutter_app/lib/data/services/first_party_catalog_service.dart, flutter_app/lib/main.dart
layer: core
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `--dart-define` Reference (SUPABASE_URL / SUPABASE_ANON_KEY / DMT_WORKER_URL)

> [!abstract] Primary Purpose
> The app has zero runtime config files — all backend wiring is compile-time via three `--dart-define` keys read through `String.fromEnvironment`. This note collects where each key is injected (CI) and where it is read. When none are set, the app runs fully offline (no Supabase SDK init, no R2 asset pipeline, catalog falls back to bundled assets).

## The three keys
| Key | Read in | Read as | Empty-string behavior |
|---|---|---|---|
| `SUPABASE_URL` | `core/config/supabase_config.dart` → `SupabaseConfig.url` | `String.fromEnvironment('SUPABASE_URL')` | offline |
| `SUPABASE_ANON_KEY` | same → `SupabaseConfig.anonKey` | `String.fromEnvironment('SUPABASE_ANON_KEY')` | offline |
| `DMT_WORKER_URL` | `data/network/network_providers.dart` and `data/services/first_party_catalog_service.dart` → `_workerBaseUrl` | `String.fromEnvironment('DMT_WORKER_URL')` | no R2 asset/catalog network |

## Inputs / Outputs
**Inputs**
- Injection point: every `flutter build` in [[ci-build]] appends `--dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }} --dart-define=DMT_WORKER_URL=${{ secrets.DMT_WORKER_URL }}` (values from GitHub repo secrets). Local dev passes the same flags to `flutter run`.

**Outputs**
- `SupabaseConfig.isConfigured` (bool) gates all online behavior.
- `assetServiceProvider` (`AssetService?`) and `firstPartyCatalogService` network paths.

## Dependencies & Links
- Depends on:
- Used by: [[ci-build]], [[first_party_catalog_service]], [[auth_provider]], [[heartbeat_service]]
- Domain map: [[Deployment-and-Ops]]
- System flow: [[Backend-Infra]]
- Spec / reference: [[Media-Storage-Tiers]]

## Key Logic / Variables
- **`SupabaseConfig`** (`supabase_config.dart`): two `static const` reads; `isConfigured => url.isNotEmpty && anonKey.isNotEmpty`. This is the single source of truth for "are we online-capable".
- **`main.dart` `_initSupabase()`**: `if (!SupabaseConfig.isConfigured) return;` else `await Supabase.initialize(url, anonKey).timeout(3s)` then `HeartbeatService.instance.start()` (drives `profiles.last_active_at` / `app_version` / `platform`, migration 023). Init failure is swallowed → online features disabled, app keeps running.
- **`network_providers.dart`**: `const _workerBaseUrl = String.fromEnvironment('DMT_WORKER_URL')`. `assetServiceProvider` returns null if `!isConfigured || _workerBaseUrl.isEmpty`. Extra runtime guard: wraps `Supabase.instance.client` in try/catch because projection sub-isolates may compile with flags set but never call `Supabase.initialize()` — reading the client there throws, so it returns null and callers fall back to local resolution.
- **`first_party_catalog_service.dart`**: same `_workerBaseUrl` const (DMT_WORKER_URL). Empty → catalog resolves from bundled `assets/first_party/manifest.json` only. Builds banner URLs `{worker}/catalog/banners/<slug>.jpg?v=N` where `N = kBannerAssetVersion` (currently `2`) — bump that const when banners are re-uploaded so the immutable 1-year R2/edge cache key changes.
- **Gotcha**: `--dart-define` is compile-time; you cannot change backend wiring without a rebuild. Banners are NOT bundled (download from R2); the two built-in cover banners are the only bundled ones.

## Notes
- `DMT_WORKER_URL` is the same Cloudflare Worker base used by [[catalog-publish-ops]] and `cloudflare/upload_banners.sh` (admin write side uses `ADMIN_TOKEN`, not these client flags).
