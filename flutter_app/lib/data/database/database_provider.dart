import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Singleton AppDatabase provider — tüm DAO'lar ve repository'ler
/// bu provider üzerinden database'e erişir.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
