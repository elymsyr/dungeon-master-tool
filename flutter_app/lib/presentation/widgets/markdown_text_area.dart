import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../theme/markdown_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/entity_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/services/mention_text.dart';
import '../../core/utils/screen_type.dart';
import '../../domain/entities/entity.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../dialogs/markdown_image_picker_dialog.dart';
import '../theme/dm_tool_colors.dart';
import '../l10n/app_localizations.dart';
import 'asset_ref_image.dart';
import 'perf/image_cache_size.dart';

/// Reusable text area with markdown rendering (view mode) and @entity mention
/// autocomplete (edit mode).
///
/// - [readOnly] = true  → renders markdown via [MarkdownBody]
/// - [readOnly] = false → editable [TextField] with @mention overlay; typing
///   `@` + an "image" keyword (any language) offers "Add image" (see
///   [showMarkdownImagePicker]), which inserts `![alt](dmt-img:…)`. While the
///   text holds embedded images the editor splits into text boxes and image
///   blocks (width slider + remove button); the stored text is unchanged.
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

class _MarkdownTextAreaState extends ConsumerState<MarkdownTextArea>
    with WidgetsBindingObserver {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  // Mention state
  OverlayEntry? _mentionOverlay;
  String _mentionQuery = '';
  int _mentionStart = -1;
  List<Entity> _filteredEntities = [];
  int _selectedIndex = 0;
  // `@resim` → listenin başında "Resim ekle" satırı.
  bool _imageOption = false;

  static final List<String> _imageKeywords = {
    for (final l in L10n.supportedLocales)
      lookupL10n(l).markdownImageKeyword.toLowerCase(),
  }.toList();

  int get _itemCount => _filteredEntities.length + (_imageOption ? 1 : 0);

  // Blok modu: metinde gömülü resim varsa edit alanı metin kutuları ve resim
  // bloklarına bölünür — TextField içinde widget göstermek imleç/seçim
  // ofsetlerini bozar. null = tek TextField. Kaydedilen metin değişmez.
  List<Object>? _blocks; // _TextBlock | MarkdownImageBlock
  String _composed = '';
  // Mention'ın çalıştığı alan: blok modunda en son yazılan metin bloğu.
  _TextBlock? _active;
  TextEditingController get _ctrl => _active?.ctrl ?? widget.controller;

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
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    // Keyboard yükselir/iner; mention overlay açıksa pozisyonu yeniden hesapla.
    if (_mentionOverlay != null) _mentionOverlay!.markNeedsBuild();
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
    if (widget.controller != old.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissMentionOverlay();
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onControllerChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    for (final b in _blocks ?? const []) {
      if (b is _TextBlock) b.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _dismissMentionOverlay();
    // Blok modunda çerçevenin odak rengi.
    if (_blocks != null) setState(() {});
  }

  // --------------- blocks ---------------

  /// Dış metin değişti (yazma, kartın senkronu) — build'de yeniden bölünür.
  void _onControllerChanged() {
    if (widget.controller.text == _composed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// Dış metin [_composed]'dan farklıysa (ya da [force]) blokları yeniden
  /// kurar. Eski controller'lar bir sonraki karede atılır — o ana kadar
  /// TextField'ları hâlâ ağaçta.
  void _syncBlocks({bool force = false}) {
    final text = widget.controller.text;
    if (!force && text == _composed) return;
    _composed = text;
    final old = _blocks;
    final segs = splitMarkdownImages(text);
    _active = null;
    _blocks = segs.length == 1
        ? null
        : [for (final s in segs) s is String ? _TextBlock(s) : s];
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final b in old) {
          if (b is _TextBlock) b.dispose();
        }
      });
    }
  }

  void _onBlockChanged(_TextBlock b) {
    _active = b;
    _commitBlocks();
    _checkMention(b.ctrl.text);
  }

  /// Blokları birleştirip dış controller'a yazar ve kaydettirir.
  void _commitBlocks() {
    final text = joinMarkdownImages([
      for (final b in _blocks!) b is _TextBlock ? b.ctrl.text : b,
    ]);
    _composed = text;
    widget.controller.text = text;
    widget.onChanged?.call(text);
  }

  void _setBlockWidth(int i, int width) {
    final b = _blocks![i] as MarkdownImageBlock;
    setState(() => _blocks![i] = (ref: b.ref, alt: b.alt, width: width));
    _commitBlocks();
  }

  /// Resmi siler; komşu metin blokları birleşsin diye yeniden kurar.
  void _removeBlock(int i) {
    _dismissMentionOverlay();
    _blocks!.removeAt(i);
    _commitBlocks();
    setState(() => _syncBlocks(force: true));
  }

  // --------------- @mention logic ---------------

  void _dismissMentionOverlay() {
    if (_mentionOverlay != null) {
      HardwareKeyboard.instance.removeHandler(_mentionKeyHandler);
      _mentionOverlay?.remove();
      _mentionOverlay = null;
      _filteredEntities = [];
      _selectedIndex = 0;
      _imageOption = false;
    }
  }

  void _onTextChanged(String text) {
    _active = null;
    widget.onChanged?.call(text);
    _checkMention(text);
  }

  void _checkMention(String text) {
    final cursorPos = _ctrl.selection.baseOffset;
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
    // Her dilin anahtar kelimesi (image/resim/bild) eşleşir; etiket o anki
    // arayüz dilinde.
    _imageOption = _imageKeywords.any((k) => k.startsWith(_mentionQuery));
    _filteredEntities = ref
        .read(entityProvider)
        .values
        .where((e) => e.name.toLowerCase().contains(_mentionQuery))
        .take(8)
        .toList();
    if (_itemCount == 0) {
      _dismissMentionOverlay();
      return;
    }
    _selectedIndex = _selectedIndex.clamp(0, _itemCount - 1);

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
        // Recalculate position on each build (accounts for scroll/resize/IME).
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.attached) {
          return const SizedBox.shrink();
        }
        final widgetPos = renderBox.localToGlobal(Offset.zero);
        final mq = MediaQuery.of(context);
        final keyboardHeight = mq.viewInsets.bottom;
        final usableHeight = mq.size.height - keyboardHeight;
        final isNarrow = mq.size.width < 600;

        // Width: dar mobil portrait'te 320'i ekrana sığdır.
        final overlayWidth = (mq.size.width - 16).clamp(40.0, 320.0).toDouble();
        const overlayMaxHeight = 200.0;
        final left = widgetPos.dx.clamp(0.0, mq.size.width - overlayWidth).toDouble();
        var top = widgetPos.dy + renderBox.size.height + 4;
        // Mobilde her zaman cursor'un üstüne aç (keyboard collision kesin
        // önlem); wide ekranda below-first ama keyboard'a girerse yukarı al.
        if (isNarrow || top + overlayMaxHeight > usableHeight) {
          top = widgetPos.dy - overlayMaxHeight - 4;
        }
        // Üst clamp — status bar / notch güvenliği.
        final maxTop = usableHeight - overlayMaxHeight;
        final minTop = mq.padding.top + 4;
        if (maxTop > minTop) {
          top = top.clamp(minTop, maxTop);
        } else {
          top = minTop;
        }

        final palette = Theme.of(context).extension<DmToolColors>();
        final items = _filteredEntities;
        final selIdx = _selectedIndex;
        final offset = _imageOption ? 1 : 0;
        final accent = palette?.featureCardAccent ?? Colors.blue;

        return Positioned(
          left: left,
          top: top,
          width: overlayWidth,
          child: Material(
            elevation: 8,
            borderRadius: palette?.cbr ?? BorderRadius.circular(4),
            color: palette?.canvasBg ?? Colors.grey[900],
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: overlayMaxHeight),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: items.length + offset,
                itemBuilder: (_, i) {
                  final isSelected = i == selIdx;
                  // Seçili satır rengi ListTile'ın kendisinde: Container
                  // rengi ListTile'ın mürekkebini örter (debug assertion).
                  final selectedColor = accent.withValues(alpha: 0.2);
                  if (i < offset) {
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: selectedColor,
                      leading: Icon(Icons.add_photo_alternate_outlined,
                          size: 18, color: palette?.tabActiveText),
                      title: Text(
                        L10n.of(context)!.markdownAddImage,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette?.tabActiveText,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      onTap: _pickImage,
                    );
                  }
                  final entity = items[i - offset];
                  return ListTile(
                    key: ValueKey(entity.id),
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: selectedColor,
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
    if (_mentionOverlay == null || _itemCount == 0) return false;
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _selectedIndex = (_selectedIndex + 1) % _itemCount;
      _mentionOverlay?.markNeedsBuild();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _selectedIndex = (_selectedIndex - 1 + _itemCount) % _itemCount;
      _mentionOverlay?.markNeedsBuild();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (_imageOption && _selectedIndex == 0) {
        _pickImage();
      } else {
        final entity =
            _filteredEntities[_selectedIndex - (_imageOption ? 1 : 0)];
        _insertMention(entity.id, entity.name);
      }
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
    _replaceQuery(_mentionStart, _ctrl.selection.baseOffset,
        '@[$entityName](entity:$entityId)');
  }

  /// Dialog açılınca odak kaybolur ve overlay kapanır; `@sorgu` aralığı
  /// önceden alınır.
  Future<void> _pickImage() async {
    final start = _mentionStart;
    final end = _ctrl.selection.baseOffset;
    _dismissMentionOverlay();
    final picked = await showMarkdownImagePicker(context);
    if (!mounted) return;
    if (picked == null) {
      (_active?.focus ?? _focusNode).requestFocus();
      return;
    }
    // Resim kendi satırında dursun.
    final text = _ctrl.text;
    final before = start > 0 && text[start - 1] != '\n' ? '\n' : '';
    final after = end < text.length && text[end] == '\n' ? '' : '\n';
    _replaceQuery(
        start, end, '$before${markdownImage(picked.$1, picked.$2)}$after');
  }

  /// `@sorgu`yu ([start]..[end]) [insert] ile değiştirir.
  void _replaceQuery(int start, int end, String insert) {
    final c = _ctrl;
    final text = c.text;
    end = end.clamp(start, text.length);
    final newText = text.substring(0, start) + insert + text.substring(end);
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    final block = _active;
    if (block == null) {
      widget.onChanged?.call(newText);
      // Refocus text field
      _focusNode.requestFocus();
      return;
    }
    _commitBlocks();
    if (insert.contains(markdownImageScheme)) {
      setState(() => _syncBlocks(force: true)); // yeni resim bloğu
    } else {
      block.focus.requestFocus();
    }
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
    // When a caller supplies textStyle (e.g. entity cards use srdInk), derive
    // heading/bullet colors from it so markdown subsections match the card
    // palette instead of falling back to the global html* colors.
    final baseColor = widget.textStyle?.color;
    return MarkdownStyleSheet(
      p: widget.textStyle ?? TextStyle(fontSize: 13, color: palette?.htmlText),
      h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: baseColor ?? palette?.htmlHeader),
      h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: baseColor ?? palette?.htmlHeader),
      h3: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: baseColor ?? palette?.htmlHeader),
      code: TextStyle(fontSize: 12, backgroundColor: palette?.htmlCodeBg),
      a: TextStyle(color: palette?.htmlLink),
      listBullet: TextStyle(fontSize: 13, color: baseColor ?? palette?.htmlText),
    ).withDmBlockquote(context);
  }

  // --------------- build ---------------

  @override
  Widget build(BuildContext context) {
    _syncBlocks();
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
      // Enter in the editor means a new line; don't fold it into a space.
      softLineBreak: true,
      // Touch devices: selection gestures swallow vertical drag → no scroll.
      selectable: !isTouchPlatform,
      styleSheet: widget.markdownStyleSheet ?? _defaultStyleSheet(palette),
      imageBuilder: (uri, title, alt) =>
          MarkdownEmbeddedImage(uri: uri, width: markdownImageWidth(title)),
      onTapLink: (text, href, title) async {
        if (href == null) return;
        if (href.startsWith('entity:')) {
          final entityId = href.substring('entity:'.length);
          _handleEntityLink(entityId);
        } else {
          final uri = Uri.tryParse(href);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }

  InputDecoration get _decoration =>
      widget.decoration ??
      InputDecoration(
        hintText: L10n.of(context)!.markdownMentionHintAlt,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  Widget _buildEditField() {
    final blocks = _blocks;
    if (blocks != null) return _buildBlockEditor(blocks);
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      maxLines: widget.expands ? null : widget.maxLines,
      minLines: widget.expands ? null : widget.minLines,
      expands: widget.expands,
      textAlignVertical: widget.textAlignVertical,
      style: widget.textStyle,
      decoration: _decoration,
      onChanged: _onTextChanged,
      onSubmitted: widget.onSubmitted,
    );
  }

  /// Dış [_focusNode] blokları saran `Focus`'a bağlanır: bir metin bloğu
  /// odaktayken de `hasFocus` true kalır (kart senkronu yazılanı ezmesin).
  Widget _buildBlockEditor(List<Object> blocks) {
    final palette = Theme.of(context).extension<DmToolColors>();
    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, b) in blocks.indexed)
          if (b is _TextBlock)
            TextField(
              key: ObjectKey(b),
              controller: b.ctrl,
              focusNode: b.focus,
              maxLines: null,
              style: widget.textStyle,
              decoration: const InputDecoration.collapsed(hintText: null),
              onChanged: (_) => _onBlockChanged(b),
              onSubmitted: widget.onSubmitted,
            )
          else
            _buildImageBlock(i, b as MarkdownImageBlock, palette),
      ],
    );
    if (widget.expands) body = SingleChildScrollView(child: body);
    return Focus(
      focusNode: _focusNode,
      skipTraversal: true,
      child: InputDecorator(
        decoration: _decoration,
        isFocused: _focusNode.hasFocus,
        expands: widget.expands,
        child: body,
      ),
    );
  }

  Widget _buildImageBlock(int i, MarkdownImageBlock b, DmToolColors? palette) =>
      _ImageBlockEditor(
        block: b,
        palette: palette,
        onWidth: (w) => _setBlockWidth(i, w),
        onRemove: () => _removeBlock(i),
      );
}

