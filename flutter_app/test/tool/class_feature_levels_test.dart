import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/mappers/chargen.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B1 — `ClassFeatureItem` becomes a level table that reaches the
/// sheet.**
///
/// `audit_packs` can only say `features` is *non-empty*; that is a statement
/// about the file. This asserts the whole chain on the shapes Open5e actually
/// ships: importer fixture → `mapClasses` → `CharacterResolver.activeFeatures`.
///
/// It drives the mapper rather than a bundled asset on purpose: a fixture can
/// state the upstream shapes (a table column, an unlevelled feature, a parent
/// that lives in another pack) that no shipped document happens to combine.
/// The asset-side half — what actually shipped after the rebuild — lives in
/// `bundled_pack_resolve_test`'s "a third-party subclass reaches the sheet".
void main() {
  /// Upstream shape, verified against the pinned snapshot: `ClassFeature` has
  /// `parent` → CharacterClass pk and no level; `ClassFeatureItem` has `parent`
  /// → ClassFeature pk plus `level`, `detail` and `column_value`.
  Map<String, dynamic> item(String parent, int level,
          {String? detail, String? columnValue}) =>
      {
        '_pk': '$parent-$level',
        'parent': parent,
        'level': level,
        'detail': detail,
        'column_value': columnValue,
      };

  final classes = <Map<String, dynamic>>[
    {
      '_pk': 'x_testwright',
      'name': 'Testwright',
      'desc': 'A base class.',
      'hit_dice': 'd8',
      'saving_throws': ['int', 'wis'],
    },
    {
      // Subclass of a base class that ships in the *built-in* pack — the
      // majority case (76 of toh's rows), and the one that needs a softRef.
      '_pk': 'x_path-of-test',
      'name': 'Path of Test',
      'subclass_of': 'srd_barbarian',
      'desc': 'A subclass.',
    },
  ];

  final features = <Map<String, dynamic>>[
    {'_pk': 'f_strike', 'parent': 'x_path-of-test', 'name': 'Hellish Strike',
      'desc': 'You strike.'},
    {'_pk': 'f_improve', 'parent': 'x_path-of-test', 'name': 'Improving Thing',
      'desc': 'It improves.'},
    {'_pk': 'f_profbonus', 'parent': 'x_path-of-test',
      'name': 'Proficiency Bonus', 'desc': ''},
    {'_pk': 'f_nolevel', 'parent': 'x_path-of-test', 'name': 'Unlevelled',
      'desc': 'No ClassFeatureItem exists for this one.'},
    {'_pk': 'f_base', 'parent': 'x_testwright', 'name': 'Base Feature',
      'desc': 'The class gets this.'},
  ];

  final featureItems = <Map<String, dynamic>>[
    item('f_strike', 3),
    item('f_improve', 6),
    item('f_improve', 14, detail: '2 dice'),
    // A class-table column: 20 rows, every one carrying a `column_value`.
    for (var l = 1; l <= 20; l++)
      item('f_profbonus', l, columnValue: '+${2 + (l - 1) ~/ 4}'),
    item('f_base', 1),
  ];

  Map<String, dynamic> emit() {
    final pack = PackBuilder('b1-test');
    mapClasses(
      pack: pack,
      norm: Normalizer(),
      source: 'Test Doc',
      classes: classes,
      features: features,
      featureItems: featureItems,
    );
    pack.resolveRefs();
    return pack.entities;
  }

  Map<String, dynamic> row(String type) => Map<String, dynamic>.from(
      emit().values.cast<Map>().firstWhere((e) => e['type'] == type));

  /// `packEntity` builds a plain `Map`, so the attribute bag needs re-typing.
  Map<String, dynamic> attrsOf(String type) =>
      Map<String, dynamic>.from(row(type)['attributes'] as Map);

  group('mapClasses emits the level table', () {
    test('subclass gets one row per level, sorted, table columns excluded', () {
      final rows = (attrsOf('subclass')['features'] as List).cast<Map>();
      expect(rows.map((r) => [r['level'], r['name']]), [
        [3, 'Hellish Strike'],
        [6, 'Improving Thing'],
        [14, 'Improving Thing'],
      ]);
      // `Proficiency Bonus` is a 20-row class table (B2), not 20 features, and
      // `Unlevelled` has no item at all — neither may invent a row.
      expect(rows.map((r) => r['name']), isNot(contains('Proficiency Bonus')));
      expect(rows.map((r) => r['name']), isNot(contains('Unlevelled')));
    });

    test('granted_at_level is the lowest level the subclass grants at', () {
      expect(attrsOf('subclass')['granted_at_level'], 3);
    });

    test('a feature that improves keeps prose once and detail after', () {
      final rows = (attrsOf('subclass')['features'] as List).cast<Map>();
      expect(rows[1]['description'], 'It improves.');
      expect(rows[2]['description'], '**At this level:** 2 dice');
    });

    test('base classes get the same table', () {
      final attrs = attrsOf('class');
      expect((attrs['features'] as List).single,
          containsPair('name', 'Base Feature'));
      // A base class is not gated by `granted_at_level` and must not carry it.
      expect(attrs.containsKey('granted_at_level'), isFalse);
    });
  });

  group('B4 — a feature becomes a card the sheet can grant', () {
    /// Every grant path is ref-based, so a row carrying only prose granted
    /// nothing. These assert the ref exists, aims at a real card, and is
    /// emitted **once** per feature however many levels it improves at.
    test('the first row of each feature aims at a minted feat', () {
      final ents = emit();
      final sub = ents.values
          .cast<Map>()
          .firstWhere((e) => e['type'] == 'subclass');
      final rows =
          (((sub['attributes'] as Map)['features']) as List).cast<Map>();
      String? featName(Map r) {
        final refs = r['granted_feat_refs'];
        if (refs is! List || refs.isEmpty) return null;
        return ((ents[refs.first] as Map)['name']) as String;
      }

      expect(featName(rows[0]), 'Hellish Strike');
      expect(featName(rows[1]), 'Improving Thing');
      // Level 14 is the same feature improving — one card, granted once, or the
      // resolver would apply it twice.
      expect(featName(rows[2]), isNull);
    });

    test('the minted card is a Subclass Feature carrying the prose', () {
      final feat = emit().values.cast<Map>().firstWhere(
          (e) => e['type'] == 'feat' && e['name'] == 'Hellish Strike');
      final a = feat['attributes'] as Map;
      expect(a['benefits'], 'You strike.');
      expect(a['chooseable'], isFalse);
      expect(a['category_ref'],
          containsPair('name', 'Subclass Feature'));
    });

    test('a base class feature is a Class Feature card', () {
      final ents = emit();
      final cls =
          ents.values.cast<Map>().firstWhere((e) => e['type'] == 'class');
      final rows =
          (((cls['attributes'] as Map)['features']) as List).cast<Map>();
      final refs = rows.single['granted_feat_refs'] as List;
      final feat = ents[refs.single] as Map;
      expect(feat['name'], 'Base Feature');
      expect((feat['attributes'] as Map)['category_ref'],
          containsPair('name', 'Class Feature'));
    });

    test('a subclass with no level table borrows the sibling level', () {
      // F-toh-02: `Path of Hellfire` ships zero `ClassFeatureItem` rows, so
      // there is no level to read off its own table. Both readers default to 1
      // when the field is absent — a Barbarian path openable at level 1.
      final pack = PackBuilder('b4-sibling');
      mapClasses(
        pack: pack,
        norm: Normalizer(),
        source: 'Test Doc',
        classes: [
          ...classes,
          {
            '_pk': 'x_featureless',
            'name': 'Path of Nothing',
            'subclass_of': 'srd_barbarian',
            'desc': 'Upstream ships no feature rows for this one.',
          },
        ],
        features: features,
        featureItems: featureItems,
      );
      pack.resolveRefs();
      final bare = pack.entities.values
          .cast<Map>()
          .firstWhere((e) => e['name'] == 'Path of Nothing');
      // Its sibling `Path of Test` opens at 3, and in 5e every path of a class
      // shares that level — derived from the data, not invented.
      expect((bare['attributes'] as Map)['granted_at_level'], 3);
    });
  });

  group('the rows reach the sheet', () {
    /// Install the emitted subclass next to the built-in SRD, so its
    /// `parent_class_ref` softRef resolves onto the built-in Barbarian exactly
    /// as it does after a real install.
    late final srd = buildBuiltinSrdEntities();
    late final subclass = () {
      final r = row('subclass');
      return Entity(
        id: 'sub1',
        categorySlug: 'subclass',
        name: r['name'] as String,
        fields: Map<String, dynamic>.from(r['attributes'] as Map),
      );
    }();
    late final world = <String, Entity>{...srd, 'sub1': subclass};
    late final barbarianId = srd.values
        .firstWhere((e) => e.categorySlug == 'class' && e.name == 'Barbarian')
        .id;

    List<int> levelsAt(int classLevel) {
      final eff = CharacterResolver.resolve(
        Character(
          id: 'pc1',
          templateId: 'tpl',
          templateName: 'Tpl',
          worldId: 'w',
          createdAt: '0',
          updatedAt: '0',
          entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: {
            'class_levels': {barbarianId: classLevel},
            'subclass_id': 'sub1',
          }),
        ),
        world,
      );
      return eff.activeFeatures
          .where((f) => f.sourceEntityId == 'sub1')
          .map((f) => f.level)
          .toList()
        ..sort();
    }

    test('nothing before granted_at_level', () => expect(levelsAt(2), isEmpty));
    test('the level-3 feature at level 3', () => expect(levelsAt(3), [3]));
    test('every earned row at level 14', () => expect(levelsAt(14), [3, 6, 14]));
  });
}
