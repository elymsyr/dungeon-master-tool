import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../application/services/builtin_srd_entities.dart';
import '../../domain/entities/entity.dart';
import '../../domain/services/entity_search.dart';
import '../theme/dm_tool_colors.dart';
import 'entity_preview_dialog.dart';
import '../l10n/app_localizations.dart';
import '../widgets/srd_text.dart';
import '../../application/providers/content_translator_provider.dart';

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
/// [contextFields]: field values of the card being edited. Its class /
///   species / background refs pick the rows shown under "Suggested" and
///   boosted in search (see `suggestedEntityIds`).
Future<List<String>?> showEntitySelectorDialog({
  required BuildContext context,
  required WidgetRef ref,
  List<String>? allowedTypes,
  bool multiSelect = false,
  List<String> excludeIds = const [],
  bool includeBuiltinSrd = false,
  List<Entity> extraEntities = const [],
  Map<String, dynamic>? contextFields,
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
      contextFields: contextFields,
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
  final Map<String, dynamic>? contextFields;

  const _EntitySelectorDialog({
    required this.ref,
    this.allowedTypes,
    this.multiSelect = false,
    this.excludeIds = const [],
    this.includeBuiltinSrd = false,
    this.extraEntities = const [],
    this.contextFields,
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

  /// Bağlama uyan satırlar — dialog açılışında bir kez hesaplanır.
  late final Set<String> _suggested = widget.contextFields == null
      ? const {}
      : suggestedEntityIds(_baseList, widget.contextFields!, _previewEntities);
  late final EntityRanking _ranking = EntityRanking(_baseList,
      suggested: _suggested,
      shownNames: {
        for (final e in _baseList)
          if (_shown(e) != e.name) e.id: searchFold(_shown(e)),
      });

  /// SRD içerik çevirisi: satırın gösterilen adı (arama iki dilde eşleşir).
  String _shown(Entity e) => srdName(context, e);
  late final List<Entity> _suggestedList = [
    for (final e in _baseList)
      if (_suggested.contains(e.id)) e,
  ];

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
    final shown = {for (final e in out) e.id: srdName(context, e)};
    out.sort((a, b) => shown[a.id]!.compareTo(shown[b.id]!));
    return List<Entity>.unmodifiable(out);
  }

  /// Ref'leri çözebilmek için önizlemeye verilen harita. Uzun basmadan önce
  /// kurulmaz: bundled SRD ~7K satır, her dialog açılışında birleştirmeye değmez.
  Map<String, Entity>? _previewEntitiesCache;
  Map<String, Entity> get _previewEntities =>
      _previewEntitiesCache ??= {
        ...widget.ref.read(entityProvider),
        if (widget.includeBuiltinSrd)
          ...widget.ref.read(builtinSrdEntitiesProvider),
        for (final e in widget.extraEntities) e.id: e,
      };

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // F4: base list pre-filtered once; only ranking runs per keystroke.
    // Boş aramada öneriler ayrı bölüm (sonra Tümü); arama varken sıralamada
    // öne çıkar. Satır: String = bölüm başlığı, Entity = kayıt.
    final List<Object> rows;
    if (_search.trim().isNotEmpty) {
      rows = _ranking.rank(_search);
    } else if (_suggestedList.isEmpty) {
      rows = _baseList;
    } else {
      final l10n = L10n.of(context)!;
      rows = [
        '${l10n.entitySelectorSuggested} (${_suggestedList.length})',
        ..._suggestedList,
        l10n.filterAll,
        ..._baseList,
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
              autofocus: true,
              decoration: InputDecoration(
                hintText: L10n.of(context)!.searchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
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
              onSubmitted: widget.multiSelect && _selected.isNotEmpty
                  ? (_) => Navigator.pop(context, _selected.toList())
                  : null,
            ),
            const SizedBox(height: 8),
            // Liste
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text(L10n.of(context)!.entitySelectorEmpty, style: TextStyle(color: palette.sidebarLabelSecondary)))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        if (row is String) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: Text(row,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: palette.sidebarLabelSecondary)),
                          );
                        }
                        final entity = row as Entity;
                        final isSelected = _selected.contains(entity.id);

                        // Önerilen bölümündeki satır Tümü'nde tekrar eder —
                        // key indeksle ayrışır.
                        return ListTile(
                          key: ValueKey('$i:${entity.id}'),
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: palette.tabIndicator.withValues(alpha: 0.1),
                          leading: _suggested.contains(entity.id)
                              ? Icon(Icons.auto_awesome, size: 12, color: palette.tabIndicator)
                              : Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: palette.tabText, shape: BoxShape.circle),
                                ),
                          title: Text(srdName(context, entity), style: const TextStyle(fontSize: 13)),
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
                          onLongPress: () => showEntityPreview(
                            context,
                            entity,
                            entities: _previewEntities,
                          ),
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context)!.btnCancel)),
        if (widget.multiSelect)
          FilledButton(
            onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
            child: Text(L10n.of(context)!.sessionAddWithQuantity(_selected.length)),
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
    (String, String)? key(Map<String, Entity> m) {
      final e = m[entityId];
      return e == null ? null : (e.categorySlug, e.name);
    }

    final hit = ref.watch(entityProvider.select(key)) ??
        // Fallback: char-sheet relation fields may reference bundled SRD rows
        // (e.g. picked Longsword) that never land in entityProvider. Resolve
        // those via the in-memory SRD map instead of rendering a raw UUID.
        ref.watch(builtinSrdEntitiesProvider.select(key));
    // SRD içerik çevirisi — yalnızca görüntü.
    final tx = ref.watch(contentTranslatorProvider);
    return Text(
      hit == null ? entityId : tx.tr(hit.$1, hit.$2),
      style: style,
      overflow: TextOverflow.ellipsis,
    );
  }
}
