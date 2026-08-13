import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/providers/first_party_catalog_provider.dart';

// Audit D2: the installed-vs-catalog upgrade trigger. `emit.packVersion` is a
// hand-bumped semver, so this comparison is the whole mechanism — a wrong
// answer either nags forever or never offers the rebuild.
void main() {
  test('offers an update only for a strictly newer semver', () {
    expect(isCatalogUpdateAvailable('1.0.0', '1.1.0'), isTrue);
    expect(isCatalogUpdateAvailable('1.9.0', '1.10.0'), isTrue); // not string <
    expect(isCatalogUpdateAvailable('1.1.0', '1.1.1'), isTrue);
    expect(isCatalogUpdateAvailable('1.1.0', '1.1.0'), isFalse);
    expect(isCatalogUpdateAvailable('2.0.0', '1.1.0'), isFalse);
  });

  test('unparsable or missing versions report no update', () {
    expect(isCatalogUpdateAvailable(null, '1.1.0'), isFalse);
    expect(isCatalogUpdateAvailable('', '1.1.0'), isFalse);
    expect(isCatalogUpdateAvailable('1.0', '1.1.0'), isFalse);
    expect(isCatalogUpdateAvailable('1.0.0', 'latest'), isFalse);
  });
}
