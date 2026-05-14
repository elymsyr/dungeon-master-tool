import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/network/character_claim_service.dart';
import 'auth_provider.dart';

final characterClaimServiceProvider = Provider<CharacterClaimService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.watch(authProvider) == null) return null;
  return CharacterClaimService(Supabase.instance.client);
});
