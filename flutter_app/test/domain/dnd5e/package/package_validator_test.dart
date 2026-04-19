import 'package:dungeon_master_tool/domain/dnd5e/effect/custom_effect_registry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/package_validator.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExt implements CustomEffectImpl {
  @override
  final String id;
  _FakeExt(this.id);
}

Dnd5ePackage _base({
  String slug = 'srd',
  String formatVersion = '2',
  String gameSystemId = 'dnd5e',
  List<String> exts = const [],
  List<CatalogEntry> conds = const [],
  List<SpellEntry> spells = const [],
}) =>
    Dnd5ePackage(
      id: 'u',
      packageIdSlug: slug,
      name: 'n',
      version: '1',
      authorId: 'a',
      authorName: 'A',
      formatVersion: formatVersion,
      gameSystemId: gameSystemId,
      requiredRuntimeExtensions: exts,
      conditions: conds,
      spells: spells,
    );

void main() {
  group('PackageValidator', () {
    late CustomEffectRegistry reg;
    late PackageValidator v;

    setUp(() {
      reg = CustomEffectRegistry();
      v = PackageValidator(reg);
    });

    test('clean package has no issues', () {
      final issues = v.validate(_base());
      expect(issues, isEmpty);
      expect(v.isFatal(issues), false);
    });

    test('fails on wrong formatVersion', () {
      final issues = v.validate(_base(formatVersion: '1'));
      expect(v.isFatal(issues), true);
      expect(issues.first.message, contains('formatVersion'));
    });

    test('fails on wrong gameSystemId', () {
      final issues = v.validate(_base(gameSystemId: 'pathfinder'));
      expect(v.isFatal(issues), true);
    });

    test('fails when required runtime extension missing', () {
      final issues = v.validate(_base(exts: ['srd:wish']));
      expect(v.isFatal(issues), true);
      expect(issues.first.message, contains('srd:wish'));
    });

    test('passes when required extension registered', () {
      reg.register(_FakeExt('srd:wish'));
      final issues = v.validate(_base(exts: ['srd:wish']));
      expect(issues, isEmpty);
    });

    test('catches duplicate local ids', () {
      final issues = v.validate(_base(conds: const [
        CatalogEntry(id: 'stunned', name: 'A', bodyJson: '{}'),
        CatalogEntry(id: 'stunned', name: 'B', bodyJson: '{}'),
      ]));
      expect(v.isFatal(issues), true);
      expect(issues.first.message, contains('duplicate'));
    });

    test('catches spell level out of 0..9', () {
      final issues = v.validate(_base(spells: const [
        SpellEntry(
          id: 'f',
          name: 'F',
          level: 10,
          schoolId: 'evocation',
          bodyJson: '{}',
        ),
      ]));
      expect(v.isFatal(issues), true);
      expect(issues.first.message, contains('level'));
    });
  });
}
