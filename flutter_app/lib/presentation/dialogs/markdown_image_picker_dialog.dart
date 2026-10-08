import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../application/providers/entity_provider.dart';
import '../../application/services/entity_image_upload.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/services/entity_search.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/asset_ref_image.dart';
import '../widgets/perf/image_cache_size.dart';
import '../widgets/srd_text.dart';

/// Markdown alanına `@resim` ile eklenecek resmi seçtirir: bir kartın herhangi
/// bir resim alanından (portre galerisi, başlık resmi, şemadaki image /
/// imagePerEra alanları — harita vb.) ya da cihazdan.
///
/// Döndürülen: `(ref, alt)`; vazgeçilirse null.
Future<(String, String)?> showMarkdownImagePicker(BuildContext context) =>
    showDialog<(String, String)>(
      context: context,
      builder: (_) => const _MarkdownImagePickerDialog(),
    );

/// [e]'nin tüm resim ref'leri, tekrarsız.
List<String> entityImageRefs(Entity e, EntityCategorySchema? cat) {
  final out = <String>{};
  void add(Object? v) {
    if (v is String) {
      if (v.isNotEmpty) out.add(v);
    } else if (v is List) {
      v.forEach(add);
    } else if (v is Map) {
      v.values.forEach(add);
    }
  }

  add(e.images);
  add(e.imagePath);
  for (final f in cat?.fields ?? const <FieldSchema>[]) {
    if (f.fieldType == FieldType.image ||
        f.fieldType == FieldType.imagePerEra) {
      add(e.fields[f.fieldKey]);
    }
  }
  return out.toList();
}

class _MarkdownImagePickerDialog extends ConsumerStatefulWidget {
  const _MarkdownImagePickerDialog();

  @override
  ConsumerState<_MarkdownImagePickerDialog> createState() =>
      _MarkdownImagePickerDialogState();
}

class _MarkdownImagePickerDialogState
    extends ConsumerState<_MarkdownImagePickerDialog> {
  String _search = '';
  Entity? _selected;

  late final Map<String, EntityCategorySchema> _cats = {
    for (final c in ref.read(worldSchemaProvider).categories) c.slug: c,
  };

  /// Resmi olan kartlar ve resimleri — dialog açılışında bir kez.
  late final List<(Entity, List<String>)> _cards = _buildCards();

  List<(Entity, List<String>)> _buildCards() {
    final cats = _cats;
    final out = <(Entity, List<String>)>[
      for (final e in ref.read(entityProvider).values)
        if (entityImageRefs(e, cats[e.categorySlug]) case final refs
            when refs.isNotEmpty)
          (e, refs),
    ];
    out.sort((a, b) => a.$1.name.compareTo(b.$1.name));
    return out;
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;
    final refs = await localizeEntityImages(ref, [path]);
    if (!mounted || refs.isEmpty) return;
    Navigator.of(context).pop((refs.first, p.basenameWithoutExtension(path)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final selected = _selected;
    return AlertDialog(
      title: Text(l10n.markdownImagePickerTitle,
          style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 520,
        height: 420,
        child: selected == null
            ? _buildCardList(l10n, palette)
            : _buildGrid(selected, palette),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.upload_file, size: 18),
          label: Text(l10n.markdownImageUpload),
          onPressed: _upload,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.btnCancel),
        ),
      ],
    );
  }

  Widget _buildCardList(L10n l10n, DmToolColors palette) {
    final q = searchFold(_search.trim());
    final cards = q.isEmpty
        ? _cards
        : [
            for (final c in _cards)
              if (searchFold(srdName(context, c.$1)).contains(q)) c,
          ];
    return Column(
      children: [
        TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Text(l10n.markdownImageNoCards,
                      style: TextStyle(color: palette.sidebarLabelSecondary)))
              : ListView.builder(
                  itemCount: cards.length,
                  itemBuilder: (_, i) {
                    final e = cards[i].$1;
                    final category = _cats[e.categorySlug]?.name ?? e.categorySlug;
                    return ListTile(
                      key: ValueKey(e.id),
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
                      title: Text(srdName(context, e),
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        e.source.isEmpty ? category : '$category · ${e.source}',
                        style: TextStyle(
                            fontSize: 10, color: palette.sidebarLabelSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => setState(() => _selected = e),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGrid(Entity e, DmToolColors palette) {
    final refs = _cards.firstWhere((c) => c.$1.id == e.id).$2;
    final broken =
        Icon(Icons.broken_image_outlined, color: palette.sidebarLabelSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => setState(() => _selected = null),
          ),
          title: Text(srdName(context, e), style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: refs.length,
            itemBuilder: (_, i) => Material(
              color: palette.featureCardBg,
              shape: RoundedRectangleBorder(
                borderRadius: palette.cbr,
                side: BorderSide(color: palette.featureCardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).pop((refs[i], e.name)),
                // Sabit kutu şart: AssetRefImage'ın yükleniyor placeholder'ı
                // `Center` ve boyut almazsa ebeveynine yayılıyor.
                child: SizedBox.expand(
                  child: AssetRefImage(
                    ref: AssetRef(refs[i]),
                    fit: BoxFit.cover,
                    cacheWidth: cachePxFromLogical(context, 140),
                    errorWidget: Center(child: broken),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
