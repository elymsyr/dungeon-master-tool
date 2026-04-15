/// Stable cross-device reference to an image/asset.
///
/// Two concrete forms are supported in the same `String` slot (entity images,
/// manifests, etc.) so that local data migrates opportunistically:
///
/// - **Cloud**: `dmt-asset://{uploader_id}/{campaign_id}/{sha256}.{ext}` — the
///   URI produced by `AssetService.uploadAsset`. Portable across devices;
///   resolved through the R2 cache on demand.
/// - **Local**: an absolute filesystem path. Used for legacy entities that
///   haven't been migrated yet and for quota-exceeded fallback uploads that
///   never made it to the cloud.
///
/// Most of the app just passes raw strings around. `AssetRef` is the thin
/// parser that lets call sites ask "is this cloud or local?" without every
/// caller re-implementing the `startsWith` check.
class AssetRef {
  AssetRef(this.raw);

  static const String scheme = 'dmt-asset://';

  final String raw;

  bool get isCloud => raw.startsWith(scheme);
  bool get isLocal => !isCloud && raw.isNotEmpty;

  /// R2 object key — `{uploader_id}/{campaign_id}/{sha256}.{ext}`.
  /// Null for local refs.
  String? get r2Key => isCloud ? raw.substring(scheme.length) : null;

  /// Filesystem path for local refs; null for cloud refs.
  String? get localPath => isLocal ? raw : null;

  /// Wrap an R2 object key into the canonical `dmt-asset://…` string.
  static String formatCloudUri(String r2Key) => '$scheme$r2Key';

  @override
  String toString() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AssetRef && other.raw == raw);

  @override
  int get hashCode => raw.hashCode;
}
