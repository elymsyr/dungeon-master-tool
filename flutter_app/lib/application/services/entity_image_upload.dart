import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/asset_ref.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/package_provider.dart';
import 'entity_media_cleanup_service.dart';
import 'local_media_localizer.dart';
import 'pending_write_buffer.dart';

/// Max number of images allowed per entity image collection — the portrait
/// gallery (`entity.images`) and each schema-defined image field are each
/// capped at this count.
const int kMaxEntityImages = 5;

/// Seçilen entity resimlerini içeriğin `media/` klasörüne alır ve kopyaların
/// yollarını döndürür.
///
/// Buluta hiçbir şey yüklenmez (Phase D — sayılan katman kaldırıldı): bir
/// kartın görseli buluta ancak DM onu paylaştığında ve bir oyuncu eksik
/// bildirdiğinde çıkar (`SharedMediaCourier`). Ham seçici yolu (`Downloads/`)
/// hiçbir zaman saklanmaz — veri kökünün dışında kaldığı için LAN eşlemesi
/// taşıyamıyor (`LanSyncSession._mediaFor`) ve kullanıcı dosyayı taşırsa
/// resim kayboluyor.
Future<List<String>> localizeEntityImages(
  WidgetRef ref,
  List<String> paths,
) async {
  final ownerDir = _ownerDir(ref, ref.read(activePackageProvider));
  return _localizeAll(paths, ownerDir);
}

/// Entity'nin resim olmayan eklerini (schema `file` / `pdf` alanları) içeriğin
/// `files/` klasörüne alır. Resimlerle aynı gerekçe: ham seçici yolu ne LAN
/// eşlemesinde taşınır ne de kullanıcı dosyayı taşıdığında açılır.
Future<List<String>> localizeEntityFiles(
  WidgetRef ref,
  List<String> paths,
) async {
  final ownerDir = _ownerDir(ref, ref.read(activePackageProvider));
  if (ownerDir == null) return paths;
  return LocalMediaLocalizer.localizeAll(
    paths,
    ownerDir: ownerDir,
    subDir: LocalMediaLocalizer.filesSubDir,
    imagesOnly: false,
  );
}

/// Kopya hedefi; aktif dünya/paket bilinmiyorsa null (kopyalama atlanır).
String? _ownerDir(WidgetRef ref, String? packageName) {
  if (packageName != null && packageName.isNotEmpty) {
    return LocalMediaLocalizer.packageDir(packageName);
  }
  final worldName = ref.read(activeCampaignProvider);
  if (worldName == null || worldName.isEmpty) return null;
  return LocalMediaLocalizer.worldDir(worldName);
}

Future<List<String>> _localizeAll(List<String> paths, String? ownerDir) async {
  if (ownerDir == null) return paths;
  return LocalMediaLocalizer.localizeAll(paths, ownerDir: ownerDir);
}

/// Best-effort cloud cleanup for an entity image ref that was just removed.
///
/// No-op when the ref is local/transient, still referenced in [remaining],
/// the host is [readOnly], or no cleanup service is configured. Flushes the
/// `entity:` outbox prefix and forces a sync tick first so the post-removal
/// row is committed before [EntityMediaCleanupService]'s reference scan runs
/// — otherwise the scan sees this entity's stale ref and skips the delete.
Future<void> cleanupRemovedEntityImageRef(
  WidgetRef ref,
  String removedRef, {
  required bool readOnly,
  required List<String> remaining,
}) async {
  if (readOnly) return; // read-only / built-in package entity
  if (!AssetRef(removedRef).isCloud) return; // only dmt-asset:// counted
  if (remaining.contains(removedRef)) return; // duplicate in same entity
  if (ref.read(authProvider) == null) return;
  final cleanup = ref.read(entityMediaCleanupServiceProvider);
  if (cleanup == null) return; // Supabase/Worker not configured → no-op
  try {
    await ref.read(pendingWriteBufferProvider).flushPrefix('entity:');
    await cleanup.cleanupRemovedRef(removedRef);
  } catch (e) {
    debugPrint('entity image cloud cleanup error: $e');
  }
}
