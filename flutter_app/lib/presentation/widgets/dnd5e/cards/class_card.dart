import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/character/caster_kind.dart';
import '../../../../domain/dnd5e/character/character_class.dart';
import '../../../../domain/dnd5e/character/character_class_json_codec.dart';
import '../../../../domain/dnd5e/core/ability.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../entity_link_chip.dart';
import '../inline_field.dart';

/// Typed renderer for a `CharacterClass` progression row.
class ClassCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const ClassCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends ConsumerState<ClassCard> {
  late String _effectiveId = widget.entityId;

  @override
  void didUpdateWidget(covariant ClassCard old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) {
      _effectiveId = widget.entityId;
    }
  }

  Future<void> _save(String name, Map<String, Object?> body) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    if (campaignId == null) return;
    final writtenId = await saveEditedEntity(
      db: ref.read(appDatabaseProvider),
      currentId: _effectiveId,
      categorySlug: 'class',
      activeCampaignId: campaignId,
      name: name,
      bodyJson: body,
    );
    if (!mounted) return;
    if (writtenId != _effectiveId) {
      setState(() => _effectiveId = writtenId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(classProgressionRowProvider(_effectiveId));
    return async.when(
      loading: () => const CardPlaceholder('Loading class…'),
      error: (e, _) => CardPlaceholder('Failed to load class: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Class "$_effectiveId" not found');
        }
        final CharacterClass cc;
        final Map<String, Object?> body;
        try {
          body = (jsonDecode(row.bodyJson) as Map).cast<String, Object?>();
          cc = characterClassFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid class body: $e');
        }
        return CardShell(
          title: row.name,
          subtitle:
              'Hit Die ${cc.hitDie.name} • ${_casterLabel(cc.casterKind)}',
          categoryColor: widget.categoryColor,
          tags: [
            CardTag('HD ${cc.hitDie.name}'),
            CardTag(_casterLabel(cc.casterKind)),
            if (cc.spellcastingAbility != null)
              CardTag(_ability(cc.spellcastingAbility!)),
          ],
          children: [
            CardFieldGroup(title: 'Identity', children: [
              CardFieldGrid(columns: 2, fields: [
                CardField(
                  label: 'Name',
                  child: InlineTextField(
                    value: row.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    onCommit: (v) => _save(v, body),
                  ),
                ),
                CardField(label: 'Hit Die', child: Text(cc.hitDie.name)),
                CardField(
                    label: 'Caster', child: Text(_casterLabel(cc.casterKind))),
                CardField(
                    label: 'Saving Throws',
                    child: Text(cc.savingThrows.isEmpty
                        ? '—'
                        : cc.savingThrows.map(_ability).join(', '))),
              ]),
            ]),
            if (cc.featureTable.isNotEmpty)
              CardFieldGroup(title: 'Level Progression', children: [
                for (final row in cc.featureTable)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text('Lv ${row.level}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final id in row.featureIds)
                                EntityLinkChip(entityId: id),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            CardFieldGroup(title: 'Description', children: [
              InlineTextField(
                value: cc.description,
                maxLines: 12,
                placeholder: 'No description yet — tap to add…',
                onCommit: (v) =>
                    _save(row.name, {...body, 'description': v}),
              ),
            ]),
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

