import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/services/content_transfer/content_archive.dart';
import '../../application/services/content_transfer/content_codec.dart';
import '../../application/services/content_transfer/content_item.dart';
import '../l10n/app_localizations.dart';

/// `.dmtz` dışa/içe aktarma menüsü — hub'ın üç sekmesi de aynısını kullanır,
/// yalnız [type] değişir.
///
/// İçe aktarma seçili öğeden bağımsız: dosyanın manifest'i ne tür olduğunu
/// zaten söylüyor, bu yüzden hangi sekmeden açılırsa açılsın çalışır.
class ContentArchiveMenu extends ConsumerWidget {
  const ContentArchiveMenu({
    super.key,
    required this.type,
    this.selectedId,
    this.selectedName,
    this.showImport = true,
  });

  final ContentItemType type;
  final String? selectedId;
  final String? selectedName;

  /// Karakter düzenleyicide false: kullanıcı kuralı "karakteri yalnızca dünya
  /// içinden import edebiliriz", menü onu delmemeli.
  final bool showImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final canExport = selectedId != null || selectedName != null;
    return PopupMenuButton<bool>(
      icon: const Icon(Icons.import_export, size: 20),
      tooltip: l10n.contentArchiveExport,
      onSelected: (isExport) =>
          isExport ? _export(context, ref) : _import(context, ref),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: true,
          enabled: canExport,
          child: Text(l10n.contentArchiveExport),
        ),
        if (showImport)
          PopupMenuItem(value: false, child: Text(l10n.contentArchiveImport)),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path =
          await _savePath(contentArchiveFileName(selectedName ?? 'dmt'));
      if (path == null) return;
      final ok = await exportContentArchive(
        codec: ref.read(contentCodecProvider),
        type: type,
        path: path,
        id: selectedId,
        name: selectedName,
      );
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? l10n.contentArchiveExported(path)
            : l10n.contentArchiveFailed('${selectedName ?? selectedId}')),
      ));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.contentArchiveFailed('$e'))));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [kContentArchiveExtension],
    );
    final path = picked?.files.singleOrNull?.path;
    if (path == null) return;

    ContentArchive? archive;
    try {
      archive = await ContentArchive.open(path);
      final result = await archive.applyTo(ref.read(contentCodecProvider));
      // Hangi liste tazelenecekse o — uygulanan şey seçili sekmeye ait
      // olmak zorunda değil.
      switch (result.ref.type) {
        case ContentItemType.world:
          ref.invalidate(campaignListProvider);
          ref.invalidate(campaignInfoListProvider);
        case ContentItemType.package:
          ref.invalidate(packageListProvider);
        case ContentItemType.character:
          ref.invalidate(characterListProvider);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(result.mediaSkipped == 0
            ? l10n.contentArchiveImported(result.ref.name)
            : l10n.contentArchiveImportedWithSkips(
                result.ref.name, result.mediaSkipped)),
      ));
    } on ContentArchiveException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.error == ContentArchiveError.unsupportedFormat
            ? l10n.contentArchiveUnsupported
            : l10n.contentArchiveFailed('${e.detail}')),
      ));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.contentArchiveFailed('$e'))));
    } finally {
      await archive?.close();
    }
  }

  /// ponytail: mobilde kaydetme diyaloğu yok — `FilePicker.saveFile` orada
  /// baytları istiyor, biz ise diske akıtıyoruz. Dosya Documents'a yazılıp
  /// yolu snackbar'da gösteriliyor. Paylaşım sayfası istenirse `share_plus`
  /// eklenir.
  Future<String?> _savePath(String fileName) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return p.join(dir.path, fileName);
    }
    final picked = await FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const [kContentArchiveExtension],
    );
    if (picked == null) return null;
    return picked.toLowerCase().endsWith('.$kContentArchiveExtension')
        ? picked
        : '$picked.$kContentArchiveExtension';
  }
}
