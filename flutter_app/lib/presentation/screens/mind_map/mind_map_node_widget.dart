import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/mind_map.dart';
import '../../theme/dm_tool_colors.dart';
import 'mind_map_notifier.dart';

/// A single mind-map node widget positioned in canvas-space.
///
/// Supports note (sharp corners), entity (rounded 6px), image, and workspace
/// node types with LOD-aware rendering and edit-mode gating.
class MindMapNodeWidget extends StatefulWidget {
  final MindMapNode node;
  final bool isSelected;
  final bool isConnecting;
  final bool canConnectTo;
  final DmToolColors palette;
  final MindMapNotifier notifier;
  final bool editMode;
  final int lodZone;
  final bool showResizeHandle;
  final void Function(String entityId)? onOpenEntity;

  const MindMapNodeWidget({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isConnecting,
    required this.canConnectTo,
    required this.palette,
    required this.notifier,
    this.editMode = false,
    this.lodZone = 0,
    this.showResizeHandle = false,
    this.onOpenEntity,
  });

  @override
  State<MindMapNodeWidget> createState() => _MindMapNodeWidgetState();
}

class _MindMapNodeWidgetState extends State<MindMapNodeWidget> {
  // Drag state
  Offset? _dragStart;
  Offset? _nodeStartPos;

  // Resize state
  Offset? _resizeStart;
  Size? _sizeAtResizeStart;

