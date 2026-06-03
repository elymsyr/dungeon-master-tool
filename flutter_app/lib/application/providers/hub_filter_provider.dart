import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Display name of the single built-in template every package/world currently
/// shares. Source of truth: `builtin_dnd5e_v2_schema.dart` `WorldSchema.name`.
/// Packages/worlds with no template info (empty `templateName`) are bucketed
/// under this name so they all filter as the one built-in template.
const builtinTemplateName = 'D&D 5e (SRD 5.2.1)';

/// Empty/blank template name → the built-in template name. Otherwise trimmed.
String normalizeTemplateName(String raw) {
  final t = raw.trim();
  return t.isEmpty ? builtinTemplateName : t;
}

/// Transient selection state for a hub-list filter dialog. Empty set on a
/// dimension = no constraint. Within a dimension selections are OR'd; across
/// dimensions AND'd. In-memory only — reset on app restart (not persisted).
class HubFilter {
  final Set<String> templates;
  final Set<String> packages;
  final Set<String> worlds;

  const HubFilter({
    this.templates = const {},
    this.packages = const {},
    this.worlds = const {},
  });

  bool get isEmpty =>
      templates.isEmpty && packages.isEmpty && worlds.isEmpty;

  /// Total selected values across all dimensions — drives the header badge.
  int get totalSelected => templates.length + packages.length + worlds.length;

  HubFilter copyWith({
    Set<String>? templates,
    Set<String>? packages,
    Set<String>? worlds,
  }) =>
      HubFilter(
        templates: templates ?? this.templates,
        packages: packages ?? this.packages,
        worlds: worlds ?? this.worlds,
      );
}

/// Worlds tab filter (template + package). Non-autoDispose so the selection
/// survives tab switches; the whole container resets on app restart.
final worldsFilterProvider =
    StateProvider<HubFilter>((_) => const HubFilter());

/// Packages tab filter (template only).
final packagesFilterProvider =
    StateProvider<HubFilter>((_) => const HubFilter());

/// Characters tab filter (template + world).
final charactersFilterProvider =
    StateProvider<HubFilter>((_) => const HubFilter());
