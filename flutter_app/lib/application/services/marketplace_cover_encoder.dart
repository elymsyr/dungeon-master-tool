import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../domain/value_objects/asset_ref.dart';
import 'asset_ref_resolver.dart';

/// Marketplace banner thumbnail caps. Keep the encoded payload small — it is
/// stored inline as base64 in `marketplace_listings.cover_image_b64`.
const int kCoverRawMaxBytes = 20 * 1024 * 1024;
const int kCoverEncodedMaxBytes = 2 * 1024 * 1024;
const int kCoverTargetWidth = 480;

/// Resolves [coverRef] (local path / `dmt-public://` / `dmt-asset://`) to a
/// cached file, downsizes it to a ~480 px-wide PNG marketplace-card thumbnail
/// and returns base64.
///
/// Returns null when the file is missing, oversize (raw or encoded), or
/// decoding fails — callers treat null as "skip" (do not overwrite an existing
/// listing banner with nothing).
Future<String?> encodeCoverThumbnailB64(
  AssetRefResolver resolver,
  String coverRef,
) async {
  if (coverRef.isEmpty) return null;
  try {
    final file = await resolver.resolve(AssetRef(coverRef));
    if (file == null || !await file.exists()) {
      debugPrint('marketplace cover: cannot resolve $coverRef');
      return null;
    }
    final rawBytes = await file.readAsBytes();
    if (rawBytes.lengthInBytes > kCoverRawMaxBytes) {
      debugPrint('marketplace cover: raw too large (${rawBytes.lengthInBytes} B)');
      return null;
    }
    final codec = await ui.instantiateImageCodec(
      rawBytes,
      targetWidth: kCoverTargetWidth,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    if (byteData == null) return null;
    final thumb = byteData.buffer.asUint8List();
    if (thumb.lengthInBytes > kCoverEncodedMaxBytes) {
      debugPrint(
          'marketplace cover: encoded too large (${thumb.lengthInBytes} B, cap $kCoverEncodedMaxBytes)');
      return null;
    }
    return base64Encode(thumb);
  } catch (e) {
    debugPrint('cover read/resize failed: $e');
    return null;
  }
}
