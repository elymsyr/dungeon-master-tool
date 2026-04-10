import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../data/datasources/local/package_local_ds.dart';
import '../../data/repositories/package_repository_impl.dart';
import '../../domain/entities/package_info.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/repositories/package_repository.dart';

final packageLocalDsProvider = Provider((_) => PackageLocalDataSource());

final packageRepositoryProvider = Provider<PackageRepository>(
  (ref) => PackageRepositoryImpl(
    ref.read(appDatabaseProvider),
    ref.read(packageLocalDsProvider),
  ),
);

/// Paket listesi — hub ekranında gösterim için.
final packageListProvider = FutureProvider<List<PackageInfo>>((ref) {
  return ref.read(packageRepositoryProvider).getPackageInfoList();
});

/// Aktif paket adı. null = henüz seçilmedi.
class ActivePackageNotifier extends StateNotifier<String?> {
  final PackageRepository _repo;

  ActivePackageNotifier(this._repo) : super(null);

  Map<String, dynamic>? _data;
  Map<String, dynamic>? get data => _data;

  Future<bool> load(String name) async {
    try {
      _data = await _repo.load(name);
      state = name;
      return true;
    } catch (e, st) {
      debugPrint('Package load error: $e\n$st');
      return false;
    }
  }

  Future<bool> create(String packageName, {WorldSchema? template}) async {
    try {
      await _repo.create(packageName, template: template);
      return load(packageName);
    } catch (e, st) {
      debugPrint('Package create error: $e\n$st');
      return false;
    }
  }

  Future<void> save() async {
    if (state != null && _data != null) {
      await _repo.save(state!, _data!);
    }
  }

  Future<void> delete(String packageName) async {
    await _repo.delete(packageName);
    if (state == packageName) {
      _data = null;
      state = null;
    }
  }
}

final activePackageProvider =
    StateNotifierProvider<ActivePackageNotifier, String?>((ref) {
  return ActivePackageNotifier(ref.read(packageRepositoryProvider));
});
