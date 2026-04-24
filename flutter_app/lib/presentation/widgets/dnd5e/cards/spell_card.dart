import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../../../../domain/dnd5e/spell/spell.dart';
import '../../../../domain/dnd5e/spell/spell_json_codec.dart';
import '../card_shell.dart';
import '../entity_link_chip.dart';
import '../inline_field.dart';
import '../inline_field_extras.dart';
import '_body_cache.dart';
import 'spell_field_editors.dart';

final _spellCache = BodyCache<(Spell, Map<String, Object?>)>();

/// Typed renderer for a Tier 2 `Spell` row with inline editing. Edits go
/// through [saveEditedEntity] which forks package-owned rows into the
/// active campaign as `hb:<cid>:<uuid>`; once forked, the card switches
/// its read-id to the new homebrew row so further edits land on the copy.
class SpellCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const SpellCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<SpellCard> createState() => _SpellCardState();
}

class _SpellCardState extends ConsumerState<SpellCard> {
  late String _effectiveId = widget.entityId;

  @override
  void didUpdateWidget(covariant SpellCard old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) {
      _effectiveId = widget.entityId;
    }
  }

  Future<void> _save({
    required String name,
    required Map<String, Object?> body,
    required int level,
    required String schoolId,
  }) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    if (campaignId == null) return;
    final writtenId = await saveEditedEntity(
      db: ref.read(appDatabaseProvider),
      currentId: _effectiveId,
      categorySlug: 'spell',
      activeCampaignId: campaignId,
      name: name,
      bodyJson: body,
      extras: {'level': level, 'schoolId': schoolId},
    );
    if (!mounted) return;
    if (writtenId != _effectiveId) {
      setState(() => _effectiveId = writtenId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(spellRowProvider(_effectiveId));
    return async.when(
      loading: () => const CardPlaceholder('Loading spell…'),
      error: (e, _) => CardPlaceholder('Failed to load spell: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Spell "$_effectiveId" not found');
        }
        final Spell spell;
        final Map<String, Object?> body;
        try {
          final cacheKey =
              '${row.id}|${row.updatedAt.millisecondsSinceEpoch}';
          final decoded = _spellCache.getOrCompute(cacheKey, () {
            final b = (jsonDecode(row.bodyJson) as Map)
                .cast<String, Object?>();
            final s = spellFromEntry(
              CatalogEntry(
                  id: row.id, name: row.name, bodyJson: row.bodyJson),
            );
            return (s, b);
          });
          spell = decoded.$1;
          body = decoded.$2;
        } catch (e) {
          return CardPlaceholder('Invalid spell body: $e');
        }
        return _SpellBody(
          spell: spell,
          body: body,
          schoolId: row.schoolId,
          level: row.level,
          name: row.name,
          categoryColor: widget.categoryColor,
          onSave: _save,
        );
      },
    );
  }
}

class _SpellBody extends ConsumerWidget {
  final Spell spell;
  final Map<String, Object?> body;
  final String name;
  final int level;
  final String schoolId;
  final Color categoryColor;
  final Future<void> Function({
    required String name,
    required Map<String, Object?> body,
    required int level,
    required String schoolId,
  }) onSave;

