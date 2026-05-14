import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/backgrounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('srdBackgrounds (SRD 5.2.1 §1.4)', () {
    final all = srdBackgrounds();
    final names =
        all.map((b) => b['name']?.toString() ?? '').toSet();

    test('ships all 16 Free Rules 2024 backgrounds', () {
      const expected = {
        'Acolyte', 'Artisan', 'Charlatan', 'Criminal',
        'Entertainer', 'Farmer', 'Guard', 'Guide',
        'Hermit', 'Merchant', 'Noble', 'Sage',
        'Sailor', 'Scribe', 'Soldier', 'Wayfarer',
      };
      expect(names, containsAll(expected));
      expect(all.length, expected.length);
    });

    test('every background has required structured fields', () {
      for (final bg in all) {
        final name = bg['name'];
        final attrs = bg['attributes'] as Map<String, dynamic>?;
        expect(attrs, isNotNull, reason: '$name missing attributes');
        expect(attrs!['ability_score_options'], isA<List>(),
            reason: '$name missing ability_score_options');
        expect((attrs['ability_score_options'] as List).length, 3,
            reason: '$name should have exactly 3 ability options');
        expect(attrs['origin_feat_ref'], isNotNull,
            reason: '$name missing origin_feat_ref');
        expect(attrs['granted_skill_refs'], isA<List>(),
            reason: '$name missing granted_skill_refs');
        expect((attrs['granted_skill_refs'] as List).length, 2,
            reason: '$name should grant exactly 2 skills');
        expect(attrs['starting_gold_gp'], isA<int>(),
            reason: '$name missing starting_gold_gp');
        expect(attrs['gold_alternative_gp'], 50,
            reason: '$name should have 50 GP alternative');
        expect(attrs['equipment_choice_groups'], isA<List>(),
            reason: '$name missing equipment_choice_groups');
      }
    });
  });
}
