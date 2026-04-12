import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Theme oluşturma dialog'u — PyQt ThemeBuilderDialog portu.
/// Sol: state listesi + ekle/sil, Sağ: seçili state'in track dosya seçicileri.
class ThemeBuilderDialog extends StatefulWidget {
  final DmToolColors palette;

  const ThemeBuilderDialog({super.key, required this.palette});

  /// Dialog'u açar. null dönerse iptal edilmiştir.
  static Future<ThemeBuilderResult?> show(BuildContext context, DmToolColors palette) {
    return showDialog<ThemeBuilderResult>(
      context: context,
      builder: (_) => ThemeBuilderDialog(palette: palette),
    );
  }

  @override
  State<ThemeBuilderDialog> createState() => _ThemeBuilderDialogState();
}

class ThemeBuilderResult {
  final String name;
  final String id;
  final Map<String, Map<String, String>> stateMap; // {stateName: {trackKey: filePath}}

  ThemeBuilderResult({required this.name, required this.id, required this.stateMap});
}

class _ThemeBuilderDialogState extends State<ThemeBuilderDialog> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  bool _autoId = true;

  // States: ordered list of state names
  final List<String> _states = ['normal'];
  int _selectedStateIndex = 0;

  // Track files: {stateName: {trackKey: filePath}}
  final Map<String, Map<String, String>> _trackFiles = {
    'normal': {},
  };

  static const _trackKeys = ['base', 'level1', 'level2', 'level3'];

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return AlertDialog(
      title: const Text('Create Theme'),
      content: SizedBox(
        width: 700,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + ID
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Theme Name',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onChanged: (v) {
                      if (_autoId) _idController.text = _slugify(v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: 'ID',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onChanged: (_) => _autoId = false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // States + Tracks
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: State list
                  SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('States', style: TextStyle(fontWeight: FontWeight.w600, color: palette.tabActiveText)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: palette.sidebarDivider),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.builder(
                              itemCount: _states.length,
                              itemBuilder: (_, i) {
                                final isSelected = i == _selectedStateIndex;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: palette.featureCardAccent.withValues(alpha: 0.15),
                                  title: Text(
                                    _states[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected ? palette.featureCardAccent : palette.tabActiveText,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: _states.length > 1
                                      ? IconButton(
                                          icon: Icon(Icons.close, size: 16, color: palette.tokenBorderHostile),
                                          onPressed: () => _removeState(i),
                                        )
                                      : null,
                                  onTap: () => setState(() => _selectedStateIndex = i),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _addState,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add State', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right: Track file pickers
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tracks — ${_states[_selectedStateIndex]}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: palette.tabActiveText),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: _trackKeys.map((trackKey) {
                              final stateName = _states[_selectedStateIndex];
                              final filePath = _trackFiles[stateName]?[trackKey] ?? '';
                              final fileName = filePath.isEmpty ? '' : filePath.split('/').last.split('\\').last;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        trackKey,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: trackKey == 'base' ? palette.featureCardAccent : palette.tabText,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: palette.sidebarDivider),
                                          borderRadius: BorderRadius.circular(4),
                                          color: palette.tabBg,
                                        ),
                                        child: Text(
                                          fileName.isEmpty ? '—' : fileName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: fileName.isEmpty ? palette.tabText.withValues(alpha: 0.4) : palette.tabActiveText,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.folder_open, size: 18, color: palette.featureCardAccent),
                                      tooltip: 'Browse',
                                      onPressed: () => _pickFile(trackKey),
                                    ),
                                    if (filePath.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.clear, size: 18, color: palette.tokenBorderHostile),
                                        tooltip: 'Clear',
                                        onPressed: () => _clearFile(trackKey),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _canCreate ? _onCreate : null,
          child: const Text('Create'),
        ),
      ],
    );
  }

  bool get _canCreate {
    if (_nameController.text.trim().isEmpty) return false;
    if (_idController.text.trim().isEmpty) return false;
    // En az bir state'de en az base track olmalı
    return _trackFiles.values.any((tracks) => tracks['base']?.isNotEmpty == true);
  }

  void _addState() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add State'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'State Name (e.g. combat, victory)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toLowerCase()),
            child: const Text('Add'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
    if (name == null || name.isEmpty) return;
    final slug = _slugify(name);
    if (slug.isEmpty || _states.contains(slug)) return;

    setState(() {
      _states.add(slug);
      _trackFiles[slug] = {};
      _selectedStateIndex = _states.length - 1;
    });
  }

  void _removeState(int index) {
    setState(() {
      final removed = _states.removeAt(index);
      _trackFiles.remove(removed);
      if (_selectedStateIndex >= _states.length) {
        _selectedStateIndex = _states.length - 1;
      }
    });
  }

  Future<void> _pickFile(String trackKey) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'ogg', 'flac', 'm4a'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;

    setState(() {
      final stateName = _states[_selectedStateIndex];
      _trackFiles.putIfAbsent(stateName, () => {});
      _trackFiles[stateName]![trackKey] = result.files.first.path!;
    });
  }

  void _clearFile(String trackKey) {
    setState(() {
      final stateName = _states[_selectedStateIndex];
      _trackFiles[stateName]?.remove(trackKey);
    });
  }

  void _onCreate() {
    // Boş state'leri filtrele
    final filteredMap = <String, Map<String, String>>{};
    for (final entry in _trackFiles.entries) {
      final nonEmpty = Map<String, String>.fromEntries(
        entry.value.entries.where((e) => e.value.isNotEmpty),
      );
      if (nonEmpty.isNotEmpty) filteredMap[entry.key] = nonEmpty;
    }

    Navigator.pop(
      context,
      ThemeBuilderResult(
        name: _nameController.text.trim(),
        id: _idController.text.trim(),
        stateMap: filteredMap,
      ),
    );
  }
}
