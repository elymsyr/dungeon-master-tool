import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/character_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/template_provider.dart';
import '../../application/services/package_import_service.dart';
import '../../application/services/template_compatibility_service.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/package_info.dart';
import '../../domain/entities/schema/template_compatibility.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Paket / karakter import dialogu — aktif dünyaya paket veya karakter
/// import etmek için. Üstteki segmented control ile kaynak seçilir.
class ImportPackageDialog extends ConsumerStatefulWidget {
  const ImportPackageDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ImportPackageDialog(),
    );
  }

  @override
  ConsumerState<ImportPackageDialog> createState() =>
      _ImportPackageDialogState();
}

enum _ImportSource { packages, characters }

class _ImportPackageDialogState extends ConsumerState<ImportPackageDialog> {
  bool _importing = false;
  _ImportSource _source = _ImportSource.packages;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final worldSchema = ref.read(worldSchemaProvider);
    final compatService = TemplateCompatibilityService();

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.importPackageTitle)),
          SegmentedButton<_ImportSource>(
            segments: const [
              ButtonSegment(
                value: _ImportSource.packages,
                icon: Icon(Icons.inventory_2, size: 16),
                label: Text('Packages', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: _ImportSource.characters,
                icon: Icon(Icons.person, size: 16),
                label: Text('Characters', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_source},
            onSelectionChanged: _importing
                ? null
                : (s) => setState(() => _source = s.first),
            showSelectedIcon: false,
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 440,
        child: switch (_source) {
          _ImportSource.packages =>
            _packagesBody(l10n, palette, worldSchema, compatService),
          _ImportSource.characters =>
            _charactersBody(l10n, palette, worldSchema, compatService),
        },
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
      ],
    );
  }

  Widget _packagesBody(L10n l10n, DmToolColors palette,
      WorldSchema worldSchema, TemplateCompatibilityService compatService) {
    final packageList = ref.watch(packageListProvider);
    return packageList.when(
      data: (packages) {
        if (packages.isEmpty) {
          return Center(
            child: Text(l10n.noPackages,
                style: TextStyle(color: palette.sidebarLabelSecondary)),
          );
        }
        return ListView.separated(
          itemCount: packages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final info = packages[index];
            return _PackageImportCard(
              info: info,
              worldSchema: worldSchema,
              compatService: compatService,
              palette: palette,
              l10n: l10n,
              importing: _importing,
              onImport: () => _importPackage(info, worldSchema),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _charactersBody(L10n l10n, DmToolColors palette,
      WorldSchema worldSchema, TemplateCompatibilityService compatService) {
    final charList = ref.watch(characterListProvider);
    final templatesAsync = ref.watch(allTemplatesProvider);
    return charList.when(
      data: (chars) {
        if (chars.isEmpty) {
          return Center(
            child: Text('No characters found.',
                style: TextStyle(color: palette.sidebarLabelSecondary)),
          );
        }
        final templates = templatesAsync.valueOrNull ?? const <WorldSchema>[];
        return ListView.separated(
          itemCount: chars.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final c = chars[index];
            final templ = templates
                .where((t) => t.schemaId == c.templateId)
                .firstOrNull;
            return _CharacterImportCard(
              character: c,
              template: templ,
              worldSchema: worldSchema,
              compatService: compatService,
              palette: palette,
              l10n: l10n,
              importing: _importing,
              onImport: templ == null
                  ? null
                  : () => _importCharacter(c, templ, worldSchema),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _importPackage(
      PackageInfo info, WorldSchema worldSchema) async {
    setState(() => _importing = true);

    try {
      final packageData =
          await ref.read(packageRepositoryProvider).load(info.name);

      final schemaMap = packageData['world_schema'] as Map<String, dynamic>?;
      if (schemaMap == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Package has no template')),
          );
        }
        setState(() => _importing = false);
        return;
      }

      final packageSchema =
          WorldSchema.fromJson(Map<String, dynamic>.from(schemaMap));
      final packageEntities =
          packageData['entities'] as Map<String, dynamic>? ?? {};

      final importService = PackageImportService();
      final entityNotifier = ref.read(entityProvider.notifier);

      final count = importService.importPackage(
        packageEntities: packageEntities,
        packageSchema: packageSchema,
        worldSchema: worldSchema,
        entityNotifier: entityNotifier,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(L10n.of(context)!.importSuccess(count))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importCharacter(
      Character c, WorldSchema template, WorldSchema worldSchema) async {
    setState(() => _importing = true);
    try {
      // Package import service konvansiyonu: `type` = kategori slug,
      // `attributes` = fields map. Character tek entity olarak import edilir.
      final entityMap = <String, dynamic>{
        'name': c.entity.name,
        'type': c.entity.categorySlug,
        'source': c.entity.source,
        'description': c.entity.description,
        'images': c.entity.images,
        'image_path': c.entity.imagePath,
        'tags': c.entity.tags,
        'dm_notes': c.entity.dmNotes,
        'pdfs': c.entity.pdfs,
        'location_id': c.entity.locationId,
        'attributes': c.entity.fields,
      };
      final packageEntities = <String, dynamic>{c.entity.id: entityMap};

      final count = PackageImportService().importPackage(
        packageEntities: packageEntities,
        packageSchema: template,
        worldSchema: worldSchema,
        entityNotifier: ref.read(entityProvider.notifier),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.importSuccess(count))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

/// Tek bir paket kartı — uyumluluk bilgisi ile.
class _PackageImportCard extends StatefulWidget {
  final PackageInfo info;
  final WorldSchema worldSchema;
  final TemplateCompatibilityService compatService;
  final DmToolColors palette;
  final L10n l10n;
  final bool importing;
  final VoidCallback onImport;

  const _PackageImportCard({
    required this.info,
    required this.worldSchema,
    required this.compatService,
    required this.palette,
    required this.l10n,
    required this.importing,
    required this.onImport,
  });

  @override
  State<_PackageImportCard> createState() => _PackageImportCardState();
}

class _PackageImportCardState extends State<_PackageImportCard> {
  TemplateCompatibility? _compat;
  bool _expanded = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkCompatibility();
  }

  Future<void> _checkCompatibility() async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final repo = container.read(packageRepositoryProvider);
      final data = await repo.load(widget.info.name);
      final schemaMap = data['world_schema'] as Map<String, dynamic>?;
      if (schemaMap != null && mounted) {
        final pkgSchema =
            WorldSchema.fromJson(Map<String, dynamic>.from(schemaMap));
        setState(() {
          _compat =
              widget.compatService.check(pkgSchema, widget.worldSchema);
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _compat = const TemplateCompatibility(
            level: CompatibilityLevel.incompatible,
            warnings: ['Failed to load package template']);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.l10n;

    final (IconData icon, Color color, String label) = _loading
        ? (Icons.hourglass_empty, palette.sidebarLabelSecondary, '...')
        : switch (_compat?.level) {
            CompatibilityLevel.perfect => (
                Icons.check_circle,
                palette.successBtnBg,
                l10n.importCompatPerfect,
              ),
            CompatibilityLevel.compatible => (
                Icons.warning_amber,
                palette.uiAutosaveTextEditing,
                l10n.importCompatWarning,
              ),
            CompatibilityLevel.incompatible => (
                Icons.cancel,
                palette.dangerBtnBg,
                l10n.importCompatIncompatible,
              ),
            null => (
                Icons.help_outline,
                palette.sidebarLabelSecondary,
                'Unknown',
              ),
          };

    final isIncompatible = _compat?.level == CompatibilityLevel.incompatible;
    final canImport = !_loading && !widget.importing && _compat != null;

    final hasDetails = _compat != null &&
        (_compat!.warnings.isNotEmpty ||
            _compat!.addedFields.isNotEmpty ||
            _compat!.removedFields.isNotEmpty ||
            _compat!.removedCategories.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: hasDetails
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, size: 18, color: palette.tabText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.info.name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: palette.tabActiveText)),
                        Text(
                          '${widget.info.templateName} · ${l10n.packageEntityCount(widget.info.entityCount)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: palette.sidebarLabelSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(label,
                          style: TextStyle(fontSize: 11, color: color)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: isIncompatible
                        ? OutlinedButton(
                            onPressed: canImport
                                ? () => _confirmForceImport(context)
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12),
                              foregroundColor: palette.dangerBtnBg,
                              side: BorderSide(color: palette.dangerBtnBg),
                            ),
                            child: const Text('Force'),
                          )
                        : FilledButton(
                            onPressed: canImport ? widget.onImport : null,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: Text(l10n.btnImport),
                          ),
                  ),
                  if (hasDetails)
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: palette.sidebarLabelSecondary,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded && _compat != null) ...[
            Divider(height: 1, color: palette.featureCardBorder),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_compat!.addedFields.isNotEmpty) ...[
                    Text(l10n.importFieldsMissing,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText)),
                    const SizedBox(height: 2),
                    ..._compat!.addedFields.map((f) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 1),
                          child: Text('• $f',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary)),
                        )),
                    const SizedBox(height: 6),
                  ],
                  if (_compat!.removedFields.isNotEmpty) ...[
                    Text(l10n.importFieldsExtra,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText)),
                    const SizedBox(height: 2),
                    ..._compat!.removedFields.map((f) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 1),
                          child: Text('• $f',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary)),
                        )),
                    const SizedBox(height: 6),
                  ],
                  if (_compat!.removedCategories.isNotEmpty) ...[
                    Text('Categories in package not in world:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText)),
                    const SizedBox(height: 2),
                    ..._compat!.removedCategories.map((c) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 1),
                          child: Text('• $c',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary)),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmForceImport(BuildContext context) {
    final palette = widget.palette;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: palette.dangerBtnBg, size: 22),
            const SizedBox(width: 8),
            const Text('Force Import'),
          ],
        ),
        content: const Text(
          'The package template is incompatible with this world.\n\n'
          'Entities from unmatched categories will be skipped, and '
          'mismatched fields will receive default values. '
          'This may result in significant data loss.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: const Text('Force Import'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) widget.onImport();
    });
  }
}

/// Tek bir karakter kartı — profil fotoğrafı + isim + template uyumluluk.
class _CharacterImportCard extends StatelessWidget {
  final Character character;
  final WorldSchema? template;
  final WorldSchema worldSchema;
  final TemplateCompatibilityService compatService;
  final DmToolColors palette;
  final L10n l10n;
  final bool importing;
  final VoidCallback? onImport;

  const _CharacterImportCard({
    required this.character,
    required this.template,
    required this.worldSchema,
    required this.compatService,
    required this.palette,
    required this.l10n,
    required this.importing,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final compat = template == null
        ? null
        : compatService.check(template!, worldSchema);

    final (IconData icon, Color color, String label) = compat == null
        ? (
            Icons.help_outline,
            palette.sidebarLabelSecondary,
            'Template missing'
          )
        : switch (compat.level) {
            CompatibilityLevel.perfect => (
                Icons.check_circle,
                palette.successBtnBg,
                l10n.importCompatPerfect,
              ),
            CompatibilityLevel.compatible => (
                Icons.warning_amber,
                palette.uiAutosaveTextEditing,
                l10n.importCompatWarning,
              ),
            CompatibilityLevel.incompatible => (
                Icons.cancel,
                palette.dangerBtnBg,
                l10n.importCompatIncompatible,
              ),
          };

    final canImport = !importing && onImport != null;

    return Container(
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.featureCardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(character.entity.name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.tabActiveText)),
                Text(
                  character.templateName,
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: FilledButton(
              onPressed: canImport ? onImport : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(l10n.btnImport),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final path = character.entity.imagePath;
    final hasImage = path.isNotEmpty && File(path).existsSync();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        shape: BoxShape.circle,
        border: Border.all(color: palette.featureCardBorder),
        image: hasImage
            ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Icon(Icons.person, size: 22, color: palette.tabText),
    );
  }
}
