import '../../../domain/dnd5e/effect/custom_effect_registry.dart';

/// Doc 15 §"Whitelisted CustomEffect Implementations" — the nine SRD content
/// effects whose semantics cannot be expressed by the [EffectDescriptor] DSL
/// alone. Each impl is registered at startup; SRD content's `CustomEffect`
/// nodes resolve `implementationId` against the runtime registry.
///
/// The interface only requires identity. The Doc 05 rule engine adds a
/// `compile(parameters)` extension when it lands; until then, these classes
/// are identity placeholders that satisfy package-import validation
/// (`requiredRuntimeExtensions` lookup) without committing to a runtime
/// representation that may need to change.
class WishImpl implements CustomEffectImpl {
  const WishImpl();
  @override
  String get id => 'srd:wish';
}

class WildShapeImpl implements CustomEffectImpl {
  const WildShapeImpl();
  @override
  String get id => 'srd:wild_shape';
}

class PolymorphImpl implements CustomEffectImpl {
  const PolymorphImpl();
  @override
  String get id => 'srd:polymorph';
}

class AnimateDeadImpl implements CustomEffectImpl {
  const AnimateDeadImpl();
  @override
  String get id => 'srd:animate_dead';
}

class SimulacrumImpl implements CustomEffectImpl {
  const SimulacrumImpl();
  @override
  String get id => 'srd:simulacrum';
}

class SummonFamilyImpl implements CustomEffectImpl {
  const SummonFamilyImpl();
  @override
  String get id => 'srd:summon_family';
}

class ConjureFamilyImpl implements CustomEffectImpl {
  const ConjureFamilyImpl();
  @override
  String get id => 'srd:conjure_family';
}

class ShapechangeImpl implements CustomEffectImpl {
  const ShapechangeImpl();
  @override
  String get id => 'srd:shapechange';
}

class GlyphOfWardingImpl implements CustomEffectImpl {
  const GlyphOfWardingImpl();
  @override
  String get id => 'srd:glyph_of_warding';
}

/// Canonical list — order matches Doc 15 §"Whitelisted CustomEffect
/// Implementations" so the doc, the SRD package's
/// `requiredRuntimeExtensions`, and runtime registration stay one-to-one.
const List<CustomEffectImpl> srdCustomEffectImpls = <CustomEffectImpl>[
  WishImpl(),
  WildShapeImpl(),
  PolymorphImpl(),
  AnimateDeadImpl(),
  SimulacrumImpl(),
  SummonFamilyImpl(),
  ConjureFamilyImpl(),
  ShapechangeImpl(),
  GlyphOfWardingImpl(),
];

/// Registers every SRD-bundled custom effect into [registry]. Idempotent at
/// the call-site granularity only — calling twice on the same registry will
/// throw via [CustomEffectRegistry.register]'s duplicate check, which is the
/// intended fail-fast behavior for accidental double-bootstrap.
void registerSrdCustomEffects(CustomEffectRegistry registry) {
  for (final impl in srdCustomEffectImpls) {
    registry.register(impl);
  }
}
