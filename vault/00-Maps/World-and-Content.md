---
type: moc
domain: world-content
updated: 2026-08-15
tags: [moc]
---

# World & Content — Map of Content

> [!summary] Scope
> The campaign container (worlds), the schema-driven entity system (NPCs/monsters/locations), content packages (personal + world + first-party), and the marketplace. Where installed content lives and how worlds are configured.

## Key Files
- [[campaign_provider]] — active world notifier; entity/character/settings queries.
- [[world_repository_impl]] · [[worlds_dao]] — world CRUD + membership-scoped queries.
- [[entity]] — generic schema-driven `@freezed` entity (fields map keyed by FieldSchema).
- [[world_entities_dao]] — entity queries by world/category.
- [[package_import_service]] · [[package_sync_service]] · [[package_payload_importer]] — ingest/sync/parse packages.
- [[world_package_installer]] — the one way to install a package (+ its link closure) into a world.
- [[package_link_service]] — package→package link graph (closure, cycles, dangling). See [[Package-Links]].
- [[packages_dao]] · [[personal_packages_dao]] — package storage.
- [[world_schema]] · [[entity_category_schema]] · [[field_schema]] — schema model (73 categories, Tier-0/Tier-1).
- [[template_mechanics]] · [[custom_template_store]] · [[custom_fields]] — user template library, the automation gate, and per-card free fields (see [[Template-System]]).
- [[first_party_catalog_service]] — official catalog fetch (R2 → cache → bundled).
- [[first_party_catalog_provider]] — official catalog **install** side: `requires` closure, banner, `installedFrom: 'official'`. Install-only — no upgrade path for an already-installed pack.
- [[bundled_packs_bootstrap]] — first-boot SRD install.
- [[world_blueprint_converter]] · [[builtin_content_names]] — the single blueprint → entity translation, and the schema-derived catalogues it validates against. Ref tiers: Tier-0 `_lookup` → in-blueprint `_ref` → SRD soft ref → **error**.
- [[bundled_worlds_installer]] — what the admin "bundled worlds" toggle runs: extracts media to disk, converts, and saves the world **with the built-in schema** so the SRD pack is linked (without it every soft ref dangles).
- [[builtin_package_provider]] — SRD pack id + read-only SRD reference overlay (`srdReferenceEntitiesProvider`).
- [[package_source_entities]] — installed packages as an entity map, and the **one ordering rule** for layering them over the built-in SRD: the package the user picked wins a name collision (audit L1).
- [[entity_link]] — the single "open this entity" entry point every ref renderer taps through, and the test for whether a ref is openable at all (audit U3).
- [[entity_preview_dialog]] — read-only quick-look card opened by long-pressing a ref link; renders off a plain `Entity` so the creation wizard's bundled/package rows work too.

## Data Flow
Packages built by [[Content-Pipeline]] → installed via [[package_import_service]] → entities land in `world_entities` ([[Data-Layer]]) → resolved by [[Character-System]] / rendered in DB screen. Schema embedded at install.

## Systems
- [[Package-Links]] — a package borrows another's content instead of duplicating it; links follow it into worlds and downloads.

## Related Domains
- [[Content-Pipeline]] (source of packages) · [[Character-System]] (consumes entities) · [[Data-Layer]] · [[Backend-Infra]] (marketplace, catalog).

## Source Docs
- `flutter_app/docs/custom_content_editor_roadmap.md`, `first_party_catalog_initiative`, `subspecies_category_jun2026` memories.
