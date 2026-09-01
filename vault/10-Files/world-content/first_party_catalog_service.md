---
type: file-note
domain: world-content
path: flutter_app/lib/data/services/first_party_catalog_service.dart
layer: data
language: dart
status: stable
updated: 2026-09-01
tags: [file]
---

# `first_party_catalog_service.dart`

> [!abstract] Primary Purpose
> READ side of the first-party (official) content channel. Fetches the official-package catalog manifest + payloads from the Cloudflare R2 worker (`{worker}/catalog/*`), gracefully falling back to bundled `assets/first_party/` when offline / worker unset / fetch fails. Surfaces official packs inside the Marketplace; the WRITE side is the `tool/catalog_publish` CLI.

## Inputs / Outputs
**Inputs**
- `--dart-define=DMT_WORKER_URL` (`_workerBaseUrl`); empty -> bundled-only.
- Bundled asset `assets/first_party/manifest.json`; per-entry `r2Path` / `bundledAsset`.
- Native `HttpClient` (no `http`/`dio` dep), 12s timeout.

**Outputs**
- `fetchManifest()` -> `List<CatalogEntry>`, **all** item types. It filtered to `'package'` until 2026-09-01, which silently dropped every `world` entry; the filter now lives in the providers ([[first_party_catalog_provider]]).
- `fetchPayload(entry)` -> `Map<String,dynamic>` (gz-decoded online; bundled fallback; throws `StateError` only when neither yields).
- `fetchBanner(slug)` -> `Uint8List?` (JPEG, null when no worker / offline / missing).
- `officialBannerUrl(slug)` static -> `{worker}/catalog/banners/<slug>.jpg?v=N`.
- `fetchCatalogBytes(r2Key)` -> `Uint8List?`, raw bytes of any catalog object (a world's media). Null on no-worker / offline / missing so the caller falls back to the bundled asset. URL-encodes with `Uri.encodeFull` — media keys carry spaces (`media/GURPS GCS Characters/…`).
- `fetchExternal(url)` -> `Uint8List?` for a file the catalog references but does not host (the adventure PDF, fetched from the publisher). Follows redirects on a **30 s connect / 10 min body** timeout rather than the 12 s `_timeout`: these are tens of megabytes off a third-party site.

## Dependencies & Links
- Depends on: `CatalogEntry` (`catalog_entry`), `OfflineException` (`error_format`)
- Used by: Marketplace official-content UI, official-catalog installer [[first_party_catalog_provider]] (-> [[package_payload_importer]])
- Domain map: [[World-and-Content]]
- System flow: [[Content-Pipeline]]
- Spec / reference: [[catalog-publish-ops]]

## Key Logic / Variables
- **Fallback chain**: online manifest -> bundled manifest; online gz payload (`gzip.decode` + `utf8.decode`) -> bundled asset. Unlike `SoundpackCatalogService`, this NEVER surfaces `OfflineException` to callers — offline always degrades to the bundled catalog so official packs stay installable without a network.
- **`kBannerAssetVersion = 2`**: cache-bust int appended as `?v=N`. The worker serves banners `Cache-Control: immutable, max-age=1y` under a stable key, so re-uploaded art would otherwise serve the year-cached old image — bump this on every banner re-crop/re-upload. Banners are NOT bundled (only built-in template/package covers are); offline cards fall back to the icon cover.
- HTTP helper `_get` maps `SocketException`/`HandshakeException`/`TimeoutException` -> `OfflineException` internally, non-200 -> `HttpException`; the public methods catch-and-fallback, so the OfflineException never escapes.

## Notes
- **Dependencies (2026-07-29)**: manifest entries carry `requires` (catalog slugs), parsed onto `CatalogEntry.requires` and resolved transitively by `FirstPartyInstallNotifier.install` before the requested entry — a package installs with the packages it links. Emitted by [[build_catalog]] from the pack's `metadata.links`; empty for every pack today. See [[Package-Links]].
- **Worlds (2026-09-01)**: a `world` entry's payload is an envelope (`{manifest, world_blueprint, character_blueprint}`) consumed by [[bundled_worlds_installer]] rather than `fetchPayload` — the bundled fallback for a world is a *directory*, not a single asset, so the installer owns that chain.
- Worker not deployed at time of writing (P7 deferred per first-party catalog initiative). Banner upload via `cloudflare/upload_banners.sh`.
