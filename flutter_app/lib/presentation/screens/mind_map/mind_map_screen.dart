import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/mind_map_id_provider.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../domain/entities/mind_map.dart';
import '../../theme/dm_tool_colors.dart';
import 'mind_map_canvas.dart';
import 'mind_map_notifier.dart';

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
    if (_consumedRealData) return; // gerçek veri yüklendi — clobber yok
    if (_initialized) {
      // İlk init boş veriyle yapıldı; cloud sync sonrası re-init için izinli.
      // Ama kullanıcı bu arada node eklemişse (state non-empty) re-init etme.
      final currentState = ref.read(mindMapProvider);
      if (currentState.nodes.isNotEmpty || currentState.edges.isNotEmpty) {
        _consumedRealData = true;
        return;
      }
      if (scoped.isEmpty) return; // hâlâ bir şey yok, retry beklemeye devam
    }
    _notifier.init(scoped);
    _initialized = true;
    _consumedRealData = scoped.isNotEmpty;
  }

  @override
  void deactivate() {
    // Init hiç başarılı olmadıysa (campaign verisi geç geldi) state boş —
    // kayıtlı mind map'i boşla ezmemek için persist'i atla.
    if (!_initialized) {
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
    ref.listen(campaignRevisionProvider, (_, _) {
      if (!_consumedRealData && mounted) _init();
    });

    final palette = Theme.of(context).extension<DmToolColors>()!;
    final notifier = ref.read(mindMapProvider.notifier);
    final mapState = ref.watch(mindMapProvider);

    return Stack(
      children: [
        // Full-bleed canvas
        MindMapCanvas(
          editMode: widget.editMode,
          onOpenEntity: widget.onOpenEntity,
        ),

        // Floating zoom controls — bottom-right
        Positioned(
          right: 16,
          bottom: 16,
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
            tooltip: 'Workspaces',
            palette: palette,
            onPressed: () => _showWorkspaceMenu(context, workspaces),
          ),
        if (workspaces.isNotEmpty) const SizedBox(height: 4),

        _FloatingButton(
          icon: Icons.center_focus_strong,
          tooltip: 'Center View',
          palette: palette,
          onPressed: notifier.centerView,
        ),
        const SizedBox(height: 4),
        _FloatingButton(
          icon: Icons.add,
          tooltip: 'Zoom In',
          palette: palette,
          onPressed: notifier.zoomIn,
        ),
        const SizedBox(height: 4),
        _FloatingButton(
          icon: Icons.remove,
          tooltip: 'Zoom Out',
          palette: palette,
          onPressed: notifier.zoomOut,
        ),
      ],
    );
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

class _FloatingButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final DmToolColors palette;
  final VoidCallback onPressed;

  const _FloatingButton({
    required this.icon,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hovered ? palette.uiFloatingHoverBg : palette.uiFloatingBg,
              border: Border.all(color: palette.uiFloatingBorder),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovered
                  ? palette.uiFloatingHoverText
                  : palette.uiFloatingText,
            ),
          ),
        ),
      );
  }
}
