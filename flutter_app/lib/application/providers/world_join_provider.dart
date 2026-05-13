import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/database_provider.dart';
import '../services/world_join_service.dart';
import 'campaign_provider.dart';
import 'world_membership_provider.dart';

final worldJoinServiceProvider = Provider<WorldJoinService>((ref) {
  return WorldJoinService(
    membership: ref.watch(worldMembershipServiceProvider),
    db: ref.watch(appDatabaseProvider),
    supabase: Supabase.instance.client,
    repository: ref.watch(campaignRepositoryProvider),
  );
});
