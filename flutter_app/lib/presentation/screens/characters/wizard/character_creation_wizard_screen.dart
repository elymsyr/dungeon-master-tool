import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../application/character_creation/ability_score_method.dart';
import '../../../../application/character_creation/ability_score_validator.dart';
import '../../../../application/character_creation/character_draft.dart';
import '../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/character_provider.dart';
import '../../../../application/providers/entity_provider.dart';
import '../../../../application/providers/role_provider.dart';
import '../../../../application/providers/template_provider.dart';
import '../../../../application/services/builtin_srd_entities.dart';
import '../../../../domain/entities/entity.dart';
import '../../../../domain/entities/schema/dnd5e_constants.dart'
    show kDnd5eSkills, kDnd5eSavingThrows;
import '../../../../domain/entities/schema/entity_category_schema.dart';
import '../../../../domain/entities/schema/world_schema.dart';
import '../../../theme/dm_tool_colors.dart';
import '../../../../application/character_creation/caster_progression.dart';
import '../../../../application/character_creation/level_up_planner.dart';
import '../../../../application/character_creation/pending_choices.dart';
import 'steps/equipment_step.dart';
import 'steps/feats_step.dart';
import 'steps/personality_step.dart';
import 'steps/proficiencies_step.dart';
import 'steps/spells_step.dart';
import 'steps/subclass_step.dart';

/// Multi-step D&D 5e character creation wizard. Authors a [CharacterDraft]
/// across six steps then commits via `characterListProvider.create`,
/// seeding the player entity's fields with the wizard's collected
/// answers.
///
/// Launched from the Characters hub tab. Closes by routing to the new
/// character's editor on finish, or popping on cancel.
class CharacterCreationWizardScreen extends ConsumerStatefulWidget {
  const CharacterCreationWizardScreen({super.key});

  @override
  ConsumerState<CharacterCreationWizardScreen> createState() =>
      _CharacterCreationWizardScreenState();
}

