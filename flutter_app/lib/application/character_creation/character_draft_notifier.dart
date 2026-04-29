import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ability_score_method.dart';
import 'character_draft.dart';

/// Wizard-scoped notifier holding a single CharacterDraft. The wizard
/// screen owns one of these via `StateNotifierProvider.autoDispose` so
/// state resets each time the user opens the wizard.
class CharacterDraftNotifier extends StateNotifier<CharacterDraft> {
  CharacterDraftNotifier(super.initial);

  final _rng = Random();

  void setName(String v) => state = state.copyWith(name: v);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setPortrait(String path) => state = state.copyWith(portraitPath: path);
  void setTags(List<String> tags) => state = state.copyWith(tags: tags);
  void setWorld(String name) => state = state.copyWith(worldName: name);
  void setLevel(int v) => state = state.copyWith(level: v.clamp(1, 20));
  void setAlignment(String v) => state = state.copyWith(alignment: v);
  void setRace(String? id) => state = state.copyWith(raceId: id);
  void setClass(String? id) => state = state.copyWith(classId: id);
  void setBackground(String? id) => state = state.copyWith(backgroundId: id);

  void setTemplate({required String id, required String name}) =>
      state = state.copyWith(templateId: id, templateName: name);

  /// Switch ability method. Resets [baseAbilities] to the method's natural
  /// starting layout so a previous method's invalid values don't carry
  /// across (e.g. switching from Random's 18 to Standard Array).
  void setAbilityMethod(AbilityScoreMethod method) {
    state = state.copyWith(
      abilityMethod: method,
      baseAbilities: _initialScoresFor(method),
      racialBonuses: const {
        'STR': 0,
        'DEX': 0,
        'CON': 0,
        'INT': 0,
        'WIS': 0,
        'CHA': 0,
      },
    );
  }

  void setAbility(String key, int value) {
    final next = Map<String, int>.from(state.baseAbilities);
    next[key] = value;
    state = state.copyWith(baseAbilities: next);
  }

  void setRacialBonus(String key, int value) {
    final next = Map<String, int>.from(state.racialBonuses);
    next[key] = value;
    state = state.copyWith(racialBonuses: next);
  }

  /// Roll 4d6 drop-lowest six times. Output is stable in [kAbilityKeys]
  /// order — UI lets the user reroll if unhappy.
  void rollRandomAbilities() {
    final rolls = <int>[];
    for (var i = 0; i < 6; i++) {
      final dice = [
        1 + _rng.nextInt(6),
        1 + _rng.nextInt(6),
        1 + _rng.nextInt(6),
        1 + _rng.nextInt(6),
      ];
      dice.sort();
      rolls.add(dice[1] + dice[2] + dice[3]);
    }
    final next = <String, int>{};
    for (var i = 0; i < kAbilityKeys.length; i++) {
      next[kAbilityKeys[i]] = rolls[i];
    }
    state = state.copyWith(baseAbilities: next);
  }

  Map<String, int> _initialScoresFor(AbilityScoreMethod method) {
    return switch (method) {
      AbilityScoreMethod.standardArray => {
          'STR': 15,
          'DEX': 14,
          'CON': 13,
          'INT': 12,
          'WIS': 10,
          'CHA': 8,
        },
      AbilityScoreMethod.pointBuy => {
          'STR': 8,
          'DEX': 8,
          'CON': 8,
          'INT': 8,
          'WIS': 8,
          'CHA': 8,
        },
      AbilityScoreMethod.random ||
      AbilityScoreMethod.manual =>
        {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10},
    };
  }
}

final characterDraftProvider = StateNotifierProvider.autoDispose<
    CharacterDraftNotifier, CharacterDraft>((ref) {
  return CharacterDraftNotifier(const CharacterDraft());
});
