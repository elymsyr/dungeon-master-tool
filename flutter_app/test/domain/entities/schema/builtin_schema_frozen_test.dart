import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_test/flutter_test.dart';

/// Free template guard (docs/free-template/ROADMAP.md K1, K2): the built-in
/// schema's JSON must not change. A new model field that leaks into the JSON
/// (missing `includeIfNull: false`) or any edit under `builtin/` turns this red.
/// If the change is intentional, update the expected values here on purpose.
const _expectedHash =
    '2776a95a777c3300d23d31adc126f2f47fa1c16a1e1fb70174fc088affd8d110';
const _expectedCategories = 75;
const _expectedFields = 928;

/// Values `generateBuiltinDnd5eV2Schema` regenerates on every call: timestamps
/// (`now`) and random v4 ids.
const _volatileKeys = {'createdAt', 'updatedAt', 'categoryId', 'fieldId'};

/// Drops [_volatileKeys] and sorts map keys.
Object? _stripVolatile(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {
      for (final k in keys)
        if (!_volatileKeys.contains(k)) k: _stripVolatile(v[k]),
    };
  }
  if (v is List) return [for (final e in v) _stripVolatile(e)];
  return v;
}

String _hash() {
  final schema = generateBuiltinDnd5eV2Schema().schema;
  final json = jsonDecode(jsonEncode(schema.toJson()));
  return sha256.convert(utf8.encode(jsonEncode(_stripVolatile(json)))).toString();
}

void main() {
  test('built-in schema JSON is frozen', () {
    expect(_hash(), _expectedHash);
  });

  test('built-in schema has the expected category and field counts', () {
    final schema = generateBuiltinDnd5eV2Schema().schema;
    expect(schema.categories, hasLength(_expectedCategories));
    expect(
      schema.categories.fold<int>(0, (n, c) => n + c.fields.length),
      _expectedFields,
    );
  });
}
