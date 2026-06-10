import '../entities/schema/world_schema.dart';

/// Persistence interface for the hub-level Template library (roadmap §1.4 /
/// PR-1.4 — "Template library + Copy").
///
/// Operates only on **user-owned** templates (the `templates` table). The
/// built-in D&D 5e template is a read-only bundled asset served by
/// `BuiltinTemplateLoader`; it is never stored or mutated through this
/// repository. The full library list the editor consumes is
/// `[builtin asset] + listUserTemplates()` (see `templateLibraryProvider`).
abstract class TemplateRepository {
  /// All user-owned templates, newest-edited first.
  Future<List<WorldSchema>> listUserTemplates();

  /// Loads a single user template by its `schemaId`, or null if absent.
  Future<WorldSchema?> load(String schemaId);

  /// Persists [template] (insert or update keyed on `schemaId`). The current
  /// content hash is recomputed and stored; `originalHash` is preserved as-is
  /// (it is frozen at creation/copy time — see [copy]). Returns the saved
  /// template (with a backfilled `originalHash` if it was previously null).
  Future<WorldSchema> save(WorldSchema template);

  /// Copies [source] into a new editable user template under [newName].
  ///
  /// Copy semantics (roadmap §1.4): a **fresh `schemaId`** (so two copies of
  /// the built-in never collide) with the **`originalHash` preserved** from the
  /// source (so the dual-hash drift-detection machinery can still match the
  /// copy back to its ancestor). `formatVersion` and content are carried over
  /// verbatim; `name` is set to [newName] and `createdAt`/`updatedAt` are
  /// stamped now. Returns the newly created template.
  Future<WorldSchema> copy({
    required WorldSchema source,
    required String newName,
  });

  /// Renames a user template in place (display name only; content unchanged).
  /// Returns the updated template, or null if [schemaId] is unknown.
  Future<WorldSchema?> rename(String schemaId, String newName);

  /// Deletes a user template by `schemaId`. No-op if absent.
  Future<void> delete(String schemaId);

  /// Whether a user template with [name] already exists — for copy/rename
  /// collision suffixing in the UI.
  Future<bool> nameExists(String name);
}
