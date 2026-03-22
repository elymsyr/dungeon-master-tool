# Dungeon Master Tool — Pre-Online Community Developer Guide

> **Document version:** 1.0  
> **Date:** March 17, 2026  
> **Language:** English  
> **Scope:** Offline/preparation phase work required before full online rollout

---

## 1. Objective

This document defines the **pre-online development track** for community-focused extensibility and content sharing.

It formalizes three major product initiatives:

1. Card and World Template Features (dynamic entity model + editable schemas)
2. Advanced Battlemap Development
3. Community Wiki (template/world sharing ecosystem)

All items here are intended as **online preparation work** and should be completed before broad online feature activation.

---

## 2. Program Principles

### 2.1 Offline-First, Online-Ready

Every feature must work locally first and expose clean boundaries for future synchronization.

### 2.2 User-Owned Data

World definitions, entity schemas, and battlemap settings must remain portable and exportable.

### 2.3 Extensibility Over Hardcoding

Core systems should shift from fixed, code-defined rules to configurable schema-driven behavior.

### 2.4 Backward Compatibility

Existing campaigns must continue to load correctly via migration and fallback mechanisms.

---

## 3. Initiative A — Card and World Template Features

### 3.1 Product Goal

Allow users to fully customize entity categories and card fields, then package these into reusable world templates.

Examples:
- Removing `description` from Lore cards
- Adding custom fields with new names and types
- Creating/removing entire entity categories
- Using custom fields inside Encounter/Combat views (not only initiative)

### 3.2 Core Capabilities

### A. Dynamic Entity Category Management
- Create custom categories (e.g., Faction, Relic, Hex, Vehicle)
- Rename existing categories
- Archive or delete categories with dependency checks
- Assign icons/colors/order metadata for UI

### B. Dynamic Field Definition
- Add/remove/reorder fields per category
- Field types: `text`, `markdown`, `integer`, `float`, `boolean`, `enum`, `date`, `image`, `file`, `relation`, `formula` (optional phase)
- Per-field validation: min/max, regex, required, default value
- Localization-ready field labels and help text

### C. World Template Packaging
- Save full schema as a `World Template`
- Export/import templates as package files (e.g., `.dmt-template`)
- Template versioning with compatibility checks

### D. Encounter Integration Upgrade
- Initiative remains available
- DM selects additional card fields used by Encounter rows (e.g., Speed, Stress, Focus, Armor Tier)
- Configurable sorting and turn display formulas

### 3.3 Data Model Design (Preliminary)

### `world_schema`
- `schema_id`
- `name`
- `version`
- `base_system` (optional)
- `created_at`, `updated_at`

### `entity_category_schema`
- `category_id`
- `schema_id`
- `name`
- `slug`
- `is_builtin`
- `order_index`

### `field_schema`
- `field_id`
- `category_id`
- `field_key`
- `label`
- `field_type`
- `required`
- `default_value`
- `validation_json`
- `visibility` (dm_only/shared/private)
- `order_index`

### `encounter_layout`
- `layout_id`
- `schema_id`
- `columns` (field key list)
- `sort_rules`
- `derived_stats` (optional)

### 3.4 Migration Strategy

1. Add a migration layer that maps current fixed entities to schema-based entities.
2. Generate a default built-in template from existing data model to preserve old campaigns.
3. Keep legacy fallback readers until at least one stable release cycle after migration.

### 3.5 UI/UX Workstreams

1. **Template Studio**
   - Category list panel
   - Field editor panel
   - Type-specific validation editor
2. **Entity Card Renderer**
   - Runtime rendering from field schemas
3. **Encounter Column Configurator**
   - Drag-drop columns
   - Preview with sample combatants

### 3.6 Definition of Done

- Users can create/edit/delete categories and fields without manual file editing.
- Existing worlds load with auto-generated default schema.
- Encounter screen can use custom template fields.
- Template export/import passes integrity validation.
- Regression tests cover migration and CRUD flows.

---

## 4. Initiative B — Advanced Battlemap Development

### 4.1 Product Goal

Upgrade the battlemap into a system-agnostic tactical surface supporting multiple grid systems, drawing, measurement, and stronger DM ergonomics.

### 4.2 Core Capabilities

### A. Multi-Grid Support
- Grid modes: `square`, `hex (pointy)`, `hex (flat)`, `isometric` (optional phase)
- Adjustable grid size, opacity, thickness, color
- Grid origin/snapping controls

### B. Measurement Tools
- Distance ruler with configurable unit ratio (e.g., 1 cell = 5 ft)
- Path measurement with segment totals
- Line/circle/cone templates for ability ranges (optional phase)

### C. Drawing and Markup Layer
- Freehand, line, rectangle, ellipse, text annotation
- Layer controls: draw layer, token layer, fog layer
- Undo/redo history for drawing actions

### D. Expanded DM Control Surface
- Larger, dedicated DM battlemap controls
- Preset toolbar layouts
- Quick-access hotkeys
- Better viewport controls for large maps

### 4.3 Technical Architecture Notes

1. Separate render layers for grid, fog, drawings, and tokens.
2. Persist battlemap state in structured data (`grid_config`, `drawing_objects`, `measurement_settings`).
3. Use deterministic IDs for drawing objects to support future sync.
4. Keep CPU/GPU budget visible; optimize redraw paths for large assets.

### 4.4 Data Structures (Draft)

