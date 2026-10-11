import 'package:drift/drift.dart';

import '../app_database.dart';

/// The `user_templates` side table (free templates, schema JSON per row).
/// No Drift table class: the table is raw DDL in `beforeOpen`, like
/// `cloud_scopes`.
class UserTemplatesDao extends DatabaseAccessor<AppDatabase> {
  UserTemplatesDao(super.db);

  /// Schema JSON of every template, oldest first.
  Future<List<String>> allJson() async {
    final rows = await customSelect(
      'SELECT schema_json FROM user_templates ORDER BY created_at, id',
    ).get();
    return [for (final r in rows) r.data['schema_json'] as String];
  }

  /// Inserts or replaces [id]; the creation time of an existing row stays.
  Future<void> upsert(String id, String schemaJson) => customStatement(
    'INSERT INTO user_templates (id, schema_json, created_at) '
    'VALUES (?, ?, ?) '
    'ON CONFLICT (id) DO UPDATE SET schema_json = excluded.schema_json',
    [id, schemaJson, DateTime.now().microsecondsSinceEpoch],
  );

  Future<void> remove(String id) =>
      customStatement('DELETE FROM user_templates WHERE id = ?', [id]);
}
