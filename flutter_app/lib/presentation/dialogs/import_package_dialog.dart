import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/template_provider.dart';
import '../../application/services/package_import_service.dart';
import '../../application/services/package_sync_service.dart';
import '../../application/services/srd_core_package_bootstrap.dart'
    show srdCorePackageName;
import '../../application/services/template_compatibility_service.dart';
import '../../data/database/database_provider.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:drift/drift.dart' hide Column, Table;
import '../../data/database/app_database.dart' show InstalledPackagesCompanion;
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
  Set<String> _installedPackageNames = const {};

  @override
  void initState() {
    super.initState();
    _loadInstalled();
  }

  Future<void> _loadInstalled() async {
    final db = ref.read(appDatabaseProvider);
    final campaignId =
        ref.read(activeCampaignProvider.notifier).data?['world_id'] as String?;
    if (campaignId == null) return;
    final rows = await db.installedPackageDao.listForCampaign(campaignId);
    if (!mounted) return;
    setState(() {
      _installedPackageNames = rows.map((r) => r.packageName).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final worldSchema = ref.read(worldSchemaProvider);
    final compatService = TemplateCompatibilityService();

    return AlertDialog(
      title: Text(l10n.importPackageTitle),
      content: SizedBox(
        width: 500,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImportSourcePillTabs(
              source: _source,
              palette: palette,
              disabled: _importing,
              onChanged: (s) => setState(() => _source = s),
              l10n: l10n,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (_source) {
                _ImportSource.packages =>
                  _packagesBody(l10n, palette, worldSchema, compatService),
                _ImportSource.characters =>
                  _charactersBody(l10n, palette, worldSchema, compatService),
              },
            ),
          ],
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
              alreadyInstalled: _installedPackageNames.contains(info.name),
              onImport: () => _importPackage(info, worldSchema),
              onRemove: () => _removePackage(info),
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
              onImport: templ == null ? null : () => _importCharacter(c),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _removePackage(PackageInfo info) async {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    var purgeAll = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text('Remove "${info.name}" from this world?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Linked entities from this package will be deleted.',
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: purgeAll,
                onChanged: (v) =>
                    setDialogState(() => purgeAll = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text(
                  'Also delete user-edited (detached) copies',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  purgeAll
                      ? 'All entities from this package will be removed.'
                      : 'Edited copies will be kept as homebrew.',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: palette.dangerBtnBg),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        );
      }),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final pkgRow = await db.packageDao.getByName(info.name);
      final activeNotifier = ref.read(activeCampaignProvider.notifier);
      final campaignId = activeNotifier.data?['world_id'] as String?;
      if (pkgRow == null || campaignId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot remove: missing context')),
          );
        }
        return;
      }
      final tier0Slugs =
          generateBuiltinDnd5eV2Schema().seedRows.keys.toSet();
      final result = await PackageSyncService(db).uninstall(
        campaignId: campaignId,
        packageId: pkgRow.id,
        purgeDetached: purgeAll,
        // Legacy worlds seeded Tier-0 lookups without a packageId tag.
        // Scrub them alongside the SRD pack so a remove leaves nothing
        // behind. Safe for non-SRD packs because their entities don't
        // live in Tier-0 categories.
        extraScrubSlugs:
            info.name == srdCorePackageName ? tier0Slugs : const {},
      );
      await activeNotifier.reload();
      await _loadInstalled();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Removed "${info.name}": ${result.removed} deleted, ${result.detachedSurvived} kept as homebrew.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remove failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importPackage(
      PackageInfo info, WorldSchema worldSchema) async {
    setState(() => _importing = true);

    try {
      final db = ref.read(appDatabaseProvider);
      final pkgRow = await db.packageDao.getByName(info.name);
      if (pkgRow == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Package not found')),
          );
        }
        return;
      }

      final activeNotifier = ref.read(activeCampaignProvider.notifier);
      final campaignId = activeNotifier.data?['world_id'] as String?;
      if (campaignId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active world')),
          );
        }
        return;
      }

      // Live-link install: register the package, then sync. New pack rows
      // come in as linked entities — pack updates propagate, user edits
      // detach to homebrew.
      await db.installedPackageDao.upsert(InstalledPackagesCompanion.insert(
        campaignId: campaignId,
        packageId: pkgRow.id,
        packageName: Value(pkgRow.name),
      ));

      // Build Tier-0 (slug,name) → uuid index from this campaign's seeded
      // entities so pack-side `_lookup` placeholders resolve.
      final build = generateBuiltinDnd5eV2Schema();
      final tier0Slugs = build.seedRows.keys.toSet();
      final tier0Rows = await (db.select(db.entities)
            ..where((t) =>
                t.campaignId.equals(campaignId) &
                t.categorySlug.isIn(tier0Slugs)))
          .get();
      final tier0Index = <String, Map<String, String>>{};
      for (final r in tier0Rows) {
        tier0Index
            .putIfAbsent(r.categorySlug, () => <String, String>{})[r.name] =
            r.id;
      }

      final result = await PackageSyncService(db).sync(
        campaignId: campaignId,
        packageId: pkgRow.id,
        resolveAttrs: (attrs) =>
            PackageImportService.resolveLookupPlaceholder(attrs, tier0Index)
                as Map<String, dynamic>,
      );
      // Reload campaign so the entity provider picks up the new rows.
      await activeNotifier.reload();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(L10n.of(context)!.importSuccess(result.added))),
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

  /// Karakter import'u **kopya değil, link** kurar. Aktif world'ün
  /// `linked_character_ids` listesine karakter id'si eklenir. Karakter
  /// hub'da tek kaynak olarak yaşar — hub'da yapılan her edit, linked
  /// world'de de görünür (EntityNotifier `characterListProvider`'ı
  /// dinliyor ve otomatik reload yapıyor).
  Future<void> _importCharacter(Character c) async {
    setState(() => _importing = true);
    try {
      final activeNotifier = ref.read(activeCampaignProvider.notifier);
      final data = activeNotifier.data;
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active world')),
          );
        }
        return;
      }
      final existing =
          (data['linked_character_ids'] as List?)?.whereType<String>().toList() ??
              <String>[];
      if (existing.contains(c.id)) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${c.entity.name}" already linked')),
          );
        }
        return;
      }
      data['linked_character_ids'] = [...existing, c.id];
      await activeNotifier.save();
      // Bump revision → EntityNotifier `_loadFromCampaign()` çalışır,
      // linked karakter world görünümüne enjekte olur.
      ref.read(campaignRevisionProvider.notifier).state++;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Linked "${c.entity.name}" to this world')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Link failed: $e')),
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
  final bool alreadyInstalled;
  final VoidCallback onImport;
  final VoidCallback onRemove;

  const _PackageImportCard({
    required this.info,
    required this.worldSchema,
    required this.compatService,
    required this.palette,
    required this.l10n,
    required this.importing,
    required this.alreadyInstalled,
    required this.onImport,
    required this.onRemove,
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
        : widget.alreadyInstalled
            ? (Icons.check_circle, palette.successBtnBg, 'Imported')
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
                  if (widget.alreadyInstalled)
                    SizedBox(
                      height: 28,
                      child: OutlinedButton.icon(
                        onPressed: widget.importing ? null : widget.onRemove,
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('Remove'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(fontSize: 12),
                          foregroundColor: palette.dangerBtnBg,
                          side: BorderSide(color: palette.dangerBtnBg),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 28,
                      child: isIncompatible
                          ? OutlinedButton(
                              onPressed: canImport
                                  ? () => _confirmForceImport(context)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                textStyle: const TextStyle(fontSize: 12),
                                foregroundColor: palette.dangerBtnBg,
                                side: BorderSide(color: palette.dangerBtnBg),
                              ),
                              child: const Text('Force'),
                            )
                          : FilledButton(
                              onPressed: canImport ? widget.onImport : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
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

/// Feed-scope tarzı pill tab: Packages / Characters seçici.
class _ImportSourcePillTabs extends StatelessWidget {
  final _ImportSource source;
  final DmToolColors palette;
  final bool disabled;
  final ValueChanged<_ImportSource> onChanged;
  final L10n l10n;

  const _ImportSourcePillTabs({
    required this.source,
    required this.palette,
    required this.disabled,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(_ImportSource, String)>[
      (_ImportSource.packages, l10n.importSourcePackages),
      (_ImportSource.characters, l10n.importSourceCharacters),
    ];
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((t) {
          final isActive = t.$1 == source;
          return InkWell(
            borderRadius: palette.br,
            onTap: disabled ? null : () => onChanged(t.$1),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color:
                    isActive ? palette.featureCardAccent : Colors.transparent,
                borderRadius: palette.br,
                border: Border.all(
                  color: isActive
                      ? palette.featureCardAccent
                      : palette.featureCardBorder,
                ),
              ),
              child: Text(
                t.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : palette.tabText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
