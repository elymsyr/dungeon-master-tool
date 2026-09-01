import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/character_ext.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

Character _char(String? ownerId) => Character(
      id: 'c1',
      templateId: 't',
      templateName: 'PC',
      worldId: 'w1',
      ownerId: ownerId,
      entity: const Entity(
        id: 'c1',
        categorySlug: 'player_character',
        name: 'Vex',
        fields: const {},
      ),
      createdAt: '',
      updatedAt: '',
    );

void main() {
  group('isOwnedBy', () {
    test('signed in: only the matching uid owns', () {
      expect(_char('u1').isOwnedBy('u1'), isTrue);
      expect(_char('u2').isOwnedBy('u1'), isFalse);
      expect(_char(null).isOwnedBy('u1'), isFalse);
    });

    test('guest: unclaimed is mine, foreign owner is not', () {
      expect(_char(null).isOwnedBy(null), isTrue);
      expect(_char('u2').isOwnedBy(null), isFalse);
    });

    test('guest release marker is never owned', () {
      expect(_char(kGuestReleasedOwnerId).isOwnedBy(null), isFalse);
      expect(_char(kGuestReleasedOwnerId).isOwnedBy('u1'), isFalse);
    });

    test('marker never leaks as an owner id', () {
      expect(_char(kGuestReleasedOwnerId).normalizedOwnerId, isNull);
      expect(_char('u1').normalizedOwnerId, 'u1');
    });
  });
}
