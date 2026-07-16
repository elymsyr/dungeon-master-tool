import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/schema/rules/rule_config.dart';
import 'entity_provider.dart';

/// The active template's [RuleConfig].
///
/// Returns the const [RuleConfig.dnd5eDefaults] (stable identity) unless the
/// world's schema carries a `metadata['rule_config']` override — which only
/// happens after a DM edits a value, the same event that legitimately changes
/// the template content-hash. [RuleConfig] is value-equal, so an override that
/// round-trips to the same values does not churn downstream rebuilds.
///
/// `dependencies` mirrors `ruleCatalogProvider`: `worldSchemaProvider` is
/// overridden inside the package screen's nested ProviderScope, and without
/// the declaration this provider would silently resolve the ROOT world's
/// config there. Root-only readers of `worldSchemaProvider` (projection,
/// combat) deliberately skip the declaration — they are never instantiated
/// under that scope, and scoping them would cascade `dependencies` repo-wide.
final ruleConfigProvider = Provider<RuleConfig>((ref) {
  final raw = ref.watch(
    worldSchemaProvider.select((s) => s.metadata['rule_config']),
  );
  if (raw is Map) {
    return RuleConfig.fromJson(Map<String, dynamic>.from(raw));
  }
  return RuleConfig.dnd5eDefaults;
}, dependencies: [worldSchemaProvider]);
