import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/mind_map_id_provider.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../domain/entities/mind_map.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/dice/dice_fab.dart';
import '../../widgets/pen_color_picker.dart';
import 'mind_map_canvas.dart';
import 'mind_map_notifier.dart';
import '../../l10n/app_localizations.dart';

/// Mind Map tab root — full-bleed canvas + floating controls at bottom-right.
class MindMapScreen extends ConsumerStatefulWidget {
  final bool editMode;
  final void Function(String entityId)? onOpenEntity;

  const MindMapScreen({
    super.key,
    this.editMode = false,
    this.onOpenEntity,
  });

  @override
  ConsumerState<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends ConsumerState<MindMapScreen> {
  late final MindMapNotifier _notifier;

  /// `_init()` campaign verisiyle başarıyla çalıştı mı? Dünya açılışında
  /// MindMapScreen, `completeLoad()` bitmeden build olabilir → `data == null`
  /// → init boş döner. Bu bayrak false kaldığı sürece `deactivate()` persist
  /// etmez (boş state ile kayıtlı mind map'i ezmeyi engeller).
  bool _initialized = false;

  /// İlk init gerçek (non-empty) mind_maps verisi okudu mu? False kaldığı
  /// sürece `campaignRevision` bump'larında re-init denenir — başka cihazdan
  /// dünya açılışında yerel Drift boş gelir, cloud sync birkaç frame sonra
  /// `data['mind_maps']`'i doldurur ama state notifier hâlâ boş kalır.
  /// Re-init için ek koruma: notifier hâlâ boş olmalı (kullanıcı edit etmeye
  /// başladıysa cloud arrive ile ezmek istemiyoruz).
  bool _consumedRealData = false;

  /// Last applied cloud-side `mind_maps[mapId]` fingerprint. Compared on every
  /// `campaignRevisionProvider` bump — when cloud snapshot brings new nodes /
  /// edges (CDC mid-session or hydrate-after-init), we re-init the notifier
  /// instead of getting stuck on the first non-empty read.
  String? _appliedFingerprint;

  String _fingerprintOf(Map<String, dynamic> scoped) {
    final nodes = scoped['nodes'];
    final edges = scoped['edges'];
    return jsonEncode({'n': nodes, 'e': edges, 's': scoped['strokes']});
  }

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(mindMapProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _init();
    });
  }

  void _init() {
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final mindMaps = data['mind_maps'] as Map? ?? {};
    final mapId = ref.read(currentMindMapIdProvider);
    final scoped = Map<String, dynamic>.from(
      mindMaps[mapId] as Map? ?? {},
    );
    final fp = _fingerprintOf(scoped);
    if (fp == _appliedFingerprint) return; // no change since last apply
    // Local pending mind_maps write — user'ın henüz flush edilmemiş edit'i
    // var, cloud snapshot'ı uygulama (kullanıcı yazımını ezme).
    final worldId = (data['world_id'] as String?) ?? 'local';
    if (ref
        .read(pendingWriteBufferProvider)
        .isPending('settings:$worldId:mind_maps')) {
      return;
    }
    if (_initialized && !_consumedRealData) {
      // İlk init boş veriyle yapıldı; cloud sync sonrası re-init için izinli.
      // Ama kullanıcı bu arada node eklemişse (state non-empty) re-init etme.
      final currentState = ref.read(mindMapProvider);
      if (currentState.nodes.isNotEmpty ||
          currentState.edges.isNotEmpty ||
          currentState.strokes.isNotEmpty) {
        _consumedRealData = true;
        _appliedFingerprint = fp;
        return;
      }
      if (scoped.isEmpty) return;
    }
    _notifier.init(scoped);
    _initialized = true;
    _consumedRealData = scoped.isNotEmpty;
    _appliedFingerprint = fp;
  }

  @override
  void deactivate() {
    // Init hiç başarılı olmadıysa (campaign verisi geç geldi) state boş —
    // kayıtlı mind map'i boşla ezmemek için persist'i atla.
    if (!_initialized) {
      super.deactivate();
      return;
    }
    // Cross-device clobber guard: ilk init boş veriyle yapıldı (cloud sync
    // henüz arrive etmedi) VE kullanıcı bu screen'de hiçbir node/edge
    // eklemedi → state hâlâ default boş. Bunu data['mind_maps'][mapId]'e
    // yazıp bulut'a göndermek tüm cihazlarda mind map'i siler. Sessiz dön.
    final preCheckState = ref.read(mindMapProvider);
    final userHasContent = preCheckState.nodes.isNotEmpty ||
        preCheckState.edges.isNotEmpty ||
        preCheckState.strokes.isNotEmpty;
    if (!_consumedRealData && !userHasContent) {
      super.deactivate();
      return;
    }
    // autoDispose mindMapProvider tab değişimde dispose olunca, notifier'ın
    // _ref'i geçersiz; flushSave içindeki ref.read'lar atar ve save düşer.
    // Burada in-memory snapshot'ı senkron al, singleton container üzerinden
    // doğrudan saveSettingsPatch çağır — pending buffer + autoDispose
    // notifier tamamen bypass.
    try {
      final vt = _notifier.viewTransform.value;
      final mapId = ref.read(currentMindMapIdProvider);
      final mapState = ref.read(mindMapProvider);
      final mindMapData = <String, dynamic>{
        'nodes': mapState.nodes.map((n) => n.toJson()).toList(),
        'edges': mapState.edges.map((e) => e.toJson()).toList(),
        'strokes': mapState.strokes.map((s) => s.toJson()).toList(),
        'scale': vt.scale,
        'pan_x': vt.panOffset.dx,
        'pan_y': vt.panOffset.dy,
      };
      final campaign = ref.read(activeCampaignProvider.notifier);
      final data = campaign.data;
      if (data != null) {
        final mindMaps = Map<String, dynamic>.from(
            data['mind_maps'] as Map? ?? <String, dynamic>{});
        mindMaps[mapId] = mindMapData;
        data['mind_maps'] = mindMaps;
        // Pending spatial timer'ı iptal et — aşağıda tam patch'i kendimiz
        // yazıyoruz, stale closure'ın 800ms sonra üstüne yazması istenmiyor.
        final worldId = (data['world_id'] as String?) ?? 'local';
        ref.read(pendingWriteBufferProvider).schedule(
              key: 'settings:$worldId:mind_maps',
              kind: WriteKind.immediate,
              action: () => campaign.saveSettingsPatch(
                  {'mind_maps': Map<String, dynamic>.from(mindMaps)}),
            );
      }
    } catch (e, st) {
      debugPrint('MindMapScreen.deactivate save: $e\n$st');
    }
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    // Campaign verisi `completeLoad()` ile geç gelir (revision bump). Cloud
    // sync de `_applySettingsRow`'tan sonra bump eder. Gerçek mind_maps
    // verisi gelene dek re-init dene; sonrası `_init`'in iç guard'ı bloklar.
    // Revision bumps from: completeLoad finish, applyInitialState, CDC
    // world_settings UPDATE. _init guards against same-fingerprint reapplies
    // + pending-local-write clobbers.
    ref.listen(campaignRevisionProvider, (_, _) {
      if (mounted) _init();
    });
    ref.listen(currentMindMapIdProvider, (_, _) {
      if (mounted) {
        _appliedFingerprint = null;
        _init();
      }
    });

    final palette = Theme.of(context).extension<DmToolColors>()!;
    final notifier = ref.read(mindMapProvider.notifier);
    // Strokes excluded — see MindMapCanvas.build.
    final mapState = ref.watch(
        mindMapProvider.select((s) => s.copyWith(strokes: const [])));

    return Stack(
      children: [
        // Full-bleed canvas
        MindMapCanvas(
          editMode: widget.editMode,
          onOpenEntity: widget.onOpenEntity,
        ),

        // Floating zoom controls — stacked right above the host's dice button,
        // same size and spacing. Padding: the Scaffold insets its FAB by the
        // safe area too (landscape phone, no bottom bar).
        Positioned(
          right: kFabMargin + MediaQuery.paddingOf(context).right,
          bottom: kAboveDiceFab + MediaQuery.paddingOf(context).bottom,
          child: _FloatingControls(
            notifier: notifier,
            mapState: mapState,
            palette: palette,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Floating controls (bottom-right)
// ---------------------------------------------------------------------------

class _FloatingControls extends StatelessWidget {
  final MindMapNotifier notifier;
  final MindMapState mapState;
  final DmToolColors palette;

  const _FloatingControls({
    required this.notifier,
    required this.mapState,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final workspaces = notifier.workspaces;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Workspace list button (only if workspaces exist)
        if (workspaces.isNotEmpty)
          _FloatingButton(
            icon: Icons.grid_view_rounded,
            tooltip: L10n.of(context)!.mindMapWorkspaces,
            palette: palette,
            onPressed: () => _showWorkspaceMenu(context, workspaces),
          ),
        if (workspaces.isNotEmpty) const SizedBox(height: kFabGap),

        ListenableBuilder(
          listenable: Listenable.merge(
              [notifier.penColor, notifier.penWidth, notifier.erasing]),
          builder: (context, _) {
            final l10n = L10n.of(context)!;
            final penColor = notifier.penColor.value;
            final erasing = notifier.erasing.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (penColor != null) ...[
                  _FloatingButton(
                    icon: Icons.pan_tool_outlined,
                    tooltip: l10n.mindMapMoveTool,
                    palette: palette,
                    onPressed: notifier.exitPen,
                  ),
                  const SizedBox(height: kFabGap),
                  _FloatingButton(
                    icon: Icons.auto_fix_normal,
                    tooltip: l10n.mindMapEraser,
                    palette: palette,
                    active: erasing,
                    onPressed: notifier.toggleEraser,
                  ),
                  const SizedBox(height: kFabGap),
                  Builder(
                    builder: (context) => _FloatingButton(
                      icon: Icons.line_weight,
                      tooltip: l10n.mindMapPenWidth,
                      palette: palette,
                      onPressed: () => _showPenWidths(context, penColor),
                      child: _WidthLine(
                          width: notifier.penWidth.value,
                          color: palette.uiFloatingText),
                    ),
                  ),
                  const SizedBox(height: kFabGap),
                ],
                Builder(
                  builder: (context) => _FloatingButton(
                    icon: Icons.edit,
                    tooltip: l10n.mindMapPen,
                    palette: palette,
                    active: penColor != null && !erasing,
                    onPressed: penColor == null || erasing
                        ? () => notifier.selectPen(notifier.lastPenColor)
                        : () => _showPenColors(context, penColor),
                    child: penColor == null ? null : PenSwatch(color: penColor),
                  ),
                ),
                const SizedBox(height: kFabGap),
              ],
            );
          },
        ),

        _FloatingButton(
          icon: Icons.center_focus_strong,
          tooltip: L10n.of(context)!.mindMapCenterView,
          palette: palette,
          onPressed: notifier.centerView,
        ),
        const SizedBox(height: kFabGap),
        _FloatingButton(
          icon: Icons.add,
          tooltip: L10n.of(context)!.zoomIn,
          palette: palette,
          onPressed: notifier.zoomIn,
        ),
        const SizedBox(height: kFabGap),
        _FloatingButton(
          icon: Icons.remove,
          tooltip: L10n.of(context)!.zoomOut,
          palette: palette,
          onPressed: notifier.zoomOut,
        ),
      ],
    );
  }

  /// Menu anchored to the left of the button in [context].
  RelativeRect _leftOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    return RelativeRect.fromRect(
        rect.translate(-56, 0), Offset.zero & overlay.size);
  }

  Future<void> _showPenWidths(BuildContext context, Color penColor) async {
    final current = notifier.penWidth.value;
    final picked = await showMenu<double>(
      context: context,
      position: _leftOf(context),
      color: palette.uiFloatingBg,
      constraints: const BoxConstraints(minWidth: 48, maxWidth: 48),
      items: [
        for (final w in MindMapNotifier.penWidths)
          PopupMenuItem<double>(
            value: w,
            height: 36,
            padding: EdgeInsets.zero,
            child: Center(
              child: Container(
                width: 36,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: w == current ? palette.uiFloatingHoverBg : null,
                  borderRadius: palette.cbr,
                ),
                child: _WidthLine(width: w, color: penColor),
              ),
            ),
          ),
      ],
    );
    if (picked != null) notifier.setPenWidth(picked);
  }

  Future<void> _showPenColors(BuildContext context, Color current) async {
    final picked = await pickPenColor(context,
        position: _leftOf(context), current: current, palette: palette);
    if (picked != null) notifier.selectPen(picked);
  }

  void _showWorkspaceMenu(
      BuildContext context, List<MindMapNode> workspaces) {
    final button = context.findRenderObject() as RenderBox;
    final offset = button.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx - 160,
        offset.dy - workspaces.length * 40.0,
        offset.dx,
        offset.dy,
      ),
      color: palette.uiFloatingBg,
      items: workspaces.map((ws) {
        final color = _parseHexColor(ws.color);
        return PopupMenuItem<String>(
          value: ws.id,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ws.label,
                  style: TextStyle(fontSize: 12, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((id) {
      if (id != null) notifier.zoomToWorkspace(id);
    });
  }

  Color _parseHexColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

/// Pen thickness preview: a short rounded bar [width] px thick.
class _WidthLine extends StatelessWidget {
  final double width;
  final Color color;
  const _WidthLine({required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}

class _FloatingButton extends StatefulWidget {
  final IconData icon;

  /// When set, replaces [icon] (pen color dot, thickness bar).
  final Widget? child;

  /// Selected tool — drawn in the hover colors.
  final bool active;
  final String tooltip;
  final DmToolColors palette;
  final VoidCallback onPressed;

  const _FloatingButton({
    required this.icon,
    this.child,
    this.active = false,
    required this.tooltip,
    required this.palette,
    required this.onPressed,
  });

  @override
  State<_FloatingButton> createState() => _FloatingButtonState();
}

class _FloatingButtonState extends State<_FloatingButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final lit = _hovered || widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: lit ? palette.uiFloatingHoverBg : palette.uiFloatingBg,
              border: Border.all(color: palette.uiFloatingBorder),
              borderRadius: palette.cbr,
            ),
            child: widget.child != null
                ? Center(child: widget.child)
                : Icon(
                    widget.icon,
                    size: 18,
                    color: lit
                        ? palette.uiFloatingHoverText
                        : palette.uiFloatingText,
                  ),
          ),
        ),
      );
  }
}
