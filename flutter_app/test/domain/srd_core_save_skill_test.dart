// R7 / F-builtin-01 — SRD 5.2.1 statbloklarının kurtarma + beceri satırları.
//
// Satırlar `docs/SRD_CC_v5.2.1.pdf` MOD/SAVE sütunundan ve "Skills"
// satırından çevrildi. Bu test iki şeyi tutuyor: tablo şekli (widget'ın
// beklediği tam satır kümesi) ve elle doğrulanmış birkaç kartın içeriği.

import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/domain/entities/schema/dnd5e_constants.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';

void main() {
  final pack = buildSrdCorePack();
  final creatures = <String, Map<String, dynamic>>{};
  for (final raw in pack.entities.values) {
    final row = raw as Map;
    if (row['type'] == 'monster' || row['type'] == 'animal') {
      creatures['${row['type']}:${row['name']}'] =
          (row['attributes'] as Map).cast<String, dynamic>();
    }
  }

  List<Map<String, dynamic>> rowsOf(String card, String field) =>
      ((creatures[card]![field] as Map)['rows'] as List)
          .map((r) => (r as Map).cast<String, dynamic>())
          .toList();

  Map<String, dynamic> row(String card, String field, String name) =>
      rowsOf(card, field).firstWhere((r) => r['name'] == name);

  group('SRD save/skill tabloları', () {
    test('yazılan her tablo presetin tam satır kümesini taşıyor', () {
      final expected = {
        'save_bonuses': kDnd5eSavingThrows.map((p) => p.name).toList(),
        'skill_bonuses': kDnd5eSkills.map((p) => p.name).toList(),
      };
      final broken = <String>[];
      for (final entry in creatures.entries) {
        for (final field in expected.keys) {
          if (!entry.value.containsKey(field)) continue;
          final names =
              rowsOf(entry.key, field).map((r) => r['name']).toList();
          if (!const ListEquality().equals(names, expected[field]!)) {
            broken.add('${entry.key}.$field');
          }
        }
      }
      expect(broken, isEmpty);
    });

    test('kurtarma satırı olan kart sayısı SRD ile aynı', () {
      final withSaves =
          creatures.values.where((a) => a.containsKey('save_bonuses')).length;
      final withSkills =
          creatures.values.where((a) => a.containsKey('skill_bonuses')).length;
      expect(withSaves, 123);
      expect(withSkills, 220);
    });

    test('Adult Red Dragon: Dex/Wis kurtarma, Perception uzmanlık', () {
      expect(row('monster:Adult Red Dragon', 'save_bonuses', 'Dexterity')['proficient'],
          isTrue);
      expect(row('monster:Adult Red Dragon', 'save_bonuses', 'Wisdom')['proficient'],
          isTrue);
      expect(row('monster:Adult Red Dragon', 'save_bonuses', 'Strength')['proficient'],
          isFalse);
      final perception = row('monster:Adult Red Dragon', 'skill_bonuses', 'Perception');
      expect(perception['proficient'], isTrue);
      expect(perception['expertise'], isTrue);
      expect(row('monster:Adult Red Dragon', 'skill_bonuses', 'Stealth')['expertise'],
          isFalse);
    });

    test('Wolf: sadece beceri satırı, kurtarma yok', () {
      expect(creatures['animal:Wolf']!.containsKey('save_bonuses'), isFalse);
      expect(row('animal:Wolf', 'skill_bonuses', 'Perception')['proficient'], isTrue);
      expect(row('animal:Wolf', 'skill_bonuses', 'Stealth')['proficient'], isTrue);
    });

    test('Giant Frog: PB ile açıklanmayan artık misc olarak yazıldı', () {
      final stealth = row('animal:Giant Frog', 'skill_bonuses', 'Stealth');
      expect(stealth['proficient'], isTrue);
      expect(stealth['misc'], 1);
    });
  });
}

class ListEquality {
  const ListEquality();
  bool equals(List<Object?> a, List<Object?> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);
}
