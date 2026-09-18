import 'package:flutter/material.dart';

import '../../../../domain/entities/entity.dart';
import '../../../../domain/value_objects/asset_ref.dart';
import '../../../theme/dm_tool_colors.dart';
import '../../../widgets/asset_ref_image.dart';
import '../../../widgets/expandable_markdown.dart';
import '../../../l10n/app_localizations.dart';

/// Floating preview card shown when a location-linked map pin is hovered
/// (desktop) or tapped (mobile). Shows the location's map when it has one —
/// with an "open map" drill-in — otherwise its own card image. "Open card"
/// is always available.
class LocationPinPreviewCard extends StatelessWidget {
  final Entity location;
  final String? mapRef;
  final VoidCallback onDrillIn;
  final VoidCallback? onOpenCard;
  final DmToolColors palette;

  const LocationPinPreviewCard({
    super.key,
    required this.location,
    required this.mapRef,
    required this.onDrillIn,
    required this.palette,
    this.onOpenCard,
  });

  /// Raw markdown — rendered, not flattened. Locations use
  /// `description_long`; every other category uses `description`.
  String _description() {
    for (final key in const ['description_long', 'description']) {
      final raw = location.fields[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    }
    return '';
  }

  /// Map when there is one, else the location's own card image.
  String? _imageRef() {
    if (mapRef != null && mapRef!.isNotEmpty) return mapRef;
    if (location.imagePath.isNotEmpty) return location.imagePath;
    return location.images.isNotEmpty ? location.images.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final desc = _description();
    final hasMap = mapRef != null && mapRef!.isNotEmpty;
    final imageRef = _imageRef();
    final onImageTap = hasMap ? onDrillIn : onOpenCard;

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
              ExpandableMarkdown(
                data: desc,
                collapsedMaxLines: 4,
                expandedMaxHeight: 180,
                collapsedTextStyle: TextStyle(
                  color: palette.uiFloatingText.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: onImageTap,
              borderRadius: palette.cbr,
              child: ClipRRect(
                borderRadius: palette.cbr,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: imageRef != null
                      ? AssetRefImage(
                          ref: AssetRef(imageRef),
                          fit: BoxFit.cover,
                          cacheWidth: 480,
                          placeholder: Container(color: palette.canvasBg),
                          errorWidget: Container(
                            color: palette.canvasBg,
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 18),
                            ),
                          ),
                        )
                      : Container(
                          color: palette.canvasBg,
                          alignment: Alignment.center,
                          child: Text(
                            l10n.noMapAssigned,
                            style: TextStyle(
                              color: palette.uiFloatingText.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (onOpenCard != null || hasMap) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onOpenCard != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenCard,
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: Text(
                          l10n.openCard,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ),
                  if (onOpenCard != null && hasMap) const SizedBox(width: 6),
                  if (hasMap)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onDrillIn,
                        icon: const Icon(Icons.map_outlined, size: 14),
                        label: Text(
                          l10n.openMap,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
