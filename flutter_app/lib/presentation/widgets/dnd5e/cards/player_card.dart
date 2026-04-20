import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/database/database_provider.dart';
import '../card_shell.dart';
import '../inline_field.dart';

/// Player-character card. Until the Batch 6 typed `Dnd5eCharacter` table
/// lands, player rows live in `homebrew_entries` with `categorySlug='player'`.
/// Layout mirrors MonsterCard / SpellCard: border, tag chips, Identity +
/// Combat + Abilities + Description groups; every scalar is inline editable.
class PlayerCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const PlayerCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends ConsumerState<PlayerCard> {
  Future<void> _save({
    required String name,
    required Map<String, Object?> body,
  }) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    final db = ref.read(appDatabaseProvider);
    await db.dnd5eContentDao.upsertHomebrewEntry(
      HomebrewEntriesCompanion.insert(
        id: widget.entityId,
        categorySlug: 'player',
        name: name,
        bodyJson: jsonEncode(body),
        campaignId: Value(campaignId),
      ),
    );
    if (!mounted) return;
    ref.invalidate(homebrewEntryRowProvider(widget.entityId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homebrewEntryRowProvider(widget.entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading player…'),
      error: (e, _) => CardPlaceholder('Failed to load player: $e'),
      data: (row) {
        final name = row?.name ?? widget.entityId;
        final body = row == null
            ? <String, Object?>{}
            : _decode(row.bodyJson);
        final pClass = (body['class'] as String?) ?? '';
        final pLevel = (body['level'] as int?) ?? 1;
        final pRace = (body['race'] as String?) ?? '';
        final pBackground = (body['background'] as String?) ?? '';
        final pAlignment = (body['alignment'] as String?) ?? '';
        final ac = (body['ac'] as int?) ?? 10;
        final hp = (body['hp'] as int?) ?? 0;
        final hpMax = (body['hpMax'] as int?) ?? hp;
        final initiative = (body['initiative'] as int?) ?? 0;
        final speed = (body['speed'] as int?) ?? 30;
        final proficiency = (body['proficiency'] as int?) ?? 2;
        final abilities = Map<String, int>.from(
            (body['abilities'] as Map?)?.cast<String, Object?>().map(
                      (k, v) => MapEntry(k, (v is int) ? v : 10),
                    ) ??
                const {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10});
        for (final k in const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']) {
          abilities.putIfAbsent(k, () => 10);
        }
        final description = (body['description'] as String?) ?? '';
        final inventory = (body['inventory'] as String?) ?? '';
        final features = (body['features'] as String?) ?? '';
        return CardShell(
          title: name,
          subtitle: _subtitle(pRace, pClass, pLevel, pAlignment),
          categoryColor: widget.categoryColor,
          tags: [
            if (pClass.isNotEmpty) CardTag(pClass),
            if (pRace.isNotEmpty) CardTag(pRace),
            CardTag('Lv $pLevel'),
            CardTag('AC $ac'),
            CardTag('HP $hp/$hpMax'),
          ],
          children: [
            CardFieldGroup(title: 'Identity', children: [
              CardFieldGrid(columns: 2, fields: [
                CardField(
                  label: 'Name',
                  child: InlineTextField(
                    value: name,
                    style: Theme.of(context).textTheme.titleMedium,
                    onCommit: (v) => _save(name: v, body: body),
                  ),
                ),
                CardField(
                  label: 'Class',
                  child: InlineTextField(
                    value: pClass,
                    placeholder: 'e.g. Fighter',
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'class': v}),
                  ),
                ),
                CardField(
                  label: 'Level',
                  child: InlineIntField(
                    value: pLevel,
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'level': v}),
                  ),
                ),
                CardField(
                  label: 'Race',
                  child: InlineTextField(
                    value: pRace,
                    placeholder: 'e.g. Elf',
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'race': v}),
                  ),
                ),
                CardField(
                  label: 'Background',
                  child: InlineTextField(
                    value: pBackground,
                    placeholder: 'e.g. Acolyte',
                    onCommit: (v) => _save(
                        name: name, body: {...body, 'background': v}),
                  ),
                ),
                CardField(
                  label: 'Alignment',
                  child: InlineTextField(
                    value: pAlignment,
                    placeholder: 'e.g. Lawful Good',
                    onCommit: (v) => _save(
                        name: name, body: {...body, 'alignment': v}),
                  ),
                ),
              ]),
            ]),
            CardFieldGroup(title: 'Combat', children: [
              CardFieldGrid(columns: 3, fields: [
                CardField(
                  label: 'Armor Class',
                  child: InlineIntField(
                    value: ac,
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'ac': v}),
                  ),
                ),
                CardField(
                  label: 'Hit Points',
                  child: InlineIntField(
                    value: hp,
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'hp': v}),
                  ),
                ),
                CardField(
                  label: 'Max HP',
                  child: InlineIntField(
                    value: hpMax,
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'hpMax': v}),
                  ),
                ),
                CardField(
                  label: 'Initiative',
                  child: InlineIntField(
                    value: initiative,
                    allowNegative: true,
                    onCommit: (v) => _save(
                        name: name, body: {...body, 'initiative': v}),
                  ),
                ),
                CardField(
                  label: 'Speed',
                  child: InlineIntField(
                    value: speed,
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'speed': v}),
                  ),
                ),
                CardField(
                  label: 'Proficiency',
                  child: InlineIntField(
                    value: proficiency,
                    onCommit: (v) => _save(
                        name: name, body: {...body, 'proficiency': v}),
                  ),
                ),
              ]),
            ]),
            CardFieldGroup(title: 'Abilities', children: [
              _AbilityEditor(
                abilities: abilities,
                onCommit: (key, value) {
                  final next = {...abilities, key: value};
                  _save(name: name, body: {...body, 'abilities': next});
                },
              ),
            ]),
            CardFieldGroup(title: 'Features & Traits', children: [
              InlineTextField(
                value: features,
                maxLines: 8,
                placeholder: 'Class features, racial traits, feats…',
                onCommit: (v) =>
                    _save(name: name, body: {...body, 'features': v}),
              ),
            ]),
            CardFieldGroup(title: 'Inventory', children: [
              InlineTextField(
                value: inventory,
                maxLines: 8,
                placeholder: 'Equipment, consumables, currency…',
                onCommit: (v) =>
                    _save(name: name, body: {...body, 'inventory': v}),
              ),
            ]),
            CardFieldGroup(title: 'Description', children: [
              InlineTextField(
                value: description,
                maxLines: 12,
                placeholder: 'Backstory, personality, appearance…',
                onCommit: (v) =>
                    _save(name: name, body: {...body, 'description': v}),
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _AbilityEditor extends StatelessWidget {
  final Map<String, int> abilities;
  final void Function(String key, int value) onCommit;
  const _AbilityEditor({required this.abilities, required this.onCommit});

  String _mod(int score) {
    final m = (score - 10) ~/ 2;
    return m >= 0 ? '+$m' : '$m';
  }

  @override
  Widget build(BuildContext context) {
    final keys = const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
    return LayoutBuilder(builder: (context, c) {
      final cellW = (c.maxWidth - 12 * 5) / 6;
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final k in keys)
            SizedBox(
              width: cellW < 60 ? c.maxWidth / 3 - 8 : cellW,
              child: Column(
                children: [
                  Text(k,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  InlineIntField(
                    value: abilities[k] ?? 10,
                    textAlign: TextAlign.center,
                    onCommit: (v) => onCommit(k, v),
                  ),
                  Text(_mod(abilities[k] ?? 10),
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      );
    });
  }
}

String _subtitle(String race, String cls, int level, String align) {
  final parts = <String>[];
  if (race.isNotEmpty) parts.add(race);
  if (cls.isNotEmpty) parts.add('$cls $level');
  if (align.isNotEmpty) parts.add(align);
  return parts.isEmpty ? 'Player Character' : parts.join(' • ');
}

Map<String, Object?> _decode(String raw) {
  try {
    final d = jsonDecode(raw);
    if (d is Map) return d.cast<String, Object?>();
  } catch (_) {}
  return <String, Object?>{};
}
