import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/combat_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/perf/image_cache_size.dart';
import '../widgets/srd_text.dart';

/// Condition picker for a combatant (session tracker + battle map token
/// menu). Picking a condition or entering a custom name asks its duration in
/// a follow-up dialog, then adds it via [CombatNotifier.addCondition].
void showAddConditionDialog(
  BuildContext context,
  WidgetRef ref,
  String combatantId,
) {
  final nameController = TextEditingController();

  // Find condition categories. The legacy schema marks them with a
  // `condition_stats` field, but the builtin v2 schema models `condition` as
  // a Tier-0 lookup WITHOUT that field — so also match well-known condition
  // slugs, else builtin conditions never show up in the picker.
  const knownConditionSlugs = {'condition', 'conditions'};
  final schema = ref.read(worldSchemaProvider);
  final cfg = schema.encounterConfig;
  final conditionSlugs = <String>{};
  for (final cat in schema.categories) {
    if (knownConditionSlugs.contains(cat.slug) ||
        cat.fields.any((f) => f.fieldKey == cfg.conditionStatsFieldKey)) {
      conditionSlugs.add(cat.slug);
    }
  }
  final entities = ref.read(entityProvider);
  final conditionEntities = entities.values
      .where((e) => conditionSlugs.contains(e.categorySlug))
      .toList()
    ..sort((a, b) => srdName(context, a).compareTo(srdName(context, b)));

  final l10n = L10n.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.sessionAddConditionTitle, style: const TextStyle(fontSize: 14)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Entity-based conditions
            if (conditionEntities.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: conditionEntities.map((e) {
                      final stats = e.fields[cfg.conditionStatsFieldKey];
                      final defaultDuration = stats is Map ? int.tryParse('${stats['default_duration'] ?? ''}') : null;
                      final hasImage = e.imagePath.isNotEmpty || e.images.isNotEmpty;
                      final imgPath = e.imagePath.isNotEmpty ? e.imagePath : (e.images.isNotEmpty ? e.images.first : null);
                      return ActionChip(
                        avatar: hasImage && imgPath != null
                            ? CircleAvatar(
                                backgroundImage: ResizeImage.resizeIfNeeded(
                                    cachePxFromLogical(context, 20),
                                    null,
                                    FileImage(File(imgPath))),
                                radius: 10,
                              )
                            : null,
                        label: Text(srdName(context, e), style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showConditionDurationDialog(context, ref, combatantId, e.name,
                              defaultDuration, entityId: e.id);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
            ],
            // Custom condition — duration asked in a follow-up dialog.
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.sessionCustomCondition),
              autofocus: conditionEntities.isEmpty,
              onSubmitted: (_) {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                _showConditionDurationDialog(context, ref, combatantId, name, null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
        FilledButton(onPressed: () {
          final name = nameController.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(ctx);
          _showConditionDurationDialog(context, ref, combatantId, name, null);
        }, child: Text(l10n.sessionAddCustom)),
      ],
    ),
  ).whenComplete(() {
    nameController.dispose();
  });
}

/// Second-step dialog: asks the condition's duration (rounds) after a
/// condition is picked or a custom name is entered. Empty = indefinite.
void _showConditionDurationDialog(
  BuildContext context,
  WidgetRef ref,
  String combatantId,
  String name,
  int? initialDuration, {
  String? entityId,
}) {
  final durationController =
      TextEditingController(text: initialDuration?.toString() ?? '');
  final l10n = L10n.of(context)!;
  void submit() {
    ref.read(combatProvider.notifier).addCondition(
          combatantId,
          name,
          int.tryParse(durationController.text.trim()),
          entityId: entityId,
        );
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(name, style: const TextStyle(fontSize: 14)),
      content: TextField(
        controller: durationController,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: l10n.sessionDurationHint),
        onSubmitted: (_) {
          submit();
          Navigator.pop(ctx);
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
        FilledButton(onPressed: () {
          submit();
          Navigator.pop(ctx);
        }, child: Text(l10n.btnAdd)),
      ],
    ),
  ).whenComplete(() {
    durationController.dispose();
  });
}
