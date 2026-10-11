import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
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
}
