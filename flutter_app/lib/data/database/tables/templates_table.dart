import 'package:drift/drift.dart';

/// Hub-level Template library (Template & Package architecture, roadmap §1.4 /
/// PR-1.4). One row per user-owned Template — the full v3 `WorldSchema` is
/// stored as a single canonical JSON blob in [dataJson], mirroring the
/// "one JSON document per template" model from the-template-system §5.1.
///
/// The **built-in** D&D 5e template is intentionally NOT a row here: it ships
/// as a bundled asset loaded by `BuiltinTemplateLoader` and is read-only. The
/// library list the editor sees is `[builtin asset] + these rows` — copying the
/// built-in (or any row) writes a new editable row into this table.
///
/// No Postgres counterpart yet — templates are a local-only catalog at this
/// stage (like `packages`); cloud sync of user templates is out of scope for
/// Phase 1.
class Templates extends Table {
  /// The template's `schemaId`. A copy always gets a FRESH id (so two copies
  /// of the built-in never collide) while preserving `originalHash` lineage
  /// inside [dataJson] for drift detection.
  TextColumn get id => text()();

  /// Display name (`WorldSchema.name`). Denormalised out of [dataJson] purely
  /// so the library list can render + sort without parsing every blob.
  TextColumn get name => text()();

  /// The complete `WorldSchema.toJson()`, canonicalised + JSON-encoded. The
  /// single source of truth for the template's content; [name]/[originalHash]/
  /// [currentHash] are denormalised projections kept in sync on every write.
  TextColumn get dataJson => text()();

  /// `WorldSchema.originalHash` — frozen lineage hash. A copy preserves its
  /// source's value so `applyTemplateUpdate` can still match an edited copy
  /// back to its built-in ancestor. Nullable for legacy rows missing it.
  TextColumn get originalHash => text().nullable()();

  /// `computeWorldSchemaContentHash` of [dataJson] at last save — the "current"
  /// hash used by the lazy template-sync flow. Recomputed on every save.
  TextColumn get currentHash => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
