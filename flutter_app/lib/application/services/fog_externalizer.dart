import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/network/asset_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';

/// F9 — fog/annotation externalization.
///
/// Encounter.fogData hâlâ base64 PNG taşıyor. Bu helper base64 baytlarını
/// alır → R2'ye `dmt-asset://...` ref olarak yükler → ref döner. Caller
/// (battle_map_notifier) fog state update'inden sonra 500 ms debounce ile
/// çağırır; tek bir SHA için cloud dedupe (aynı fog → re-upload yok).
///
/// MVP — helper kod-ready. battle_map_notifier wiring bir sonraki PR.
/// Mevcut sync engine `fogData` field'ını base64 olarak push etmeye devam
/// eder; bu helper opt-in olarak büyük fog (>200KB) için kullanılır.
class FogExternalizer {
  FogExternalizer({
    required AssetService? assetService,
    required String campaignId,
  })  : _asset = assetService,
        _campaignId = campaignId;

  final AssetService? _asset;
  final String _campaignId;

  /// Boyut eşiği — bu eşiğin altındaki fog base64 olarak kalır (round-trip
  /// upload maliyeti yarar üretmiyor).
  static const int sizeThresholdBytes = 200 * 1024;

  /// Debounce penceresi — battle_map_notifier `_fogUploadDebouncer.schedule()`
  /// caller'da bu değeri kullanır.
  static const Duration debounceWindow = Duration(milliseconds: 500);

  /// Base64 fog PNG → AssetRef (`dmt-asset://`). Boyut threshold altındaysa
  /// veya AssetService kullanılamıyorsa null döner; caller base64'te bırakır.
  Future<String?> externalize(String fogBase64) async {
    if (fogBase64.isEmpty) return null;
    final svc = _asset;
    if (svc == null) return null;

    Uint8List bytes;
    try {
      bytes = base64Decode(fogBase64);
    } catch (e) {
      debugPrint('FogExternalizer base64 decode error: $e');
      return null;
    }
    if (bytes.length < sizeThresholdBytes) return null;

    final sha = sha256.convert(bytes).toString();
    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File(p.join(tmpDir.path, 'fog_$sha.png'));
    try {
      await tmpFile.writeAsBytes(bytes, flush: true);
      final uri = await svc.uploadAsset(
        tmpFile,
        campaignId: _campaignId,
        kind: MediaKind.battleMap,
      );
      return uri.toString();
    } catch (e) {
      debugPrint('FogExternalizer upload error: $e');
      return null;
    } finally {
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {}
    }
  }

  /// Tersine: bir fog field zaten AssetRef ise raw'ı döner; base64 ise
  /// caller'a olduğu gibi geçer (caller dispatch eder).
  static bool isExternalRef(String value) {
    return value.startsWith(AssetRef.scheme) ||
        value.startsWith(AssetRef.publicScheme) ||
        value.startsWith(AssetRef.transientScheme);
  }
}

/// Provider — campaign bazlı; caller `fogExternalizerProvider(worldId)` ile alır.
final fogExternalizerProvider =
    Provider.family<FogExternalizer, String>((ref, campaignId) {
  return FogExternalizer(
    assetService: ref.watch(assetServiceProvider),
    campaignId: campaignId,
  );
});