  const _SpellBody({
    required this.spell,
    required this.body,
    required this.name,
    required this.level,
    required this.schoolId,
    required this.categoryColor,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsAsync = ref.watch(allSpellSchoolsProvider);
    final schoolOptions = schoolsAsync.maybeWhen(
      data: (list) =>
          list.map((s) => CatalogOption(id: s.id, name: s.name)).toList(),
      orElse: () => const <CatalogOption>[],
    );

    final levelLabel = level == 0 ? 'Cantrip' : 'Level $level';
    final schoolName = schoolOptions
        .where((o) => o.id == schoolId)
        .map((o) => o.name)
        .followedBy([_titleCaseSlug(schoolId)])
        .first;
    final isCantrip = level == 0;

    return CardShell(
      title: name,
      subtitle: '$levelLabel • $schoolName${spell.ritual ? ' • Ritual' : ''}',
      categoryColor: categoryColor,
      tags: [
        CardTag(levelLabel),
        EntityLinkChip(entityId: schoolId, displayLabel: schoolName),
        if (spell.ritual) const CardTag('Ritual'),
        for (final cid in spell.classListIds)
          EntityLinkChip(entityId: cid),
      ],
      children: [
        CardFieldGroup(title: 'Identity', children: [
          CardFieldGrid(columns: 2, fields: [
            CardField(
              label: 'Name',
              child: InlineTextField(
                value: name,
                style: Theme.of(context).textTheme.titleMedium,
                onCommit: (v) => onSave(
                  name: v,
                  body: body,
                  level: level,
                  schoolId: schoolId,
                ),
              ),
            ),
            CardField(
              label: 'Level',
              child: InlineIntField(
                value: level,
                onCommit: (v) => onSave(
                  name: name,
                  body: {...body, 'level': v},
                  level: v,
                  schoolId: schoolId,
                ),
              ),
            ),
            CardField(
              label: 'School',
              child: InlineCatalogRelationField(
                value: schoolId,
                options: schoolOptions,
                onCommit: (v) => onSave(
                  name: name,
                  body: {...body, 'schoolId': v},
                  level: level,
                  schoolId: v,
                ),
              ),
            ),
            CardField(
              label: 'Ritual',
              child: InlineBoolField(
                value: spell.ritual,
                onCommit: (v) => onSave(
                  name: name,
                  body: {...body, if (v) 'ritual': true}
                    ..removeWhere((k, _) => !v && k == 'ritual'),
                  level: level,
                  schoolId: schoolId,
                ),
              ),
            ),
          ]),
        ]),
        CardFieldGroup(title: 'Casting', children: [
          CardFieldGrid(columns: 2, fields: [
            CardField(
              label: 'Casting Time',
              child: SpellCastingTimeEditor(
                value: spell.castingTime,
                onCommit: (v) => onSave(
                  name: name,
                  body: {...body, 'castingTime': encodeCastingTime(v)},
                  level: level,
                  schoolId: schoolId,
                ),
              ),
            ),
            CardField(
              label: 'Range',
              child: SpellRangeEditor(
                value: spell.range,
                onCommit: (v) => onSave(
                  name: name,
                  body: {...body, 'range': encodeSpellRange(v)},
                  level: level,
                  schoolId: schoolId,
                ),
              ),
            ),
            CardField(
              label: 'Components',
              child: SpellComponentsEditor(
                value: spell.components,
                onCommit: (cs) => onSave(
                  name: name,
                  body: {
                    ...body,
                    'components':
                        cs.map(encodeSpellComponent).toList(),
                  },
                  level: level,
                  schoolId: schoolId,
                ),
              ),
            ),
            CardField(
              label: 'Duration',
              child: SpellDurationEditor(
                value: spell.duration,
                onCommit: (v) => onSave(
                  name: name,
                  body: {...body, 'duration': encodeSpellDuration(v)},
                  level: level,
                  schoolId: schoolId,
                ),
              ),
            ),
          ]),
        ]),
        CardFieldGroup(title: 'Description', children: [
          InlineTextField(
            value: spell.description,
            maxLines: 12,
            placeholder: 'No description yet — tap to add…',
            onCommit: (v) => onSave(
              name: name,
              body: {...body, 'description': v},
              level: level,
              schoolId: schoolId,
            ),
          ),
        ]),
        if (isCantrip || spell.cantripUpgrade.isNotEmpty)
          CardFieldGroup(title: 'Cantrip Upgrade', children: [
            InlineTextField(
              value: spell.cantripUpgrade,
              maxLines: 6,
              placeholder:
                  'Scales at levels 5, 11, 17 — tap to add…',
              onCommit: (v) => onSave(
                name: name,
                body: {
                  ...body,
                  if (v.isNotEmpty) 'cantripUpgrade': v,
                }..removeWhere(
                    (k, _) => v.isEmpty && k == 'cantripUpgrade'),
                level: level,
                schoolId: schoolId,
              ),
            ),
          ]),
        if (!isCantrip || spell.higherLevelSlot.isNotEmpty)
          if (!isCantrip)
            CardFieldGroup(
                title: 'Using a Higher-Level Spell Slot', children: [
              InlineTextField(
                value: spell.higherLevelSlot,
                maxLines: 6,
                placeholder:
                    'Upcasting effects — tap to add…',
                onCommit: (v) => onSave(
                  name: name,
                  body: {
                    ...body,
                    if (v.isNotEmpty) 'higherLevelSlot': v,
                  }..removeWhere(
                      (k, _) => v.isEmpty && k == 'higherLevelSlot'),
                  level: level,
                  schoolId: schoolId,
                ),
              ),
            ]),
      ],
    );
  }
}

String _titleCaseSlug(String id) {
  final idx = id.indexOf(':');
  final local = idx < 0 ? id : id.substring(idx + 1);
  if (local.isEmpty) return id;
  return local
      .split(RegExp(r'[-_]'))
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
