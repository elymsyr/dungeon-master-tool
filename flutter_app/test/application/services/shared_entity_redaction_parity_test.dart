// Faz 5.5b — redaksiyon Dart'tan SQL'e geçerken aynı alanlar saklanıyor mu
// (§2.6: "iki yorumlayıcının ayrışması tam olarak sır sızdıran senaryo").
//
//   flutter test test/application/services/shared_entity_redaction_parity_test.dart
//
// Eski yol: `redactDmOnly(entityToRaw(e))` → `entity_shares.payload_json`.
// Yeni yol: `CloudPushService.collect` bulut satırını `dm_only_keys` ile
// yazar → `get_shared_entities` `dm_notes`'u seçmez, `fields_json::jsonb -
// dm_only_keys` yapar → `sharedEntityRowToRaw`. SQL adımı burada birebir
// taklit ediliyor (094'teki SELECT); ikisi aynı kartı vermeli.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/application/services/entity_share_prepare.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_database.dart';

/// 094 `get_shared_entities`'in SELECT'i: `dm_notes` yok, NULL anahtar
/// listesi kartı hiç döndürmez, boş liste gövdeyi olduğu gibi bırakır.
Map<String, dynamic>? sqlSharedEntity(Map<String, dynamic> row) {
  final keys = row['dm_only_keys'] as List?;
  if (keys == null) return null;
  final fields = jsonDecode(row['fields_json'] as String) as Map;
  for (final k in keys) {
    fields.remove(k);
  }
  return {
    for (final c in const [
      'id', 'world_id', 'category_slug', 'name', 'source', 'description',
      'image_path', 'images_json', 'tags_json', 'pdfs_json', 'location_id',
      'package_id', 'package_entity_id', 'linked', 'updated_at',
    ])
      c: row[c],
    'fields_json': jsonEncode(fields),
    'revision': 1,
  };
}

void main() {
  late AppDatabase db;
  late CloudPushService svc;

  setUp(() async {
    db = openTestDatabase();
    await db.customSelect('SELECT 1').get();
    svc = CloudPushService(
        db: db, client: SupabaseClient('http://localhost:1', 'test-key'));
    await db.worldsDao.upsert(WorldsCompanion.insert(
        id: 'w1', worldName: 'Aegis', isOnline: const Value(true)));
  });

  tearDown(() async => db.close());

  Future<Map<String, dynamic>> cloudRow(
      Entity e, Map<String, List<String>> keys) async {
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: e.id,
      worldId: 'w1',
      categorySlug: e.categorySlug,
      name: e.name,
      source: Value(e.source),
      description: Value(e.description),
      imagePath: Value(e.imagePath),
      imagesJson: Value(jsonEncode(e.images)),
      tagsJson: Value(jsonEncode(e.tags)),
      dmNotes: Value(e.dmNotes),
      pdfsJson: Value(jsonEncode(e.pdfs)),
      locationId: Value(e.locationId),
      fieldsJson: Value(jsonEncode(e.fields)),
      updatedAt: Value(DateTime(2026, 10, 2)),
    ));
    final batches =
        await svc.collect('w1', DateTime.fromMillisecondsSinceEpoch(0), keys);
    return batches
        .firstWhere((b) => b.table == 'world_entities')
        .rows
        .firstWhere((r) => r['id'] == e.id);
  }

  test('yerleşik şemanın her gizli alanı iki yolda da saklanıyor', () async {
    final schema = generateBuiltinDnd5eV2Schema().schema;
    final keys = dmOnlyKeysBySlug(schema);
    final withSecrets = keys.entries.where((e) => e.value.isNotEmpty).toList();
    expect(withSecrets, isNotEmpty, reason: 'şemada gizli alan kalmadı mı?');

    for (final (i, MapEntry(key: slug, value: secret)) in withSecrets.indexed) {
      final cat = schema.categories.firstWhere((c) => c.slug == slug);
      final public =
          cat.fields.firstWhere((f) => !secret.contains(f.fieldKey)).fieldKey;
      final e = Entity(
        id: 'e$i',
        name: 'Kara Şövalye',
        categorySlug: slug,
        source: 'homebrew',
        description: 'Sarayın muhafızı.',
        images: const ['dmt-content://abc.png'],
        imagePath: 'dmt-content://def.png',
        tags: const ['boss'],
        dmNotes: 'SIR: aslında kardeşi',
        locationId: 'loc-7',
        fields: {
          public: 'görünür',
          for (final k in secret) k: 'SIR-$k',
        },
      );

      final old = entityFromRaw(
          e.id,
          jsonDecode(jsonEncode(redactDmOnly(entityToRaw(e), secret)))
              as Map<String, dynamic>);
      final sql = sqlSharedEntity(await cloudRow(e, keys));
      expect(sql, isNotNull, reason: slug);
      final fresh = entityFromRaw(
          e.id,
          sharedEntityRowToRaw(
              jsonDecode(jsonEncode(sql)) as Map<String, dynamic>));

      expect(fresh, equals(old), reason: slug);
      expect(jsonEncode(entityToRaw(fresh)), isNot(contains('SIR')),
          reason: slug);
      expect(fresh.fields[public], 'görünür', reason: slug);
    }
  });

  test('şemada olmayan kategori buluttan hiç dönmez', () async {
    const e = Entity(id: 'x', categorySlug: 'yok-boyle', name: 'X');
    final row = await cloudRow(e, dmOnlyKeysBySlug(generateBuiltinDnd5eV2Schema().schema));
    expect(row['dm_only_keys'], isNull);
    expect(sqlSharedEntity(row), isNull);
  });
}
