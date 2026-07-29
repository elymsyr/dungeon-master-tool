import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';

void main() {
  test('everything the SRD bootstrap encodes is JSON-encodable', () {
    final pack = buildSrdCorePack();
    final build = generateBuiltinDnd5eV2Schema();
    final schemaJson = build.schema.toJson();

    jsonEncode({'metadata': pack.metadata});
    jsonEncode(schemaJson['categories'] ?? []);
    jsonEncode(schemaJson['encounterConfig'] ?? {});
    jsonEncode(schemaJson['encounterLayouts'] ?? []);

    for (final rows in build.seedRows.values) {
      for (final row in rows) {
        jsonEncode(row['fields'] ?? <String, dynamic>{});
      }
    }
    for (final e in pack.entities.values) {
      final raw = Map<String, dynamic>.from(e as Map);
      jsonEncode(raw['attributes'] ?? <String, dynamic>{});
      jsonEncode(raw['images'] ?? const []);
      jsonEncode(raw['tags'] ?? const []);
      jsonEncode(raw['pdfs'] ?? const []);
    }
  });
}
