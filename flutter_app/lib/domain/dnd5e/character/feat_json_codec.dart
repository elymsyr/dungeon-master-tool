import 'dart:convert';

import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'feat.dart';

/// JSON codec for Tier 1 content class [Feat]. Body shape:
/// `{"category": String, "repeatable"?: bool, "prerequisite"?: String,
///   "effects"?: [<effect>...], "description"?: String}`
///
/// `category` encodes [FeatCategory.name] (origin/general/fightingStyle/epicBoon).
/// `repeatable` is omitted when false. `effects` route through
/// `effect_descriptor_codec`. Empty lists + empty description omitted.

Feat featFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Feat');
  return Feat(
    id: e.id,
    name: e.name,
    category: _requireCategory(body, 'category', e.id),
    repeatable: _optBool(body, 'repeatable', e.id) ?? false,
    prerequisite: _optString(body, 'prerequisite', e.id),
    effects: _decodeEffectList(body, 'effects', e.id),
    description: _optString(body, 'description', e.id) ?? '',
  );
}

CatalogEntry featToEntry(Feat f) {
  return CatalogEntry(
    id: f.id,
    name: f.name,
    bodyJson: jsonEncode(<String, Object?>{
      'category': f.category.name,
      if (f.repeatable) 'repeatable': true,
      if (f.prerequisite != null) 'prerequisite': f.prerequisite,
      if (f.effects.isNotEmpty)
        'effects': f.effects.map(encodeEffect).toList(),
      if (f.description.isNotEmpty) 'description': f.description,
    }),
  );
}

FeatCategory _requireCategory(
    Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('$ctx: missing or non-string field "$key".');
  }
  for (final c in FeatCategory.values) {
    if (c.name == v) return c;
  }
  throw FormatException('$ctx: unknown "$key" value "$v".');
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

String? _optString(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! String) {
    throw FormatException('$ctx: field "$key" must be a string when present.');
  }
  return v;
}

bool? _optBool(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! bool) {
    throw FormatException('$ctx: field "$key" must be a bool when present.');
  }
  return v;
}
