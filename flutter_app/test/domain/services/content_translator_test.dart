import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/content_translator.dart';
import 'package:flutter_test/flutter_test.dart';

/// **SRD TR Faz 4.1 — `ContentTranslator`.** Eşleşmeyen ya da çevrilmemiş
/// metin İngilizce kalır; çeviri sadece gösterilen kopyaya uygulanır, girdi
/// değer asla değişmez (K3) ve makine değerleri (ref, zar, `source`) aynen
/// geçer.
void main() {
  const tx = ContentTranslator({
    '_schema': {'Summary': 'Özet', 'Standard': 'Standart', 'Rare': ''},
    'condition': {'Poisoned': 'Zehirlenme', 'Blinded': ''},
    'class': {
      'Rage': 'Hiddet',
      'Starting Equipment': 'Başlangıç Ekipmanı',
      'Choose one': 'Birini seç',
      '+1d6 damage.': '+1d6 hasar.',
    },
  });

  FieldSchema field(
    FieldType type, {
    String key = 'k',
    String label = 'Summary',
    List<Map<String, String>> subFields = const [],
  }) =>
      FieldSchema(
        fieldId: 'f',
        categoryId: 'c',
        fieldKey: key,
        label: label,
        fieldType: type,
        subFields: subFields,
        createdAt: '',
        updatedAt: '',
      );

  test('tr: eksik, boş ve başka scope → İngilizce', () {
    expect(tx.tr('condition', 'Poisoned'), 'Zehirlenme');
    expect(tx.tr('condition', 'Prone'), 'Prone'); // tabloda yok
    expect(tx.tr('condition', 'Blinded'), 'Blinded'); // "" = çevrilmedi
    expect(tx.tr('spell', 'Poisoned'), 'Poisoned'); // scope'lar ayrı
    expect(ContentTranslator.identity.tr('condition', 'Poisoned'), 'Poisoned');
  });

  test('field: etiketler çevrilir, değişiklik yoksa aynı nesne döner', () {
    final f = field(FieldType.text,
        subFields: const [{'key': 'a', 'label': 'Summary'}]);
    final shown = tx.field(f);
    expect(shown.label, 'Özet');
    expect(shown.subFields.single, {'key': 'a', 'label': 'Özet'});
    expect(shown.fieldKey, f.fieldKey);
    final untouched = field(FieldType.text, label: 'Speed');
    expect(identical(tx.field(untouched), untouched), isTrue);
    expect(identical(ContentTranslator.identity.field(f), f), isTrue);
  });

  test('value: metin, enum ve makine alanları', () {
    expect(tx.value('condition', field(FieldType.text), 'Poisoned'),
        'Zehirlenme');
    expect(tx.value('condition', field(FieldType.markdown), 'Prone'), 'Prone');
    expect(tx.value('x', field(FieldType.enum_), 'Standard'), 'Standart');
    expect(tx.value('x', field(FieldType.enum_), ['Standard', 'Rare']),
        ['Standart', 'Rare']);
    // `source` gibi kimlik alanları ve relation/zar değerleri dokunulmaz.
    expect(
        tx.value('condition', field(FieldType.text, key: 'source'), 'Poisoned'),
        'Poisoned');
    expect(tx.value('condition', field(FieldType.relation), 'Poisoned'),
        'Poisoned');
    expect(tx.value('condition', field(FieldType.dice), '1d6'), '1d6');
  });

  test('value: yapılandırılmış listeler kopyalanır, girdi değişmez (K3)', () {
    final features = [
      {
        'level': 1,
        'name': 'Rage',
        'description': 'Unknown text',
        'granted_feat_refs': [
          {'_ref': 'feat', 'name': 'Rage'},
        ],
      },
    ];
    final shown =
        tx.value('class', field(FieldType.classFeatures), features) as List;
    expect(shown.single['name'], 'Hiddet');
    expect(shown.single['description'], 'Unknown text');
    expect(shown.single['level'], 1);
    // Ref zarfının içindeki ad çevrilmez — çözüm İngilizce adla yapılır.
    expect(shown.single['granted_feat_refs'],
        [
          {'_ref': 'feat', 'name': 'Rage'},
        ]);
    expect(features.single['name'], 'Rage');

    final groups = [
      {
        'group_id': 'starting_kit',
        'label': 'Starting Equipment',
        'prompt': 'Choose one',
        'options': [
          {'label': 'Choose one', 'items': ['x']},
        ],
      },
    ];
    final g = (tx.value('class', field(FieldType.equipmentChoiceGroups), groups)
            as List)
        .single as Map;
    expect(g['group_id'], 'starting_kit');
    expect(g['label'], 'Başlangıç Ekipmanı');
    expect(g['prompt'], 'Birini seç');
    expect((g['options'] as List).single, {'label': 'Birini seç', 'items': ['x']});
    expect(groups.single['label'], 'Starting Equipment');

    final table = {'2': '+1d6 damage.', '3': 'Other.'};
    expect(tx.value('class', field(FieldType.levelTextTable), table),
        {'2': '+1d6 hasar.', '3': 'Other.'});
    expect(table['2'], '+1d6 damage.');
  });

  test('forCard: homebrew kartın içeriği çevrilmez, şema sözcükleri çevrilir', () {
    expect(identical(tx.forCard(true), tx), isTrue);
    final hb = tx.forCard(false);
    expect(identical(tx.forCard(false), hb), isTrue);
    expect(hb.tr('class', 'Rage'), 'Rage');
    expect(hb.value('class', field(FieldType.text), 'Rage'), 'Rage');
    expect(hb.value('class', field(FieldType.enum_), 'Standard'), 'Standart');
    expect(hb.field(field(FieldType.text)).label, 'Özet');
  });
}