/// Edit modundaki resim bloğu. Sürükleme sırasında genişlik yalnız burada
/// tutulur — her adımda metni birleştirip kaydetmek ve bütün alanı yeniden
/// kurmak yerine; bırakınca [onWidth] bir kez çağrılır.
class _ImageBlockEditor extends StatefulWidget {
  const _ImageBlockEditor({
    required this.block,
    required this.palette,
    required this.onWidth,
    required this.onRemove,
  });

  final MarkdownImageBlock block;
  final DmToolColors? palette;
  final ValueChanged<int> onWidth;
  final VoidCallback onRemove;

  @override
  State<_ImageBlockEditor> createState() => _ImageBlockEditorState();
}

class _ImageBlockEditorState extends State<_ImageBlockEditor> {
  int? _drag;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final width = _drag ?? widget.block.width;
    final shown = width ?? 100;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownEmbeddedImage(
          uri: markdownImageUri(widget.block.ref),
          width: width,
          action: Material(
            color: (palette?.canvasBg ?? Colors.black).withValues(alpha: 0.8),
            shape: const CircleBorder(),
            child: IconButton(
              icon: Icon(Icons.close, size: 16, color: palette?.tabActiveText),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              onPressed: widget.onRemove,
            ),
          ),
        ),
        Row(
          children: [
            Icon(Icons.photo_size_select_large,
                size: 16, color: palette?.sidebarLabelSecondary),
            Expanded(
              child: Slider(
                value: shown.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                label: '$shown%',
                onChanged: (v) => setState(() => _drag = v.round()),
                onChangeEnd: (v) {
                  _drag = null;
                  widget.onWidth(v.round());
                },
              ),
            ),
            Text('$shown%',
                style: TextStyle(
                    fontSize: 12, color: palette?.sidebarLabelSecondary)),
          ],
        ),
      ],
    );
  }
}

