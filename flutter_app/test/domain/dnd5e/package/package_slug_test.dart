import 'package:dungeon_master_tool/domain/dnd5e/package/package_slug.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('package slug', () {
    test('accepts lowercase + digits + underscore', () {
      expect(isValidPackageSlug('srd'), true);
      expect(isValidPackageSlug('arctic_homebrew'), true);
      expect(isValidPackageSlug('srd_2'), true);
      expect(isValidPackageSlug('a'), true);
    });

    test('rejects uppercase, leading digit, empty, too long', () {
      expect(isValidPackageSlug('SRD'), false);
      expect(isValidPackageSlug('1srd'), false);
      expect(isValidPackageSlug(''), false);
      expect(isValidPackageSlug('a' * 33), false);
      expect(isValidPackageSlug('has-dash'), false);
      expect(isValidPackageSlug('has space'), false);
    });

    test('validatePackageSlug throws on bad input', () {
      expect(() => validatePackageSlug('BAD'), throwsArgumentError);
      expect(validatePackageSlug('srd'), 'srd');
    });
  });
}
