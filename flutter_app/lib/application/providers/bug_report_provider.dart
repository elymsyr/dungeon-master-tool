import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/bug_reports_remote_ds.dart';
import 'admin_provider.dart';

final bugReportsDataSourceProvider = Provider<BugReportsRemoteDataSource>(
  (ref) => BugReportsRemoteDataSource(),
);

/// Admin Reports tab filter state: 'open' | 'read' | 'resolved' | 'all'.
final bugReportStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'open');

/// Admin listesi — filter state'ine göre yeniden yüklenir.
final adminBugReportsProvider =
    FutureProvider.autoDispose<List<BugReport>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(bugReportsDataSourceProvider);
  final status = ref.watch(bugReportStatusFilterProvider);
  return ds.fetchForAdmin(status: status == 'all' ? null : status);
});
