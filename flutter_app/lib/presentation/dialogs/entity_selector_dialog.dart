import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../theme/dm_tool_colors.dart';

/// Entity seçici dialog — relation field'larda kullanılır.
/// [allowedTypes]: sadece bu kategorideki entity'ler gösterilir (null=tümü).
/// [multiSelect]: true ise birden fazla seçim, false ise tek seçim.
/// Döndürülen: seçilen entity ID'leri listesi.
Future<List<String>?> showEntitySelectorDialog({
  required BuildContext context,
  required WidgetRef ref,
  List<String>? allowedTypes,
  bool multiSelect = false,
  List<String> excludeIds = const [],
}) async {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _EntitySelectorDialog(
      ref: ref,
      allowedTypes: allowedTypes,
      multiSelect: multiSelect,
      excludeIds: excludeIds,
    ),
  );
}

class _EntitySelectorDialog extends StatefulWidget {
  final WidgetRef ref;
  final List<String>? allowedTypes;
  final bool multiSelect;
  final List<String> excludeIds;

  const _EntitySelectorDialog({
    required this.ref,
    this.allowedTypes,
    this.multiSelect = false,
    this.excludeIds = const [],
  });

  @override
  State<_EntitySelectorDialog> createState() => _EntitySelectorDialogState();
}

class _EntitySelectorDialogState extends State<_EntitySelectorDialog> {
  String _search = '';
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final entities = widget.ref.read(entityProvider);

    // Filtrele
    final filtered = entities.values.where((e) {
      if (widget.excludeIds.contains(e.id)) return false;
      if (widget.allowedTypes != null && !widget.allowedTypes!.contains(e.categorySlug)) return false;
      if (_search.isNotEmpty && !e.name.toLowerCase().contains(_search.toLowerCase())) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return AlertDialog(
      title: Text(
        widget.multiSelect ? 'Select Entities' : 'Select Entity',
        style: const TextStyle(fontSize: 16),
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            // Arama
            TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            // Liste
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('No entities found', style: TextStyle(color: palette.sidebarLabelSecondary)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final entity = filtered[i];
                        final isSelected = _selected.contains(entity.id);

                        return ListTile(
                          key: ValueKey(entity.id),
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: palette.tabIndicator.withValues(alpha: 0.1),
                          leading: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: palette.tabText, shape: BoxShape.circle),
                          ),
                          title: Text(entity.name, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(entity.categorySlug, style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                          trailing: isSelected ? Icon(Icons.check, size: 16, color: palette.tabIndicator) : null,
                          onTap: () {
                            if (widget.multiSelect) {
                              setState(() {
                                if (isSelected) { _selected.remove(entity.id); }
                                else { _selected.add(entity.id); }
                              });
                            } else {
                              Navigator.pop(context, [entity.id]);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (widget.multiSelect)
          FilledButton(
            onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
            child: Text('Add (${_selected.length})'),
          ),
      ],
    );
  }
}

/// Entity ID'den adını çöz — ConsumerWidget olarak kullanılır.
class EntityNameText extends ConsumerWidget {
  final String entityId;
  final TextStyle? style;

  const EntityNameText(this.entityId, {this.style, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(entityProvider);
    final entity = entities[entityId];
    return Text(
      entity?.name ?? entityId,
      style: style,
      overflow: TextOverflow.ellipsis,
    );
  }
}
