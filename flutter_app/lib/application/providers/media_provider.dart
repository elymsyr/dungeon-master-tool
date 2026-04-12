import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import 'campaign_provider.dart';

/// Active campaign/package'ın media dizin yolu.
/// PackageScreen'de packagesDir'e override edilir.
final mediaDirectoryProvider = Provider<String>((ref) {
  final name = ref.watch(activeCampaignProvider);
  if (name == null) return '';
  return p.join(AppPaths.worldsDir, name, 'media');
});

/// MediaGalleryDialog'un cloud mode için kullandığı kampanya ID'si.
/// Active campaign yoksa boş string — dialog lokal moda düşer.
/// PackageScreen kendi context'ine override eder.
final mediaCampaignIdProvider = Provider<String>((ref) {
  return ref.watch(activeCampaignProvider) ?? '';
});
