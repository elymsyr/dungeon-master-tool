// Open5e fixture loaders. Every Open5e data file is a JSON array of Django
// fixture records `{model, pk, fields}`. These helpers read a file and expose
// the records as `{pk, ...fields}` maps plus parent-grouping utilities used to
// reassemble the normalized v2 graph (Creature ← CreatureAction ← Attack,
// Creature ← CreatureTrait).
import 'dart:convert';
import 'dart:io';

/// One fixture record flattened to `{'_pk': pk, ...fields}`.
typedef Fixture = Map<String, dynamic>;

/// Read a fixture file. Returns [] if the file is absent (a document may not
/// carry every content type).
List<Fixture> loadFixtures(String path) {
  final f = File(path);
  if (!f.existsSync()) return const [];
  final raw = jsonDecode(f.readAsStringSync());
  if (raw is! List) return const [];
  final out = <Fixture>[];
  for (final r in raw) {
    if (r is! Map) continue;
    final fields = r['fields'];
    if (fields is! Map) continue;
    final m = <String, dynamic>{'_pk': r['pk']};
    fields.forEach((k, v) => m[k.toString()] = v);
    out.add(m);
  }
  return out;
}

/// Group fixtures by the value of [key] (e.g. `parent`).
Map<String, List<Fixture>> groupBy(List<Fixture> rows, String key) {
  final out = <String, List<Fixture>>{};
  for (final r in rows) {
    final k = r[key];
    if (k == null) continue;
    (out[k.toString()] ??= <Fixture>[]).add(r);
  }
  return out;
}

/// Index fixtures by primary key.
Map<String, Fixture> byPk(List<Fixture> rows) {
  return {for (final r in rows) r['_pk'].toString(): r};
}
