import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../../../../domain/dnd5e/character/caster_kind.dart';
import '../../../../domain/dnd5e/character/character_class.dart';
import '../../../../domain/dnd5e/character/character_class_json_codec.dart';
import '../../../../domain/dnd5e/core/ability.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';

/// Typed renderer for a `CharacterClass` progression row. Reads
/// `class_progressions` — the Drift row carries the same JSON body shape.
class ClassCard extends ConsumerWidget {
  final String entityId;
  final Color categoryColor;

  const ClassCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classProgressionRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading class…'),
      error: (e, _) => CardPlaceholder('Failed to load class: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Class "$entityId" not found');
        }
        final CharacterClass cc;
        try {
          cc = characterClassFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid class body: $e');
        }
        return CardShell(
          title: cc.name,
          subtitle:
              'Hit Die ${cc.hitDie.name} • ${_casterLabel(cc.casterKind)}',
          categoryColor: categoryColor,
          tags: [
            CardTag('HD ${cc.hitDie.name}'),
            CardTag(_casterLabel(cc.casterKind)),
            if (cc.spellcastingAbility != null)
              CardTag(_ability(cc.spellcastingAbility!)),
          ],
          children: [
            if (cc.savingThrows.isNotEmpty)
              CardKeyValue(
                'Saving Throws',
                cc.savingThrows.map(_ability).join(', '),
              ),
            if (cc.featureTable.isNotEmpty)
              CardSection(
                title: 'LEVEL PROGRESSION',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in cc.featureTable)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          'Lv ${row.level}: ${row.featureIds.map(_local).join(', ')}',
                        ),
                      ),
                  ],
                ),
              ),
            if (cc.description.isNotEmpty)
              CardSection(title: 'DESCRIPTION', child: Text(cc.description)),
          ],
        );
      },
    );
  }
}

String _casterLabel(CasterKind k) => switch (k) {
      CasterKind.none => 'Non-caster',
      CasterKind.full => 'Full Caster',
      CasterKind.half => 'Half Caster',
      CasterKind.third => '1/3 Caster',
      CasterKind.pact => 'Pact Magic',
    };

String _ability(Ability a) => switch (a) {
      Ability.strength => 'STR',
      Ability.dexterity => 'DEX',
      Ability.constitution => 'CON',
      Ability.intelligence => 'INT',
      Ability.wisdom => 'WIS',
      Ability.charisma => 'CHA',
    };

String _local(String id) {
  final idx = id.indexOf(':');
  return idx < 0 ? id : id.substring(idx + 1);
}
