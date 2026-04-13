import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/release_check_service.dart';

/// GitHub release-metadata cache for the current session. Caches the
/// first successful response so tab switches don't re-hit the API.
/// Fail-soft: returns `null` on any network / parse error.
final releaseCheckServiceProvider = Provider<ReleaseCheckService>((ref) {
  return ReleaseCheckService();
});

final latestReleaseProvider = FutureProvider<ReleaseInfo?>((ref) {
  return ref.read(releaseCheckServiceProvider).fetchLatest();
});
