import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/datasources/remote/promoted_links_remote_ds.dart';

final promotedLinksDataSourceProvider =
    Provider<PromotedLinksRemoteDataSource>((ref) {
  return PromotedLinksRemoteDataSource();
});

/// Promoted links for the support dialog; empty in an offline build.
final promotedLinksProvider =
    FutureProvider.autoDispose<List<PromotedLink>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return ref.watch(promotedLinksDataSourceProvider).list();
});
