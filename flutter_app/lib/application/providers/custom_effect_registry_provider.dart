import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dnd5e/effect/custom_effect_registry.dart';
import '../dnd5e/effect/srd_custom_effects.dart';

/// App-wide [CustomEffectRegistry] singleton. Eagerly registers the SRD
/// `CustomEffect` impl whitelist (Doc 15 §"Whitelisted CustomEffect
/// Implementations") so `Dnd5ePackageImporter` can resolve any
/// `requiredRuntimeExtensions` entry the moment a package is imported.
///
/// Doc 14: package import fails fast on missing impl ids — populating the
/// registry at provider construction (rather than on first use) means a
/// startup-time guarantee that the SRD package will never be rejected for
/// a missing `srd:wish` etc.
final customEffectRegistryProvider = Provider<CustomEffectRegistry>((ref) {
  final registry = CustomEffectRegistry();
  registerSrdCustomEffects(registry);
  return registry;
});
