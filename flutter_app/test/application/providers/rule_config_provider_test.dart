import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/providers/rule_config_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_config.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

WorldSchema _schema({Map<String, dynamic> metadata = const {}}) => WorldSchema(
      schemaId: 'test-schema',
      createdAt: '0',
      updatedAt: '0',
      metadata: metadata,
    );

ProviderContainer _container(WorldSchema schema, {ProviderContainer? parent}) {
  final c = ProviderContainer(
    parent: parent,
    overrides: [worldSchemaProvider.overrideWithValue(schema)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ruleConfigProvider', () {
    test('schema without rule_config metadata → the const dnd5e defaults', () {
      final c = _container(_schema());
      final config = c.read(ruleConfigProvider);
      expect(identical(config, RuleConfig.dnd5eDefaults), isTrue,
          reason: 'stable identity keeps downstream rebuilds cheap');
    });

    test('schema with a rule_config override → parsed values', () {
      final c = _container(_schema(metadata: {
        'rule_config': {'ac_unarmored_base': 13, 'asi_levels': [4, 6]},
      }));
      final config = c.read(ruleConfigProvider);
      expect(config.acUnarmoredBase, 13);
      expect(config.asiLevels, [4, 6]);
      expect(config.acShieldBonus, RuleConfig.dnd5eDefaults.acShieldBonus,
          reason: 'unset keys keep defaults');
    });

    test('nested scope override wins inside the scope (package screen)', () {
      // Mirrors package_screen.dart: a nested ProviderScope overrides
      // worldSchemaProvider with the package schema. Without the
      // `dependencies` declaration, the child read used to resolve the ROOT
      // world's config.
      final parent = _container(_schema(metadata: {
        'rule_config': {'ac_unarmored_base': 11},
      }));
      final child = _container(
        _schema(metadata: {
          'rule_config': {'ac_unarmored_base': 13},
        }),
        parent: parent,
      );
      expect(parent.read(ruleConfigProvider).acUnarmoredBase, 11);
      expect(child.read(ruleConfigProvider).acUnarmoredBase, 13);
    });
  });
}
