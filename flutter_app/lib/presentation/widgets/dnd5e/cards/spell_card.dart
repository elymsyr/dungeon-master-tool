import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../../../../domain/dnd5e/spell/casting_time.dart';
import '../../../../domain/dnd5e/spell/spell.dart';
import '../../../../domain/dnd5e/spell/spell_components.dart';
import '../../../../domain/dnd5e/spell/spell_duration.dart';
import '../../../../domain/dnd5e/spell/spell_json_codec.dart';
import '../../../../domain/dnd5e/spell/spell_range.dart';
import '../card_shell.dart';
import '../entity_link_chip.dart';
import '../inline_field.dart';

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
          body = (jsonDecode(row.bodyJson) as Map).cast<String, Object?>();
          spell = spellFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
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

class _SpellBody extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final levelLabel = level == 0 ? 'Cantrip' : 'Level $level';
    final schoolLabel = _localSlug(schoolId);
    return CardShell(
      title: name,
      subtitle: '$levelLabel • $schoolLabel${spell.ritual ? ' • Ritual' : ''}',
      categoryColor: categoryColor,
      tags: [
        CardTag(levelLabel),
        EntityLinkChip(entityId: schoolId, displayLabel: schoolLabel),
        if (spell.ritual) const CardTag('Ritual'),
        for (final cid in spell.classListIds)
          EntityLinkChip(entityId: cid),
      ],
      children: [
        // Editable name lives at the top so the header stays stable.
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
              child: InlineTextField(
                value: schoolId,
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
              child: Text(spell.ritual ? 'Yes' : 'No'),
            ),
          ]),
        ]),
        CardFieldGroup(title: 'Casting', children: [
          CardFieldGrid(columns: 2, fields: [
            CardField(
                label: 'Casting Time',
                child: Text(_castingTimeText(spell.castingTime))),
            CardField(
                label: 'Range', child: Text(_rangeText(spell.range))),
            CardField(
                label: 'Components',
                child: Text(_componentsText(spell.components))),
            CardField(
                label: 'Duration',
                child: Text(_durationText(spell.duration))),
          ]),
        ]),
        CardFieldGroup(title: 'Description', children: [
          InlineTextField(
            value: spell.description,
            maxLines: 16,
            placeholder: 'No description yet — tap to add…',
            onCommit: (v) => onSave(
              name: name,
              body: {...body, 'description': v},
              level: level,
              schoolId: schoolId,
            ),
          ),
        ]),
      ],
    );
  }
}

String _localSlug(String id) {
  final idx = id.indexOf(':');
  return idx < 0 ? id : id.substring(idx + 1);
}

String _castingTimeText(CastingTime ct) => switch (ct) {
      ActionCast() => '1 action',
      BonusActionCast() => '1 bonus action',
      ReactionCast(trigger: final t) => '1 reaction ($t)',
      MinutesCast(minutes: final m) => '$m minute${m == 1 ? '' : 's'}',
      HoursCast(hours: final h) => '$h hour${h == 1 ? '' : 's'}',
    };

String _rangeText(SpellRange r) => switch (r) {
      SelfRange() => 'Self',
      TouchRange() => 'Touch',
      SightRange() => 'Sight',
      UnlimitedRange() => 'Unlimited',
      FeetRange(feet: final f) => '${f.toStringAsFixed(0)} ft.',
      MilesRange(miles: final m) => '${m.toStringAsFixed(0)} mi.',
    };

String _componentsText(List<SpellComponent> cs) {
  final parts = <String>[];
  String? materials;
  for (final c in cs) {
    switch (c) {
      case VerbalComponent():
        parts.add('V');
      case SomaticComponent():
        parts.add('S');
      case MaterialComponent(description: final d):
        parts.add('M');
        materials = d;
    }
  }
  final base = parts.join(', ');
  return materials == null ? base : '$base ($materials)';
}

String _durationText(SpellDuration d) => switch (d) {
      SpellInstantaneous() => 'Instantaneous',
      SpellRounds(rounds: final r, concentration: final c) =>
        '${c ? 'Concentration, up to ' : ''}$r round${r == 1 ? '' : 's'}',
      SpellMinutes(minutes: final m, concentration: final c) =>
        '${c ? 'Concentration, up to ' : ''}$m minute${m == 1 ? '' : 's'}',
      SpellHours(hours: final h, concentration: final c) =>
        '${c ? 'Concentration, up to ' : ''}$h hour${h == 1 ? '' : 's'}',
      SpellDays(days: final d) => '$d day${d == 1 ? '' : 's'}',
      SpellUntilDispelled() => 'Until dispelled',
      SpellSpecial(description: final d) => 'Special ($d)',
    };
