/// Documentation typedef. At runtime every `ContentReference<T>` is a namespaced
/// id of shape `<packageId>:<localId>` (e.g. 'srd:stunned'). The type parameter
/// is for reader clarity only — Dart erases it. Referential integrity is checked
/// by `ContentRegistryValidator` at load/import time, not by the type system.
typedef ContentReference<T> = String;

/// Validates the namespaced id shape. Throws [ArgumentError] on malformed input.
/// Shared by every Tier 1 catalog class factory.
String validateContentId(String id) {
  final i = id.indexOf(':');
  if (i <= 0 || i == id.length - 1) {
    throw ArgumentError('ContentId "$id" must be of shape <packageId>:<localId>');
  }
  return id;
}
