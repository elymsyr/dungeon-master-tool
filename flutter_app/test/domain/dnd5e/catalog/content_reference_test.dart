import 'package:dungeon_master_tool/domain/dnd5e/catalog/content_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateContentId', () {
    test('accepts shape <pkg>:<local>', () {
      expect(validateContentId('srd:stunned'), 'srd:stunned');
      expect(validateContentId('homebrew_pack:frozen'), 'homebrew_pack:frozen');
    });

    test('rejects missing colon', () {
      expect(() => validateContentId('stunned'), throwsArgumentError);
    });

    test('rejects empty package part', () {
      expect(() => validateContentId(':stunned'), throwsArgumentError);
    });

    test('rejects empty local part', () {
      expect(() => validateContentId('srd:'), throwsArgumentError);
    });
  });
}
