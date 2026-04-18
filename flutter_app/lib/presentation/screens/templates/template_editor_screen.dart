import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/save_state_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../dialogs/bug_report_dialog.dart';
import '../../dialogs/import_package_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../theme/palettes.dart';
import '../../widgets/app_icon_image.dart';
import '../../widgets/close_guard.dart';
import '../../widgets/save_sync_indicator.dart';
import '../hub/template_editor.dart';

/// Fullscreen template editor — world açma flow'una eş chrome:
/// back butonu, Save, ileri/geri, tema/dil/bug report.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  final WorldSchema initial;
  final bool isNew;

  const TemplateEditorScreen({
    required this.initial,
    required this.isNew,
    super.key,
  });

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late WorldSchema _schema;
  final _undoStack = <WorldSchema>[];
  final _redoStack = <WorldSchema>[];
  bool _dirty = false;
  final _editorKey = GlobalKey<TemplateEditorState>();
  ActiveTemplateNotifier? _activeTpl;

  @override
  void initState() {
    super.initState();
    _schema = widget.initial;
    _dirty = widget.isNew;
    // SaveSyncIndicator/save_state_provider/cloud_sync_provider aktif
    // template'i dışarıdan okuyacak — ilk frame sonrasında açalım.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeTpl = ref.read(activeTemplateProvider.notifier);
      _activeTpl!.open(_schema);
    });
  }

  @override
  void dispose() {
    // ref post-dispose kullanılamaz; initState'te yakaladığımız notifier
    // üzerinden kapat.
    _activeTpl?.close();
    super.dispose();
  }

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  void _onSchemaChanged(WorldSchema updated) {
    _undoStack.add(_schema);
    if (_undoStack.length > 100) _undoStack.removeAt(0);
    _redoStack.clear();
    setState(() {
      _schema = updated;
      _dirty = true;
    });
    ref.read(activeTemplateProvider.notifier).update(updated);
    ref.read(saveStateProvider.notifier).markDirty();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final prev = _undoStack.removeLast();
    _redoStack.add(_schema);
    setState(() {
      _schema = prev;
      _dirty = true;
    });
    ref.read(activeTemplateProvider.notifier).update(prev);
    ref.read(saveStateProvider.notifier).markDirty();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(_schema);
    setState(() {
      _schema = next;
      _dirty = true;
    });
    ref.read(activeTemplateProvider.notifier).update(next);
    ref.read(saveStateProvider.notifier).markDirty();
  }

  Future<bool> _handleBack() async {
    if (!_dirty) return true;
    final ok = await confirmCloseUnconditional(
      context: context,
      title: 'Close template editor?',
    );
    return ok;
  }

  Future<void> _exit() async {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/hub');
    }
  }

  // Save + cloud sync — SaveSyncIndicator üzerinden yapılır; dialog'u
  // tetikleyen tek düğmeyi AppBar'da o widget sağlıyor.

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _handleBack();
        if (ok) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            tooltip: 'Back',
            onPressed: () async {
              final ok = await _handleBack();
              if (ok) _exit();
            },
          ),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const AppIconImage(size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _schema.name.isEmpty ? 'Template' : _schema.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (_dirty)
                Text('•', style: TextStyle(color: palette.tokenBorderActive, fontSize: 18)),
            ],
          ),
          actions: [
            // Undo / Redo
            IconButton(
              icon: const Icon(Icons.undo, size: 18),
              tooltip: 'Undo',
              onPressed: _canUndo ? _undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo, size: 18),
              tooltip: 'Redo',
              onPressed: _canRedo ? _redo : null,
            ),
            const SizedBox(width: 4),
            // Save & Sync — world editor ile aynı tek-düğme davranışı.
            const SaveSyncIndicator(),
            const SizedBox(width: 4),
            // Import Package
            IconButton(
              icon: const Icon(Icons.inventory_2, size: 20),
              tooltip: l10n.importPackage,
              onPressed: () => ImportPackageDialog.show(context),
            ),
            // Theme
            PopupMenuButton<String>(
              icon: const Icon(Icons.palette, size: 20),
              tooltip: l10n.lblTheme,
              onSelected: (name) => ref.read(themeProvider.notifier).setTheme(name),
              itemBuilder: (_) => themeNames
                  .map((name) => PopupMenuItem(
                        value: name,
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: themePalettes[name]?.canvasBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(name[0].toUpperCase() + name.substring(1)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            // Language
            PopupMenuButton<String>(
              icon: const Icon(Icons.language, size: 20),
              tooltip: l10n.lblLanguage,
              onSelected: (code) => ref.read(localeProvider.notifier).setLocale(code),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'en', child: Text('English')),
                PopupMenuItem(value: 'tr', child: Text('Türkçe')),
                PopupMenuItem(value: 'de', child: Text('Deutsch')),
                PopupMenuItem(value: 'fr', child: Text('Français')),
              ],
            ),
            // Bug report
            IconButton(
              icon: const Icon(Icons.bug_report_outlined, size: 20),
              tooltip: 'Report a Bug',
              onPressed: () => BugReportDialog.show(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: TemplateEditor(
          key: _editorKey,
          initial: _schema,
          hideHeader: true,
          onBack: () async {
            final ok = await _handleBack();
            if (ok) _exit();
          },
          onSchemaChanged: _onSchemaChanged,
        ),
      ),
    );
  }
}
