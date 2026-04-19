import 'package:dungeon_master_tool/domain/dnd5e/world/campaign.dart';
import 'package:dungeon_master_tool/domain/dnd5e/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PackageVersion', () {
    test('components >= 0', () {
      expect(() => PackageVersion(-1, 0, 0), throwsArgumentError);
    });

    test('equality by triple', () {
      expect(PackageVersion(1, 2, 3), PackageVersion(1, 2, 3));
      expect(PackageVersion(1, 2, 3) == PackageVersion(1, 2, 4), isFalse);
    });
  });

  group('World', () {
    test('rejects duplicate installed packages', () {
      final now = DateTime(2026, 1, 1);
      expect(
          () => World(
                id: 'w',
                name: 'W',
                createdAt: now,
                installedPackages: [
                  InstalledPackage(
                      packageId: 'srd',
                      version: PackageVersion(1, 0, 0),
                      installedAt: now),
                  InstalledPackage(
                      packageId: 'srd',
                      version: PackageVersion(1, 0, 0),
                      installedAt: now),
                ],
              ),
          throwsArgumentError);
    });

    test('hasPackage lookup', () {
      final now = DateTime(2026, 1, 1);
      final w = World(
        id: 'w',
        name: 'W',
        createdAt: now,
        installedPackages: [
          InstalledPackage(
              packageId: 'srd',
              version: PackageVersion(1, 0, 0),
              installedAt: now),
        ],
      );
      expect(w.hasPackage('srd'), isTrue);
      expect(w.hasPackage('homebrew'), isFalse);
    });
  });

  group('Campaign', () {
    test('lastPlayedAt cannot precede createdAt', () {
      expect(
          () => Campaign(
                id: 'c',
                worldId: 'w',
                name: 'C',
                createdAt: DateTime(2026, 2, 1),
                lastPlayedAt: DateTime(2026, 1, 1),
              ),
          throwsArgumentError);
    });
  });
}
