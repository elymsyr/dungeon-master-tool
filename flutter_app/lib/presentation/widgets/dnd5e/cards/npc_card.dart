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
import 'monster_card.dart';

/// NPC card. Three render paths:
/// - `srd:*` id → pass through to [MonsterCard] (SRD creature reused as NPC).
/// - `hb:*` id pointing at the `monsters` typed table → [MonsterCard].
/// - Otherwise → homebrew-entries backed layout matching MonsterCard's
///   paper + grouped style (Identity / Combat / Abilities / Traits /
///   Description) with inline editing on every scalar.
class NpcCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const NpcCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<NpcCard> createState() => _NpcCardState();
}

class _NpcCardState extends ConsumerState<NpcCard> {
  Future<void> _save({
    required String name,
    required Map<String, Object?> body,
  }) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    final db = ref.read(appDatabaseProvider);
    await db.dnd5eContentDao.upsertHomebrewEntry(
      HomebrewEntriesCompanion.insert(
        id: widget.entityId,
        categorySlug: 'npc',
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
    final monsterRow = ref.watch(monsterRowProvider(widget.entityId));
    if (monsterRow.valueOrNull != null) {
      return MonsterCard(
        entityId: widget.entityId,
        categoryColor: widget.categoryColor,
      );
    }

    final async = ref.watch(homebrewEntryRowProvider(widget.entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading NPC…'),
      error: (e, _) => CardPlaceholder('Failed to load NPC: $e'),
      data: (row) {
        final name = row?.name ?? widget.entityId;
        final body =
            row == null ? <String, Object?>{} : _decode(row.bodyJson);
        final role = (body['role'] as String?) ?? '';
        final location = (body['location'] as String?) ?? '';
        final disposition = (body['disposition'] as String?) ?? '';
        final alignment = (body['alignment'] as String?) ?? '';
        final race = (body['race'] as String?) ?? '';
        final cr = (body['cr'] as String?) ?? '—';
        final ac = (body['ac'] as int?) ?? 10;
        final hp = (body['hp'] as int?) ?? 0;
        final speed = (body['speed'] as int?) ?? 30;
        final abilities = Map<String, int>.from(
            (body['abilities'] as Map?)?.cast<String, Object?>().map(
                      (k, v) => MapEntry(k, (v is int) ? v : 10),
                    ) ??
                const {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10});
        for (final k in const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']) {
          abilities.putIfAbsent(k, () => 10);
        }
        final traits = (body['traits'] as String?) ?? '';
        final actions = (body['actions'] as String?) ?? '';
        final description = (body['description'] as String?) ?? '';
        return CardShell(
          title: name,
          subtitle: _subtitle(race, role, alignment),
          categoryColor: widget.categoryColor,
          tags: [
            if (role.isNotEmpty) CardTag(role),
            if (disposition.isNotEmpty) CardTag(disposition),
            CardTag('CR $cr'),
            CardTag('AC $ac'),
            CardTag('HP $hp'),
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
                  label: 'Role',
                  child: InlineTextField(
                    value: role,
                    placeholder: 'e.g. Innkeeper',
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'role': v}),
                  ),
                ),
                CardField(
                  label: 'Race',
                  child: InlineTextField(
                    value: race,
                    placeholder: 'e.g. Human',
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'race': v}),
                  ),
                ),
                CardField(
                  label: 'Alignment',
                  child: InlineTextField(
                    value: alignment,
                    placeholder: 'e.g. Neutral Good',
                    onCommit: (v) => _save(
                        name: name, body: {...body, 'alignment': v}),
                  ),
                ),
                CardField(
                  label: 'Location',
                  child: InlineTextField(
                    value: location,
                    placeholder: 'Where they live',
                    onCommit: (v) => _save(
                        name: name, body: {...body, 'location': v}),
                  ),
                ),
                CardField(
                  label: 'Disposition',
                  child: InlineTextField(
                    value: disposition,
                    placeholder: 'Friendly / Neutral / Hostile',
                    onCommit: (v) => _save(
                        name: name, body: {...body, 'disposition': v}),
                  ),
                ),
              ]),
            ]),
            CardFieldGroup(title: 'Combat', children: [
              CardFieldGrid(columns: 4, fields: [
                CardField(
                  label: 'CR',
                  child: InlineTextField(
                    value: cr,
                    placeholder: '1/4',
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'cr': v}),
                  ),
                ),
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
                  label: 'Speed',
                  child: InlineIntField(
                    value: speed,
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'speed': v}),
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
            CardFieldGroup(title: 'Traits', children: [
              InlineTextField(
                value: traits,
                maxLines: 8,
                placeholder: 'Passives, senses, languages, resistances…',
                onCommit: (v) =>
                    _save(name: name, body: {...body, 'traits': v}),
              ),
            ]),
            CardFieldGroup(title: 'Actions', children: [
              InlineTextField(
                value: actions,
                maxLines: 8,
                placeholder: 'Attack patterns, special actions…',
                onCommit: (v) =>
                    _save(name: name, body: {...body, 'actions': v}),
              ),
            ]),
            CardFieldGroup(title: 'Description', children: [
              InlineTextField(
                value: description,
                maxLines: 12,
                placeholder: 'Appearance, personality, plot hooks…',
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

String _subtitle(String race, String role, String alignment) {
  final parts = <String>[];
  if (race.isNotEmpty) parts.add(race);
  if (role.isNotEmpty) parts.add(role);
  if (alignment.isNotEmpty) parts.add(alignment);
  return parts.isEmpty ? 'Non-Player Character' : parts.join(' • ');
}

Map<String, Object?> _decode(String raw) {
  try {
    final d = jsonDecode(raw);
    if (d is Map) return d.cast<String, Object?>();
  } catch (_) {}
  return <String, Object?>{};
}
