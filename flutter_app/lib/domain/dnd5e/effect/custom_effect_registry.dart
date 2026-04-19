import '../catalog/content_reference.dart';

/// Contract a Dart-backed custom effect implementation must satisfy. The
/// `compile` step turning parameters into the engine's runtime representation
/// lives in Doc 05 (rule engine); this interface intentionally stops at
/// identity so Doc 01 does not depend on the compiler types.
abstract interface class CustomEffectImpl {
  /// Namespaced id matching `CustomEffect.implementationId` on content.
  String get id;
}

/// Process-wide registry for [CustomEffectImpl]s. Packages declare which ids
/// they require in `requiredRuntimeExtensions` (Doc 14); import fails fast
/// when the runtime lacks an id.
class CustomEffectRegistry {
  final Map<String, CustomEffectImpl> _byId = {};

  void register(CustomEffectImpl impl) {
    validateContentId(impl.id);
    if (_byId.containsKey(impl.id)) {
      throw StateError(
          'CustomEffectImpl "${impl.id}" already registered');
    }
    _byId[impl.id] = impl;
  }

  CustomEffectImpl? byId(String id) => _byId[id];

  bool contains(String id) => _byId.containsKey(id);

  Iterable<String> get ids => _byId.keys;

  void clear() => _byId.clear();
}
