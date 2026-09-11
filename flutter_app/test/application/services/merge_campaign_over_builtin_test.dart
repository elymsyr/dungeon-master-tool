import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';

Entity _e(String id, String name, String slug) =>
    Entity(id: id, name: name, categorySlug: slug);

void main() {
  test('campaign copy hides the builtin twin from iteration', () {
    final builtin = {'srd-archery': _e('srd-archery', 'Archery', 'feat')};
    final campaign = {'synth-archery': _e('synth-archery', 'archery', 'feat')};

    final merged = mergeCampaignOverBuiltin(campaign, builtin);

    expect(merged.values.map((e) => e.id), ['synth-archery']);
    expect(merged.length, 1);
    // Old builtin id still dereferences (worldless char bound to a world).
    expect(merged['srd-archery']?.id, 'synth-archery');
  });

  test('builtin-only rows survive; same name in another category is kept', () {
    final builtin = {
      'srd-slow-spell': _e('srd-slow-spell', 'Slow', 'spell'),
      'srd-slow-mastery': _e('srd-slow-mastery', 'Slow', 'weapon-mastery'),
    };
    final campaign = {'w-slow': _e('w-slow', 'Slow', 'spell')};

    final merged = mergeCampaignOverBuiltin(campaign, builtin);

    expect(merged.keys.toSet(), {'w-slow', 'srd-slow-mastery'});
  });
}
