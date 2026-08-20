import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/emit.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';
import '../../tool/open5e_import/sources.dart';

/// **Audit phase R6 — names and pack identity.**
///
/// Two guards. The alias table (F-pass0-07) has to rename the card *and* keep
/// the pack's own `_ref` graph resolving, because a ref placeholder is written
/// with the upstream spelling long before the card is added. The Open5e
/// Originals fold (F-open5e-01) has to leave the second document's game system
/// readable on the card it contributes.
void main() {
  Map<String, dynamic> card(String slug, String name,
          {Map<String, dynamic>? attrs}) =>
      {'name': name, 'type': slug, 'attributes': attrs ?? <String, dynamic>{}};

  group('R6 — card name aliases', () {
    test('a measured variant adopts the built-in spelling, anything else does '
        'not', () {
      expect(canonicalCardName('Eye bite'), 'Eyebite');
      expect(canonicalCardName('devils sight'), "Devil's Sight");
      expect(canonicalCardName('Legendary Resistance (3/ Day)'),
          'Legendary Resistance (3/Day)');
      // Not an alias: R6 is a table, not a fold — a name that merely *looks*
      // like a built-in one keeps its own spelling (§2.3 stays strict).
      expect(canonicalCardName('Fire Ball'), 'Fire Ball');
      expect(canonicalCardName('  Eyebite  '), 'Eyebite');
    });

    test('the rename lands on the card and the ref written with the upstream '
        'spelling still resolves', () {
      final pack = PackBuilder('open5e-test');
      final spellId = pack.add(card('spell', 'Eye bite'));
      pack.add(card('monster', 'Warlock', attrs: {
        'spell_refs': [
          {'_ref': 'spell', 'name': 'Eye bite'},
        ],
      }));

      expect(pack.entities[spellId]!['name'], 'Eyebite');
      expect(pack.has('spell', 'Eyebite'), isTrue);
      expect(pack.has('spell', 'Eye bite'), isTrue);
      expect(pack.resolveRefs(), isEmpty);

      final warlock = pack.entities[pack.stableId('monster', 'Warlock')]!;
      expect((warlock['attributes']['spell_refs'] as List).single, spellId);
    });
  });

  group('R6 — Open5e Originals fold', () {
    SourceDoc doc(String slug, String system) => SourceDoc(
          slug: slug,
          title: 'Open5e Originals',
          publisher: 'Open5e',
          license: 'ogl-10a',
          gameSystem: system,
          v2Dir: '/nonexistent',
          files: const {},
        );

    test('the second document\'s game system reaches the card it contributes',
        () {
      final dir = Directory.systemTemp.createTempSync('r6-merge');
      addTearDown(() => dir.deleteSync(recursive: true));

      final primary = assemblePack(
        doc: doc('open5e', '5e-2014'),
        entities: {
          'a': {
            'name': 'School of Abjuring and Warding',
            'type': 'subclass',
            'source': 'Open5e Originals',
          },
        },
        sourceDataRev: 'rev',
      );
      final secondary = assemblePack(
        doc: doc('open5e-2024', '5e-2024'),
        entities: {
          'b': {
            'name': 'Abjurationist',
            'type': 'subclass',
            'source': 'Open5e Originals',
          },
        },
        sourceDataRev: 'rev',
      );
      // The fold keys off the package name, which `SourceDoc` derives.
      expect(primary.doc.packageName, 'open5e-open5e');
      expect(secondary.doc.packageName, 'open5e-open5e-2024');

      final merged =
          mergeOpen5eOriginals([primary, secondary], dir.path, 'rev').single;
      final entities =
          (merged.payload['entities'] as Map).cast<String, dynamic>();
      expect(entities['a']['source'], 'Open5e Originals');
      expect(entities['b']['source'], 'Open5e Originals (5e-2024)');
      expect(merged.payload['metadata']['game_system'], '5e-2014');

      final written = jsonDecode(
          File('${dir.path}/open5e-open5e.pkg.json').readAsStringSync()) as Map;
      expect((written['entities'] as Map)['b']['source'],
          'Open5e Originals (5e-2024)');
    });
  });
}
