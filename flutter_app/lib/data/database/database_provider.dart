import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Aktif kullanıcı ID'si. Değiştiğinde appDatabaseProvider yeniden oluşturulur
/// ve tüm downstream provider'lar (DAO, repository, vb.) cascade invalidate olur.
final activeUserIdProvider = StateProvider<String?>((ref) => null);

/// Singleton AppDatabase provider — tüm DAO'lar ve repository'ler
/// bu provider üzerinden database'e erişir.
///
/// `activeUserIdProvider` değiştiğinde yeni user-scoped DB açılır,
/// eski DB kapatılır.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  final db = AppDatabase.forUser(userId);
  ref.onDispose(db.close);
  return db;
});
