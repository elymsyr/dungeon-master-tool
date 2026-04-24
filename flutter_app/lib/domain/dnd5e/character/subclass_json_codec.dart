import 'dart:convert';

import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'character_class.dart';
import 'subclass.dart';

/// JSON codec for Tier 1 content class [Subclass]. Body shape:
/// `{"parentClassId": String, "featureTable"?: [<row>...], "description"?: String}`
///
/// Each row: `{"level": int, "featureIds"?: [String...], "effects"?: [<effect>...]}`.
///
/// Rows are emitted sorted by level for deterministic output. `effects` route
/// through `effect_descriptor_codec`. Empty lists + empty description omitted.

Subclass subclassFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Subclass');
  return Subclass(
    id: e.id,
    name: e.name,
    parentClassId: _requireString(body, 'parentClassId', e.id),
    featureTable: _decodeRows(body, 'featureTable', e.id),
    bonusSpellIds: _decodeBonusSpellIds(body, 'bonusSpellIds', e.id),
    description: _optString(body, 'description', e.id) ?? '',
  );
}

CatalogEntry subclassToEntry(Subclass s) {
  final rows = [...s.featureTable]..sort((a, b) => a.level.compareTo(b.level));
  final bonus = s.bonusSpellIds.isEmpty
      ? null
      : <String, Object?>{
          for (final level in (s.bonusSpellIds.keys.toList()..sort()))
            level.toString(): s.bonusSpellIds[level],
        };
  return CatalogEntry(
    id: s.id,
    name: s.name,
    bodyJson: jsonEncode(<String, Object?>{
      'parentClassId': s.parentClassId,
      if (rows.isNotEmpty) 'featureTable': rows.map(_encodeRow).toList(),
      if (bonus != null) 'bonusSpellIds': bonus,
      if (s.description.isNotEmpty) 'description': s.description,
    }),
  );
}

Map<int, List<String>> _decodeBonusSpellIds(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const {};
  if (raw is! Map) {
    throw FormatException(
        '$ctx: "$key" must be an object mapping level strings to spell-id arrays.');
  }
  final out = <int, List<String>>{};
  raw.forEach((k, v) {
    if (k is! String) {
      throw FormatException('$ctx: "$key" keys must be string levels.');
    }
    final level = int.tryParse(k);
    if (level == null) {
      throw FormatException('$ctx: "$key" key "$k" is not an integer level.');
    }
    if (v is! List) {
      throw FormatException('$ctx: "$key.$k" must be an array of spell ids.');
    }
    out[level] = v.map((e) {
      if (e is! String) {
        throw FormatException('$ctx: "$key.$k" entries must be strings.');
      }
      return e;
    }).toList();
  });
  return out;
}

Map<String, Object?> _encodeRow(ClassFeatureRow r) => <String, Object?>{
      'level': r.level,
      if (r.featureIds.isNotEmpty) 'featureIds': r.featureIds,
      if (r.effects.isNotEmpty)
        'effects': r.effects.map(encodeEffect).toList(),
    };

List<ClassFeatureRow> _decodeRows(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) {
    if (e is! Map) {
      throw FormatException('$ctx: "$key" entries must be JSON objects.');
    }
    final m = e.cast<String, Object?>();
    return ClassFeatureRow(
      level: _requireInt(m, 'level', ctx),
      featureIds: _optStringList(m, 'featureIds', ctx),
      effects: _decodeEffectList(m, 'effects', ctx),
    );
  }).toList();
}

List<EffectDescriptor> _decodeEffectList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) => decodeEffect(e, ctx)).toList();
}

List<String> _optStringList(
    Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return const [];
  if (v is! List) {
    throw FormatException('$ctx: field "$key" must be an array when present.');
  }
  return v.map((e) {
    if (e is! String) {
      throw FormatException('$ctx: "$key" entries must be strings.');
    }
    return e;
  }).toList();
}

Map<String, Object?> _decodeBody(CatalogEntry e, String typeName) {
  final Object? decoded;
  try {
    decoded = jsonDecode(e.bodyJson);
  } on FormatException catch (err) {
    throw FormatException(
        '${e.id}: $typeName body is not valid JSON: ${err.message}');
  }
  if (decoded is! Map) {
    throw FormatException(
        '${e.id}: $typeName body must be a JSON object (got ${decoded.runtimeType}).');
  }
  return decoded.cast<String, Object?>();
}

String _requireString(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('$ctx: missing or non-string field "$key".');
  }
  return v;
}

String? _optString(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! String) {
    throw FormatException('$ctx: field "$key" must be a string when present.');
  }
  return v;
}

int _requireInt(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! int) {
    throw FormatException('$ctx: missing or non-int field "$key".');
  }
  return v;
}
