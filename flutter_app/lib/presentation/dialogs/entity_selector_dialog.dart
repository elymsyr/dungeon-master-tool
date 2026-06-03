import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../application/services/builtin_srd_entities.dart';
import '../../domain/entities/entity.dart';
import '../theme/dm_tool_colors.dart';

/// Entity seçici dialog — relation field'larda kullanılır.
/// [allowedTypes]: sadece bu kategorideki entity'ler gösterilir (null=tümü).
/// [multiSelect]: true ise birden fazla seçim, false ise tek seçim.
/// [includeBuiltinSrd]: true ise bundled SRD 5.2.1 Core rows (longsword vb.)
///   campaign entity map'ine eklenir. Karakter sayfası relation field'larında
///   true geçilmeli; map/session/mindmap picker'ları default false bırakır
///   (yoksa ~7K SRD satırı liste'ye düşer).
/// Döndürülen: seçilen entity ID'leri listesi.
/// [extraEntities]: additional source rows merged on top of the campaign +
///   bundled SRD maps, deduped by (slug, name). Character-sheet pickers pass
///   the character's standalone-package entities here so options picked from
///   official packages at creation remain addable post-creation.
Future<List<String>?> showEntitySelectorDialog({
  required BuildContext context,
  required WidgetRef ref,
  List<String>? allowedTypes,
  bool multiSelect = false,
  List<String> excludeIds = const [],
  bool includeBuiltinSrd = false,
  List<Entity> extraEntities = const [],
}) async {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _EntitySelectorDialog(
      ref: ref,
      allowedTypes: allowedTypes,
      multiSelect: multiSelect,
      excludeIds: excludeIds,
      includeBuiltinSrd: includeBuiltinSrd,
      extraEntities: extraEntities,
    ),
  );
}

class _EntitySelectorDialog extends StatefulWidget {
  final WidgetRef ref;
  final List<String>? allowedTypes;
  final bool multiSelect;
  final List<String> excludeIds;
  final bool includeBuiltinSrd;
  final List<Entity> extraEntities;

  const _EntitySelectorDialog({
    required this.ref,
    this.allowedTypes,
    this.multiSelect = false,
    this.excludeIds = const [],
    this.includeBuiltinSrd = false,
    this.extraEntities = const [],
  });

  @override
  State<_EntitySelectorDialog> createState() => _EntitySelectorDialogState();
}

class _EntitySelectorDialogState extends State<_EntitySelectorDialog> {
  String _search = '';
  final Set<String> _selected = {};
  Timer? _searchDebounce;

  // F4: pre-converted Set lookups + sorted base list. The base list
  // (entities filtered by excludeIds + allowedTypes) only changes when
  // the dialog opens; only the search predicate runs per-keystroke.
  late final Set<String> _excludeSet = widget.excludeIds.toSet();
  late final Set<String>? _allowedSet = widget.allowedTypes?.toSet();
  late final List<Entity> _baseList = _buildBaseList();

  List<Entity> _buildBaseList() {
    final out = <Entity>[];
    final seenKeys = <String>{}; // (slug::name) — collapse cross-source dupes
    void consider(Iterable<Entity> src, {required bool dedupe}) {
      for (final e in src) {
        if (_excludeSet.contains(e.id)) continue;
        if (_allowedSet != null && !_allowedSet.contains(e.categorySlug)) {
          continue;
        }
        final key = '${e.categorySlug}::${e.name.toLowerCase()}';
        if (dedupe && seenKeys.contains(key)) continue;
        out.add(e);
        seenKeys.add(key);
      }
    }

    // Campaign first (authored content wins), then bundled SRD, then the
    // character's standalone packages — each deduped against what came before.
    consider(widget.ref.read(entityProvider).values, dedupe: false);
    if (widget.includeBuiltinSrd) {
      consider(widget.ref.read(builtinSrdEntitiesProvider).values,
          dedupe: true);
    }
    consider(widget.extraEntities, dedupe: true);
    out.sort((a, b) => a.name.compareTo(b.name));
    return List<Entity>.unmodifiable(out);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // F4: search filter only — base list pre-filtered once in initState.
    // Lowercase the query once instead of per item.
    final List<Entity> filtered;
    if (_search.isEmpty) {
      filtered = _baseList;
    } else {
      final q = _search.toLowerCase();
      filtered = [
        for (final e in _baseList)
          if (e.name.toLowerCase().contains(q)) e,
      ];
    }

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
            // Arama — F4: 150 ms debounce before re-running the filter.
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce =
                    Timer(const Duration(milliseconds: 150), () {
                  if (!mounted) return;
                  setState(() => _search = v);
                });
              },
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
                          subtitle: Text(
                            entity.source.isEmpty
                                ? entity.categorySlug
                                : '${entity.categorySlug} · ${entity.source}',
                            style: TextStyle(
                                fontSize: 10,
                                color: palette.sidebarLabelSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
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
    // F2: scoped to the one entity's name. Avoids full-map watch — the
    // text only rebuilds when this specific entity's name flips.
    final name = ref.watch(entityProvider.select((m) => m[entityId]?.name));
    // Fallback: char-sheet relation fields may reference bundled SRD rows
    // (e.g. picked Longsword) that never land in entityProvider. Resolve
    // those via the in-memory SRD map instead of rendering a raw UUID.
    final resolved = name ??
        ref.watch(
          builtinSrdEntitiesProvider.select((m) => m[entityId]?.name),
        );
    return Text(
      resolved ?? entityId,
      style: style,
      overflow: TextOverflow.ellipsis,
    );
  }
}
