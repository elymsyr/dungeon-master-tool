import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/admin_beta_requests_remote_ds.dart';
import 'admin_provider.dart';

final adminBetaRequestsDataSourceProvider =
    Provider<AdminBetaRequestsRemoteDataSource>((ref) {
  return AdminBetaRequestsRemoteDataSource();
});

final adminBetaRequestsProvider =
    FutureProvider.autoDispose<List<BetaRequestEntry>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminBetaRequestsDataSourceProvider);
  return ds.list();
});

final adminBetaParticipantsProvider =
    FutureProvider.autoDispose<List<BetaParticipantEntry>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminBetaRequestsDataSourceProvider);
  return ds.listParticipants();
});
