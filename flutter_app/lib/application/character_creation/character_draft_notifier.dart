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
  /// Picks a world. Clears any package-source selection — world and
  /// standalone packages are mutually exclusive content sources.
  void setWorld(String name) => state = state.copyWith(
        worldName: name,
        sourcePackages: name.isEmpty ? state.sourcePackages : const [],
      );

  /// Selects standalone content packages as extra entity sources. Clears
  /// [worldName] so the wizard runs in built-in + packages mode.
  void setSourcePackages(List<String> names) => state = state.copyWith(
        sourcePackages: List.unmodifiable(names),
        worldName: names.isEmpty ? state.worldName : '',
      );
  void setLevel(int v) => state = state.copyWith(level: v.clamp(1, 20));
  void setAlignment(String v) => state = state.copyWith(alignment: v);
  void setRace(String? id) => state = state.copyWith(
        raceId: id,
        // Subspecies is scoped to the parent species — switching species
        // invalidates any prior pick.
        subspeciesId: null,
      );
  void setSubspecies(String? key) =>
      state = state.copyWith(subspeciesId: key);
  void setClass(String? id) => state = state.copyWith(
        classId: id,
        subclassId: null,
        // Skill/tool/spell choices are class-scoped — switching class
        // invalidates them. Weapon Mastery picks and L1 Order pick are also
        // class-scoped (count, filter, and feat options all depend on the
        // chosen class), as is the Rogue/Druid bonus-language slot.
        skillChoiceIds: const [],
        toolChoiceIds: const [],
        cantripIds: const [],
        preparedSpellIds: const [],
        weaponMasteryChoiceIds: const [],
        bonusLanguageChoiceIds: const [],
        l1OrderChoiceId: null,
      );
  void setBackground(String? id) => state = state.copyWith(
        backgroundId: id,
        // Background tool variant pick (e.g. Soldier Gaming Set variant)
        // belongs to the chosen background — reset on swap.
        backgroundToolVariantId: null,
      );
  void setSubclass(String? id) => state = state.copyWith(subclassId: id);

  void setEquipmentChoice(String groupId, String optionId) {
    state = state.copyWith(
      equipmentChoices: {...state.equipmentChoices, groupId: optionId},
    );
  }

  /// Toggle a skill choice. Caller is responsible for capping the picked
  /// list against the class's `skill_proficiency_choice_count` — when the
  /// cap is exceeded we no-op so the UI's disabled state matches stored
  /// state.
  void toggleSkillChoice(String id, {required int cap}) {
    final ids = [...state.skillChoiceIds];
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      if (ids.length >= cap) return;
      ids.add(id);
    }
    state = state.copyWith(skillChoiceIds: ids);
  }

  void clearSkillChoices() =>
      state = state.copyWith(skillChoiceIds: const []);

  void toggleToolChoice(String id, {required int cap}) {
    final ids = [...state.toolChoiceIds];
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      if (ids.length >= cap) return;
      ids.add(id);
    }
    state = state.copyWith(toolChoiceIds: ids);
  }

  void clearToolChoices() =>
      state = state.copyWith(toolChoiceIds: const []);

  void toggleLanguageChoice(String id, {required int cap}) {
    final ids = [...state.languageChoiceIds];
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      if (ids.length >= cap) return;
      ids.add(id);
    }
    state = state.copyWith(languageChoiceIds: ids);
  }

  void clearLanguageChoices() =>
      state = state.copyWith(languageChoiceIds: const []);

  void toggleBonusLanguageChoice(String id, {required int cap}) {
    final ids = [...state.bonusLanguageChoiceIds];
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      if (ids.length >= cap) return;
      ids.add(id);
    }
    state = state.copyWith(bonusLanguageChoiceIds: ids);
  }

  void toggleWeaponMasteryChoice(String id, {required int cap}) {
    final ids = [...state.weaponMasteryChoiceIds];
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      if (ids.length >= cap) return;
      ids.add(id);
    }
    state = state.copyWith(weaponMasteryChoiceIds: ids);
  }

  void setBackgroundToolVariant(String? variantId) =>
      state = state.copyWith(backgroundToolVariantId: variantId);

  void setL1OrderChoice(String? featId) =>
      state = state.copyWith(l1OrderChoiceId: featId);

  void toggleCantrip(String id, {required int cap}) {
    final ids = [...state.cantripIds];
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      if (ids.length >= cap) return;
      ids.add(id);
    }
    state = state.copyWith(cantripIds: ids);
  }

  void togglePreparedSpell(String id, {required int cap}) {
    final ids = [...state.preparedSpellIds];
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      if (ids.length >= cap) return;
      ids.add(id);
    }
    state = state.copyWith(preparedSpellIds: ids);
  }

  void clearSpellChoices() => state = state.copyWith(
        cantripIds: const [],
        preparedSpellIds: const [],
      );

  void setPersonalityTraits(String v) =>
      state = state.copyWith(personalityTraits: v);
  void setIdeals(String v) => state = state.copyWith(ideals: v);
  void setBonds(String v) => state = state.copyWith(bonds: v);
  void setFlaws(String v) => state = state.copyWith(flaws: v);
  void setBackstory(String v) => state = state.copyWith(backstory: v);
  void setTrinket(String v) => state = state.copyWith(trinket: v);

  /// Roll a Tiny trinket from the SRD d100 table. Caller provides the
  /// table so the notifier stays Flutter-free; the personality step
  /// passes [kSrdTrinkets].
  void rollTrinket(List<String> table) {
    if (table.isEmpty) return;
    final pick = table[_rng.nextInt(table.length)];
    state = state.copyWith(trinket: pick);
  }

  void setFeatIds(List<String> ids) =>
      state = state.copyWith(featIds: List.unmodifiable(ids));
  void addFeatId(String id) {
    if (state.featIds.contains(id)) return;
    state = state.copyWith(featIds: [...state.featIds, id]);
  }
  void removeFeatId(String id) {
    state = state.copyWith(
      featIds: [for (final f in state.featIds) if (f != id) f],
    );
  }
  void setOriginFeatChoice(String key, String optionId) {
    state = state.copyWith(
      originFeatChoices: {...state.originFeatChoices, key: optionId},
    );
  }

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

  /// Standard Array: assign [value] to [key]. If another ability already
  /// holds [value], the two abilities swap values so the array stays a
  /// valid permutation (no duplicate, none dropped).
  void swapAbility(String key, int value) {
    final next = Map<String, int>.from(state.baseAbilities);
    final previous = next[key];
    for (final k in kAbilityKeys) {
      if (k != key && next[k] == value) {
        next[k] = previous ?? value;
        break;
      }
    }
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
