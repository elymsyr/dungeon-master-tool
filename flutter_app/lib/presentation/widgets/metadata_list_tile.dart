import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/value_objects/asset_ref.dart';
import '../theme/dm_tool_colors.dart';
import 'asset_ref_image.dart';
import 'banner_metrics.dart';

/// Cover + name + description + tags içeren shared list satırı.
/// Hub tab'larında (Characters / Worlds / Packages / Templates) kullanılır.
///
/// Cover, tile'ın dış kenarlarına yapışık (flush) yerleşir — dışarıdaki
/// Container'ın [Clip.antiAlias] ile yuvarlak köşelere göre klip'lemesi
/// beklenir. İç padding sadece metin bloğuna uygulanır.
///
/// İki layout variant:
///   - [MetadataTileLayout.leftAvatar]: Sol tarafta tile yüksekliğini
///     kaplayan dikdörtgen profil fotoğrafı (karakter tab'ları için).
///   - [MetadataTileLayout.topBanner]: İsmin üstünde full-width banner
///     cover image (worlds / packages / templates için).
enum MetadataTileLayout { leftAvatar, topBanner }

class MetadataListTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;

  /// Optional widget rendered inline before the [subtitle] text (same row).
  /// Used by official catalog cards to put a verified checkmark where user
  /// cards show the `@username`. Null → subtitle renders as a plain text line.
  final Widget? subtitleLeading;

  final String description;
  final List<String> tags;
  final String coverImagePath;

  /// Base64-encoded cover bytes — used by marketplace listings whose covers
  /// live as inline blobs rather than local/cloud asset refs. Takes priority
  /// over [coverImagePath] when both are set.
  final String? coverImageB64;

  /// Flutter bundle asset path for the cover (e.g. official catalog banners,
  /// built-in template/package banners). Takes priority over
  /// [coverImagePath]/[coverImageB64]; rendered via [Image.asset] with an icon
  /// fallback when the asset is missing.
  final String? coverAssetPath;

  /// Remote cover URL (e.g. official catalog banners served from R2). Rendered
  /// via [Image.network] with an icon fallback while loading / on error. Used
  /// after [coverAssetPath] and before the b64/asset-ref sources.
  final String? coverNetworkUrl;

  final bool isSelected;
  final DmToolColors palette;
  final VoidCallback onSettings;
  final MetadataTileLayout layout;

  /// Ek header badge'leri — "Built-in" gibi metadata'ya bağlı olmayan flag'ler.
  final List<Widget> trailingBadges;

  /// Optional chip strip rendered *in place of* the tag wrap. Character
  /// tiles pass the HP/Species/Class/Level/AC/User stat chips here so the
  /// row shows live combat info instead of authored tags.
  final Widget? infoChips;

  /// Small icons overlaid on the top-right corner of the card cover area.
  /// Used for role/online status indicators on world cards.
  final List<Widget> topRightOverlay;

  /// Badges overlaid on the top-LEFT corner of the cover (topBanner layout).
  /// Marketplace cards put the item-type pill here so it sits on the banner
  /// instead of crowding the title row.
  final List<Widget> topLeftOverlay;

  /// Custom trailing widget that replaces the gear settings button. Used by
  /// surfaces that need a popup menu (sidebar / world character rows) in the
  /// same slot the main character tab uses for settings.
  final Widget? trailingControl;

  const MetadataListTile({
    super.key,
    required this.icon,
    required this.name,
    required this.subtitle,
    this.subtitleLeading,
    required this.description,
    required this.tags,
    required this.coverImagePath,
    this.coverImageB64,
    this.coverAssetPath,
    this.coverNetworkUrl,
    required this.isSelected,
    required this.palette,
    required this.onSettings,
    this.layout = MetadataTileLayout.leftAvatar,
    this.trailingBadges = const [],
    this.infoChips,
    this.topRightOverlay = const [],
    this.topLeftOverlay = const [],
    this.trailingControl,
  });

  // AssetRefImage local/cloud/public ref'leri çözer; çözülemezse fallback
  // (errorWidget) gösterilir — varlık kontrolü artık render sırasında yapılır.
  bool get _hasImage =>
      (coverAssetPath?.isNotEmpty ?? false) ||
      (coverNetworkUrl?.isNotEmpty ?? false) ||
      coverImagePath.isNotEmpty ||
      (coverImageB64?.isNotEmpty ?? false);

  /// Decoded base64 cover bytes, or null when absent / malformed.
  Uint8List? get _coverBytes {
    final b64 = coverImageB64;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// Cover image source resolution: base64 blob first (marketplace), else the
  /// asset ref (native hub lists). Returns [fallback] when neither resolves.
  Widget _coverImage({required int cacheWidth, required Widget fallback}) {
    final asset = coverAssetPath;
    if (asset != null && asset.isNotEmpty) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final url = coverNetworkUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
      );
    }
    final bytes = _coverBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return AssetRefImage(
      ref: AssetRef(coverImagePath),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorWidget: fallback,
    );
  }

  static const double _leftCoverWidth = 96;
  static const double _topCoverHeight = kBannerCoverHeight;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      MetadataTileLayout.leftAvatar => _buildLeftAvatar(),
      MetadataTileLayout.topBanner => _buildTopBanner(),
    };
  }

  Widget _buildLeftAvatar() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _leftCover(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: _textBlock(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [trailingControl ?? _settingsButton()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        (topRightOverlay.isEmpty && topLeftOverlay.isEmpty)
            ? _topCover()
            : Stack(
                children: [
                  _topCover(),
                  if (topLeftOverlay.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: topLeftOverlay,
                      ),
                    ),
                  if (topRightOverlay.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: topRightOverlay,
                      ),
                    ),
                ],
              ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _textBlock()),
              trailingControl ?? _settingsButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leftCover() {
    final border = Border(
      right: BorderSide(color: palette.featureCardBorder),
    );
    final fallback = Container(
      width: _leftCoverWidth,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: border,
      ),
      alignment: Alignment.center,
      child: Icon(icon,
          size: 36,
          color: isSelected ? palette.featureCardAccent : palette.tabText),
    );
    if (!_hasImage) return fallback;
    return Container(
      width: _leftCoverWidth,
      decoration: BoxDecoration(border: border),
      child: _coverImage(cacheWidth: 300, fallback: fallback),
    );
  }

  Widget _topCover() {
    final border = Border(
      bottom: BorderSide(color: palette.featureCardBorder),
    );
    final fallback = Container(
      height: _topCoverHeight,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: border,
      ),
      alignment: Alignment.center,
      child: Icon(icon,
          size: 40,
          color: isSelected
              ? palette.featureCardAccent
              : palette.sidebarLabelSecondary),
    );
    if (!_hasImage) return fallback;
    return Container(
      height: _topCoverHeight,
      decoration: BoxDecoration(border: border),
      width: double.infinity,
      child: _coverImage(cacheWidth: 1200, fallback: fallback),
    );
  }

  Widget _textBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...trailingBadges,
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          if (subtitleLeading != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                subtitleLeading!,
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 11, color: palette.sidebarLabelSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 11, color: palette.sidebarLabelSecondary),
              overflow: TextOverflow.ellipsis,
            ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: palette.tabText),
          ),
        ],
        if (infoChips != null) ...[
          const SizedBox(height: 4),
          infoChips!,
        ] else if (tags.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: tags
                .take(5)
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: palette.sidebarFilterBg,
                        borderRadius: palette.chr,
                      ),
                      child: Text(t,
                          style: TextStyle(
                              fontSize: 9, color: palette.tabText)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _settingsButton() {
    return IconButton(
      icon: Icon(Icons.settings, size: 16, color: palette.tabText),
      tooltip: 'Settings',
      onPressed: onSettings,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}
