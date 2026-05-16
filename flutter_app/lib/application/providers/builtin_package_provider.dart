import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../services/srd_core_package_bootstrap.dart';
import 'package_provider.dart' show srdCorePackageBootstrapProvider;

/// Built-in SRD pack'in Drift row id'sini resolve eder.
///
/// Bootstrap'a bağımlı: `srdCorePackageBootstrapProvider` complete olmadan
/// pack row henüz mevcut olmayabilir. Bootstrap tamamlanınca getByName ile
/// id çekilir. Null = pack henüz install değil (rare edge).
final builtinPackageIdProvider = FutureProvider<String?>((ref) async {
  await ref.watch(srdCorePackageBootstrapProvider.future);
  final db = ref.watch(appDatabaseProvider);
  final all = await db.packagesDao.getAll();
  return all.where((p) => p.name == srdCorePackageName).firstOrNull?.id;
});