### `battlemap_config`
- `map_id`
- `grid_mode`
- `grid_size_px`
- `grid_offset_x`, `grid_offset_y`
- `grid_style`
- `unit_label`
- `unit_per_cell`

### `drawing_object`
- `drawing_id`
- `shape_type`
- `points`
- `style`
- `layer`
- `created_by`
- `created_at`

### 4.5 Definition of Done

- DM can switch between supported grid systems during setup.
- Users can draw and erase annotations reliably.
- Distance measurement supports custom unit ratios.
- Battlemap controls remain usable on low and high resolutions.
- Performance remains acceptable with large map files.

---

## 5. Initiative C — Community Wiki

### 5.1 Product Goal

Create a community content ecosystem where users can publish and discover:
- World Templates
- Complete Worlds
- Ready-to-use content packs

### 5.2 Scope for Pre-Online Phase

Since this is pre-online work, the initial implementation should prioritize:

1. Package standards and metadata
2. Import/export quality and safety
3. Moderation-ready structure
4. Offline/local discovery UX with future online bridge in mind

### 5.3 Content Package Specification (Draft)

### Package Types
- `template-package`
- `world-package`
- `asset-pack`

### Required Metadata
- `package_id`
- `title`
- `author`
- `version`
- `compatible_app_versions`
- `license`
- `tags`
- `description`
- `checksum`

### Safety Requirements
- Integrity validation (checksum)
- Explicit license declaration
- Restricted file type whitelist
- Import preview before apply

### 5.4 Community Wiki Functional Modules

### A. Publisher Tools
- Export package wizard
- Validation summary
- License selection and attribution field

### B. Consumer Tools
- Browse catalog (offline/local first)
- Filter by system, tags, language, popularity
- Install with conflict resolution dialog

### C. Moderation Foundations (Pre-Online Ready)
- Report metadata schema
- Content status model: `draft`, `published`, `flagged`, `deprecated`
- Audit-ready package manifest

### 5.5 Definition of Done

- Users can export/import template and world packages with metadata.
- Import process blocks incompatible or unsafe package structures.
- Package manifests are versioned and checksum-validated.
- UX supports future migration to server-hosted wiki without format break.

---

## 6. Mandatory Pre-Online Foundation Tasks

The following tasks are explicitly in scope and must be treated as preparation work before online rollout:

```markdown
- [ ] **GM Player Screen Control:** Add a specific edit/control view for the GM to manage the Player Window more effectively.
- [ ] **Single Player Screen:** The battle map view and player view will be on a single window.
- [ ] **Auto Event Log:** On the Session View Tab, for each combat round, damages and everything should be printed to the event log automatically.
- [ ] **Free Single Import:** Users should be able to import an entitiy from the import data sources such as spells, items and else, directly into any other entitiy like characters or npcs without needing to import them to the card entity database first.
- [ ] **Embedded PDF Viewer:** Implement a native PDF viewer within the application (Session/Docs tab).
- [ ] **Standardize UI (#30):** Fix inconsistent button sizes and layouts across the application.
- [ ] **Soundpad Transitions (#29):**
    - [ ] Make loop switching smoother to avoid audio glitches.
    - [ ] Add support for "mid-length" transition sounds between loops.
```

---

## 7. Suggested Delivery Order (Pre-Online)

1. Complete mandatory foundation tasks (Section 6).
2. Build dynamic schema engine (Initiative A core).
3. Implement advanced battlemap foundations (Initiative B core).
4. Define package format and local community import/export flow (Initiative C core).
5. Finalize migration and compatibility tests.
6. Prepare online bridge integration points.

---

## 8. Quality Gates and Testing

### 8.1 Functional Tests
- Dynamic category/field CRUD tests
- Encounter rendering from custom fields
- Grid mode switching and measurement tests
- Drawing persistence and undo/redo tests
- Package import/export validation tests

### 8.2 Regression Tests
- Legacy world load migration tests
- UI consistency checks on major windows
- Serialization compatibility snapshots

### 8.3 Non-Functional Tests
- Battlemap performance stress tests (large maps)
- Package validation performance under batch imports
- Stability tests for repeated schema edits

---

## 9. Risks and Mitigations

### Risk 1: Schema Complexity Explosion
- **Impact:** High
- **Mitigation:** Strong validation, template linting, and guided UI defaults

### Risk 2: Migration Breakage for Existing Worlds
- **Impact:** High
- **Mitigation:** Dual-read compatibility + migration previews + backup prompts

### Risk 3: Battlemap Feature Bloat
- **Impact:** Medium
- **Mitigation:** Ship core grid/draw/measure first; defer advanced templates

### Risk 4: Unsafe Community Packages
- **Impact:** High
- **Mitigation:** Strict manifest rules, checksums, and import sandbox checks

---

## 10. Expected Outcomes

When this pre-online program is completed:

1. Users can adapt the tool to any tabletop style through template customization.
2. DM battlemap workflows become significantly stronger and more ergonomic.
3. The community can start sharing reusable world systems and content packs.
4. The codebase becomes structurally ready for online sync and hosted discovery.

---

## 11. Next-Step Implementation Artifacts

Recommended follow-up documents:

1. `Template Engine Technical Spec` (data contracts + migration scripts)
2. `Battlemap Interaction Spec` (UX flows + performance budgets)
3. `Community Package RFC` (manifest schema, license policy, integrity rules)
4. `Pre-Online QA Matrix` (test cases, acceptance criteria, release gates)
