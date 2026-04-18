import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/services/package_import_service.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/package_info.dart';
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
                  _packagesBody(l10n, palette, worldSchema),
                _ImportSource.characters =>
                  _charactersBody(l10n, palette, worldSchema),
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
      WorldSchema worldSchema) {
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
      WorldSchema worldSchema) {
    final charList = ref.watch(characterListProvider);
    return charList.when(
      data: (chars) {
        if (chars.isEmpty) {
          return Center(
            child: Text('No characters found.',
                style: TextStyle(color: palette.sidebarLabelSecondary)),
          );
        }
        return ListView.separated(
          itemCount: chars.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final c = chars[index];
            return _CharacterImportCard(
              character: c,
              palette: palette,
              l10n: l10n,
              importing: _importing,
              onImport: () => _importCharacter(c),
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

/// Tek bir paket kartı.
class _PackageImportCard extends StatelessWidget {
  final PackageInfo info;
  final DmToolColors palette;
  final L10n l10n;
  final bool importing;
  final VoidCallback onImport;

  const _PackageImportCard({
    required this.info,
    required this.palette,
    required this.l10n,
    required this.importing,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.featureCardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.inventory_2, size: 18, color: palette.tabText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.tabActiveText)),
                Text(
                  '${info.templateName} · ${l10n.packageEntityCount(info.entityCount)}',
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: FilledButton(
              onPressed: importing ? null : onImport,
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
}

/// Tek bir karakter kartı — profil fotoğrafı + isim.
class _CharacterImportCard extends StatelessWidget {
  final Character character;
  final DmToolColors palette;
  final L10n l10n;
  final bool importing;
  final VoidCallback? onImport;

  const _CharacterImportCard({
    required this.character,
    required this.palette,
    required this.l10n,
    required this.importing,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
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
