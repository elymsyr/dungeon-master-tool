import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_provider.dart';
import 'character_provider.dart';
import 'package_provider.dart';

final globalTagsProvider = Provider<Set<String>>((ref) {
  final out = <String>{};

  final characters = ref.watch(characterListProvider).valueOrNull;
  if (characters != null) {
    for (final c in characters) {
      out.addAll(c.entity.tags.where((t) => t.trim().isNotEmpty));
    }
  }

  ref.watch(campaignInfoListProvider);
  ref.watch(packageListProvider);

  return out;
});
