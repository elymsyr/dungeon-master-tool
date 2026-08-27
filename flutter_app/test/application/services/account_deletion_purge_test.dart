import 'package:dungeon_master_tool/application/services/account_deletion_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bellekte sahte bir bucket: yol → obje. Klasörler sanal, tıpkı Supabase
/// Storage'daki gibi — altındaki son obje silinince listeden düşerler.
class _FakeBucket {
  _FakeBucket(Iterable<String> keys) : _keys = {...keys};

  final Set<String> _keys;
  int listCalls = 0;

  /// `limit` burada bilerek var: bug tam olarak buydu — `SearchOptions.limit`
  /// varsayılanı 100 ve `list()` onu gövdeye koyuyor, yani sayfa sınırı
  /// sunucu tarafında gerçek.
  Future<List<StorageEntry>> list(String path, {required int limit}) async {
    listCalls++;
    final prefix = '$path/';
    final names = <String, bool>{};
    for (final key in _keys) {
      if (!key.startsWith(prefix)) continue;
      final rest = key.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash == -1) {
        names[rest] = false;
      } else {
        names[rest.substring(0, slash)] = true;
      }
    }
    final sorted = names.keys.toList()..sort();
    return [
      for (final name in sorted.take(limit)) (name: name, isFolder: names[name]!),
    ];
  }

  Future<int> remove(List<String> keys) async {
    var n = 0;
    for (final key in keys) {
      if (_keys.remove(key)) n++;
    }
    return n;
  }

  int get remaining => _keys.length;
}

void main() {
  group('purgeStorageTree', () {
    test('sayfa sınırının ötesindeki objeleri de siler', () async {
      // Regresyon: sayfa başına 100 sınırı varken 250 objenin 150'si sessizce
      // kalıyordu — hesap satırı düşünce owner-scoped RLS artık eşleşmediği
      // için kalıcı olarak erişilemez hâle geliyorlardı.
      final bucket = _FakeBucket([
        for (var i = 0; i < 250; i++) 'uid/file_${i.toString().padLeft(3, '0')}',
      ]);

      await purgeStorageTree(
        path: 'uid',
        list: (p) => bucket.list(p, limit: 100),
        remove: bucket.remove,
      );

      expect(bucket.remaining, 0);
      expect(bucket.listCalls, greaterThan(1), reason: 'tek sayfa yetmemeli');
    });

    test('alt klasörlere iner (shared-payloads/{uid}/listings/...)', () async {
      final bucket = _FakeBucket([
        'uid/avatar.png',
        'uid/listings/a.json.gz',
        'uid/listings/b.json.gz',
        'uid/listings/nested/c.json.gz',
      ]);

      await purgeStorageTree(
        path: 'uid',
        list: (p) => bucket.list(p, limit: 100),
        remove: bucket.remove,
      );

      expect(bucket.remaining, 0);
    });

    test('başka kullanıcının prefixine dokunmaz', () async {
      final bucket = _FakeBucket(['uid/mine.png', 'other/theirs.png']);

      await purgeStorageTree(
        path: 'uid',
        list: (p) => bucket.list(p, limit: 100),
        remove: bucket.remove,
      );

      expect(bucket.remaining, 1);
    });

    test('eksik silme sessiz geçmez, StateError atar', () async {
      // Supabase `remove` RLS'e takılan objeyi listeden çıkarır ama 200 döner;
      // exception gelmez. Sayı farkı tek sinyal.
      final bucket = _FakeBucket(['uid/a.png', 'uid/b.png']);

      expect(
        () => purgeStorageTree(
          path: 'uid',
          list: (p) => bucket.list(p, limit: 100),
          // Yalnız birini siliyormuş gibi davran.
          remove: (keys) async => bucket.remove(keys.take(1).toList()),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('incomplete'),
          ),
        ),
      );
    });

    test('hiç silmeyen bir remove sonsuz döngüye girmez', () async {
      final bucket = _FakeBucket(['uid/a.png']);

      expect(
        () => purgeStorageTree(
          path: 'uid',
          list: (p) => bucket.list(p, limit: 100),
          remove: (_) async => 0,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
