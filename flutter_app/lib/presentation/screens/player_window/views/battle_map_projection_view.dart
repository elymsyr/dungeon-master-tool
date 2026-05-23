import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/services/asset_ref_resolver.dart';
import '../../../../domain/entities/projection/battle_map_snapshot.dart';
import '../../../../domain/entities/projection/projection_item.dart';
import '../../../../domain/value_objects/asset_ref.dart';
import '../../../theme/dm_tool_colors.dart';
import '../../../widgets/asset_ref_image.dart';

/// Player-window view of a battle map. Receives a [BattleMapSnapshot] over
/// IPC, decodes the background and fog images on demand, and renders them
/// with a custom painter. Read-only — no interaction.
///
/// Performance:
/// - `AutomaticKeepAliveClientMixin` keeps the decoded background image
///   alive across tab switches.
/// - Background and fog are decoded only when their source paths/data
///   change (memoized via `_lastMapPath` / `_lastFogHash`).
/// - Token rendering is a single CustomPaint pass — no per-token widgets.
class BattleMapProjectionView extends ConsumerStatefulWidget {
  final BattleMapProjection item;

  /// Online viewer mode — wraps the map canvas in an InteractiveViewer so
  /// the remote player can pan/zoom locally. The initiative side panel
  /// stays fixed (it lives outside the transformed subtree).
  final bool interactive;

  const BattleMapProjectionView({
    required this.item,
    this.interactive = false,
    super.key,
  });

  @override
  ConsumerState<BattleMapProjectionView> createState() =>
      _BattleMapProjectionViewState();
}

