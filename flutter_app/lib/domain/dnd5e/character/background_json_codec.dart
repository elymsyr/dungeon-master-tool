import 'dart:convert';

import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'background.dart';

/// JSON codec for Tier 1 content class [Background]. Body shape:
/// `{"effects"?: [<effect>...], "description"?: String}`
///
/// `effects` route through `effect_descriptor_codec`. Empty effect list and
/// empty description are omitted from the encoded body.

Background backgroundFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Background');
  return Background(
    id: e.id,
    name: e.name,
    effects: _decodeEffectList(body, 'effects', e.id),
    description: _optString(body, 'description', e.id) ?? '',
  );
}

CatalogEntry backgroundToEntry(Background b) {
  return CatalogEntry(
    id: b.id,
    name: b.name,
    bodyJson: jsonEncode(<String, Object?>{
      if (b.effects.isNotEmpty)
        'effects': b.effects.map(encodeEffect).toList(),
      if (b.description.isNotEmpty) 'description': b.description,
    }),
  );
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
