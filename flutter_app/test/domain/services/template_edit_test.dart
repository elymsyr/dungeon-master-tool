import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:dungeon_master_tool/domain/services/template_edit.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-11T00:00:00Z';

EntityCategorySchema _cat() => const EntityCategorySchema(
  categoryId: 'c',
  schemaId: 's',
  name: 'Faction',
  slug: 'faction',
  createdAt: _now,
  updatedAt: _now,
);

List<String> _labels(EntityCategorySchema c, String? g) =>
    fieldsIn(c, g).map((f) => f.label).toList();

void main() {
  group('keyFromLabel', () {
    test('folds letters, joins words, never clashes', () {
      expect(keyFromLabel('Çok Güzel İsim', const []), 'cok_guzel_isim');
      expect(keyFromLabel('Hit Points (max)', const []), 'hit_points_max');
      expect(keyFromLabel('Tür', const ['tur']), 'tur_2');
      expect(keyFromLabel('Tür', const ['tur', 'tur_2']), 'tur_3');
      expect(keyFromLabel('!!!', const []), 'field');
      expect(
        keyFromLabel('Legendary Action', const [], separator: '-'),
        'legendary-action',
      );
    });
  });

  group('fields and groups', () {
    EntityCategorySchema base() {
      var c = addGroup(_cat(), id: 'g1', name: 'Kimlik');
      c = addGroup(c, id: 'g2', name: 'Savaş');
      for (final (id, label, g) in [
        ('a', 'Tür', 'g1'),
        ('b', 'Sınıf', 'g1'),
        ('c', 'AC', 'g2'),
        ('d', 'Not', null),
      ]) {
        c = addField(
          c,
          id: id,
          label: label,
          type: FieldType.text,
          groupId: g,
          now: _now,
        );
      }
      return c;
    }

    test('add puts a keyed field where asked', () {
      final c = addField(
        base(),
        id: 'e',
        label: 'Tür',
        type: FieldType.markdown,
        groupId: 'g1',
        index: 0,
        now: _now,
      );
      expect(_labels(c, 'g1'), ['Tür', 'Tür', 'Sınıf']);
      expect(c.fields.firstWhere((f) => f.fieldId == 'e').fieldKey, 'tur_2');
    });

    test('move works inside a group and across groups', () {
      var c = moveField(base(), 'b', groupId: 'g1', index: 0);
      expect(_labels(c, 'g1'), ['Sınıf', 'Tür']);
      c = moveField(c, 'c', groupId: 'g1', index: 1);
      expect(_labels(c, 'g1'), ['Sınıf', 'AC', 'Tür']);
      expect(_labels(c, 'g2'), isEmpty);
      c = moveField(c, 'd', groupId: 'g2');
      expect(_labels(c, null), isEmpty);
      expect(_labels(c, 'g2'), ['Not']);
    });

    test('removing a field drops it from the filters too', () {
      final c = base().copyWith(filterFieldKeys: ['tur', 'ac']);
      final out = removeField(c, 'a');
      expect(out.fields.map((f) => f.fieldId), isNot(contains('a')));
      expect(out.filterFieldKeys, ['ac']);
    });

    test('removing a group keeps its fields', () {
      var c = removeGroup(base(), 'g1');
      expect(c.fieldGroups.map((g) => g.groupId), ['g2']);
      expect(_labels(c, null), ['Not', 'Tür', 'Sınıf']);
      c = removeGroup(base(), 'g1', moveTo: 'g2');
      expect(_labels(c, 'g2'), ['AC', 'Tür', 'Sınıf']);
    });

    test('groups reorder', () {
      final c = reorderGroups(base(), 0, 1);
      expect(sortedGroups(c).map((g) => g.groupId), ['g2', 'g1']);
    });

    test('every SRD copy category survives a move', () {
      final copy = copyAsFreeTemplate(
        generateBuiltinDnd5eV2Schema().schema,
        id: 'x',
        name: 'x',
        now: _now,
      );
      for (final cat in copy.categories.where((c) => c.fields.isNotEmpty)) {
        final moved = moveField(cat, cat.fields.first.fieldId);
        expect(moved.fields, hasLength(cat.fields.length), reason: cat.slug);
      }
    });
  });

  group('type change', () {
    test('follows the compatibility table', () {
      const t = FieldType.text, md = FieldType.markdown;
      expect(typeChangeOf(t, false, md, false), TypeChange.compatible);
      expect(
        typeChangeOf(FieldType.integer, false, FieldType.float_, false),
        TypeChange.compatible,
      );
      expect(
        typeChangeOf(FieldType.float_, false, FieldType.integer, false),
        TypeChange.incompatible,
      );
      expect(
        typeChangeOf(FieldType.enum_, false, t, false),
        TypeChange.compatible,
      );
      expect(
        typeChangeOf(FieldType.enum_, false, FieldType.integer, false),
        TypeChange.incompatible,
      );
      expect(typeChangeOf(t, false, t, true), TypeChange.compatible);
      expect(typeChangeOf(t, true, t, false), TypeChange.incompatible);
      expect(
        typeChangeOf(FieldType.relation, true, FieldType.relation, false),
        TypeChange.lossy,
      );
      expect(typeChangeOf(t, false, t, false), TypeChange.same);
    });

    test('an incompatible change makes a new field with a new key', () {
      var c = addField(
        _cat(),
        id: 'a',
        label: 'Boyut',
        type: FieldType.enum_,
        now: _now,
      );
      c = addField(c, id: 'b', label: 'Not', type: FieldType.text, now: _now);
      c = c.copyWith(filterFieldKeys: ['boyut']);
      final out = changeFieldType(
        c,
        'a',
        FieldType.integer,
        false,
        newId: 'n',
        now: _now,
      );
      expect(out.fields.map((f) => f.fieldId), ['n', 'b']);
      final f = out.fields.first;
      expect(
        (f.label, f.fieldKey, f.fieldType),
        ('Boyut', 'boyut_2', FieldType.integer),
      );
      expect(out.filterFieldKeys, isEmpty);
    });

    test('a compatible change keeps the field and its key', () {
      final c = addField(
        _cat(),
        id: 'a',
        label: 'Ad',
        type: FieldType.text,
        now: _now,
      );
      final out = changeFieldType(
        c,
        'a',
        FieldType.markdown,
        false,
        newId: 'n',
        now: _now,
      );
      expect(out.fields.single.fieldId, 'a');
      expect(out.fields.single.fieldKey, 'ad');
      expect(out.fields.single.fieldType, FieldType.markdown);
    });

    test('a table is a palette style; leaving it drops its settings', () {
      expect(
        paletteFieldTypes,
        containsAll([
          FieldType.table,
          FieldType.statTable,
          FieldType.skillTable,
        ]),
      );
      expect(isLegacyFieldType(FieldType.table), isFalse);
      expect(isLegacyFieldType(FieldType.proficiencyTable), isTrue);
      expect(canBeList(FieldType.table), isFalse);
      expect(
        typeChangeOf(FieldType.table, false, FieldType.text, false),
        TypeChange.incompatible,
      );
      final c = addField(
        _cat(),
        id: 'a',
        label: 'Skills',
        type: FieldType.table,
        now: _now,
      );
      final out = changeFieldType(
        replaceField(
          c,
          c.fields.single.copyWith(styleConfig: const {'fixedRows': true}),
        ),
        'a',
        FieldType.markdown,
        false,
        newId: 'n',
        now: _now,
      );
      expect(out.fields.single.fieldKey, 'skills_2');
      expect(out.fields.single.styleConfig, isNull);
    });
  });

  group('categories', () {
    final empty = emptyFreeTemplate(
      id: 't',
      name: 'T',
      playerCardName: 'PC',
      now: _now,
    );

    test('the player card cannot be removed', () {
      final pc = empty.categories.single;
      expect(canRemoveCategory(pc), isFalse);
      expect(removeCategory(empty, pc.categoryId).categories, hasLength(1));
    });

    test('add, reorder and remove', () {
      var s = addCategory(empty, id: 'f', name: 'Fraksiyon', now: _now);
      s = addCategory(s, id: 'f2', name: 'Fraksiyon', now: _now);
      expect(s.categories.map((c) => c.slug), [
        'player-character',
        'fraksiyon',
        'fraksiyon-2',
      ]);
      expect(s.categories.last.schemaId, 't');
      s = reorderCategories(s, ['${empty.schemaId}-player', 'f2', 'f']);
      expect(s.categories.map((c) => c.categoryId), ['t-player', 'f2', 'f']);
      expect(s.categories.map((c) => c.orderIndex), [0, 1, 2]);
      s = removeCategory(s, 'f');
      expect(s.categories.map((c) => c.categoryId), ['t-player', 'f2']);
    });
  });

  group('presets (DESIGN §9)', () {
    // The player card and an NPC category, both holding the Skills preset.
    WorldSchema base() {
      var s = _bare(
        emptyFreeTemplate(id: 't', name: 'T', playerCardName: 'PC', now: _now),
      );
      s = addCategory(s, id: 'npc', name: 'NPC', now: _now);
      s = addPreset(
        s,
        id: 'p',
        label: 'Skills',
        type: FieldType.skillTable,
        now: _now,
      );
      final p = presetById(s, 'p')!;
      for (final c in s.categories) {
        s = replaceCategory(
          s,
          addPresetField(c, p, id: 'f-${c.categoryId}', now: _now),
        );
      }
      return s;
    }

    FieldSchema fieldOf(WorldSchema s, String cat) =>
        s.categories.firstWhere((c) => c.categoryId == cat).fields.single;

    test('a preset change reaches every bound field; card marks stay', () {
      var s = base();
      expect(presetUses(s, 'p').map((c) => c.categoryId), ['t-player', 'npc']);
      expect(fieldOf(s, 'npc').fieldKey, 'skills');
      final rows = [
        {'_id': 'r1', 'name': 'Athletics', 'ability': 'STR'},
      ];
      s = replacePreset(
        s,
        presetById(s, 'p')!.copyWith(
          label: 'Beceriler',
          styleConfig: SkillTableSpec(rows: rows).toConfig(),
        ),
      );
      for (final cat in ['t-player', 'npc']) {
        final f = fieldOf(s, cat);
        expect(f.label, 'Beceriler');
        expect(SkillTableSpec.of(f).rows, rows);
        expect(f.fieldKey, 'skills'); // a key is made once (V3)
      }
      // E4.6: a new row reaches the card; its mark on Athletics stays.
      s = replacePreset(
        s,
        presetById(s, 'p')!.copyWith(
          styleConfig: SkillTableSpec(
            rows: [
              ...rows,
              {'_id': 'r2', 'name': 'Sailing'},
            ],
          ).toConfig(),
        ),
      );
      final shown = tableRows(SkillTableSpec.of(fieldOf(s, 'npc')).table, [
        {'_id': 'r1', 'proficient': true},
      ]);
      expect(shown.map((r) => r['name']), ['Athletics', 'Sailing']);
      expect(shown.first['proficient'], isTrue);
    });

    test('break link: the field keeps what it has and stops following', () {
      var s = base();
      final npc = s.categories.firstWhere((c) => c.categoryId == 'npc');
      s = replaceCategory(s, unlinkField(npc, 'f-npc'));
      s = replacePreset(s, presetById(s, 'p')!.copyWith(label: 'New'));
      expect(fieldOf(s, 'npc').label, 'Skills');
      expect(fieldOf(s, 'npc').presetId, isNull);
      expect(fieldOf(s, 't-player').label, 'New');
    });

    test('delete: bound fields stay as independent copies (V7)', () {
      final s = removePreset(base(), 'p');
      expect(presetsOf(s), isEmpty);
      for (final cat in ['t-player', 'npc']) {
        expect(fieldOf(s, cat).presetId, isNull);
        expect(fieldOf(s, cat).fieldType, FieldType.skillTable);
      }
    });

    test('once per category, and not over a field with its key (V8)', () {
      final s = base();
      final p = presetById(s, 'p')!;
      expect(canAddPreset(s.categories.first, p), isFalse);
      final taken = addField(
        _cat(),
        id: 'x',
        label: 'Skills',
        type: FieldType.text,
        now: _now,
      );
      expect(canAddPreset(taken, p), isFalse);
      expect(canAddPreset(_cat(), p), isTrue);
    });

    test('save as preset keeps the key; a copy stands alone', () {
      var s = _bare(
        emptyFreeTemplate(id: 't', name: 'T', playerCardName: 'PC', now: _now),
      );
      final pc = s.categories.single;
      s = replaceCategory(
        s,
        addField(pc, id: 'hp', label: 'HP', type: FieldType.integer, now: _now),
      );
      s = saveAsPreset(s, pc.categoryId, 'hp', id: 'p', now: _now);
      final p = presetById(s, 'p')!;
      expect(p.fieldKey, 'hp');
      expect(p.fieldType, FieldType.integer);
      expect(s.categories.single.fields.single.presetId, 'p');
      s = copyPreset(s, 'p', id: 'p2', label: 'HP (copy)', now: _now);
      expect(presetById(s, 'p2')!.fieldKey, 'hp_copy');
      expect(presetUses(s, 'p2'), isEmpty);
    });
  });
}

/// An empty template without the player card's own fields: a bare
/// playground for the editing tests.
WorldSchema _bare(WorldSchema s) => s.copyWith(
  categories: [for (final c in s.categories) c.copyWith(fields: const [])],
);
