# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dungeon Master Tool — a cross-platform (Android, iOS, Windows, Linux, macOS), offline-first D&D campaign manager built with Flutter. Optional cloud sync via Supabase + Cloudflare R2 asset pipeline.

## Common Commands

All commands run from `flutter_app/`:

```bash
# Install dependencies
flutter pub get

# Code generation (Freezed, Drift, Riverpod, JSON)
dart run build_runner build --delete-conflicting-outputs
# Watch mode:
dart run build_runner watch --delete-conflicting-outputs

# Run app
flutter run                    # default device
flutter run -d linux           # specific platform

# Static analysis
dart analyze

# Run all tests
flutter test
# Single test file
flutter test test/domain/entity_test.dart

# Generate localization files
flutter gen-l10n
```

## Architecture

Clean Architecture with Riverpod, all under `flutter_app/lib/`:

```
domain/          Pure Dart: entities (Freezed), abstract repositories, value objects
  entities/schema/   WorldSchema → EntityCategorySchema → FieldSchema (16 field types)
  entities/events/   EventEnvelope (24 event types for cross-component communication)
data/            Drift (SQLite) database, DAOs, repository implementations, datasources
  database/          app_database.dart + tables/ + daos/ (Campaign, Entity, Session, Map, MindMap)
application/     Riverpod providers (~30), business services
  providers/         campaignProvider, combatProvider, entityProvider, authProvider, etc.
  services/          RuleEngineV2, AudioEngine, PackageImportService, TemplateSyncService
presentation/    Screens, widgets, themes (11 themes), routing (go_router), l10n
  widgets/field_widgets/   Schema-driven field renderers (one per FieldType)
  l10n/                    ARB files: en (template), tr, de, fr
```

## Key Architectural Concepts

- **Schema-driven entity system**: `WorldSchema` defines categories and fields; entities are bags of key-value pairs validated against the schema. Templates are user-editable schemas.
- **Offline-first**: Drift (SQLite) is the source of truth. Supabase cloud sync is optional. `SupabaseConfig.isConfigured` gates all remote features.
- **Riverpod state management**: Mix of `Provider`, `StateProvider`, `FutureProvider`, `AsyncNotifier`. Campaign state uses a monotonic `campaignRevisionProvider` to trigger re-reads for in-place mutations without full rebuild.
- **Event bus**: `EventEnvelope` (24 types) for cross-component communication — combat events, entity changes, session events, projection updates.
- **Multi-window**: `desktop_multi_window` + `ProjectionIpc` for dual-screen player window on desktop.
- **Rules engine (RuleV2)**: Composable predicate+effect model on categories. Evaluated reactively via `computedFieldsProvider` — no static cache.
- **Template sync**: Lazy drift detection via `originalHash`. When a campaign's template diverges from the source, the user sees a diff dialog on next open.
- **Admin system**: `isAdminProvider` checks Supabase `is_admin()` RPC. Admin-only features: built-in template editing (`bypassBuiltinGuard`), user management.

## Code Generation

Freezed models generate `*.freezed.dart` + `*.g.dart`. Drift generates `app_database.g.dart`. Always re-run `build_runner` after changing annotated files. Generated files are gitignored.

## Localization

All user-facing strings go through ARB files in `lib/presentation/l10n/`. Add keys to `app_en.arb` first, then add translations to `app_tr.arb`, `app_de.arb`, `app_fr.arb`. Access via `L10n.of(context)!.keyName`.

## Non-Flutter Code

- `cloudflare/` — TypeScript Cloudflare Worker for R2 asset pipeline (JWT auth, rate limiting)
- `supabase/migrations/` — SQL migrations for cloud_backups, community_assets, social features

## Coding Conventions

- Riverpod for state; `@riverpod` annotations where possible
- Freezed for immutable models
- Drift for database; no raw SQL outside DAOs
- Domain layer has zero Flutter/third-party imports
- Turkish comments are common throughout the codebase — this is intentional