class _BattleMapProjectionViewState
    extends ConsumerState<BattleMapProjectionView>
    with AutomaticKeepAliveClientMixin {
  ui.Image? _bgImage;
  ui.Image? _fogImage;
  String? _lastMapPath;
  String? _lastFogHash;
  final Map<String, ui.Image> _tokenImageCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _maybeReloadBackground();
    _maybeReloadFog();
    _preloadTokenImages();
  }

  @override
  void didUpdateWidget(covariant BattleMapProjectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeReloadBackground();
    _maybeReloadFog();
    _preloadTokenImages();
  }

  @override
  void dispose() {
    _bgImage?.dispose();
    _fogImage?.dispose();
    for (final img in _tokenImageCache.values) {
      img.dispose();
    }
    super.dispose();
  }

  Future<void> _maybeReloadBackground() async {
    final path = widget.item.snapshot.mapPath;
    if (path == _lastMapPath) return;
    _lastMapPath = path;
    if (path == null || path.isEmpty) {
      debugPrint('SCREENCAST: battlemap mapPath is null/empty');
      setState(() => _bgImage = null);
      return;
    }
    try {
      // Resolve through the shared resolver: local path (offline window) or
      // `dmt-asset://` / `dmt-public://` ref (remote player).
      final file =
          await ref.read(assetRefResolverProvider).resolve(AssetRef(path));
      if (file == null) {
        debugPrint('SCREENCAST: map image unresolved path=$path');
        if (mounted) setState(() => _bgImage = null);
        return;
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      debugPrint('SCREENCAST: map image decoded ${frame.image.width}x${frame.image.height}');
      setState(() {
        _bgImage?.dispose();
        _bgImage = frame.image;
      });
    } catch (e) {
      debugPrint('SCREENCAST: map image load FAILED: $e');
      if (mounted) setState(() => _bgImage = null);
    }
  }

  Future<void> _maybeReloadFog() async {
    final fogB64 = widget.item.snapshot.fogDataBase64;
    final hash = fogB64?.length.toString();
    if (hash == _lastFogHash) return;
    _lastFogHash = hash;
    if (fogB64 == null || fogB64.isEmpty) {
      setState(() => _fogImage = null);
      return;
    }
    try {
      final bytes = base64Decode(fogB64);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _fogImage?.dispose();
        _fogImage = frame.image;
      });
    } catch (_) {
      if (mounted) setState(() => _fogImage = null);
    }
  }

  Future<void> _preloadTokenImages() async {
    final paths = <String>{};
    for (final t in widget.item.snapshot.tokens) {
      if (t.imagePath != null && t.imagePath!.isNotEmpty) {
        paths.add(t.imagePath!);
      }
    }
    // Drop cached images that are no longer referenced
    final stale = _tokenImageCache.keys.where((p) => !paths.contains(p)).toList();
    for (final p in stale) {
      _tokenImageCache.remove(p)?.dispose();
    }
    for (final p in paths) {
      if (_tokenImageCache.containsKey(p)) continue;
      try {
        final file =
            await ref.read(assetRefResolverProvider).resolve(AssetRef(p));
        if (file == null) continue;
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        setState(() => _tokenImageCache[p] = frame.image);
      } catch (_) {
        // Skip — fallback to colored circle
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snap = widget.item.snapshot;
    // Drop initiative side panel on narrow viewports (mobile) — the map
    // canvas is too small to share. Threshold matches Flutter's compact
    // breakpoint.
    final isCompact = MediaQuery.of(context).size.width < 600;
    final canvas = LayoutBuilder(builder: (context, constraints) {
      Widget c = CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _BattleMapProjectionPainter(
          snapshot: snap,
          bgImage: _bgImage,
          fogImage: _fogImage,
          tokenImages: _tokenImageCache,
          compact: isCompact,
        ),
      );
      if (widget.interactive) {
        c = InteractiveViewer(
          minScale: 0.5,
          maxScale: 8,
          clipBehavior: Clip.hardEdge,
          child: c,
        );
      }
      return c;
    });
    return RepaintBoundary(
      child: ColoredBox(
        color: Colors.black,
        child: isCompact
            ? canvas
            : Row(
                children: [
                  Expanded(child: canvas),
                  // Initiative side panel — outside the transformed subtree so
                  // pan/zoom doesn't drag the text. Reserves its own width so
                  // the map canvas isn't squished underneath an opaque overlay.
                  SizedBox(
                    width: 280,
                    child: _InitiativeSidePanel(snapshot: snap),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Standalone painter — does NOT depend on the DM-side BattleMapPainter so
/// the player isolate stays decoupled from gameplay state. Renders 4 layers:
///   1. background image (BoxFit.contain)
///   2. grid (if visible)
///   3. fog (with BlendMode.srcATop on background)
///   4. tokens (circle + image + name + condition badges)
class _BattleMapProjectionPainter extends CustomPainter {
  final BattleMapSnapshot snapshot;
  final ui.Image? bgImage;
  final ui.Image? fogImage;
  final Map<String, ui.Image> tokenImages;

  /// When true, render strokes thinner and labels smaller for narrow
  /// viewports (mobile second-screen).
  final bool compact;

  _BattleMapProjectionPainter({
    required this.snapshot,
    required this.bgImage,
    required this.fogImage,
    required this.tokenImages,
    this.compact = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Always paint the full background dark first — guarantees we never see
    // the bare scaffold even if canvas dims are degenerate.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );

    // Compute the BoxFit.contain rect for the background.
    final canvasW = snapshot.canvasWidth.toDouble();
    final canvasH = snapshot.canvasHeight.toDouble();
    if (canvasW <= 0 || canvasH <= 0) {
      // Safety: if dims weren't measured yet, just leave the dark fill above.
      return;
    }

    // Determine the canvas-space focus rect to display. If the DM has pushed
    // a normalized viewport (live mirror mode), we display exactly that
    // sub-rect. Otherwise we fit the entire canvas.
    final viewportN = snapshot.viewportNormalized;
    final double focusLeft;
    final double focusTop;
    final double focusW;
    final double focusH;
    if (viewportN != null && viewportN.width > 0 && viewportN.height > 0) {
      focusLeft = viewportN.left * canvasW;
      focusTop = viewportN.top * canvasH;
      focusW = viewportN.width * canvasW;
      focusH = viewportN.height * canvasH;
    } else {
      focusLeft = 0;
      focusTop = 0;
      focusW = canvasW;
      focusH = canvasH;
    }

    // BoxFit.contain: scale so the focus rect fits inside the player viewport,
    // then center it. This is a uniform scale — same factor in x and y — so
    // aspect mismatches between DM and player monitors leave black bars
    // rather than distorting the map.
    final scale = (size.width / focusW < size.height / focusH)
        ? size.width / focusW
        : size.height / focusH;

    // Translation: maps canvas-space (cx, cy) → screen-space.
    //   screen = (canvas - focusOrigin) * scale + screenOrigin
    // where screenOrigin centers the focus rect inside `size`.
    final dx = (size.width - focusW * scale) / 2 - focusLeft * scale;
    final dy = (size.height - focusH * scale) / 2 - focusTop * scale;

    // Whole-canvas dest rect (still drawn — fog/grid/tokens use the same
    // transform). Parts that fall outside `size` get clipped by the canvas.
    final destRect = Rect.fromLTWH(dx, dy, canvasW * scale, canvasH * scale);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 1. Background
    if (bgImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        bgImage!.width.toDouble(),
        bgImage!.height.toDouble(),
      );
      canvas.drawImageRect(bgImage!, src, destRect, Paint());
    } else {
      canvas.drawRect(destRect, Paint()..color = const Color(0xFF1a1a1a));
    }

    // 2. Grid — uses the same destRect (full canvas in screen space).
    // Matches DM grid style (dim 55/255 alpha, cosmetic 1px pen).
    if (snapshot.gridVisible && snapshot.gridSize > 0) {
      final gridPaint = Paint()
        ..color = const Color(0x37ffffff)
        ..strokeWidth = 1;
      final step = snapshot.gridSize * scale;
      final gx0 = destRect.left;
      final gy0 = destRect.top;
      final gx1 = destRect.right;
      final gy1 = destRect.bottom;
      for (double x = gx0; x <= gx1; x += step) {
        canvas.drawLine(Offset(x, gy0), Offset(x, gy1), gridPaint);
      }
      for (double y = gy0; y <= gy1; y += step) {
        canvas.drawLine(Offset(gx0, y), Offset(gx1, y), gridPaint);
      }
    }

    // 3. Tokens — drawn BEFORE fog so the fog actually hides hidden tokens.
    final activeIdx = snapshot.turnIndex;
    for (var i = 0; i < snapshot.tokens.length; i++) {
      final t = snapshot.tokens[i];
      final mult = snapshot.tokenSizeMultipliers[t.id] ?? 1.0;
      final tokenRadius = (snapshot.tokenSize * mult * scale) / 2;
      final cx = dx + t.x * scale;
      final cy = dy + t.y * scale;
      final tokenColor = _hexColor(t.colorHex);
      final isActive = i == activeIdx;

      // Border — DM TokenWidget border kalınlıkları canvas-space (3.2/7.0).
      // Scale ile çarp ki map zoom seviyesi DM ile aynıyken görünen kalınlık
      // da eşleşsin. Border, çekirdek tokenRadius'un dışına eklenir.
      final borderPx = (isActive ? 7.0 : 3.2) * scale;
      canvas.drawCircle(
        Offset(cx, cy),
        tokenRadius + borderPx * 0.5,
        Paint()..color = tokenColor,
      );

      // Image clipped to circle, or fallback fill
      final img = t.imagePath != null ? tokenImages[t.imagePath!] : null;
      if (img != null) {
        canvas.save();
        canvas.clipPath(
          Path()
            ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: tokenRadius)),
        );
        // Centered square crop of the source image so non-square portraits
        // don't get squashed when drawn into the circular dst rect.
        final iw = img.width.toDouble();
        final ih = img.height.toDouble();
        final s = iw < ih ? iw : ih;
        final src = Rect.fromLTWH((iw - s) / 2, (ih - s) / 2, s, s);
        final dst = Rect.fromCircle(center: Offset(cx, cy), radius: tokenRadius);
        canvas.drawImageRect(img, src, dst, Paint());
        canvas.restore();
      } else {
        // No-image fallback: DM `_tokenColor()` parity — name-hashed HSL,
        // full opacity (NOT border-color * alpha).
        final hash = t.name.hashCode;
        final hue = (hash.abs() % 360).toDouble();
        final initialsBg = HSLColor.fromAHSL(1.0, hue, 0.6, 0.4).toColor();
        canvas.drawCircle(
          Offset(cx, cy),
          tokenRadius,
          Paint()..color = initialsBg,
        );
        // 2-char initials split-by-space (DM `_buildInitials` parity).
        if (t.name.isNotEmpty) {
          final initials = t.name
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase();
          final dmSize = tokenRadius * 2;
          final fontSize = (dmSize * 0.35).clamp(8.0, 24.0);
          final tp = TextPainter(
            text: TextSpan(
              text: initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(blurRadius: 2, color: Colors.black54),
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            Offset(cx - tp.width / 2, cy - tp.height / 2),
          );
        }
      }
    }

    // 4. Fog — drawn after tokens so hidden tokens actually disappear
    // behind the dark mask. The fog image's alpha channel encodes
    // hidden=opaque, revealed=transparent. Blur is applied as a Paint
    // imageFilter for soft, feathered edges.
    if (fogImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        fogImage!.width.toDouble(),
        fogImage!.height.toDouble(),
      );
      final sigma = (12 * scale).clamp(4.0, 32.0);
      // Pad fog dst by ~3σ outside destRect, then clip strictly to destRect.
      // Blur feathers alpha→0 at the dst rect edge — without padding, that
      // feather would land on top of the bg image's edge and the bg would
      // peek through full-cover fog. With padding + tight clip, the feather
      // is in the cropped-out ring; what remains in destRect is opaque.
      final fogPad = sigma * 3;
      final fogDest = Rect.fromLTRB(
        destRect.left - fogPad,
        destRect.top - fogPad,
        destRect.right + fogPad,
        destRect.bottom + fogPad,
      );
      canvas.save();
      canvas.clipRect(destRect);
      canvas.drawImageRect(
        fogImage!,
        src,
        fogDest,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.medium
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          )
          ..colorFilter = const ColorFilter.mode(
            Color(0xFF000000),
            BlendMode.srcIn,
          ),
      );
      canvas.restore();
    }

    // 5. Annotation strokes — drawn ABOVE the fog so the DM's drawings
    // remain visible even where players are looking through fog.
    final strokeMult = compact ? 0.5 : 1.0;
    for (final s in snapshot.strokes) {
      if (s.points.length < 4) continue;
      final path = Path()
        ..moveTo(dx + s.points[0] * scale, dy + s.points[1] * scale);
      for (var i = 2; i + 1 < s.points.length; i += 2) {
        path.lineTo(dx + s.points[i] * scale, dy + s.points[i + 1] * scale);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _hexColor(s.colorHex)
          ..strokeWidth = s.width * scale * strokeMult
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 6. Measurements (ruler + circle) — also above fog.
    for (final m in snapshot.measurements) {
      final p1 = Offset(dx + m.x1 * scale, dy + m.y1 * scale);
      final p2 = Offset(dx + m.x2 * scale, dy + m.y2 * scale);
      if (m.type == 'ruler') {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = const Color(0xFFFFD54F)
            ..strokeWidth = compact ? 1.2 : 2,
        );
        final dotR = compact ? 2.5 : 4.0;
        canvas.drawCircle(p1, dotR, Paint()..color = const Color(0xFFFFD54F));
        canvas.drawCircle(p2, dotR, Paint()..color = const Color(0xFFFFD54F));
        final dxC = m.x2 - m.x1;
        final dyC = m.y2 - m.y1;
        final dist = math.sqrt(dxC * dxC + dyC * dyC);
        if (snapshot.gridSize > 0) {
          final cells = dist / snapshot.gridSize;
          final feet = (cells * snapshot.feetPerCell).round();
          final tp = TextPainter(
            text: TextSpan(
              text: '$feet ft',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: compact ? 9 : 13,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final mid = (p1 + p2) / 2;
          tp.paint(canvas, Offset(mid.dx + 6, mid.dy - tp.height / 2));
        }
      } else {
        // circle
        final r = (p2 - p1).distance;
        canvas.drawCircle(
          p1,
          r,
          Paint()
            ..color = const Color(0xFF00BCD4)
            ..strokeWidth = compact ? 1.2 : 2
            ..style = PaintingStyle.stroke,
        );
        canvas.drawCircle(p1, compact ? 2 : 3,
            Paint()..color = const Color(0xFF00BCD4));
        if (snapshot.gridSize > 0) {
          final cells = r / scale / snapshot.gridSize;
          final feet = (cells * snapshot.feetPerCell).round();
          final tp = TextPainter(
            text: TextSpan(
              text: '$feet ft',
              style: TextStyle(
                color: const Color(0xFF00BCD4),
                fontSize: compact ? 9 : 13,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(p1.dx + 6, p1.dy - tp.height - 4));
        }
      }
    }

    canvas.restore(); // matches the save() + clipRect at the start
  }

  Color _hexColor(String hex) {
    var clean = hex.replaceFirst('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.parse(clean, radix: 16));
  }

  @override
  bool shouldRepaint(covariant _BattleMapProjectionPainter old) {
    return old.snapshot != snapshot ||
        old.bgImage != bgImage ||
        old.fogImage != fogImage ||
        old.tokenImages.length != tokenImages.length ||
        old.compact != compact;
  }
}

/// Right-side overlay that lists every combatant in initiative order with
/// HP, conditions, and a highlight on whose turn it is. Player-only —
/// the DM has its own combat tracker in the session screen.
///
/// HP visibility rule (per the user spec): only `isPlayer` tokens show
/// numeric HP. Everything else displays "???" so the players don't see
/// the monster sheet.
// ---------------------------------------------------------------------------
// Initiative side panel — subtle D&D feel, parchment text, soft brass accents
// ---------------------------------------------------------------------------
//
// Toned down from the previous "iron + heavy brass" look — the user said it
// was too sharp/angular. Now: soft slate background, a single thin brass
// left rule, no diamond accents, gentle 3px row rounding, and a subtle
// brass underline on the active row instead of a thick rim.

const _ddBgDark = Color(0xFF18140e);      // soft dark slate
const _ddBgRow = Color(0xFF221b12);       // row fill
const _ddBgRowActive = Color(0xFF2c2412); // active row tint (brass-ish)
const _ddBrass = Color(0xFFc8a14a);       // brass accent
const _ddBrassDim = Color(0xFF5a4622);    // dim brass divider
const _ddParchment = Color(0xFFece2c5);   // parchment text
const _ddParchmentDim = Color(0xFF8a7c5a);// dim parchment for secondary
const _ddBlood = Color(0xFFb13838);       // wounded HP
const _ddCrimson = Color(0xFFd14b4b);     // ??? HP (NPCs)
const _ddSage = Color(0xFF77b04a);        // healthy HP

class _InitiativeSidePanel extends StatelessWidget {
  final BattleMapSnapshot snapshot;
  const _InitiativeSidePanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final tokens = snapshot.tokens;
    final activeIdx = snapshot.turnIndex;

    return Container(
      decoration: const BoxDecoration(
        color: _ddBgDark,
        // Single thin brass rule — no rounded corners, no double border.
        border: Border(
          left: BorderSide(color: _ddBrassDim, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            activeName: activeIdx >= 0 && activeIdx < tokens.length
                ? tokens[activeIdx].name
                : null,
          ),
          Expanded(
            child: tokens.isEmpty
                ? const Center(
                    child: Text(
                      'No combatants',
                      style: TextStyle(
                        color: _ddParchmentDim,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                    itemCount: tokens.length,
                    itemBuilder: (context, i) {
                      return _InitiativeRow(
                        key: ValueKey(tokens[i].id),
                        token: tokens[i],
                        isActive: i == activeIdx,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String? activeName;
  const _PanelHeader({required this.activeName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: const BoxDecoration(
        // Subtle separator only — no heavy brass underline.
        border: Border(
          bottom: BorderSide(color: _ddBrassDim, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Initiative',
            style: TextStyle(
              color: _ddBrass,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            activeName ?? '— Awaiting combat —',
            style: const TextStyle(
              color: _ddParchment,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InitiativeRow extends StatelessWidget {
  final TokenSnapshot token;
  final bool isActive;
  const _InitiativeRow({super.key, required this.token, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final hpText = token.isPlayer ? '${token.hp} / ${token.maxHp}' : '???';
    final hpRatio = token.isPlayer && token.maxHp > 0
        ? (token.hp / token.maxHp).clamp(0.0, 1.0)
        : null;

    final tokenColor = _hexColor(token.colorHex);
    final bg = isActive ? _ddBgRowActive : _ddBgRow;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        // Subtle brass underline marks the active row instead of a heavy rim.
        border: isActive
            ? Border(
                left: BorderSide(color: palette.tokenBorderActive, width: 2),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
            child: Row(
              children: [
                // Init badge — soft circle with category color fill.
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: tokenColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: tokenColor, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${token.init}',
                    style: const TextStyle(
                      color: _ddParchment,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    token.name,
                    style: TextStyle(
                      color: isActive ? palette.tokenBorderActive : _ddParchment,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hpText,
                  style: TextStyle(
                    color: token.isPlayer
                        ? (hpRatio != null && hpRatio < 0.34
                            ? _ddBlood
                            : _ddSage)
                        : _ddCrimson,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          // Slim HP bar — only for player characters.
          if (hpRatio != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 10, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      Container(color: const Color(0xFF1a120a)),
                      FractionallySizedBox(
                        widthFactor: hpRatio,
                        child: Container(
                          color: hpRatio > 0.66
                              ? _ddSage
                              : hpRatio > 0.33
                                  ? _ddBrass
                                  : _ddBlood,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Conditions strip — image badges with turn count overlay.
          if (token.conditions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final c in token.conditions) _ConditionBadge(condition: c),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Color _hexColor(String hex) {
    var clean = hex.replaceFirst('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.parse(clean, radix: 16));
  }
}

/// Single condition badge — soft rounded art tile with the turn count in
/// the bottom-right corner. Falls back to text-only when no image is given.
class _ConditionBadge extends StatelessWidget {
  final ConditionSnapshot condition;
  const _ConditionBadge({required this.condition});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        condition.imagePath != null && condition.imagePath!.isNotEmpty;
    return Tooltip(
      message: condition.turns != null
          ? '${condition.name} (${condition.turns} rounds)'
          : condition.name,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 30,
          height: 30,
          color: const Color(0xFF14100a),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                AssetRefImage(
                  ref: AssetRef(condition.imagePath!),
                  fit: BoxFit.cover,
                  cacheWidth: 80,
                  placeholder: _conditionFallback(),
                  errorWidget: _conditionFallback(),
                )
              else
                _conditionFallback(),
              if (condition.turns != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 1),
                    decoration: const BoxDecoration(
                      color: _ddBrass,
                      borderRadius:
                          BorderRadius.only(topLeft: Radius.circular(3)),
                    ),
                    child: Text(
                      '${condition.turns}',
                      style: const TextStyle(
                        color: Color(0xFF15110b),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conditionFallback() {
    final initial =
        condition.name.isNotEmpty ? condition.name[0].toUpperCase() : '?';
    return Container(
      color: const Color(0xFF2a1f10),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: _ddParchment,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
