import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Audit phase U1 — a correct ref is not a visible ref.**
///
/// Every chargen filter that used to test membership with
/// `(fields['class_refs'] as List).contains(classId)` now routes through
/// [resolveEntityRefList]. The raw form matched a plain id and nothing else, so
/// a packaged spell naming its class as a `{slug, name}` soft ref was invisible
/// in the wizard even though the ref was written correctly — and the parallel
/// `tags` fallback was the only reason bundled spells appeared at all.
void main() {
  Entity ent(String id, String slug, String name) =>
      Entity(id: id, categorySlug: slug, name: name);

  final world = <String, Entity>{
    'c-wiz': ent('c-wiz', 'class', 'Wizard'),
    'c-cle': ent('c-cle', 'class', 'Cleric'),
  };

  test('all three ref envelopes give the same id', () {
    expect(
      resolveEntityRefList(const [
        'c-wiz',
        {'slug': 'class', 'name': 'Cleric'},
        {'_ref': 'class', 'name': 'Cleric'},
      ], world),
      const ['c-wiz', 'c-cle', 'c-cle'],
    );
  });

  test('a soft ref matches the class the wizard picked', () {
    // The membership test every reader now performs.
    const softRefs = [
      {'slug': 'class', 'name': 'Wizard'}
    ];
    // The raw form this replaced — `(refs as List).contains(classId)` — was
    // false here, which is the whole defect.
    expect(resolveEntityRefList(softRefs, world).contains('c-wiz'), isTrue);
  });

  test('unresolvable entries drop, they never throw', () {
    expect(
      resolveEntityRefList(const [
        {'slug': 'class', 'name': 'Artificer'}, // not installed
        'no-such-id',
        42,
        null,
        'c-cle',
      ], world),
      const ['c-cle'],
    );
    expect(resolveEntityRefList(null, world), isEmpty);
    expect(resolveEntityRefList('c-wiz', world), isEmpty);
  });

  // ── Audit phase M1 — feat ASI never applied to a packaged feat ────────
  // `asi_ability_options` is an ability *relation* list, so the same card
  // carries a different shape depending on where it came from: an installed
  // pack resolved its envelopes to ids, an as-authored card still holds the
  // envelope, and parts of the built-in pack ship plain names. The resolver
  // read only the envelope, so no bundled feat ever bumped an ability.
  test('an ability option reads the same in all three shapes', () {
    final abilities = <String, Entity>{
      'a-str': ent('a-str', 'ability', 'Strength'),
    };
    for (final raw in <Object>[
      'a-str', // installed: resolved id
      {'slug': 'ability', 'name': 'Strength'}, // soft ref
      {'_lookup': 'ability', 'name': 'Strength'}, // as authored, unresolved
      'Strength', // built-in plain name
      'STR', // abbreviation
    ]) {
      expect(abilityAbbrevFromRef(raw, abilities), 'STR', reason: '$raw');
    }
    expect(abilityAbbrevFromRef('Luck', abilities), isNull);
    expect(abilityAbbrevFromRef(null, abilities), isNull);
  });
}
