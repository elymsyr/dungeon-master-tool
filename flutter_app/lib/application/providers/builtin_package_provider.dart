import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../../domain/entities/entity.dart';
import '../services/srd_core_package_bootstrap.dart';
import 'entity_provider.dart' show entityFromRaw;
import 'package_provider.dart'
    show srdCorePackageBootstrapProvider, packageRepositoryProvider;

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

/// Read-only snapshot of the built-in SRD pack's entities, parsed into typed
/// [Entity] objects (every category — Tier-0 lookups like conditions/damage
/// types plus Tier-1 content like spells/monsters). Feeds
/// `packageReferenceOverlayProvider`, which unions it with the entities of
/// every package the viewed package links; that union is what
/// `EntityNotifier(referenceOverlayFor: …)` injects, so a package's category
/// lists render SRD + linked content without persisting any of it.
///
/// Source of truth is the installed SRD package row, so the overlay always
/// matches what the SRD package itself shows. Marked `linked: true` so the UI
/// treats them as pack rows (fork-on-edit, read-only badge). Cached by
/// Riverpod — loaded once per DB instance.
final srdReferenceEntitiesProvider =
    FutureProvider<Map<String, Entity>>((ref) async {
  await ref.watch(srdCorePackageBootstrapProvider.future);
  final data =
      await ref.watch(packageRepositoryProvider).load(srdCorePackageName);
  final raw = data['entities'];
  if (raw is! Map) return const <String, Entity>{};
  final out = <String, Entity>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    final id = entry.key.toString();
    out[id] = entityFromRaw(id, Map<String, dynamic>.from(value))
        .copyWith(linked: true);
  }
  return out;
});
