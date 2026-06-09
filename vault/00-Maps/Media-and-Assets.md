---
type: moc
domain: media
updated: 2026-06-09
tags: [moc]
---

# Media & Assets — Map of Content

> [!summary] Scope
> Image/audio storage and lifecycle across three tiers (free / counted / transient), soundpack playback, bundling for export, and orphan GC. The storage *policy* lives here; the storage *backends* (Supabase Storage + R2) live in [[Backend-Infra]].

## Key Files
- [[soundpad_engine]] — audio playback/mixing via flutter_soloud. See [[Audio-SoLoud]].
- [[soundpack_catalog_service]] — list installed soundpacks.
- [[media_bundler]] · [[media_manifest_restorer]] — bundle/restore media on export/import.
- [[free_media_service]] — fetch free-tier media (quota-exempt).
- [[entity_image_upload]] — upload entity portrait to media storage.
- [[entity_media_cleanup_service]] — GC media on entity/world/package delete.
- [[cover_image_bundler]] · [[marketplace_cover_sync_service]] — marketplace listing covers.

## Data Flow
Upload → tier decision ([[Media-Storage-Tiers]]): free (Supabase `free-media`, uncounted) vs counted (R2 permanent, 100 MB quota) vs transient (R2 LRU pool). Cleanup on delete via [[entity_media_cleanup_service]].

## Related Domains
- [[Backend-Infra]] (R2 worker, Supabase buckets) · [[World-and-Content]] (what owns media) · [[Projection-Second-Screen]] (displays it).

## Source Docs
- `flutter_app/docs/security_media_supabase_r2_audit_may21.md`, `media_redesign_test_plan_may21.md`; `online_media_storage_redesign_may21`, `entity_media_cloud_cleanup_may21` memories.
