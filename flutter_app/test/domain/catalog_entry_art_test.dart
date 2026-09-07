import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/domain/entities/catalog/catalog_entry.dart';

void main() {
  test('art bytes count toward the advertised download size', () {
    final e = CatalogEntry.fromJson({
      'slug': 'open5e-vom',
      'size_bytes': 1000,
      'art_count': 1063,
      'art_bytes': 103900000,
    });
    expect(e.artCount, 1063);
    // Kart görselleri boyuta girmezse paket 1 KB görünür, 100 MB iner.
    expect(e.downloadBytes, 1000 + 103900000);
  });

  test('art fields default to zero for an entry without card art', () {
    final e = CatalogEntry.fromJson({'slug': 'x', 'size_bytes': 5});
    expect(e.artCount, 0);
    expect(e.downloadBytes, 5);
  });
}
