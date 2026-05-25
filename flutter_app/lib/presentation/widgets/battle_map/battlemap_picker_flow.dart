import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../screens/battle_map/battle_map_notifier.dart';
import '../../theme/dm_tool_colors.dart';
import '../asset_ref_image.dart';

/// Opens the battle map background picker — DM chooses between a fresh
/// device file or an already-uploaded image from a location entity's
/// `battlemaps` field. Location refs skip re-upload because they are already
/// `dmt-asset://` refs counted under `MediaKind.battleMap`.
Future<void> openBattlemapPicker(
  BuildContext context,
  WidgetRef ref,
  BattleMapNotifier notifier,
) async {
  final source = await showModalBottomSheet<_PickerSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('From device'),
            onTap: () => Navigator.pop(ctx, _PickerSource.device),
          ),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('From location battlemaps'),
            onTap: () => Navigator.pop(ctx, _PickerSource.location),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  if (source == _PickerSource.device) {
    await notifier.pickMapImage(context);
    return;
  }

  final locId = await _pickLocationWithBattlemaps(context, ref);
  if (locId == null || !context.mounted) return;
  final entity = ref.read(entityProvider)[locId];
  if (entity == null) return;
  final battlemaps = _battlemapsOf(entity);
  if (battlemaps.isEmpty) return;
  final picked = await _pickBattlemapImage(context, battlemaps);
  if (picked == null || !context.mounted) return;
  await notifier.applyMapImage(context, picked);
}

enum _PickerSource { device, location }

List<String> _battlemapsOf(Entity e) {
  final raw = e.fields['battlemaps'];
  if (raw is! List) return const [];
  return [for (final v in raw) if (v is String && v.isNotEmpty) v];
}

Future<String?> _pickLocationWithBattlemaps(
  BuildContext context,
  WidgetRef ref,
) async {
  final entities = ref.read(entityProvider);
  final eligible = [
    for (final e in entities.values)
      if (e.categorySlug == 'location' && _battlemapsOf(e).isNotEmpty) e,
  ];
  if (eligible.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No locations with battlemaps')),
    );
    return null;
  }
  final picked = await showEntitySelectorDialog(
    context: context,
    ref: ref,
    allowedTypes: const ['location'],
    excludeIds: [
      for (final e in entities.values)
        if (e.categorySlug == 'location' && _battlemapsOf(e).isEmpty) e.id,
    ],
  );
  return picked == null || picked.isEmpty ? null : picked.first;
}

Future<String?> _pickBattlemapImage(
  BuildContext context,
  List<String> refs,
) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final palette = Theme.of(ctx).extension<DmToolColors>()!;
      return AlertDialog(
        title: const Text('Choose battlemap', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 480,
          height: 480,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.4,
            ),
            itemCount: refs.length,
            itemBuilder: (c, i) {
              final r = refs[i];
              return InkWell(
                onTap: () => Navigator.pop(ctx, r),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AssetRefImage(
                    ref: AssetRef(r),
                    cacheWidth: 480,
                    placeholder: Container(
                      color: palette.sidebarLabelSecondary.withValues(alpha: 0.1),
                    ),
                    errorWidget: Container(
                      color: palette.sidebarLabelSecondary.withValues(alpha: 0.1),
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}
