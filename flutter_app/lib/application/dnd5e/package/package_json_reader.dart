import 'dart:convert';

import '../../../domain/dnd5e/package/dnd5e_package.dart';
import '../../../domain/dnd5e/package/dnd5e_package_codec.dart';

/// Parses a `dnd5e-pkg/2` serialized payload (see [Dnd5ePackageCodec]) into a
/// [Dnd5ePackage]. Format and shape errors surface as [FormatException] with
/// a pointed field name so importers can bubble them up verbatim.
///
/// Accepts either a raw JSON string or an already-decoded `Map<String, Object?>`
/// (e.g. when the caller has bundled the file into memory differently).
class PackageJsonReader {
  final Dnd5ePackageCodec _codec;

  const PackageJsonReader({Dnd5ePackageCodec codec = const Dnd5ePackageCodec()})
      : _codec = codec;

  Dnd5ePackage readJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Package JSON is not valid: ${e.message}');
    }
    if (decoded is! Map) {
      throw const FormatException(
          'Package JSON root must be an object (got non-object).');
    }
    return _codec.decode(decoded.cast<String, Object?>());
  }

  Dnd5ePackage readMap(Map<String, Object?> source) => _codec.decode(source);
}

/// Emitter counterpart: turns a [Dnd5ePackage] back into a stable JSON string.
///
/// `pretty: true` produces newline-indented output for the committed
/// `build_artifacts/` copy (Doc 15 §Open Question 2). `pretty: false` emits
/// the compact form that ships with the app bundle.
class PackageJsonWriter {
  final Dnd5ePackageCodec _codec;

  const PackageJsonWriter({Dnd5ePackageCodec codec = const Dnd5ePackageCodec()})
      : _codec = codec;

  String writeJson(Dnd5ePackage pkg, {bool pretty = false}) {
    final map = _codec.encode(pkg);
    if (!pretty) return jsonEncode(map);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }
}
