import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

/// The equipment step renders each starting-equipment item as a chip that links
/// to its card, and falls back to plain text when the ref doesn't resolve.
/// That fallback must never be the normal case for bundled content — if these
/// refs stop resolving, starting equipment silently degrades back to flat text
/// (and the resolver grants nothing), with no error anywhere.
void main() {
  test('every builtin starting-equipment ref resolves to a card', () {
    final entities = buildBuiltinSrdEntities();
    final unresolved = <String>[];
    var checked = 0;

    for (final e in entities.values) {
      final groups = e.fields['equipment_choice_groups'];
      if (groups is! List) continue;
      for (final g in groups) {
        if (g is! Map) continue;
        for (final o in (g['options'] as List? ?? const [])) {
          if (o is! Map) continue;
          for (final item in (o['items'] as List? ?? const [])) {
            if (item is! Map) continue;
            checked++;
            if (resolveEntityRef(item['ref'], entities) == null) {
              unresolved.add('${e.name} / ${o['option_id']}: ${item['ref']}');
            }
          }
        }
      }
    }

    expect(checked, greaterThan(0), reason: 'no equipment groups found at all');
    expect(unresolved, isEmpty);
  });
}
