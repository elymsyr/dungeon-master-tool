import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

/// Guards the memo key in `character_editor_screen._resolveMemo`, which
/// caches `CharacterResolver.resolve` on `(pc.id, pc.entity.fields, entities)`
/// and skips the ~1500-line resolve for every name / description / DM-notes
/// keystroke. That key is only complete while the resolver reads NOTHING
/// else off the character. If a new pass starts reading e.g. `pc.worldId`,
/// the memo goes stale (wrong AC / grants) — this test fails first.
void main() {
  test('CharacterResolver reads only pc.id and pc.entity.fields', () {
    final src = File('lib/domain/services/character_resolver.dart')
        .readAsStringSync();
    final reads = RegExp(r'\bpc\.[A-Za-z_][A-Za-z0-9_.]*')
        .allMatches(src)
        .map((m) => m[0]!)
        .toSet();
    expect(reads, {'pc.id', 'pc.entity.fields'},
        reason: 'New character input in the resolver — extend the memo key '
            'in character_editor_screen._resolveMemo to cover it.');
  });
}