class _CharacterCreationWizardScreenState
    extends ConsumerState<CharacterCreationWizardScreen> {
  int _currentStep = 0;
  bool _committing = false;
  bool _activatingWorld = false;
  String? _lastActivatedWorld;

  @override
  void initState() {
    super.initState();
    // Force-refresh the world list providers on mount. Cold-start + auto-open
    // flows otherwise let the wizard render against a stale snapshot that
    // includes worlds the user deleted in a prior session (file legacy +
    // DB-merged source). Re-entering the wizard used to fix it because
    // some other surface had invalidated in the meantime — invalidating
    // here makes the behavior deterministic.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(campaignListProvider);
      ref.invalidate(campaignInfoListProvider);
      _pickActiveWorldIfAny();
    });
  }

  /// Reads activeCampaignProvider; falls back to `activeCampaignIdProvider`
  /// + `campaignInfoListProvider` to handle the cold-open race where the
  /// campaign name notifier hasn't propagated yet but the id is already
  /// resolved. Without the fallback, hitting "Create Character" on the
  /// first frame after opening a world produced a worldless draft.
  void _pickActiveWorldIfAny() {
    final draft = ref.read(characterDraftProvider);
    if (draft.worldName.isNotEmpty) return;
    final activeWorld = ref.read(activeCampaignProvider);
    if (activeWorld != null && activeWorld.isNotEmpty) {
      ref.read(characterDraftProvider.notifier).setWorld(activeWorld);
      return;
    }
    final activeId = ref.read(activeCampaignIdProvider).valueOrNull;
    if (activeId == null) return;
    final infos = ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    final match = infos.where((i) => i.id == activeId).firstOrNull;
    if (match == null) return;
    ref.read(characterDraftProvider.notifier).setWorld(match.name);
  }

  /// Entity source the wizard reads from. Active campaign's entities when
  /// the user picked a world, otherwise the bundled SRD map so race /
  /// class / background pickers stay populated without any DB write.
  Map<String, Entity> _wizardEntities() {
    final draft = ref.read(characterDraftProvider);
    final builtin = ref.read(builtinSrdEntitiesProvider);
    if (draft.worldName.isEmpty) return builtin;
    final campaign = ref.read(entityProvider);
    return mergeWithBuiltinSrd(campaign, builtin, useCampaign: true);
  }

  Future<void> _activateWorld(String name) async {
    if (_lastActivatedWorld == name) return;
    final current = ref.read(activeCampaignProvider);
    if (current == name) {
      _lastActivatedWorld = name;
      return;
    }
    setState(() => _activatingWorld = true);
    try {
      await ref.read(activeCampaignProvider.notifier).load(name);
      _lastActivatedWorld = name;
    } finally {
      if (mounted) setState(() => _activatingWorld = false);
    }
  }

  static const _alignments = [
    'Lawful Good', 'Neutral Good', 'Chaotic Good',
    'Lawful Neutral', 'True Neutral', 'Chaotic Neutral',
    'Lawful Evil', 'Neutral Evil', 'Chaotic Evil',
    'Unaligned',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final draft = ref.watch(characterDraftProvider);
    final notifier = ref.read(characterDraftProvider.notifier);
    final templatesAsync = ref.watch(allTemplatesProvider);
    final campaignsAsync = ref.watch(campaignListProvider);
    // Cold-open race: activeCampaignProvider may arrive after initState's
    // postFrame. Watch both name + id providers and re-pick whenever they
    // settle, as long as the user hasn't explicitly picked a world yet.
    ref.listen<String?>(activeCampaignProvider, (_, _) {
      if (mounted) _pickActiveWorldIfAny();
    });
    ref.listen<AsyncValue<String?>>(activeCampaignIdProvider, (_, _) {
      if (mounted) _pickActiveWorldIfAny();
    });
    ref.listen(campaignInfoListProvider, (_, _) {
      if (mounted) _pickActiveWorldIfAny();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Character'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _committing ? null : () => context.pop(),
        ),
      ),
      backgroundColor: palette.srdParchment,
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Template load error: $e')),
        data: (templates) {
          final playerTemplates = templates
              .where((t) => findPlayerCategory(t) != null)
              .toList();
          if (playerTemplates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No template with a Player category is available. '
                  'Add one in the Templates tab first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.sidebarLabelSecondary),
                ),
              ),
            );
          }
          return campaignsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('World load error: $e')),
            data: (worlds) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  onStepTapped: (i) {
                    final firstError = _firstErrorBefore(i, draft);
                    if (firstError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(firstError)),
                      );
                      return;
                    }
                    setState(() => _currentStep = i);
                  },
                  onStepContinue: () {
                    final err = _validateStep(_currentStep, draft);
                    if (err != null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(err)));
                      return;
                    }
                    if (_currentStep == _stepCount - 1) {
                      _commit(draft, playerTemplates);
                    } else {
                      setState(() => _currentStep += 1);
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep == 0) {
                      context.pop();
                    } else {
                      setState(() => _currentStep -= 1);
                    }
                  },
                  controlsBuilder: (ctx, details) {
                    final isLast = _currentStep == _stepCount - 1;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          FilledButton(
                            onPressed:
                                _committing ? null : details.onStepContinue,
                            child: _committing && isLast
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(isLast ? 'Create' : 'Continue'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed:
                                _committing ? null : details.onStepCancel,
                            child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                          ),
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('Identity'),
                      isActive: _currentStep >= 0,
                      state: _stateFor(0, draft),
                      content: _StepBody(
                        active: _currentStep == 0,
                        child: _IdentityStep(
                          draft: draft,
                          notifier: notifier,
                          worlds: worlds,
                          templates: playerTemplates,
                          alignments: _alignments,
                          activatingWorld: _activatingWorld,
                          onWorldPicked: _activateWorld,
                        ),
                      ),
                    ),
                    Step(
                      title: const Text('Race / Species'),
                      isActive: _currentStep >= 1,
                      state: _stateFor(1, draft),
                      content: _StepBody(
                        active: _currentStep == 1,
                        child: _RaceStep(draft: draft, notifier: notifier),
                      ),
                    ),
                    Step(
                      title: const Text('Class'),
                      isActive: _currentStep >= 2,
                      state: _stateFor(2, draft),
                      content: _StepBody(
                        active: _currentStep == 2,
                        child: _EntityPickStep(
                          title: 'Class',
                          slugs: const ['class'],
                          selectedId: draft.classId,
                          onChanged: notifier.setClass,
                        ),
                      ),
                    ),
                    Step(
                      title: const Text('Subclass'),
                      isActive: _currentStep >= 3,
                      state: _stateFor(3, draft),
                      content: _StepBody(
                        active: _currentStep == 3,
                        child:
                            SubclassStep(draft: draft, notifier: notifier),
                      ),
                    ),
                    Step(
                      title: const Text('Background'),
                      isActive: _currentStep >= 4,
                      state: _stateFor(4, draft),
                      content: _StepBody(
                        active: _currentStep == 4,
                        child: _EntityPickStep(
                          title: 'Background',
                          slugs: const ['background'],
                          selectedId: draft.backgroundId,
                          onChanged: notifier.setBackground,
                          optional: true,
                        ),
                      ),
                    ),
                    Step(
                      title: const Text('Abilities'),
                      isActive: _currentStep >= 5,
                      state: _stateFor(5, draft),
                      content: _StepBody(
                        active: _currentStep == 5,
                        child:
                            _AbilitiesStep(draft: draft, notifier: notifier),
                      ),
                    ),
                    Step(
                      title: const Text('Feats'),
                      isActive: _currentStep >= 6,
                      state: _stateFor(6, draft),
                      content: _StepBody(
                        active: _currentStep == 6,
                        child: FeatsStep(draft: draft, notifier: notifier),
                      ),
                    ),
                    Step(
                      title: const Text('Proficiencies & Languages'),
                      isActive: _currentStep >= 7,
                      state: _stateFor(7, draft),
                      content: _StepBody(
                        active: _currentStep == 7,
                        child: ProficienciesStep(
                            draft: draft, notifier: notifier),
                      ),
                    ),
                    Step(
                      title: const Text('Spells'),
                      isActive: _currentStep >= 8,
                      state: _stateFor(8, draft),
                      content: _StepBody(
                        active: _currentStep == 8,
                        child:
                            SpellsStep(draft: draft, notifier: notifier),
                      ),
                    ),
                    Step(
                      title: const Text('Equipment'),
                      isActive: _currentStep >= 9,
                      state: _stateFor(9, draft),
                      content: _StepBody(
                        active: _currentStep == 9,
                        child:
                            EquipmentStep(draft: draft, notifier: notifier),
                      ),
                    ),
                    Step(
                      title: const Text('Personality & Flavor'),
                      isActive: _currentStep >= 10,
                      state: _stateFor(10, draft),
                      content: _StepBody(
                        active: _currentStep == 10,
                        child: PersonalityStep(
                            draft: draft, notifier: notifier),
                      ),
                    ),
                    Step(
                      title: const Text('Review'),
                      isActive: _currentStep >= 11,
                      state: _stateFor(11, draft),
                      content: _StepBody(
                        active: _currentStep == 11,
                        child: _ReviewStep(draft: draft),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static const _stepCount = 12;

  StepState _stateFor(int index, CharacterDraft draft) {
    if (_currentStep == index) return StepState.editing;
    if (_validateStep(index, draft) == null) return StepState.complete;
    return StepState.indexed;
  }

  String? _firstErrorBefore(int target, CharacterDraft draft) {
    for (var i = 0; i < target; i++) {
      final err = _validateStep(i, draft);
      if (err != null) return 'Step ${i + 1}: $err';
    }
    return null;
  }

  String? _validateStep(int index, CharacterDraft draft) {
    return switch (index) {
      0 => _validateIdentity(draft),
      1 => draft.raceId == null ? 'Pick a race.' : null,
      2 => draft.classId == null ? 'Pick a class.' : null,
      3 => null,
      4 => null,
      5 => AbilityScoreValidator.validate(
              method: draft.abilityMethod,
              scores: draft.baseAbilities,
            ) ??
            AbilityScoreValidator.validateBackgroundAsi(draft.racialBonuses),
      6 => validateFeatsStep(draft, _wizardEntities()),
      7 => _validateProficiencies(draft),
      8 => _validateSpells(draft),
      9 => null,
      10 => null, // personality is optional
      11 => null,
      _ => null,
    };
  }

  /// Spell-pick caps check. Mirrors the Spells step's own derivation so
  /// the wizard can flag an incomplete picker. Empty spell catalogs in
  /// the active campaign suppress the check — no fail on missing data.
  String? _validateSpells(CharacterDraft draft) {
    final entities = _wizardEntities();
    final classEntity =
        draft.classId == null ? null : entities[draft.classId];
    if (classEntity == null) return null;
    final kind = parseCasterKind(classEntity.fields['caster_kind']);
    if (kind == CasterKind.none) return null;

    final cantripCap = levelTableValue(
            classEntity.fields['cantrips_known_by_level'], draft.level) ??
        defaultCantripsKnown(kind, draft.level);
    final preparedCap = levelTableValue(
            classEntity.fields['prepared_spells_by_level'], draft.level) ??
        defaultPreparedSpells(kind, draft.level);

    final spellCount = entities.values
        .where((e) =>
            e.categorySlug == 'spell' &&
            (e.fields['class_refs'] is List) &&
            (e.fields['class_refs'] as List).contains(draft.classId))
        .length;
    if (spellCount == 0) return null;

    // Spell slots are no longer required to be filled — players may leave
    // them empty and pick remaining spells in the editor later. Only fail
    // when the draft somehow holds *more* than the SRD cap.
    if (cantripCap > 0 && draft.cantripIds.length > cantripCap) {
      return 'Pick at most $cantripCap cantrip(s).';
    }
    if (preparedCap > 0 && draft.preparedSpellIds.length > preparedCap) {
      return 'Pick at most $preparedCap spell(s).';
    }
    return null;
  }

  /// Caps check for the Proficiencies & Languages step. We can only know
  /// the caps when the class and background entities are already loaded,
  /// so look them up here rather than relying on draft-only data. Empty
  /// option lists in the active campaign suppress the cap — the wizard
  /// shouldn't block when the world author hasn't seeded the lookup yet.
  String? _validateProficiencies(CharacterDraft draft) {
    final entities = _wizardEntities();
    int intField(Entity? e, String key) {
      final v = e?.fields[key];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    List<String> listField(Entity? e, String key) {
      final v = e?.fields[key];
      if (v is List) return v.whereType<String>().toList();
      return const [];
    }

    final classEntity =
        draft.classId == null ? null : entities[draft.classId];
    final background =
        draft.backgroundId == null ? null : entities[draft.backgroundId];
    final skillCap = intField(classEntity, 'skill_proficiency_choice_count');
    final toolCap = intField(classEntity, 'tool_proficiency_count');
    final languageCap = intField(background, 'granted_language_count');
    final skillOptionsCount =
        listField(classEntity, 'skill_proficiency_options').length;
    final toolOptionsCount =
        listField(classEntity, 'tool_proficiency_options').length;
    final languageOptionsCount =
        entities.values.where((e) => e.categorySlug == 'language').length;

    // Caps are upper bounds only — players may leave some slots empty and
    // pick remaining proficiencies in the editor later. Only fail when the
    // draft exceeds the SRD cap.
    if (skillCap > 0 &&
        skillOptionsCount > 0 &&
        draft.skillChoiceIds.length > skillCap) {
      return 'Pick at most $skillCap class skill(s).';
    }
    if (toolCap > 0 &&
        toolOptionsCount > 0 &&
        draft.toolChoiceIds.length > toolCap) {
      return 'Pick at most $toolCap class tool(s).';
    }
    if (languageCap > 0 &&
        languageOptionsCount > 0 &&
        draft.languageChoiceIds.length > languageCap) {
      return 'Pick at most $languageCap language(s).';
    }
    return null;
  }

  String? _validateIdentity(CharacterDraft d) {
    if (d.name.trim().isEmpty) return 'Name required.';
    if (d.templateId.isEmpty) return 'Template required.';
    // World is optional — when left blank the commit step falls back to
    // the auto-provisioned SRD 5.2.1 default world.
    if (d.level < 1 || d.level > 20) return 'Level must be 1-20.';
    return null;
  }

  Future<void> _commit(
    CharacterDraft draft,
    List<WorldSchema> templates,
  ) async {
    final template = templates
        .where((t) => t.schemaId == draft.templateId)
        .firstOrNull;
    if (template == null) {
      _snack('Selected template no longer available.');
      return;
    }
    final playerCat = findPlayerCategory(template);
    if (playerCat == null) {
      _snack('Template has no Player category.');
      return;
    }
    setState(() => _committing = true);
    try {
      // Empty world is intentional — the character runs against the
      // bundled SRD entity map. Editor falls back to
      // [builtinSrdEntitiesProvider] when worldId is null.
      final worldName = draft.worldName;
      String? resolvedWorldId;
      if (worldName.isNotEmpty) {
        final infos =
            ref.read(campaignInfoListProvider).valueOrNull ?? const [];
        resolvedWorldId =
            infos.where((i) => i.name == worldName).firstOrNull?.id;
      }
      // Cold-open fallback: draft.worldName may still be empty if the user
      // hit Create before activeCampaignProvider populated. Use the
      // canonical id directly so the new char binds to the open world
      // instead of becoming orphan.
      resolvedWorldId ??= ref.read(activeCampaignIdProvider).valueOrNull;
      final entities = _wizardEntities();
      Entity? lookup(String? id) =>
          id == null ? null : entities[id];

      final featContributions =
          deriveFeatChoiceContributions(draft, entities);
      final seed = buildSeedFields(
        draft: draft,
        playerCat: playerCat,
        race: lookup(draft.raceId),
        characterClass: lookup(draft.classId),
        background: lookup(draft.backgroundId),
        featContributions: featContributions,
        entities: entities,
      );

      final created =
          await ref.read(characterListProvider.notifier).create(
                name: draft.name.trim(),
                template: template,
                worldId: resolvedWorldId,
                description: draft.description.trim(),
                tags: draft.tags,
                portraitPath: draft.portraitPath,
                seedFields: seed,
              );
      if (!mounted) return;
      context.pushReplacement('/character/${created.id}');
    } catch (e) {
      if (mounted) _snack('Failed to create character: $e');
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Builds the entity.fields map seed: ability scores, level, alignment,
/// race/class/background relations, derived combat stats. Pure; no UI.
///
/// Field keys vary across templates (v2 builtin uses `species_ref` /
/// `class_refs` / `background_ref` / `alignment_ref`; legacy default uses
/// `race` / `class_` / `background` / `alignment`). Each conceptual seed
/// resolves to whichever key the [playerCat] actually exposes, so the
/// wizard works on both schemas without forking.
Map<String, dynamic> buildSeedFields({
  required CharacterDraft draft,
  required EntityCategorySchema playerCat,
  required Entity? race,
  required Entity? characterClass,
  required Entity? background,
  FeatChoiceContributions? featContributions,
  Map<String, Entity> entities = const {},
}) {
  final featBumps = featContributions?.abilityBumps ?? const <String, int>{};
  // SRD 2024 p.83: background ASIs (`draft.racialBonuses`) flow through the
  // separate `background_asi` field so [CharacterResolver] can gate them by
  // `background.ability_score_options` and surface the source on the sheet.
  // `base_abilities` stays the raw allocation (point buy / standard array /
  // random) plus feat choice-group ability picks (which the wizard resolves
  // pre-save because the resolver does not currently walk feat choice groups).
  // `stat_block` keeps the fully summed view so the editor stat chips render
  // without re-running the resolver.
  final rawWithFeat = <String, int>{
    for (final k in kAbilityKeys)
      k: (draft.baseAbilities[k] ?? 10) + (featBumps[k] ?? 0),
  };
  final stat = <String, int>{
    for (final k in kAbilityKeys)
      k: rawWithFeat[k]! + (draft.racialBonuses[k] ?? 0),
  };
  final backgroundAsi = <String, int>{
    for (final k in kAbilityKeys)
      if ((draft.racialBonuses[k] ?? 0) != 0) k: draft.racialBonuses[k]!,
  };
  final conMod = abilityModifier(stat['CON'] ?? 10);
  final dexMod = abilityModifier(stat['DEX'] ?? 10);

  final hitDie = _parseHitDie(characterClass?.fields['hit_die']);
  final maxHp = hitDie + conMod +
      (draft.level - 1) * ((hitDie ~/ 2) + 1 + conMod);
  final profBonus = 2 + ((draft.level - 1) ~/ 4);

  final fieldsByKey = {for (final f in playerCat.fields) f.fieldKey: f};

  void writeRelation(
    Map<String, dynamic> out,
    List<String> candidateKeys,
    String? entityId,
  ) {
    if (entityId == null) return;
    for (final key in candidateKeys) {
      final f = fieldsByKey[key];
      if (f == null) continue;
      out[key] = f.isList ? [entityId] : entityId;
      return;
    }
  }

  void writeScalar(
    Map<String, dynamic> out,
    List<String> candidateKeys,
    Object value,
  ) {
    for (final key in candidateKeys) {
      if (!fieldsByKey.containsKey(key)) continue;
      out[key] = value;
      return;
    }
  }

  final out = <String, dynamic>{};
  if (fieldsByKey.containsKey('stat_block')) {
    out['stat_block'] = stat;
  }
  writeScalar(out, const ['level'], draft.level);
  if (draft.alignment.isNotEmpty) {
    writeScalar(out, const ['alignment_ref', 'alignment'], draft.alignment);
  }
  writeRelation(out, const ['species_ref', 'race'], race?.id);
  writeRelation(out, const ['class_refs', 'class_'], characterClass?.id);
  writeRelation(out, const ['background_ref', 'background'], background?.id);
  writeScalar(out, const ['proficiency_bonus'], profBonus);
  // Species drives Walk speed & size — fall back to SRD medium humanoid
  // defaults when the species entity hasn't been populated yet.
  final speedFt = race?.fields['speed_ft'] is int
      ? race!.fields['speed_ft'] as int
      : 30;
  final sizeRef = race?.fields['size_ref'] is String
      ? race!.fields['size_ref'] as String
      : null;
  if (fieldsByKey.containsKey('combat_stats')) {
    out['combat_stats'] = {
      'hp': maxHp,
      'max_hp': maxHp,
      'ac': 10 + dexMod,
      'speed': '$speedFt ft',
      'level': draft.level,
      'initiative': dexMod >= 0 ? '+$dexMod' : '$dexMod',
      'cr': '',
      'xp': 0,
    };
  }
  if (fieldsByKey.containsKey('speed_walk_ft')) {
    out['speed_walk_ft'] = speedFt;
  }
  for (final extra in const [
    'speed_burrow_ft',
    'speed_climb_ft',
    'speed_fly_ft',
    'speed_swim_ft',
  ]) {
    if (!fieldsByKey.containsKey(extra)) continue;
    final v = race?.fields[extra];
    if (v is int && v > 0) out[extra] = v;
  }
  if (sizeRef != null && fieldsByKey.containsKey('size_ref')) {
    out['size_ref'] = sizeRef;
  }
  if (fieldsByKey.containsKey('xp')) out['xp'] = 0;
  if (fieldsByKey.containsKey('initiative_modifier')) {
    out['initiative_modifier'] = dexMod;
  }

  // Class levels — v2 schema's class_levels levelTable expects
  // {classSlug: level}. Seed if class chosen.
  if (characterClass != null && fieldsByKey.containsKey('class_levels')) {
    out['class_levels'] = {characterClass.id: draft.level};
  }

  // Resolver inputs — these keys are read by CharacterResolver. They live
  // outside the player-category schema (template-agnostic) so we always
  // write them regardless of fieldsByKey.
  out['race_id'] = draft.raceId ?? '';
  out['subspecies_id'] = draft.subspeciesId ?? '';
  out['background_id'] = draft.backgroundId ?? '';
  out['subclass_id'] = draft.subclassId ?? '';
  out['feat_ids'] = [
    if (background?.fields['origin_feat_ref'] is String)
      background!.fields['origin_feat_ref'] as String,
    ...draft.featIds,
  ];
  // Mirror onto the visible `feats` relation list so the card renders them.
  if (fieldsByKey.containsKey('feats')) {
    final featIds = (out['feat_ids'] as List).whereType<String>().toList();
    out['feats'] = featIds;
  }
  out['equipment_choices'] = Map<String, String>.from(draft.equipmentChoices);
  out['feat_choices'] = Map<String, String>.from(draft.originFeatChoices);
  out['base_abilities'] = rawWithFeat;
  out['background_asi'] = backgroundAsi;
  // Class skill/tool picks + background language picks. Mirrored to the PC
  // category's matching ref lists when present so the editor renders them
  // without further work.
  final featSkillIds = featContributions?.skillIds ?? const <String>[];
  final featToolIds = featContributions?.toolIds ?? const <String>[];
  final featCantripIds = featContributions?.cantripIds ?? const <String>[];
  final featPreparedIds = featContributions?.preparedSpellIds ?? const <String>[];
  out['skill_choice_ids'] = [
    ...draft.skillChoiceIds,
    for (final id in featSkillIds)
      if (!draft.skillChoiceIds.contains(id)) id,
  ];
  out['tool_choice_ids'] = [
    ...draft.toolChoiceIds,
    for (final id in featToolIds)
      if (!draft.toolChoiceIds.contains(id)) id,
  ];
  out['language_choice_ids'] = List<String>.from(draft.languageChoiceIds);

  void appendIds(List<String> targetKeys, Iterable<String> ids) {
    if (ids.isEmpty) return;
    for (final to in targetKeys) {
      if (!fieldsByKey.containsKey(to)) continue;
      final existing = (out[to] is List)
          ? List<String>.from(out[to] as List)
          : <String>[];
      for (final id in ids) {
        if (id.isEmpty) continue;
        if (!existing.contains(id)) existing.add(id);
      }
      out[to] = existing;
      return;
    }
  }

  // Skill / save proficiency-table population. The flat `skill_proficiencies`
  // and `saving_throw_proficiencies` ref fields no longer exist on the PC
  // schema — the `skills` and `saving_throws` proficiency tables are the
  // single source of truth, so flip their per-row `proficient` flags
  // directly. Skill IDs from the draft resolve to entity names; class
  // `saving_throw_refs` give the save-row names.
  final skillEntityIdSet = <String>{
    ...draft.skillChoiceIds,
    for (final id in featSkillIds)
      if (!draft.skillChoiceIds.contains(id)) id,
    if (background?.fields['granted_skill_refs'] is List)
      ...(background!.fields['granted_skill_refs'] as List).whereType<String>(),
    if (race?.fields['granted_skill_proficiencies'] is List)
      ...(race!.fields['granted_skill_proficiencies'] as List)
          .whereType<String>(),
  };
  final skillNames = <String>{
    for (final id in skillEntityIdSet)
      if (entities[id] != null) entities[id]!.name,
  };
  if (fieldsByKey.containsKey('skills')) {
    out['skills'] = {
      'rows': [
        for (final p in kDnd5eSkills)
          {
            'name': p.name,
            'ability': p.ability,
            'proficient': skillNames.contains(p.name),
            'expertise': false,
            'misc': 0,
          },
      ],
    };
  }
  if (fieldsByKey.containsKey('saving_throws')) {
    final saveNames = <String>{};
    final raw = characterClass?.fields['saving_throw_refs'];
    if (raw is List) {
      for (final r in raw) {
        if (r is Map && r['name'] is String) {
          saveNames.add(r['name'] as String);
        } else if (r is String) {
          final e = entities[r];
          if (e != null) saveNames.add(e.name);
        }
      }
    }
    out['saving_throws'] = {
      'rows': [
        for (final p in kDnd5eSavingThrows)
          {
            'name': p.name,
            'ability': p.ability,
            'proficient': saveNames.contains(p.name),
            'expertise': false,
            'misc': 0,
          },
      ],
    };
  }
  appendIds(
    const ['tool_proficiencies'],
    [
      ...draft.toolChoiceIds,
      for (final id in featToolIds)
        if (!draft.toolChoiceIds.contains(id)) id,
    ],
  );
  appendIds(const ['language_refs', 'languages'], draft.languageChoiceIds);
  // PC schema's spell list is `spells_known` with hasEquip-style per-row
  // "prepared" flag. Cantrips have no slot cost so we flag them prepared by
  // default; chosen prepared spells get the same. The widget parses both
  // flat-id and `{id, equipped}` shapes — write the richer shape so the
  // prepared flag survives the round-trip.
  if (fieldsByKey.containsKey('spells_known')) {
    final existing = (out['spells_known'] is List)
        ? List<Map<String, dynamic>>.from(
            (out['spells_known'] as List).whereType<Map>().map(
                  (m) => Map<String, dynamic>.from(m),
                ),
          )
        : <Map<String, dynamic>>[];
    final seen = {
      for (final r in existing) r['id']?.toString(): true,
    };
    void add(Iterable<String> ids, {required bool prepared}) {
      for (final id in ids) {
        if (id.isEmpty || seen.containsKey(id)) continue;
        existing.add({'id': id, 'equipped': prepared, 'source': 'auto'});
        seen[id] = true;
      }
    }

    add(draft.cantripIds, prepared: true);
    add(featCantripIds, prepared: true);
    add(draft.preparedSpellIds, prepared: true);
    add(featPreparedIds, prepared: true);
    out['spells_known'] = existing;
  }
  out['cantrip_ids'] = [
    ...draft.cantripIds,
    for (final id in featCantripIds)
      if (!draft.cantripIds.contains(id)) id,
  ];
  out['prepared_spell_ids'] = [
    ...draft.preparedSpellIds,
    for (final id in featPreparedIds)
      if (!draft.preparedSpellIds.contains(id)) id,
  ];

  // Personality / flavor — write to dedicated PC fields when the
  // template declares them; otherwise stash under a single
  // `personality` map so editor can surface them later.
  void writeText(List<String> candidateKeys, String value) {
    if (value.isEmpty) return;
    for (final key in candidateKeys) {
      if (!fieldsByKey.containsKey(key)) continue;
      out[key] = value;
      return;
    }
  }

  writeText(const ['personality_traits'], draft.personalityTraits);
  writeText(const ['ideals'], draft.ideals);
  writeText(const ['bonds'], draft.bonds);
  writeText(const ['flaws'], draft.flaws);
  writeText(const ['backstory'], draft.backstory);
  writeText(const ['trinket'], draft.trinket);
  // Mirror unconditionally on the resolver-input side so future editor
  // features can read these without going through the player category.
  out['personality_traits'] = draft.personalityTraits;
  out['ideals'] = draft.ideals;
  out['bonds'] = draft.bonds;
  out['flaws'] = draft.flaws;
  out['backstory'] = draft.backstory;
  out['trinket'] = draft.trinket;
  // Background `granted_skill_refs` is already folded into [skillEntityIdSet]
  // above and reflected in the populated `skills` proficiency table.

  // Materialise the equipment-choice selection. For each picked
  // {group_id: option_id} pair, walk the source entity's
  // `equipment_choice_groups` list, find the chosen option, then append
  // its `items[].ref` entity IDs to the PC's inventory and sum
  // `gold_gp` into the gp purse.
  final equipmentItemIds = <String>[];
  var goldGain = 0;
  void absorbFrom(Entity? src) {
    if (src == null) return;
    final raw = src.fields['equipment_choice_groups'];
    if (raw is! List) return;
    for (final g in raw) {
      if (g is! Map) continue;
      final groupId = g['group_id']?.toString() ?? '';
      // Storage key is scoped by source entity id so class + background
      // picks don't collide on identical group_ids (e.g. both 'A').
      final optionId = draft.equipmentChoices['${src.id}:$groupId'];
      if (optionId == null || optionId.isEmpty) continue;
      final options = g['options'];
      if (options is! List) continue;
      for (final o in options) {
        if (o is! Map) continue;
        if (o['option_id']?.toString() != optionId) continue;
        final items = o['items'];
        if (items is List) {
          for (final i in items) {
            if (i is! Map) continue;
            final ref = i['ref'];
            final qty = i['quantity'] is int ? i['quantity'] as int : 1;
            if (ref is String && ref.isNotEmpty) {
              for (var n = 0; n < qty; n++) {
                equipmentItemIds.add(ref);
              }
            }
          }
        }
        final gold = o['gold_gp'];
        if (gold is int) goldGain += gold;
      }
    }
  }

  absorbFrom(characterClass);
  absorbFrom(background);

  if (equipmentItemIds.isNotEmpty) {
    // Inventory keeps duplicates — 2× handaxe is two list entries, not
    // one. We deliberately don't dedupe like appendIds does.
    for (final key in const ['inventory', 'equipment_refs']) {
      if (!fieldsByKey.containsKey(key)) continue;
      final existing = (out[key] is List)
          ? List<String>.from(out[key] as List)
          : <String>[];
      existing.addAll(equipmentItemIds);
      out[key] = existing;
      break;
    }
  }
  if (goldGain > 0 && fieldsByKey.containsKey('gp')) {
    final existing = (out['gp'] is int) ? out['gp'] as int : 0;
    out['gp'] = existing + goldGain;
  }

  // Inherit granted refs from each source entity (race / class / subclass)
  // onto the PC. Source keys (`granted_*`) come from the producer schemas;
  // PC sink keys differ per category (e.g. `resistance_refs` not
  // `granted_damage_resistances`), so we map per pair and write into the
  // first sink key that the PC schema actually exposes.
  void copyListFrom(
    Entity src,
    String fromKey,
    List<String> toKeys,
  ) {
    final raw = src.fields[fromKey];
    if (raw is! List) return;
    final ids = raw.whereType<String>().toList();
    if (ids.isEmpty) return;
    for (final to in toKeys) {
      if (!fieldsByKey.containsKey(to)) continue;
      final existing = (out[to] is List)
          ? List<String>.from(out[to] as List)
          : <String>[];
      for (final id in ids) {
        if (!existing.contains(id)) existing.add(id);
      }
      out[to] = existing;
      return;
    }
  }

  void absorbGrants(Entity? src) {
    if (src == null) return;
    copyListFrom(src, 'trait_refs', const ['trait_refs']);
    copyListFrom(src, 'action_refs', const ['action_refs']);
    copyListFrom(src, 'bonus_action_refs', const ['bonus_action_refs']);
    copyListFrom(src, 'reaction_refs', const ['reaction_refs']);
    copyListFrom(src, 'granted_action_refs', const ['action_refs']);
    copyListFrom(src, 'granted_bonus_action_refs', const ['bonus_action_refs']);
    copyListFrom(src, 'granted_reaction_refs', const ['reaction_refs']);
    copyListFrom(src, 'granted_languages', const ['language_refs', 'languages']);
    copyListFrom(src, 'granted_senses', const ['senses']);
    copyListFrom(src, 'granted_damage_resistances',
        const ['resistance_refs', 'damage_resistances']);
    copyListFrom(src, 'granted_damage_immunities',
        const ['damage_immunity_refs', 'damage_immunities']);
    copyListFrom(src, 'granted_damage_vulnerabilities',
        const ['vulnerability_refs', 'damage_vulnerabilities']);
    copyListFrom(src, 'granted_condition_immunities',
        const ['condition_immunity_refs', 'condition_immunities']);
    // `granted_skill_proficiencies` is folded into the `skills` table above.
  }

  // Race first so its grants land before class/subclass — order is cosmetic
  // (lists dedupe), but keeps trait_refs in a predictable layer.
  absorbGrants(race);
  absorbGrants(characterClass);
  final subclassEntity =
      draft.subclassId == null ? null : entities[draft.subclassId];
  absorbGrants(subclassEntity);

  // Subspecies / ancestry — `subspecies_id` carries the picked option's
  // *name*. Find the matching row in `subspecies_options` and absorb the
  // same granted_*_refs fields the species top-level uses.
  if (draft.subspeciesId != null && draft.subspeciesId!.isNotEmpty && race != null) {
    final raw = race.fields['subspecies_options'];
    if (raw is List) {
      for (final row in raw) {
        if (row is! Map) continue;
        if (row['name']?.toString() != draft.subspeciesId) continue;
        // Wrap the row in a synthetic Entity so absorbGrants can reuse the
        // same `copyListFrom(src, fromKey, toKeys)` walker.
        final syntheticFields = <String, dynamic>{};
        for (final entry in row.entries) {
          syntheticFields[entry.key.toString()] = entry.value;
        }
        final syn = Entity(
          id: '__subspecies__',
          name: row['name']?.toString() ?? '',
          categorySlug: 'species',
          source: 'srd',
          description: '',
          images: const [],
          imagePath: '',
          tags: const [],
          dmNotes: '',
          pdfs: const [],
          locationId: null,
          fields: syntheticFields,
        );
        absorbGrants(syn);
        break;
      }
    }
  }

  // Per-level class & subclass feature grants. `features` rows are
  // narrative-only by schema, but custom content can attach
  // `granted_modifiers` / `granted_*` ref lists on a row; absorb those
  // for rows whose level ≤ the draft level. Feature-row `effects` flow
  // through the resolver at read time; we only mirror ref-list grants
  // onto the PC entity here so the editor surface picks them up.
  void absorbFeatureRows(Entity? src) {
    if (src == null) return;
    final rows = src.fields['features'];
    if (rows is! List) return;
    for (final row in rows) {
      if (row is! Map) continue;
      final lvl = row['level'];
      if (lvl is! int || lvl > draft.level) continue;
      void copyRow(String fromKey, List<String> toKeys) {
        final raw = row[fromKey];
        if (raw is! List) return;
        final ids = raw.whereType<String>().toList();
        if (ids.isEmpty) return;
        for (final to in toKeys) {
          if (!fieldsByKey.containsKey(to)) continue;
          final existing = (out[to] is List)
              ? List<String>.from(out[to] as List)
              : <String>[];
          for (final id in ids) {
            if (!existing.contains(id)) existing.add(id);
          }
          out[to] = existing;
          return;
        }
      }

      copyRow('granted_damage_resistances',
          const ['resistance_refs', 'damage_resistances']);
      copyRow('granted_damage_immunities',
          const ['damage_immunity_refs', 'damage_immunities']);
      copyRow('granted_damage_vulnerabilities',
          const ['vulnerability_refs', 'damage_vulnerabilities']);
      copyRow('granted_condition_immunities',
          const ['condition_immunity_refs', 'condition_immunities']);
      copyRow('granted_senses', const ['senses']);
      copyRow('granted_languages', const ['language_refs', 'languages']);
      copyRow('granted_feat_refs', const ['feats']);
      copyRow('granted_trait_refs', const ['trait_refs']);
      copyRow('granted_action_refs', const ['action_refs']);
      copyRow('granted_bonus_action_refs', const ['bonus_action_refs']);
      copyRow('granted_reaction_refs', const ['reaction_refs']);
    }
  }

  absorbFeatureRows(characterClass);
  absorbFeatureRows(subclassEntity);

  // Seed pending choices from class+level progression. Mirrors the level-up
  // dialog's emission so a freshly-created Cleric (Divine Order at L1) or any
  // other class flagged for a mandatory pick lands in the editor with a
  // resolvable `!` badge. From-level 0 captures every grant at or below the
  // draft level.
  //
  // Wizard steps don't gate progression on filling caps — the player may
  // skip cantrip/spell/feat picks and finalize anyway. Anything still
  // unresolved at finalize is persisted as a pending choice so the level-up
  // dialog and the editor's pending-choices panel can surface it later.
  final seededPending = <Map<String, dynamic>>[];

  if (characterClass != null) {
    final creationPlan = planLevelUp(
      fromLevel: 0,
      toLevel: draft.level,
      classEntity: characterClass,
      subclassEntity: subclassEntity,
      entities: entities,
    );
    final pending = pendingChoicesFromPlan(
      plan: creationPlan,
      classId: characterClass.id,
      classLabel: characterClass.name,
      hasSubclass: subclassEntity != null,
    );
    // Caps the wizard validated against — used to compute remaining picks
    // for cantrip/spell pending choices.
    final kind = parseCasterKind(characterClass.fields['caster_kind']);
    final cantripCap = kind == CasterKind.none
        ? 0
        : (levelTableValue(
                characterClass.fields['cantrips_known_by_level'], draft.level) ??
            defaultCantripsKnown(kind, draft.level));
    final preparedCap = kind == CasterKind.none
        ? 0
        : (levelTableValue(
                characterClass.fields['prepared_spells_by_level'], draft.level) ??
            defaultPreparedSpells(kind, draft.level));
    final cantripRemaining =
        (cantripCap - draft.cantripIds.length).clamp(0, cantripCap);
    final spellRemaining =
        (preparedCap - draft.preparedSpellIds.length).clamp(0, preparedCap);

    for (final p in pending) {
      switch (p.kind) {
        case PendingChoiceKind.subclass:
          // Wizard's subclass step resolves it inline when the user picks
          // one; only persist if the user skipped it.
          if (subclassEntity == null) seededPending.add(p.toMap());
        case PendingChoiceKind.cantrips:
          if (cantripRemaining > 0) {
            seededPending.add(
              newPendingChoice(
                kind: p.kind,
                level: p.level,
                classId: p.classId,
                classLabel: p.classLabel,
                count: cantripRemaining,
              ).toMap(),
            );
          }
        case PendingChoiceKind.spells:
          if (spellRemaining > 0) {
            seededPending.add(
              newPendingChoice(
                kind: p.kind,
                level: p.level,
                classId: p.classId,
                classLabel: p.classLabel,
                count: spellRemaining,
                maxSpellLevel: p.maxSpellLevel,
              ).toMap(),
            );
          }
        case PendingChoiceKind.asiOrFeat:
        case PendingChoiceKind.fightingStyle:
        case PendingChoiceKind.weaponMastery:
        case PendingChoiceKind.divineOrder:
        case PendingChoiceKind.featureOption:
        case PendingChoiceKind.skillProficiency:
        case PendingChoiceKind.toolProficiency:
        case PendingChoiceKind.languages:
        case PendingChoiceKind.expertise:
        case PendingChoiceKind.featAsi:
        case PendingChoiceKind.featChoice:
          // Wizard has no inline resolver for these — always persist so the
          // pending panel + level-up dialog can surface them.
          seededPending.add(p.toMap());
      }
    }
  }

  // Skipped wizard-step picks (Skills / Tools / Languages) — anything the
  // player left unselected in the Proficiencies step gets surfaced as a
  // pending upgrade on the character card, mirroring the spell-skip path
  // above. Field-key lookups are done with local helpers to mirror the
  // existing `_validateProficiencies` logic.
  int intOf(Object? v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
  List<String> listOf(Object? v) {
    if (v is! List) return const [];
    return v.whereType<String>().toList();
  }

  if (characterClass != null) {
    final skillCap = intOf(characterClass.fields['skill_proficiency_choice_count']);
    final skillOptions =
        listOf(characterClass.fields['skill_proficiency_options']).length;
    if (skillCap > 0 && skillOptions > 0) {
      final remaining =
          (skillCap - draft.skillChoiceIds.length).clamp(0, skillCap);
      if (remaining > 0) {
        seededPending.add(newPendingChoice(
          kind: PendingChoiceKind.skillProficiency,
          level: draft.level,
          classId: characterClass.id,
          classLabel: characterClass.name,
          count: remaining,
        ).toMap());
      }
    }
    final toolCap = intOf(characterClass.fields['tool_proficiency_count']);
    final toolOptions =
        listOf(characterClass.fields['tool_proficiency_options']).length;
    if (toolCap > 0 && toolOptions > 0) {
      final remaining =
          (toolCap - draft.toolChoiceIds.length).clamp(0, toolCap);
      if (remaining > 0) {
        seededPending.add(newPendingChoice(
          kind: PendingChoiceKind.toolProficiency,
          level: draft.level,
          classId: characterClass.id,
          classLabel: characterClass.name,
          count: remaining,
        ).toMap());
      }
    }
  }
  if (background != null) {
    final languageCap = intOf(background.fields['granted_language_count']);
    final languageOptions =
        entities.values.where((e) => e.categorySlug == 'language').length;
    if (languageCap > 0 && languageOptions > 0) {
      final remaining =
          (languageCap - draft.languageChoiceIds.length).clamp(0, languageCap);
      if (remaining > 0) {
        seededPending.add(newPendingChoice(
          kind: PendingChoiceKind.languages,
          level: draft.level,
          classId: background.id,
          classLabel: background.name,
          count: remaining,
        ).toMap());
      }
    }
  }

  // Underfilled feat choice groups (e.g. Magic Initiate: picked the list but
  // skipped some/all cantrip + L1 spell picks). One pending entry per group,
  // keyed by feat_id (`sourceEntityId`) + group label (`featureName`); the
  // resolver dialog re-reads the group definition off the feat entity.
  {
    final activeFeatIds = <String>[];
    final bgOrigin = background?.fields['origin_feat_ref'];
    if (bgOrigin is String && bgOrigin.isNotEmpty) {
      activeFeatIds.add(bgOrigin);
    }
    for (final id in draft.featIds) {
      if (!activeFeatIds.contains(id)) activeFeatIds.add(id);
    }
    for (final featId in activeFeatIds) {
      final feat = entities[featId];
      if (feat == null) continue;
      final effects = feat.fields['effects'];
      if (effects is! List) continue;
      for (final row in effects) {
        if (row is! Map) continue;
        if (row['kind'] != 'choice_group') continue;
        final payload = row['payload'];
        if (payload is! Map) continue;
        final groupId = payload['group_id']?.toString() ?? '';
        if (groupId.isEmpty) continue;
        final pickKind = payload['pick_kind']?.toString() ?? 'enum';
        if (pickKind == 'ability') continue;
        final pick = payload['pick'] is int ? payload['pick'] as int : 1;
        final storageKey = '$featId:$groupId';
        final raw = draft.originFeatChoices[storageKey] ?? '';
        final pickedCount =
            raw.isEmpty ? 0 : raw.split(',').where((s) => s.isNotEmpty).length;
        final remaining = (pick - pickedCount).clamp(0, pick);
        if (remaining <= 0) continue;
        final label = payload['label']?.toString() ?? groupId;
        seededPending.add(newPendingChoice(
          kind: PendingChoiceKind.featChoice,
          level: draft.level,
          classLabel: feat.name,
          featureName: label,
          count: remaining,
          sourceEntityId: featId,
        ).toMap());
      }
    }
  }

  if (seededPending.isNotEmpty) {
    final existing = out['pending_choices'];
    final list = existing is List ? List<dynamic>.from(existing) : <dynamic>[];
    list.addAll(seededPending);
    out['pending_choices'] = list;
  }

  // Spell slots — derive from class caster_kind + level so a fresh
  // character spawns with the correct slot maxes without the user touching
  // the level-up dialog. Stored on the `spell_slots` field as
  // `{max: {spellLevel: count}, remaining: {spellLevel: count}}`. The
  // `_SpellSlotGridFieldWidget` renders one row per spell level with
  // tappable pips for remaining slots.
  if (characterClass != null) {
    final slots = spellSlotsForClass(characterClass, draft.level);
    if (slots.isNotEmpty) {
      final maxOut = <String, dynamic>{};
      final remainingOut = <String, dynamic>{};
      for (final entry in slots.entries) {
        final k = entry.key.toString();
        maxOut[k] = entry.value;
        remainingOut[k] = entry.value;
      }
      out['spell_slots'] = {'max': maxOut, 'remaining': remainingOut};
    }
  }

  return out;
}

/// Parse hit die spec like "d8", "1d10", "8" → integer faces. Defaults to 8.
int _parseHitDie(dynamic raw) {
  if (raw is int) return raw;
  if (raw is String) {
    final lower = raw.toLowerCase().trim();
    final match = RegExp(r'd(\d+)').firstMatch(lower);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 8;
    }
    final n = int.tryParse(lower);
    if (n != null) return n;
  }
  return 8;
}

// ── Step widgets ──────────────────────────────────────────────────────────

class _IdentityStep extends StatelessWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;
  final List<String> worlds;
  final List<WorldSchema> templates;
  final List<String> alignments;
  final bool activatingWorld;
  final Future<void> Function(String) onWorldPicked;

  const _IdentityStep({
    required this.draft,
    required this.notifier,
    required this.worlds,
    required this.templates,
    required this.alignments,
    required this.activatingWorld,
    required this.onWorldPicked,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // Auto-pick template/world if user has only one option.
    if (draft.templateId.isEmpty && templates.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setTemplate(
          id: templates.first.schemaId,
          name: templates.first.name,
        );
      });
    }
    if (draft.worldName.isNotEmpty) {
      // Make sure the picked world's entities are loaded so race/class/
      // background steps see them. Idempotent — `_activateWorld` no-ops
      // when already active. Empty `worldName` is the SRD-default mode
      // and intentionally activates no campaign.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onWorldPicked(draft.worldName));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DebouncedTextField(
          initialValue: draft.name,
          decoration: const InputDecoration(
            labelText: 'Character Name *',
          ),
          onChangedDebounced: notifier.setName,
        ),
        const SizedBox(height: 12),
        _DebouncedTextField(
          initialValue: draft.description,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Short description',
            hintText: 'A weather-beaten ranger from the Northlands...',
          ),
          onChangedDebounced: notifier.setDescription,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue:
                    draft.templateId.isEmpty ? null : draft.templateId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Template *'),
                items: templates
                    .map((t) => DropdownMenuItem(
                          value: t.schemaId,
                          child: Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final tpl = templates.firstWhere((t) => t.schemaId == v);
                  notifier.setTemplate(id: tpl.schemaId, name: tpl.name);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(builder: (_) {
                // Dedupe — getAvailable() can return duplicates if a world
                // was created twice in past sessions. DropdownButton asserts
                // exactly-one match for its value, so we collapse duplicates.
                // Empty string is the sentinel for "Built-in SRD" — that's
                // the default; picking a campaign loads its entities on top.
                final uniqueWorlds = <String>{...worlds}.toList();
                final pickerValue = draft.worldName.isNotEmpty &&
                        uniqueWorlds.contains(draft.worldName)
                    ? draft.worldName
                    : '';
                return DropdownButtonFormField<String>(
                  initialValue: pickerValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'World / Package',
                    suffixIcon: activatingWorld
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text(
                        'Built-in SRD (default)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...uniqueWorlds.map(
                      (w) => DropdownMenuItem(
                        value: w,
                        child: Text(
                          w,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: activatingWorld
                      ? null
                      : (v) {
                          if (v == null) return;
                          notifier.setWorld(v);
                          if (v.isNotEmpty) onWorldPicked(v);
                        },
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                initialValue: draft.level,
                decoration: const InputDecoration(labelText: 'Level *'),
                items: List.generate(20, (i) => i + 1)
                    .map((n) =>
                        DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) notifier.setLevel(v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue:
                    draft.alignment.isEmpty ? null : draft.alignment,
                decoration: const InputDecoration(labelText: 'Alignment'),
                items: alignments
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) notifier.setAlignment(v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PortraitTile(
              path: draft.portraitPath,
              onPick: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                final path = result?.files.firstOrNull?.path;
                if (path != null) notifier.setPortrait(path);
              },
              onClear:
                  draft.portraitPath.isEmpty ? null : () => notifier.setPortrait(''),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Portrait (optional). You can change it later in the editor.',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ],
        ),
        if (draft.level > 1) _HigherLevelStartPanel(level: draft.level),
      ],
    );
  }
}

/// Read-only advisory shown on the Identity step when starting level > 1.
/// Lists the SRD §1 "Starting at Higher Levels" bundle (extra GP + magic
/// items) so the player and DM can stock the character accordingly — the
/// wizard does not auto-grant these items yet (follow-up: A11 commit).
class _HigherLevelStartPanel extends StatelessWidget {
  final int level;
  const _HigherLevelStartPanel({required this.level});

  ({String money, String items}) _bundle(int lvl) {
    if (lvl <= 4) {
      return (money: 'Normal starting equipment.', items: '1 Common');
    }
    if (lvl <= 10) {
      return (
        money: '500 GP plus 1d10 × 25 GP plus normal starting equipment.',
        items: '1 Common, 1 Uncommon',
      );
    }
    if (lvl <= 16) {
      return (
        money:
            '5,000 GP plus 1d10 × 250 GP plus normal starting equipment.',
        items: '2 Common, 3 Uncommon, 1 Rare',
      );
    }
    return (
      money:
          '20,000 GP plus 1d10 × 250 GP plus normal starting equipment.',
      items: '2 Common, 4 Uncommon, 3 Rare, 1 Very Rare',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final bundle = _bundle(level);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.cbr,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: palette.tabActiveText),
              const SizedBox(width: 6),
              Text(
                'Starting at Higher Levels (Level $level)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'SRD §1 recommends the DM grant this bundle in addition to '
            'standard starting equipment:',
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Money: ${bundle.money}',
            style: TextStyle(fontSize: 11, color: palette.tabActiveText),
          ),
          Text(
            '• Magic items: ${bundle.items}',
            style: TextStyle(fontSize: 11, color: palette.tabActiveText),
          ),
          const SizedBox(height: 4),
          Text(
            'Add the GP and magic-item picks manually in the editor — the '
            'wizard does not auto-grant these yet.',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: palette.sidebarLabelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitTile extends StatelessWidget {
  final String path;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const _PortraitTile({
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // Drop synchronous `File.existsSync()` from build path — matches the
    // editor pattern: lean on `Image.file` errorBuilder to handle missing
    // files without blocking the frame.
    final hasImagePath = path.isNotEmpty;
    final placeholder = Icon(Icons.add_a_photo_outlined,
        color: palette.sidebarLabelSecondary);
    return Stack(
      children: [
        InkWell(
          onTap: onPick,
          child: Container(
            width: 96,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.featureCardBg,
              border: Border.all(color: palette.featureCardBorder),
              borderRadius: palette.cbr,
            ),
            child: hasImagePath
                ? Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  )
                : placeholder,
          ),
        ),
        if (onClear != null)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onClear,
            ),
          ),
      ],
    );
  }
}

/// Race / Species picker. Composes the standard entity picker with a
/// second-tier subspecies (lineage / ancestry / legacy) picker that
/// appears when the chosen species declares `subspecies_options`.
class _RaceStep extends ConsumerWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const _RaceStep({required this.draft, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(wizardEntitiesProvider);
    final raceEntity =
        draft.raceId == null ? null : entities[draft.raceId];
    final options = _subspeciesOptions(raceEntity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntityPickStep(
          title: 'Race',
          slugs: const ['species', 'race'],
          selectedId: draft.raceId,
          onChanged: notifier.setRace,
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _subspeciesPickerLabel(raceEntity),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final opt in options)
            RadioListTile<String?>(
              value: opt['name']?.toString(),
              // ignore: deprecated_member_use
              groupValue: draft.subspeciesId,
              // ignore: deprecated_member_use
              onChanged: notifier.setSubspecies,
              dense: true,
              title: Text(opt['name']?.toString() ?? ''),
              subtitle: (opt['description']?.toString().isNotEmpty ?? false)
                  ? Text(opt['description']!.toString())
                  : null,
            ),
        ],
      ],
    );
  }

  static List<Map<String, dynamic>> _subspeciesOptions(Entity? e) {
    if (e == null) return const [];
    final raw = e.fields['subspecies_options'];
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map) Map<String, dynamic>.from(r),
    ];
  }

  static String _subspeciesPickerLabel(Entity? e) {
    if (e == null) return 'Lineage';
    switch (e.name) {
      case 'Dragonborn':
        return 'Draconic Ancestry';
      case 'Goliath':
        return 'Giant Ancestry';
      case 'Tiefling':
        return 'Fiendish Legacy';
      default:
        return 'Lineage';
    }
  }
}

class _EntityPickStep extends ConsumerWidget {
  final String title;
  final List<String> slugs;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool optional;

  const _EntityPickStep({
    required this.title,
    required this.slugs,
    required this.selectedId,
    required this.onChanged,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final entities = ref.watch(wizardEntitiesProvider);
    final candidates = entities.values
        .where((e) => slugs.contains(e.categorySlug))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (candidates.isEmpty) {
      final slugLabel = slugs.join(' / ');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          optional
              ? 'No "$slugLabel" entities available. You can add one later in the editor.'
              : 'No "$slugLabel" entities available. Create one in the Database tab first.',
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (optional)
          RadioListTile<String?>(
            value: null,
            // ignore: deprecated_member_use
            groupValue: selectedId,
            // ignore: deprecated_member_use
            onChanged: onChanged,
            dense: true,
            title: const Text('None'),
          ),
        ...candidates.map((e) => RadioListTile<String?>(
              value: e.id,
              // ignore: deprecated_member_use
              groupValue: selectedId,
              // ignore: deprecated_member_use
              onChanged: onChanged,
              dense: true,
              title: Text(e.name),
              subtitle: e.description.isEmpty
                  ? null
                  : Text(
                      e.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            )),
      ],
    );
  }
}

class _AbilitiesStep extends StatelessWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const _AbilitiesStep({required this.draft, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final asiTotal = _asiTotal(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: AbilityScoreMethod.values
              .map((m) => ChoiceChip(
                    label: Text(m.label),
                    selected: draft.abilityMethod == m,
                    onSelected: (_) => notifier.setAbilityMethod(m),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        if (draft.abilityMethod == AbilityScoreMethod.pointBuy)
          _PointBuyHeader(draft: draft, palette: palette),
        if (draft.abilityMethod == AbilityScoreMethod.standardArray)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Distribute 15/14/13/12/10/8 across the six abilities.',
              style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
        if (draft.abilityMethod == AbilityScoreMethod.random)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.casino, size: 16),
                  label: const Text('Roll 4d6 drop low ×6'),
                  onPressed: notifier.rollRandomAbilities,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reroll if unhappy.',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...kAbilityKeys.map((k) => _AbilityRow(
              abilityKey: k,
              base: draft.baseAbilities[k] ?? 10,
              racial: draft.racialBonuses[k] ?? 0,
              asiTotal: asiTotal,
              method: draft.abilityMethod,
              standardArrayUsed: _standardArrayUsageFor(draft, k),
              onBase: (v) => notifier.setAbility(k, v),
              onRacial: (v) => notifier.setRacialBonus(k, v),
            )),
        const SizedBox(height: 8),
        _BackgroundAsiHeader(
          total: asiTotal,
          palette: palette,
          onClear: () {
            for (final k in kAbilityKeys) {
              notifier.setRacialBonus(k, 0);
            }
          },
        ),
      ],
    );
  }

  static int _asiTotal(CharacterDraft d) {
    var t = 0;
    for (final k in kAbilityKeys) {
      t += d.racialBonuses[k] ?? 0;
    }
    return t;
  }

  /// For Standard Array UI: which values are still available given other
  /// abilities' picks (so the dropdown can hide already-used numbers).
  List<int> _standardArrayUsageFor(CharacterDraft d, String currentKey) {
    final used = <int>[];
    for (final k in kAbilityKeys) {
      if (k == currentKey) continue;
      used.add(d.baseAbilities[k] ?? 10);
    }
    return used;
  }
}

class _PointBuyHeader extends StatelessWidget {
  final CharacterDraft draft;
  final DmToolColors palette;
  const _PointBuyHeader({required this.draft, required this.palette});

  @override
  Widget build(BuildContext context) {
    final spent = AbilityScoreValidator.pointBuyCost(draft.baseAbilities);
    final overspent = spent < 0 || spent > kPointBuyBudget;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            overspent ? Icons.warning_amber : Icons.check_circle,
            color: overspent ? palette.dangerBtnBg : palette.successBtnBg,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Points spent: ${spent < 0 ? '—' : spent} / $kPointBuyBudget',
            style: TextStyle(
              fontSize: 12,
              color: overspent
                  ? palette.dangerBtnBg
                  : palette.tabActiveText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '(scores 8-15)',
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundAsiHeader extends StatelessWidget {
  final int total;
  final DmToolColors palette;
  final VoidCallback onClear;

  const _BackgroundAsiHeader({
    required this.total,
    required this.palette,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 6),
        Text(
          'Background ASI: $total / 3',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.tabActiveText,
          ),
        ),
        const Spacer(),
        if (total > 0)
          TextButton.icon(
            icon: const Icon(Icons.clear, size: 14),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onClear,
          ),
      ],
    );
  }
}

class _AbilityRow extends StatelessWidget {
  final String abilityKey;
  final int base;
  final int racial;
  final int asiTotal;
  final AbilityScoreMethod method;
  final List<int> standardArrayUsed;
  final ValueChanged<int> onBase;
  final ValueChanged<int> onRacial;

  const _AbilityRow({
    required this.abilityKey,
    required this.base,
    required this.racial,
    required this.asiTotal,
    required this.method,
    required this.standardArrayUsed,
    required this.onBase,
    required this.onRacial,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final total = base + racial;
    final mod = abilityModifier(total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              abilityKey,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 110, child: _baseEditor()),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: DropdownButtonFormField<int>(
              initialValue: racial,
              decoration: const InputDecoration(labelText: 'ASI'),
              items: const [0, 1, 2].map((v) {
                final enabled = _asiOptionEnabled(v);
                return DropdownMenuItem(
                  value: v,
                  enabled: enabled,
                  child: Text(
                    '+$v',
                    style: TextStyle(
                      color: enabled ? null : palette.sidebarLabelSecondary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) onRacial(v);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '= $total (${mod >= 0 ? '+' : ''}$mod)',
                maxLines: 1,
                style: TextStyle(
                  color: palette.tabActiveText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _baseEditor() {
    return switch (method) {
      AbilityScoreMethod.standardArray => DropdownButtonFormField<int>(
          initialValue:
              kStandardArray.contains(base) ? base : kStandardArray.first,
          decoration: const InputDecoration(labelText: 'Base'),
          items: kStandardArray.map((v) {
            final taken =
                v != base && standardArrayUsed.where((u) => u == v).length >=
                    _countOf(kStandardArray, v);
            return DropdownMenuItem(
              value: v,
              enabled: !taken,
              child: Text('$v'),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onBase(v);
          },
        ),
      AbilityScoreMethod.pointBuy => DropdownButtonFormField<int>(
          initialValue: base.clamp(8, 15),
          decoration: const InputDecoration(labelText: 'Base'),
          // W10: items are state-independent — promoted to a static const
          // list so the wizard doesn't reallocate 8 DropdownMenuItems per
          // rebuild of every ability row.
          items: _kPointBuyDropdownItems,
          onChanged: (v) {
            if (v != null) onBase(v);
          },
        ),
      AbilityScoreMethod.random ||
      AbilityScoreMethod.manual =>
        TextFormField(
          key: ValueKey('manual_$abilityKey-$base'),
          initialValue: '$base',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Base'),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null) onBase(parsed);
          },
        ),
    };
  }

  int _countOf(List<int> arr, int v) => arr.where((x) => x == v).length;

  /// Soft cap: each ability ≤ +2, total ≤ +3. Patterns +2/+1, +1/+1,
  /// +1/+1/+1 all reachable.
  bool _asiOptionEnabled(int candidate) {
    final othersTotal = asiTotal - racial;
    if (othersTotal + candidate > 3) return false;
    if (candidate > 2) return false;
    return true;
  }
}

class _ReviewStep extends ConsumerWidget {
  final CharacterDraft draft;
  const _ReviewStep({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final entities = ref.watch(wizardEntitiesProvider);
    String nameOf(String? id) =>
        id == null ? '—' : (entities[id]?.name ?? '—');
    String namesOf(Iterable<String> ids) {
      final names = ids
          .map((id) => entities[id]?.name ?? id)
          .where((n) => n.isNotEmpty)
          .toList();
      return names.isEmpty ? '—' : names.join(', ');
    }

    final stat = <String, int>{
      for (final k in kAbilityKeys)
        k: (draft.baseAbilities[k] ?? 10) + (draft.racialBonuses[k] ?? 0),
    };
    final conMod = abilityModifier(stat['CON'] ?? 10);
    final dexMod = abilityModifier(stat['DEX'] ?? 10);
    final wisMod = abilityModifier(stat['WIS'] ?? 10);
    final classEntity =
        draft.classId == null ? null : entities[draft.classId];
    final race = draft.raceId == null ? null : entities[draft.raceId];
    final hitDie = _parseHitDie(classEntity?.fields['hit_die']);
    final maxHp = hitDie +
        conMod +
        (draft.level - 1) * ((hitDie ~/ 2) + 1 + conMod);
    final profBonus = 2 + ((draft.level - 1) ~/ 4);
    final speedFt = race?.fields['speed_ft'] is int
        ? race!.fields['speed_ft'] as int
        : 30;

    // Spellcasting summary — null when caster_kind = None.
    final casterKind =
        parseCasterKind(classEntity?.fields['caster_kind']);
    int? castingMod;
    if (classEntity != null && casterKind != CasterKind.none) {
      final ref = classEntity.fields['casting_ability_ref'];
      if (ref is String) {
        final abilityEntity = entities[ref];
        final key = abilityEntity?.name.substring(0, 3).toUpperCase();
        if (key != null && kAbilityKeys.contains(key)) {
          castingMod = abilityModifier(stat[key] ?? 10);
        }
      }
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.tabActiveText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );

    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            t,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: palette.tabActiveText,
            ),
          ),
        );

    Widget chip(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            borderRadius: palette.chr,
            border: Border.all(color: palette.featureCardBorder),
          ),
          child: Text(t, style: const TextStyle(fontSize: 12)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Identity'),
        row('Name', draft.name),
        row('World', draft.worldName),
        row('Template', draft.templateName),
        row('Level', '${draft.level}'),
        row('Alignment', draft.alignment.isEmpty ? '—' : draft.alignment),
        row('Race', nameOf(draft.raceId)),
        row('Class', nameOf(draft.classId)),
        row('Subclass', nameOf(draft.subclassId)),
        row('Background', nameOf(draft.backgroundId)),
        heading('Ability Scores'),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: kAbilityKeys.map((k) {
            final v = stat[k] ?? 10;
            final mod = abilityModifier(v);
            return chip('$k $v (${mod >= 0 ? '+' : ''}$mod)');
          }).toList(),
        ),
        heading('Derived Stats'),
        row('Hit Points', '$maxHp'),
        row('Armor Class', '${10 + dexMod} (unarmored)'),
        row('Initiative', dexMod >= 0 ? '+$dexMod' : '$dexMod'),
        row('Speed', '$speedFt ft'),
        row('Proficiency Bonus', '+$profBonus'),
        row('Passive Perception', '${10 + wisMod}'),
        if (castingMod != null) ...[
          row(
            'Spell Save DC',
            '${8 + profBonus + castingMod}',
          ),
          row(
            'Spell Attack Bonus',
            '+${profBonus + castingMod}',
          ),
        ],
        heading('Proficiencies & Languages'),
        row('Skills', namesOf(draft.skillChoiceIds)),
        row('Tools', namesOf(draft.toolChoiceIds)),
        row('Languages', namesOf(draft.languageChoiceIds)),
        if (draft.cantripIds.isNotEmpty ||
            draft.preparedSpellIds.isNotEmpty) ...[
          heading('Spells'),
          row('Cantrips', namesOf(draft.cantripIds)),
          row(
            'Prepared / Known',
            namesOf(draft.preparedSpellIds),
          ),
        ],
        if (draft.equipmentChoices.isNotEmpty) ...[
          heading('Equipment'),
          row(
            'Picks',
            '${draft.equipmentChoices.length} option(s) selected',
          ),
        ],
        if (draft.personalityTraits.isNotEmpty ||
            draft.ideals.isNotEmpty ||
            draft.bonds.isNotEmpty ||
            draft.flaws.isNotEmpty ||
            draft.backstory.isNotEmpty ||
            draft.trinket.isNotEmpty) ...[
          heading('Personality & Flavor'),
          if (draft.personalityTraits.isNotEmpty)
            row('Traits', draft.personalityTraits),
          if (draft.ideals.isNotEmpty) row('Ideals', draft.ideals),
          if (draft.bonds.isNotEmpty) row('Bonds', draft.bonds),
          if (draft.flaws.isNotEmpty) row('Flaws', draft.flaws),
          if (draft.backstory.isNotEmpty)
            row('Backstory', draft.backstory),
          if (draft.trinket.isNotEmpty) row('Trinket', draft.trinket),
        ],
      ],
    );
  }
}

/// W2: collapses Stepper bodies for non-active steps. Material `Stepper`
/// builds every `Step.content` widget on every screen rebuild — that
/// means typing into the Identity step would re-run `build()` on 11
/// other step widgets even though only one is visible. Wrapping each
/// content in `_StepBody` short-circuits to `SizedBox.shrink` when the
/// step is not the current one. The inner widget is still constructed
/// (cheap allocation) but its build tree is never walked.
class _StepBody extends StatelessWidget {
  final bool active;
  final Widget child;
  const _StepBody({required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return child;
  }
}

/// W10: stable list of `DropdownMenuItem<int>` for point-buy base scores
/// (8–15). Used by every ability row's `_baseEditor`; promoting it to a
/// top-level const avoids rebuilding 8 widgets × 6 abilities per frame.
final List<DropdownMenuItem<int>> _kPointBuyDropdownItems = [
  for (var v = 8; v <= 15; v++)
    DropdownMenuItem<int>(value: v, child: Text('$v')),
];

/// W3: TextFormField wrapper that debounces 250 ms before pushing the
/// new value into the notifier. Keeps per-keystroke fanout off the
/// CharacterDraft graph. Wizard Next-button validators read the notifier
/// state — 250 ms is below the inter-action latency budget, so the
/// buffered write reliably flushes before validation runs.
class _DebouncedTextField extends StatefulWidget {
  final String initialValue;
  final InputDecoration decoration;
  final ValueChanged<String> onChangedDebounced;
  final int minLines;
  final int maxLines;

  const _DebouncedTextField({
    required this.initialValue,
    required this.decoration,
    required this.onChangedDebounced,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  State<_DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<_DebouncedTextField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      widget.onChangedDebounced(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: widget.initialValue,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      decoration: widget.decoration,
      onChanged: _onChanged,
    );
  }
}
