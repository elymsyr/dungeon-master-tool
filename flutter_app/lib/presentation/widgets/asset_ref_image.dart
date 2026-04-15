import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services/asset_ref_resolver.dart';
import '../../domain/value_objects/asset_ref.dart';

/// Displays an image from an [AssetRef] — local path or `dmt-asset://` cloud
/// URI. Cloud refs download + cache on first render; subsequent renders hit
/// the SHA-keyed disk cache (see [AssetService.downloadAsset]).
///
/// While resolving, shows [placeholder]; on failure, shows [errorWidget].
class AssetRefImage extends ConsumerStatefulWidget {
  const AssetRefImage({
    super.key,
    required this.ref,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.placeholder,
    this.errorWidget,
  });

  final AssetRef ref;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  ConsumerState<AssetRefImage> createState() => _AssetRefImageState();
}

class _AssetRefImageState extends ConsumerState<AssetRefImage> {
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(AssetRefImage old) {
    super.didUpdateWidget(old);
    if (old.ref != widget.ref) {
      _future = _resolve();
    }
  }

  Future<File?> _resolve() {
    return ref.read(assetRefResolverProvider).resolve(widget.ref);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return widget.placeholder ??
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        }
        final file = snap.data;
        if (file == null) {
          return widget.errorWidget ??
              const Icon(Icons.broken_image_outlined);
        }
        return Image.file(
          file,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          cacheWidth: widget.cacheWidth,
          errorBuilder: (_, _, _) =>
              widget.errorWidget ?? const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
