import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

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
  final String description;
  final List<String> tags;
  final String coverImagePath;
  final bool isSelected;
  final DmToolColors palette;
  final VoidCallback onSettings;
  final MetadataTileLayout layout;

  /// Ek header badge'leri — "Built-in" gibi metadata'ya bağlı olmayan flag'ler.
  final List<Widget> trailingBadges;

  const MetadataListTile({
    super.key,
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.tags,
    required this.coverImagePath,
    required this.isSelected,
    required this.palette,
    required this.onSettings,
    this.layout = MetadataTileLayout.leftAvatar,
    this.trailingBadges = const [],
  });

  bool get _hasImage =>
      coverImagePath.isNotEmpty && File(coverImagePath).existsSync();

  static const double _leftCoverWidth = 96;
  static const double _topCoverHeight = 120;

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
              children: [_settingsButton()],
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
        _topCover(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _textBlock()),
              _settingsButton(),
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
      child: Image.file(
        File(coverImagePath),
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (_, _, _) => fallback,
      ),
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
      child: Image.file(
        File(coverImagePath),
        fit: BoxFit.cover,
        cacheWidth: 1200,
        errorBuilder: (_, _, _) => fallback,
      ),
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
        if (tags.isNotEmpty) ...[
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