  // Inline edit (label)
  bool _editingLabel = false;
  late TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.node.label);
  }

  @override
  void didUpdateWidget(MindMapNodeWidget old) {
    super.didUpdateWidget(old);
    if (old.node.label != widget.node.label && !_editingLabel) {
      _labelCtrl.text = widget.node.label;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final palette = widget.palette;

    // Workspace nodes are painted by the painter — use a transparent
    // overlay widget for interaction only.
    if (n.nodeType == 'workspace') {
      return _buildWorkspaceOverlay(n, palette);
    }

    final borderColor = widget.isConnecting
        ? palette.tabIndicator
        : widget.canConnectTo
            ? palette.tabIndicator.withValues(alpha: 0.7)
            : widget.isSelected
                ? palette.lineSelected
                : palette.sidebarDivider;

    final borderWidth =
        (widget.isSelected || widget.isConnecting || widget.canConnectTo)
            ? 2.0
            : 1.0;

    final borderRadius = switch (n.nodeType) {
      'note' => BorderRadius.zero,
      'entity' => BorderRadius.circular(6),
      _ => BorderRadius.zero,
    };

    // LOD zone 1: no shadow, simplified
    final showShadow = widget.lodZone == 0;

    return Positioned(
      left: n.x - n.width / 2,
      top: n.y - n.height / 2,
      width: n.width,
      height: n.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card
          GestureDetector(
            onTap: _onTap,
            onSecondaryTapUp: (d) =>
                _showContextMenu(context, d.globalPosition),
            onLongPress: () => _showContextMenu(context, null),
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: n.width,
                height: n.height,
                decoration: BoxDecoration(
                  color: _nodeColor(n.nodeType, palette),
                  borderRadius: borderRadius,
                  border:
                      Border.all(color: borderColor, width: borderWidth),
                  boxShadow: showShadow
                      ? (widget.isSelected
                          ? [
                              BoxShadow(
                                color: palette.tabIndicator
                                    .withValues(alpha: 0.25),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ])
                      : null,
                ),
                child: widget.lodZone == 0
                    ? _buildContent(n, palette)
                    : _buildSimplifiedContent(n, palette),
              ),
            ),
          ),

          // Single resize handle — bottom-right
          if (widget.showResizeHandle) _buildResizeHandle(palette),
        ],
      ),
    );
  }

  Color _nodeColor(String nodeType, DmToolColors palette) {
    return switch (nodeType) {
      'note' => palette.nodeBgNote,
      'entity' => palette.nodeBgEntity,
      'image' => Colors.transparent,
      _ => palette.tabBg,
    };
  }

  // -------------------------------------------------------------------------
  // Workspace overlay (transparent, for hit-testing only)
  // -------------------------------------------------------------------------

  Widget _buildWorkspaceOverlay(MindMapNode n, DmToolColors palette) {
    return Positioned(
      left: n.x - n.width / 2,
      top: n.y - n.height / 2,
      width: n.width,
      height: n.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.notifier.setSelectedNode(n.id),
        onSecondaryTapUp: (d) =>
            _showContextMenu(context, d.globalPosition),
        child: Listener(
          onPointerDown: (event) {
            // Middle mouse button drag for workspace
            if (event.buttons == 4) {
              _dragStart = event.position;
              _nodeStartPos = Offset(n.x, n.y);
            }
          },
          onPointerMove: (event) {
            if (_dragStart == null || _nodeStartPos == null) return;
            final delta = event.position - _dragStart!;
            final scale = widget.notifier.viewTransform.value.scale;
            widget.notifier.updateNodePosition(
              n.id,
              _nodeStartPos! + delta / scale,
            );
          },
          onPointerUp: (_) {
            _dragStart = null;
            _nodeStartPos = null;
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const SizedBox.expand(),
              // Resize handle for workspace
              if (widget.showResizeHandle) _buildResizeHandle(palette),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Content
  // -------------------------------------------------------------------------

  double get _fontSize =>
      (widget.node.style['fontSize'] as num?)?.toDouble() ?? 12.0;

  Widget _buildContent(MindMapNode n, DmToolColors palette) {
    return switch (n.nodeType) {
      'note' => _buildNoteContent(n, palette),
      'entity' => _buildEntityContent(n, palette),
      'image' => _buildImageContent(n, palette),
      _ => _buildNoteContent(n, palette),
    };
  }

  /// LOD zone 1 — simplified: just label, no content body
  Widget _buildSimplifiedContent(MindMapNode n, DmToolColors palette) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        n.label,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          color: palette.nodeText,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildNoteContent(MindMapNode n, DmToolColors palette) {
    final fs = _fontSize;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label (editable on double-tap in edit mode)
          GestureDetector(
            onDoubleTap: widget.editMode
                ? () => setState(() => _editingLabel = true)
                : null,
            child: _editingLabel
                ? TextField(
                    controller: _labelCtrl,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: fs,
                      fontWeight: FontWeight.bold,
                      color: palette.nodeText,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (v) {
                      widget.notifier.updateNodeLabel(n.id, v);
                      setState(() => _editingLabel = false);
                    },
                    onEditingComplete: () {
                      widget.notifier.updateNodeLabel(n.id, _labelCtrl.text);
                      setState(() => _editingLabel = false);
                    },
                  )
                : Text(
                    n.label,
                    style: TextStyle(
                      fontSize: fs,
                      fontWeight: FontWeight.bold,
                      color: palette.nodeText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: palette.nodeText.withValues(alpha: 0.25)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              n.content.isEmpty
                  ? 'Double-tap header to rename\nRight-click to edit content'
                  : n.content,
              style: TextStyle(
                fontSize: fs - 1,
                color: n.content.isEmpty
                    ? palette.nodeText.withValues(alpha: 0.4)
                    : palette.nodeText.withValues(alpha: 0.85),
                height: 1.4,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityContent(MindMapNode n, DmToolColors palette) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: palette.tabIndicator),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  n.label,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.bold,
                    color: palette.tabActiveText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (n.entityId != null)
            Text(
              'Linked entity',
              style:
                  TextStyle(fontSize: 10, color: palette.tabIndicator),
            )
          else
            Text(
              'No entity linked',
              style: TextStyle(
                  fontSize: 10,
                  color: palette.tabText.withValues(alpha: 0.4)),
            ),
          if (n.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                n.content,
                style: TextStyle(
                    fontSize: 10, color: palette.tabText, height: 1.4),
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageContent(MindMapNode n, DmToolColors palette) {
    if (n.imageUrl != null && n.imageUrl!.isNotEmpty) {
      final file = File(n.imageUrl!);
      if (file.existsSync()) {
        return ClipRRect(
          child: Image.file(file,
              fit: BoxFit.cover, width: n.width, height: n.height),
        );
      }
    }
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.tabBg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined,
              size: 28, color: palette.tabText.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          Text('Right-click to set image',
              style: TextStyle(
                  fontSize: 10,
                  color: palette.tabText.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Drag (left-click and middle-click)
  // -------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    _dragStart = event.position;
    _nodeStartPos = Offset(widget.node.x, widget.node.y);
    widget.notifier.setSelectedNode(widget.node.id);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragStart == null || _nodeStartPos == null) return;
    if (_resizeStart != null) return; // resize takes over

    final delta = event.position - _dragStart!;
    final scale = widget.notifier.viewTransform.value.scale;
    widget.notifier.updateNodePosition(
      widget.node.id,
      _nodeStartPos! + delta / scale,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    _dragStart = null;
    _nodeStartPos = null;
  }

  // -------------------------------------------------------------------------
  // Tap
  // -------------------------------------------------------------------------

  void _onTap() {
    if (widget.canConnectTo) {
      widget.notifier.connectTo(widget.node.id);
    } else {
      widget.notifier.setSelectedNode(widget.node.id);
    }
  }

  // -------------------------------------------------------------------------
  // Unified context menu — all node types
  // -------------------------------------------------------------------------

  void _showContextMenu(BuildContext context, Offset? globalPos) {
    final palette = widget.palette;
    final n = widget.node;
    final currentFontSize = (n.style['fontSize'] as num?)?.toDouble() ?? 12.0;

    final items = <PopupMenuEntry<String>>[];

    // --- Type-specific items first (above divider) ---

    if (n.nodeType == 'entity' && n.entityId != null) {
      items.add(PopupMenuItem(
          value: 'inspect',
          child: _menuItem(Icons.open_in_new, 'Inspect', palette)));
    }

    if (n.nodeType == 'image') {
      items.add(PopupMenuItem(
          value: 'set_image',
          child: _menuItem(Icons.image_outlined, 'Change Image', palette)));
    }

    if (n.nodeType == 'workspace') {
      items.add(PopupMenuItem(
          value: 'rename',
          child: _menuItem(Icons.text_fields, 'Rename', palette)));
      items.add(PopupMenuItem(
          value: 'pick_color',
          child: _menuItem(Icons.palette, 'Pick Color', palette)));
    }

    if (n.nodeType == 'note') {
      items.add(PopupMenuItem(
          value: 'edit',
          child: _menuItem(Icons.edit_outlined, 'Edit Content', palette)));

      // Font size sub-items
      items.add(const PopupMenuDivider());
      for (final entry in [('font_small', 'Small (10)', 10.0), ('font_normal', 'Normal (12)', 12.0), ('font_large', 'Large (16)', 16.0)]) {
        final isActive = (currentFontSize - entry.$3).abs() < 0.5;
        items.add(PopupMenuItem(
          value: entry.$1,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: isActive
                    ? Icon(Icons.check, size: 14, color: palette.uiFloatingText)
                    : null,
              ),
              const SizedBox(width: 4),
              Text(entry.$2,
                  style: TextStyle(
                      fontSize: 12, color: palette.uiFloatingText)),
            ],
          ),
        ));
      }
    }

    if (n.nodeType == 'entity') {
      items.add(PopupMenuItem(
          value: 'edit',
          child: _menuItem(Icons.edit_outlined, 'Edit Content', palette)));
    }

    // --- Divider + common items ---
    if (items.isNotEmpty) items.add(const PopupMenuDivider());

    items.addAll([
      PopupMenuItem(
          value: 'connect',
          child: _menuItem(Icons.linear_scale, 'Connect to...', palette)),
      PopupMenuItem(
          value: 'duplicate',
          child: _menuItem(Icons.copy_outlined, 'Duplicate', palette)),
      PopupMenuItem(
          value: 'move',
          child: _menuItem(Icons.open_with, 'Move', palette)),
      PopupMenuItem(
          value: 'resize',
          child: _menuItem(Icons.aspect_ratio, 'Resize', palette)),
      const PopupMenuDivider(),
      PopupMenuItem(
          value: 'delete',
          child: _menuItem(Icons.delete_outline, 'Delete', palette,
              danger: true)),
    ]);

    final pos = globalPos ?? Offset(n.x, n.y);
    showMenu<String>(
      context: context,
      position:
          RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: items,
      color: palette.uiFloatingBg,
    ).then((value) {
      if (!mounted) return;
      switch (value) {
        case 'inspect':
          if (n.entityId != null) widget.onOpenEntity?.call(n.entityId!);
        case 'edit':
          if (context.mounted) _showEditContentDialog(context);
        case 'rename':
          if (n.nodeType == 'workspace') {
            if (context.mounted) _showRenameDialog(context, n);
          } else {
            setState(() => _editingLabel = true);
          }
        case 'pick_color':
          if (context.mounted) _showColorPickerDialog(context, n);
        case 'set_image':
          if (context.mounted) _pickImageForNode(context);
        case 'connect':
          widget.notifier.startConnecting(n.id);
        case 'duplicate':
          widget.notifier.duplicateNode(n.id);
        case 'move':
          widget.notifier.enterMoveMode(n.id);
        case 'resize':
          widget.notifier.enterResizeMode(n.id);
        case 'delete':
          widget.notifier.deleteNode(n.id);
        case 'font_small':
          widget.notifier.updateNodeStyle(n.id, {'fontSize': 10});
        case 'font_normal':
          widget.notifier.updateNodeStyle(n.id, {'fontSize': 12});
        case 'font_large':
          widget.notifier.updateNodeStyle(n.id, {'fontSize': 16});
        default:
          break;
      }
    });
  }

  Widget _menuItem(IconData icon, String label, DmToolColors palette,
      {bool danger = false}) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: danger ? Colors.red[300] : palette.uiFloatingText),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color:
                    danger ? Colors.red[300] : palette.uiFloatingText)),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Dialogs
  // -------------------------------------------------------------------------

  void _showEditContentDialog(BuildContext context) {
    final palette = widget.palette;
    final ctrl = TextEditingController(text: widget.node.content);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.uiFloatingBg,
        title: Text('Edit Content',
            style: TextStyle(
                color: palette.uiFloatingText, fontSize: 14)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 8,
            style:
                TextStyle(fontSize: 12, color: palette.uiFloatingText),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: palette.uiFloatingBorder)),
              hintText: 'Enter markdown content...',
              hintStyle: TextStyle(
                  color: palette.uiFloatingText.withValues(alpha: 0.4),
                  fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: palette.uiFloatingText)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.notifier
                  .updateNodeContent(widget.node.id, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, MindMapNode n) {
    final palette = widget.palette;
    final ctrl = TextEditingController(text: n.label);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.uiFloatingBg,
        title: Text('Rename',
            style: TextStyle(
                color: palette.uiFloatingText, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 12, color: palette.uiFloatingText),
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderSide:
                    BorderSide(color: palette.uiFloatingBorder)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: palette.uiFloatingText)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.notifier.updateNodeLabel(n.id, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog(BuildContext context, MindMapNode n) {
    final palette = widget.palette;
    final colors = [
      '#42a5f5', '#ef5350', '#66bb6a', '#ffa726', '#ab47bc',
      '#26c6da', '#ec407a', '#8d6e63', '#78909c', '#ffee58',
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.uiFloatingBg,
        title: Text('Pick Color',
            style: TextStyle(
                color: palette.uiFloatingText, fontSize: 14)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((hex) {
            final c = Color(
                int.parse(hex.replaceAll('#', 'FF'), radix: 16));
            return GestureDetector(
              onTap: () {
                widget.notifier.updateWorkspaceColor(n.id, hex);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: n.color == hex
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _pickImageForNode(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path != null) {
        widget.notifier.updateNodeImageUrl(widget.node.id, path);
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Single resize handle (bottom-right corner)
  // -------------------------------------------------------------------------

  Widget _buildResizeHandle(DmToolColors palette) {
    return Positioned(
      right: -4,
      bottom: -4,
      child: GestureDetector(
        onPanStart: (d) {
          _resizeStart = d.globalPosition;
          _sizeAtResizeStart =
              Size(widget.node.width, widget.node.height);
        },
        onPanUpdate: (d) {
          if (_resizeStart == null || _sizeAtResizeStart == null) return;
          final scale = widget.notifier.viewTransform.value.scale;
          final delta = (d.globalPosition - _resizeStart!) / scale;
          final newW =
              (_sizeAtResizeStart!.width + delta.dx).clamp(150.0, 2000.0);
          final newH =
              (_sizeAtResizeStart!.height + delta.dy).clamp(80.0, 2000.0);
          widget.notifier
              .updateNodeSize(widget.node.id, Size(newW, newH));
        },
        onPanEnd: (_) {
          _resizeStart = null;
          _sizeAtResizeStart = null;
          widget.notifier.exitResizeMode();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeDownRight,
          child: CustomPaint(
            size: const Size(16, 16),
            painter: _ResizeHandlePainter(palette.tabIndicator),
          ),
        ),
      ),
    );
  }
}

/// Paints a small triangle resize indicator.
class _ResizeHandlePainter extends CustomPainter {
  final Color color;
  _ResizeHandlePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ResizeHandlePainter old) => old.color != color;
}