class _TextBlock {
  _TextBlock(String text) : ctrl = TextEditingController(text: text);

  final TextEditingController ctrl;
  final FocusNode focus = FocusNode();

  void dispose() {
    ctrl.dispose();
    focus.dispose();
  }
}

/// Markdown resimlerini çizer: `dmt-img:` gömülüleri [AssetRefImage] ile
/// (yerel yol / `dmt-*://` ref), http(s) olanları ağdan; diğerlerini göstermez.
///
/// Resim satırın tamamını kaplayan bir blok olur (yanına yazı gelmez, alta
/// geçer), üstte/altta boşlukla. [width] satır genişliğinin yüzdesi; null ise
/// doğal boyut, en fazla [maxHeight] yükseklik. [action] resmin sağ üst
/// köşesine konur (edit modunda silme düğmesi).
class MarkdownEmbeddedImage extends StatelessWidget {
  const MarkdownEmbeddedImage(
      {required this.uri, this.width, this.action, super.key});

  final Uri uri;
  final int? width;
  final Widget? action;

  static const double maxHeight = 320;

  @override
  Widget build(BuildContext context) {
    const broken = Icon(Icons.broken_image_outlined);
    final raw = uri.toString();
    Widget image;
    if (raw.startsWith(markdownImageScheme)) {
      final ref =
          decodeMarkdownImageRef(raw.substring(markdownImageScheme.length));
      if (ref == null) return broken;
      image = AssetRefImage(
        ref: AssetRef(ref),
        fit: BoxFit.contain,
        // Decode boyutu [width]'ten bağımsız: boyut barı sürüklenirken resim
        // yeniden decode edilmez (her adımda boşa düşüp geri gelirdi) ve
        // okuma/edit modu aynı cache girdisini paylaşır. Küçük resim büyütülmez.
        cacheWidth:
            cachePxFromLogical(context, MediaQuery.sizeOf(context).width),
        placeholder: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: broken,
      );
    } else if (uri.isScheme('http') || uri.isScheme('https')) {
      image = Image.network(raw,
          fit: BoxFit.contain, errorBuilder: (_, _, _) => broken);
    } else {
      return const SizedBox.shrink();
    }
    image = ClipRRect(
      borderRadius:
          Theme.of(context).extension<DmToolColors>()?.cbr ?? BorderRadius.zero,
      child: image,
    );
    if (action case final action?) {
      // En küçük boyut: küçük/bozuk resimde düğme Stack'ten taşar ve
      // dokunuş ona ulaşmaz.
      image = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        child: Stack(
          children: [image, Positioned(top: 4, right: 4, child: action)],
        ),
      );
    }
    // Ağaç [width] null olsa da aynı kalır; yoksa ilk sürüklemede resim
    // state'i baştan kurulup yeniden yüklenir.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Align(
          alignment: Alignment.center,
          child: FractionallySizedBox(
            widthFactor: width == null ? null : width! / 100,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: width == null ? maxHeight : double.infinity),
              child: image,
            ),
          ),
        ),
      ),
    );
  }
}
