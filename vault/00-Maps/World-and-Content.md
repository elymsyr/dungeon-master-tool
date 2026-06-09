---
type: moc
domain: world-content
updated: 2026-06-09
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
- [[packages_dao]] · [[personal_packages_dao]] — package storage.
- [[world_schema]] · [[entity_category_schema]] · [[field_schema]] — schema model (73 categories, Tier-0/Tier-1).
- [[first_party_catalog_service]] — official catalog fetch (R2 → cache → bundled).
- [[bundled_packs_bootstrap]] — first-boot SRD install.

## Data Flow
Packages built by [[Content-Pipeline]] → installed via [[package_import_service]] → entities land in `world_entities` ([[Data-Layer]]) → resolved by [[Character-System]] / rendered in DB screen. Schema embedded at install.

## Related Domains
- [[Content-Pipeline]] (source of packages) · [[Character-System]] (consumes entities) · [[Data-Layer]] · [[Backend-Infra]] (marketplace, catalog).

## Source Docs
- `flutter_app/docs/custom_content_editor_roadmap.md`, `first_party_catalog_initiative`, `subspecies_category_jun2026` memories.
