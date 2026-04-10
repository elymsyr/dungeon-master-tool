import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/services/package_import_service.dart';
import '../../application/services/template_compatibility_service.dart';
import '../../domain/entities/package_info.dart';
import '../../domain/entities/schema/template_compatibility.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Paket import dialogu — dünyaya paket import etmek için.
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

class _ImportPackageDialogState extends ConsumerState<ImportPackageDialog> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final packageList = ref.watch(packageListProvider);
    final worldSchema = ref.read(worldSchemaProvider);
    final compatService = TemplateCompatibilityService();

    return AlertDialog(
      title: Text(l10n.importPackageTitle),
      content: SizedBox(
        width: 450,
        height: 400,
        child: packageList.when(
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
      ],
    );
  }

  Future<void> _importPackage(
      PackageInfo info, WorldSchema worldSchema) async {
    setState(() => _importing = true);

    try {
      // Paket verisini yükle
      final packageData =
          await ref.read(packageRepositoryProvider).load(info.name);

      // Paket schema'sını al
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
              content:
                  Text(L10n.of(context)!.importSuccess(count))),
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
    // Paket schema'sını yüklememiz gerekiyor — bu kart için lazy load
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

    // Uyumluluk durumu
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
          // Header
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
                  // Uyumluluk badge
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
                  // Import butonu
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
                  // Expand arrow
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
          // Expanded details
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
