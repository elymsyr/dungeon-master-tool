import 'dart:convert';

import '../../../domain/entities/schema/world_schema.dart';
import '../../database/app_database.dart';

/// Kullanıcı template kütüphanesi. Kayıtlar `custom_templates` yan
/// tablosunda tutulur — şema [AppDatabase] `beforeOpen`'daki raw DDL ile
/// idempotent kurulur, codegen ve `schemaVersion` bump'ı yok (mevcut
/// `lan_paired_devices` / `asset_refs` deseni).
///
/// Built-in template burada DURMAZ: koddan üretilir ve her zaman listenin
/// başına eklenir. Buradaki her template **mekaniksizdir** — bkz.
/// `templateIdHasMechanics`.
class CustomTemplateStore {
  CustomTemplateStore(this._db);

  final AppDatabase _db;

  Future<List<WorldSchema>> list() async {
    final rows = await _db
        .customSelect(
          'SELECT schema_json FROM custom_templates '
          'ORDER BY name COLLATE NOCASE',
        )
        .get();
    final out = <WorldSchema>[];
    for (final r in rows) {
      try {
        out.add(WorldSchema.fromJson(
          Map<String, dynamic>.from(
              jsonDecode(r.read<String>('schema_json')) as Map),
        ));
      } catch (_) {
        // Bozuk/eski bir kayıt tüm kütüphaneyi düşürmesin.
      }
    }
    return out;
  }

  Future<void> upsert(WorldSchema schema) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT INTO custom_templates '
      '(schema_id, name, schema_json, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(schema_id) DO UPDATE SET '
      'name = excluded.name, '
      'schema_json = excluded.schema_json, '
      'updated_at = excluded.updated_at',
      [schema.schemaId, schema.name, jsonEncode(schema.toJson()), now, now],
    );
  }

  Future<void> delete(String schemaId) async {
    await _db.customStatement(
      'DELETE FROM custom_templates WHERE schema_id = ?',
      [schemaId],
    );
  }
}
