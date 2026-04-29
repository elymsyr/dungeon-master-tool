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
import '../../../../application/providers/template_provider.dart';
import '../../../../domain/entities/entity.dart';
import '../../../../domain/entities/schema/entity_category_schema.dart';
import '../../../../domain/entities/schema/world_schema.dart';
import '../../../theme/dm_tool_colors.dart';
import 'steps/equipment_step.dart';
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
    // Default world = already-active campaign so race/class/background
    // entity lists render immediately. Picking another world in the
    // Identity step calls `_activateWorld` which loads + bumps revision.
    final active = ref.read(activeCampaignProvider);
    if (active != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(characterDraftProvider.notifier).setWorld(active);
      });
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Character'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _committing ? null : () => context.pop(),
        ),
      ),
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
                      content: _IdentityStep(
                        draft: draft,
                        notifier: notifier,
                        worlds: worlds,
                        templates: playerTemplates,
                        alignments: _alignments,
                        activatingWorld: _activatingWorld,
                        onWorldPicked: _activateWorld,
                      ),
                    ),
                    Step(
                      title: const Text('Race / Species'),
                      isActive: _currentStep >= 1,
                      state: _stateFor(1, draft),
                      content: _EntityPickStep(
                        title: 'Race',
                        slugs: const ['species', 'race'],
                        selectedId: draft.raceId,
                        onChanged: notifier.setRace,
                      ),
                    ),
                    Step(
                      title: const Text('Class'),
                      isActive: _currentStep >= 2,
                      state: _stateFor(2, draft),
                      content: _EntityPickStep(
                        title: 'Class',
                        slugs: const ['class'],
                        selectedId: draft.classId,
                        onChanged: notifier.setClass,
                      ),
                    ),
                    Step(
                      title: const Text('Subclass'),
                      isActive: _currentStep >= 3,
                      state: _stateFor(3, draft),
                      content:
                          SubclassStep(draft: draft, notifier: notifier),
                    ),
                    Step(
                      title: const Text('Background'),
                      isActive: _currentStep >= 4,
                      state: _stateFor(4, draft),
                      content: _EntityPickStep(
                        title: 'Background',
                        slugs: const ['background'],
                        selectedId: draft.backgroundId,
                        onChanged: notifier.setBackground,
                        optional: true,
                      ),
                    ),
                    Step(
                      title: const Text('Equipment'),
                      isActive: _currentStep >= 5,
                      state: _stateFor(5, draft),
                      content:
                          EquipmentStep(draft: draft, notifier: notifier),
                    ),
                    Step(
                      title: const Text('Abilities'),
                      isActive: _currentStep >= 6,
                      state: _stateFor(6, draft),
                      content:
                          _AbilitiesStep(draft: draft, notifier: notifier),
                    ),
                    Step(
                      title: const Text('Review'),
                      isActive: _currentStep >= 7,
                      state: _stateFor(7, draft),
                      content: _ReviewStep(draft: draft),
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

  static const _stepCount = 8;

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
      5 => null,
      6 => AbilityScoreValidator.validate(
          method: draft.abilityMethod,
          scores: draft.baseAbilities,
        ),
      7 => null,
      _ => null,
    };
  }

  String? _validateIdentity(CharacterDraft d) {
    if (d.name.trim().isEmpty) return 'Name required.';
    if (d.templateId.isEmpty) return 'Template required.';
    if (d.worldName.isEmpty) return 'World required.';
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
      final entities = ref.read(entityProvider);
      Entity? lookup(String? id) =>
          id == null ? null : entities[id];

      final seed = _buildSeedFields(
        draft: draft,
        playerCat: playerCat,
        race: lookup(draft.raceId),
        characterClass: lookup(draft.classId),
        background: lookup(draft.backgroundId),
      );

      final created =
          await ref.read(characterListProvider.notifier).create(
                name: draft.name.trim(),
                template: template,
                worldName: draft.worldName,
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
Map<String, dynamic> _buildSeedFields({
  required CharacterDraft draft,
  required EntityCategorySchema playerCat,
  required Entity? race,
  required Entity? characterClass,
  required Entity? background,
}) {
  final stat = <String, int>{
    for (final k in kAbilityKeys)
      k: (draft.baseAbilities[k] ?? 10) + (draft.racialBonuses[k] ?? 0),
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
  if (fieldsByKey.containsKey('combat_stats')) {
    out['combat_stats'] = {
      'hp': maxHp,
      'max_hp': maxHp,
      'ac': 10 + dexMod,
      'speed': '30 ft',
      'level': draft.level,
      'initiative': dexMod >= 0 ? '+$dexMod' : '$dexMod',
      'cr': '',
      'xp': 0,
    };
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
  out['background_id'] = draft.backgroundId ?? '';
  out['subclass_id'] = draft.subclassId ?? '';
  out['feat_ids'] = [
    if (background?.fields['origin_feat_ref'] is String)
      background!.fields['origin_feat_ref'] as String,
    ...draft.featIds,
  ];
  out['equipment_choices'] = Map<String, String>.from(draft.equipmentChoices);
  out['feat_choices'] = Map<String, String>.from(draft.originFeatChoices);
  out['base_abilities'] = stat;

  // Inherit race / species traits + granted refs onto the PC. Species
  // exposes them as `trait_refs` / `granted_languages` / `granted_senses`
  // / `granted_damage_resistances` / `granted_skill_proficiencies`; PC
  // surface keys differ slightly so we map per pair.
  if (race != null) {
    void copyList(String fromKey, List<String> toKeys) {
      final src = race.fields[fromKey];
      if (src is! List) return;
      final ids = src.whereType<String>().toList();
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

    copyList('trait_refs', const ['trait_refs']);
    copyList('granted_languages', const ['language_refs', 'languages']);
    copyList('granted_senses', const ['senses']);
    copyList('granted_damage_resistances',
        const ['resistance_refs', 'damage_resistances']);
    copyList('granted_skill_proficiencies', const ['skill_proficiencies']);
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
    if (draft.worldName.isEmpty && worlds.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setWorld(worlds.first);
        onWorldPicked(worlds.first);
      });
    } else if (draft.worldName.isNotEmpty) {
      // Make sure the picked world's entities are loaded so race/class/
      // background steps see them. Idempotent — `_activateWorld` no-ops
      // when already active.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onWorldPicked(draft.worldName));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: draft.name,
          decoration: const InputDecoration(
            labelText: 'Character Name *',
          ),
          onChanged: notifier.setName,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: draft.description,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Short description',
            hintText: 'A weather-beaten ranger from the Northlands...',
          ),
          onChanged: notifier.setDescription,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue:
                    draft.templateId.isEmpty ? null : draft.templateId,
                decoration: const InputDecoration(labelText: 'Template *'),
                items: templates
                    .map((t) => DropdownMenuItem(
                          value: t.schemaId,
                          child: Text(t.name),
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
              child: DropdownButtonFormField<String>(
                initialValue: draft.worldName.isEmpty ? null : draft.worldName,
                decoration: InputDecoration(
                  labelText: 'World *',
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
                items: worlds
                    .map((w) =>
                        DropdownMenuItem(value: w, child: Text(w)))
                    .toList(),
                onChanged: activatingWorld
                    ? null
                    : (v) {
                        if (v == null) return;
                        notifier.setWorld(v);
                        onWorldPicked(v);
                      },
              ),
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
      ],
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
    final hasImage = path.isNotEmpty && File(path).existsSync();
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: hasImage
                ? Image.file(File(path), fit: BoxFit.cover)
                : Icon(Icons.add_a_photo_outlined,
                    color: palette.sidebarLabelSecondary),
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
    final entities = ref.watch(entityProvider);
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
              ? 'No "$slugLabel" entities in this world. You can add one later in the editor.'
              : 'No "$slugLabel" entities in this world. Create one in the Database tab first.',
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
              method: draft.abilityMethod,
              standardArrayUsed: _standardArrayUsageFor(draft, k),
              onBase: (v) => notifier.setAbility(k, v),
              onRacial: (v) => notifier.setRacialBonus(k, v),
            )),
        const SizedBox(height: 8),
        _RacialBonusHint(palette: palette),
      ],
    );
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

class _RacialBonusHint extends StatelessWidget {
  final DmToolColors palette;
  const _RacialBonusHint({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      '2024 SRD Origin: distribute +3 across abilities (e.g. +2/+1 or +1/+1/+1).',
      style: TextStyle(
        fontSize: 11,
        color: palette.sidebarLabelSecondary,
      ),
    );
  }
}

class _AbilityRow extends StatelessWidget {
  final String abilityKey;
  final int base;
  final int racial;
  final AbilityScoreMethod method;
  final List<int> standardArrayUsed;
  final ValueChanged<int> onBase;
  final ValueChanged<int> onRacial;

  const _AbilityRow({
    required this.abilityKey,
    required this.base,
    required this.racial,
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
            width: 80,
            child: DropdownButtonFormField<int>(
              initialValue: racial,
              decoration: const InputDecoration(labelText: 'Racial'),
              items: const [0, 1, 2, 3]
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text('+$v'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onRacial(v);
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              '= $total (${mod >= 0 ? '+' : ''}$mod)',
              style: TextStyle(
                color: palette.tabActiveText,
                fontWeight: FontWeight.w600,
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
          items: List.generate(8, (i) => 8 + i)
              .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
              .toList(),
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
}

class _ReviewStep extends ConsumerWidget {
  final CharacterDraft draft;
  const _ReviewStep({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final entities = ref.watch(entityProvider);
    String nameOf(String? id) =>
        id == null ? '—' : (entities[id]?.name ?? '—');

    final stat = <String, int>{
      for (final k in kAbilityKeys)
        k: (draft.baseAbilities[k] ?? 10) + (draft.racialBonuses[k] ?? 0),
    };

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 110,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Name', draft.name),
        row('World', draft.worldName),
        row('Template', draft.templateName),
        row('Level', '${draft.level}'),
        row('Alignment', draft.alignment.isEmpty ? '—' : draft.alignment),
        row('Race', nameOf(draft.raceId)),
        row('Class', nameOf(draft.classId)),
        row('Background', nameOf(draft.backgroundId)),
        row('Ability method', draft.abilityMethod.label),
        const SizedBox(height: 8),
        Text(
          'Ability Scores',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: palette.tabActiveText,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: kAbilityKeys.map((k) {
            final v = stat[k] ?? 10;
            final mod = abilityModifier(v);
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.featureCardBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: palette.featureCardBorder),
              ),
              child: Text(
                '$k $v (${mod >= 0 ? '+' : ''}$mod)',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
