import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../../../../domain/dnd5e/spell/casting_time.dart';
import '../../../../domain/dnd5e/spell/spell.dart';
import '../../../../domain/dnd5e/spell/spell_components.dart';
import '../../../../domain/dnd5e/spell/spell_duration.dart';
import '../../../../domain/dnd5e/spell/spell_json_codec.dart';
import '../../../../domain/dnd5e/spell/spell_range.dart';
import '../card_shell.dart';

/// Typed renderer for a Tier 2 `Spell` row. Decodes `bodyJson` via
/// `spellFromEntry` and lays out level/school/components/duration + description.
class SpellCard extends ConsumerWidget {
  final String entityId;
  final Color categoryColor;

  const SpellCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(spellRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading spell…'),
      error: (e, _) => CardPlaceholder('Failed to load spell: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Spell "$entityId" not found');
        }
        final Spell spell;
        try {
          spell = spellFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid spell body: $e');
        }
        return _SpellCardBody(
          spell: spell,
          categoryColor: categoryColor,
          schoolId: row.schoolId,
        );
      },
    );
  }
}

class _SpellCardBody extends StatelessWidget {
  final Spell spell;
  final Color categoryColor;
  final String schoolId;

  const _SpellCardBody({
    required this.spell,
    required this.categoryColor,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context) {
    final levelLabel = spell.level.value == 0
        ? 'Cantrip'
        : 'Level ${spell.level.value}';
    final schoolLabel = _localSlug(schoolId);
    return CardShell(
      title: spell.name,
      subtitle: '$levelLabel • $schoolLabel${spell.ritual ? ' • Ritual' : ''}',
      categoryColor: categoryColor,
      tags: [
        CardTag(levelLabel),
        CardTag(schoolLabel),
        if (spell.ritual) const CardTag('Ritual'),
        for (final cid in spell.classListIds) CardTag(_localSlug(cid)),
      ],
      children: [
        CardKeyValue('Casting Time', _castingTimeText(spell.castingTime)),
        CardKeyValue('Range', _rangeText(spell.range)),
        CardKeyValue('Components', _componentsText(spell.components)),
        CardKeyValue('Duration', _durationText(spell.duration)),
        if (spell.description.isNotEmpty)
          CardSection(
            title: 'DESCRIPTION',
            child: Text(spell.description),
          ),
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
