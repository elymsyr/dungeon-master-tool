import 'package:drift/drift.dart';

/// Faz 4 — push'un iki yerel gereksinimi: satırın **düzenleme zamanı** ve
/// silinmiş satırın kaydı.
///
/// Push bir kuyruk tutmuyor; "bu dünyada watermark'tan sonra değişen satırlar"
/// taramasıyla çalışıyor (bkz. `CloudPushService`). Tarama iki şeyi göremez:
///
/// 1. `updated_at`'i olmayan satırı — o yüzden DAO upsert'leri [stampedNow]
///    ile damgalıyor. Zaman **istemcide, düzenleme anında** yazılır ve bulutta
///    `now()` ile ezilmez (§2.8): geç gelen çevrimdışı yazma yeni veriyi
///    ezmesin.
/// 2. Artık var olmayan satırı — o yüzden silmeler [recordTombstone] ile
///    ayrıca hatırlanıyor. Push satırı bulutta DELETE eder, oradaki
///    `tg_world_tombstone` trigger'ı `world_tombstones`'a yazar ve yerel kayıt
///    düşer.
extension SyncStamp on DatabaseConnectionUser {
  /// Buluta bildirilecek silmeyi kaydeder. `worldId` boş bırakılırsa satır
  /// hiçbir dünya taramasına düşmez — dünya kapsamlı tablolarda hep verilmeli.
  Future<void> recordTombstone(
    String table,
    String rowId, {
    required String worldId,
  }) =>
      recordTombstones(table, [rowId], worldId: worldId);

  /// Tek ifadeyle yazar: dünyanın tamamı silindiğinde (full-replace import,
  /// dünya silme) bu liste binlerce satır olabiliyor ve satır başına ayrı
  /// INSERT ölçülebilir bir gecikme demekti.
  Future<void> recordTombstones(
    String table,
    Iterable<String> rowIds, {
    required String worldId,
  }) async {
    if (worldId.isEmpty) return;
    final ids = [
      for (final id in rowIds)
        if (id.isNotEmpty) id,
    ];
    if (ids.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    const chunk = 200;
    for (var i = 0; i < ids.length; i += chunk) {
      final slice = ids.sublist(i, (i + chunk).clamp(0, ids.length));
      final values = List.filled(slice.length, '(?, ?, ?, ?)').join(', ');
      await customStatement(
        'INSERT OR REPLACE INTO sync_tombstones '
        '(table_name, row_id, world_id, deleted_at) VALUES $values',
        [
          for (final id in slice) ...[table, id, worldId, now],
        ],
      );
    }
  }
}

/// `updated_at`'i şimdiyle damgalar — çağıran açıkça bir değer vermişse ona
/// dokunmaz (import / LAN / bulut uygulaması kendi zamanını taşır).
Value<DateTime?> stampedNow(Value<DateTime?> existing) =>
    existing.present && existing.value != null
        ? existing
        : Value(DateTime.now());
