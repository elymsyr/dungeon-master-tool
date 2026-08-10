import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// `audit_packs --builtin` (audit phase **T2**) censuses the built-in pack by
/// reading each row's flat value map — Tier-0 seed rows keep theirs under
/// `fields`, Tier-1 SRD rows under `attributes`. Nothing else asserts that,
/// and the failure is silent: if a row shape drifted, the census would report
/// 0% filled for a whole category and read as a content hole instead of a
/// tool bug. That is the one thing worth pinning here.
void main() {
  test('every Tier-0 seed row exposes its values under `fields`', () {
    final seedRows = generateBuiltinDnd5eV2Schema().seedRows;
    var rows = 0;
    seedRows.forEach((slug, list) {
      for (final row in list) {
        rows++;
        expect(row['name'], isA<String>(), reason: '$slug row has no name');
        expect(row['fields'], isA<Map>(),
            reason: '$slug/${row['name']} has no `fields` map — the census '
                'would count it as a fully empty entity');
      }
    });
    // Tier-1 / Tier-2 categories ship shape only, so this counts Tier-0 alone.
    expect(rows, greaterThan(300));
  });

  test('every SRD core row exposes its values under `attributes`', () {
    final pack = buildSrdCorePack();
    expect(pack.entities, isNotEmpty);
    for (final raw in pack.entities.values) {
      final row = raw as Map;
      expect(row['type'], isA<String>());
      expect(row['attributes'], isA<Map>(),
          reason: '${row['name']} has no `attributes` map');
    }
  });
}
