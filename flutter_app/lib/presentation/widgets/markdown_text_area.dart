import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../domain/entities/entity.dart';
import '../theme/dm_tool_colors.dart';

/// Reusable text area with markdown rendering (view mode) and @entity mention
/// autocomplete (edit mode).
///
/// - [readOnly] = true  → renders markdown via [MarkdownBody]
/// - [readOnly] = false → editable [TextField] with @mention overlay
class MarkdownTextArea extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final TextStyle? textStyle;
  final InputDecoration? decoration;
  final TextAlignVertical? textAlignVertical;
  final MarkdownStyleSheet? markdownStyleSheet;
  final void Function(String entityId)? onEntityTap;
  final ValueChanged<String>? onSubmitted;

  const MarkdownTextArea({
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.readOnly = false,
    this.maxLines,
    this.minLines,
    this.expands = false,
    this.textStyle,
    this.decoration,
    this.textAlignVertical,
    this.markdownStyleSheet,
    this.onEntityTap,
    this.onSubmitted,
    super.key,
  });

  @override
  ConsumerState<MarkdownTextArea> createState() => _MarkdownTextAreaState();
}

class _MarkdownTextAreaState extends ConsumerState<MarkdownTextArea> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  // Mention state
  OverlayEntry? _mentionOverlay;
  String _mentionQuery = '';
  int _mentionStart = -1;
  List<Entity> _filteredEntities = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant MarkdownTextArea old) {
    super.didUpdateWidget(old);
    if (widget.focusNode != old.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (_ownsFocusNode) _focusNode.dispose();
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _dismissMentionOverlay();
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _dismissMentionOverlay();
  }

  // --------------- @mention logic ---------------

  void _dismissMentionOverlay() {
    if (_mentionOverlay != null) {
      HardwareKeyboard.instance.removeHandler(_mentionKeyHandler);
      _mentionOverlay?.remove();
      _mentionOverlay = null;
      _filteredEntities = [];
      _selectedIndex = 0;
    }
  }

  void _onTextChanged(String text) {
    widget.onChanged?.call(text);
    _checkMention(text);
  }

  void _checkMention(String text) {
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos <= 0) {
      _dismissMentionOverlay();
      return;
    }

    final beforeCursor = text.substring(0, cursorPos);
    final atIndex = beforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      final query = beforeCursor.substring(atIndex + 1);
      // Require at least 1 character after @, no newlines, max 30 chars
      if (query.isNotEmpty && !query.contains('\n') && query.length < 30) {
        _mentionStart = atIndex;
        _mentionQuery = query.toLowerCase();
        _showMentionOverlay();
        return;
      }
    }
    _dismissMentionOverlay();
  }

  void _showMentionOverlay() {
    final entities = ref.read(entityProvider);
    if (entities.isEmpty) {
      _dismissMentionOverlay();
      return;
    }

    final filtered = entities.values
        .where((e) => e.name.toLowerCase().contains(_mentionQuery))
        .take(8)
        .toList();
    if (filtered.isEmpty) {
      _dismissMentionOverlay();
      return;
    }

    _filteredEntities = filtered;
    _selectedIndex = _selectedIndex.clamp(0, filtered.length - 1);

    // If overlay already exists, just rebuild it
    if (_mentionOverlay != null) {
      _mentionOverlay!.markNeedsBuild();
      return;
    }

    // Register keyboard handler for arrow/enter/escape navigation
    HardwareKeyboard.instance.addHandler(_mentionKeyHandler);

    final overlay = Overlay.of(context);

    _mentionOverlay = OverlayEntry(
      builder: (ctx) {
        // Recalculate position on each build (accounts for scroll/resize)
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.attached) {
          return const SizedBox.shrink();
        }
        final widgetPos = renderBox.localToGlobal(Offset.zero);
        final screenSize = MediaQuery.of(context).size;

        // Position below the widget, clamped to screen
        const overlayWidth = 320.0;
        const overlayMaxHeight = 200.0;
        final left = widgetPos.dx.clamp(0.0, screenSize.width - overlayWidth);
        var top = widgetPos.dy + renderBox.size.height + 4;
        // If would go off-screen bottom, show above instead
        if (top + overlayMaxHeight > screenSize.height) {
          top = widgetPos.dy - overlayMaxHeight - 4;
        }

        final palette = Theme.of(context).extension<DmToolColors>();
        final items = _filteredEntities;
        final selIdx = _selectedIndex;

        return Positioned(
          left: left,
          top: top,
          width: overlayWidth,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(4),
            color: palette?.canvasBg ?? Colors.grey[900],
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: overlayMaxHeight),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final entity = items[i];
                  final isSelected = i == selIdx;
                  return Container(
                    color: isSelected
                        ? (palette?.featureCardAccent ?? Colors.blue).withValues(alpha: 0.2)
                        : null,
                    child: ListTile(
                      dense: true,
                      title: Text(
                        entity.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette?.tabActiveText,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: Text(
                        entity.categorySlug,
                        style: TextStyle(fontSize: 10, color: palette?.sidebarLabelSecondary),
                      ),
                      onTap: () => _insertMention(entity.id, entity.name),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_mentionOverlay!);
  }

  bool _mentionKeyHandler(KeyEvent event) {
    if (_mentionOverlay == null || _filteredEntities.isEmpty) return false;
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _selectedIndex = (_selectedIndex + 1) % _filteredEntities.length;
      _mentionOverlay?.markNeedsBuild();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _selectedIndex = (_selectedIndex - 1 + _filteredEntities.length) % _filteredEntities.length;
      _mentionOverlay?.markNeedsBuild();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      final entity = _filteredEntities[_selectedIndex];
      _insertMention(entity.id, entity.name);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _dismissMentionOverlay();
      return true;
    }
    return false;
  }

  void _insertMention(String entityId, String entityName) {
    _dismissMentionOverlay();
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    final mention = '@[$entityName](entity:$entityId)';
    final newText = text.substring(0, _mentionStart) +
        mention +
        text.substring(cursorPos);
    widget.controller.text = newText;
    final newCursor = _mentionStart + mention.length;
    widget.controller.selection = TextSelection.collapsed(offset: newCursor);
    widget.onChanged?.call(newText);
    // Refocus text field
    _focusNode.requestFocus();
  }

  // --------------- entity link tap ---------------

  void _handleEntityLink(String entityId) {
    if (widget.onEntityTap != null) {
      widget.onEntityTap!(entityId);
    } else {
      ref.read(entityNavigationProvider.notifier).state = entityId;
    }
  }

  // --------------- markdown style ---------------

  MarkdownStyleSheet _defaultStyleSheet(DmToolColors? palette) {
    return MarkdownStyleSheet(
      p: widget.textStyle ?? TextStyle(fontSize: 13, color: palette?.htmlText),
      h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette?.htmlHeader),
      h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette?.htmlHeader),
      h3: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette?.htmlHeader),
      code: TextStyle(fontSize: 12, backgroundColor: palette?.htmlCodeBg),
      a: TextStyle(color: palette?.htmlLink),
      listBullet: TextStyle(fontSize: 13, color: palette?.htmlText),
    );
  }

  // --------------- build ---------------

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();

    if (widget.readOnly) {
      return _buildMarkdownView(palette);
    }
    return _buildEditField();
  }

  /// Strip the `@` prefix from entity mention links for display.
  /// `@[Name](entity:id)` → `[Name](entity:id)`
  static final _mentionDisplayRe = RegExp(r'@(\[[^\]]+\]\(entity:[^)]+\))');

  Widget _buildMarkdownView(DmToolColors? palette) {
    final raw = widget.controller.text;
    if (raw.isEmpty) return const SizedBox.shrink();

    // Remove @ prefix from mention links so only the name renders
    final text = raw.replaceAllMapped(_mentionDisplayRe, (m) => m[1]!);

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: widget.markdownStyleSheet ?? _defaultStyleSheet(palette),
      onTapLink: (text, href, title) {
        if (href != null && href.startsWith('entity:')) {
          final entityId = href.substring('entity:'.length);
          _handleEntityLink(entityId);
        }
      },
    );
  }

  Widget _buildEditField() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      maxLines: widget.expands ? null : widget.maxLines,
      minLines: widget.expands ? null : widget.minLines,
      expands: widget.expands,
      textAlignVertical: widget.textAlignVertical,
      style: widget.textStyle,
      decoration: widget.decoration ??
          InputDecoration(
            hintText: 'Use @ to mention entities. Markdown supported.',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
      onChanged: _onTextChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
