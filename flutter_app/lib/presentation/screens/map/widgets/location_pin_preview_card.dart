import 'package:flutter/material.dart';

import '../../../../domain/entities/entity.dart';
import '../../../../domain/value_objects/asset_ref.dart';
import '../../../theme/dm_tool_colors.dart';
import '../../../widgets/asset_ref_image.dart';

/// Floating preview card shown when a location-linked map pin is hovered
/// (desktop) or tapped (mobile). The map thumbnail is the drill-in handle.
class LocationPinPreviewCard extends StatelessWidget {
  final Entity location;
  final String? mapRef;
  final VoidCallback onDrillIn;
  final DmToolColors palette;

  const LocationPinPreviewCard({
    super.key,
    required this.location,
    required this.mapRef,
    required this.onDrillIn,
    required this.palette,
  });

  String _shortDescription() {
    final raw = location.fields['description_long'];
    if (raw is! String) return '';
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 140) return clean;
    return '${clean.substring(0, 140)}…';
  }

  @override
  Widget build(BuildContext context) {
    final desc = _shortDescription();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: palette.uiFloatingBg,
          border: Border.all(color: palette.uiFloatingBorder),
          borderRadius: palette.cbr,
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.name,
              style: TextStyle(
                color: palette.uiFloatingText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  color: palette.uiFloatingText.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: onDrillIn,
              borderRadius: palette.cbr,
              child: ClipRRect(
                borderRadius: palette.cbr,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: (mapRef != null && mapRef!.isNotEmpty)
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            AssetRefImage(
                              ref: AssetRef(mapRef!),
                              fit: BoxFit.cover,
                              cacheWidth: 480,
                              placeholder: Container(color: palette.canvasBg),
                              errorWidget: Container(
                                color: palette.canvasBg,
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 18),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Open map',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: palette.canvasBg,
                          alignment: Alignment.center,
                          child: Text(
                            'No map assigned',
                            style: TextStyle(
                              color: palette.uiFloatingText.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
