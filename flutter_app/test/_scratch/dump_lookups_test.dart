import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_srd_pack.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dump', () {
    final build = generateBuiltinDnd5eV2Schema();
    final cats = {for (final c in srdFreeTemplate.categories) c.slug: c};
    for (final slug in freeSrdLookups) {
      final c = cats[slug]!;
      final rows = build.seedRows[slug] ?? const [];
      print('## $slug | fields: ${c.fields.map((f) => '${f.fieldKey}:${f.fieldType.name}').join(', ')}');
      print('   cards(${rows.length}): ${rows.map((r) => r['name']).join(' / ')}');
    }
    print('## trinket | ${cats['trinket']?.fields.map((f) => '${f.fieldKey}:${f.fieldType.name}').join(', ')}');
  });
}
