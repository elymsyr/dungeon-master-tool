// Dev harness for the Markdown description-completion engine
// (`lib/domain/services/template_migration/description_generator.dart`;
// roadmap PR-3.0 / master-roadmap §4.1).
//
// Run from the Flutter project root (`flutter_app/`):
//
//     dart run tool/description_generator_harness.dart
//
// It exercises the per-kind effect/clause text templates and the per-category
// section assembler, and asserts:
//   * the §4.2 Athlete worked example assembles **byte-for-byte** the doc's
//     AFTER `description` string (proves section ordering + bold-led paragraphs),
//   * representative parametric kinds (content-convert §6) render the expected
//     bold-led prose,
//   * an out-of-scope combat kind and an unknown kind still render (nothing is
//     dropped — content-convert §6),
//   * assembly is deterministic (two runs are identical) and drops empty
//     sections.
//
// The engine is pure-Dart and inert in the app until the wave converter
// (`convert_packs_v3.dart`) calls it, so this script is the verification gate
// for the slice before any pack is converted. NOT part of the app build.
//
// ignore_for_file: avoid_print

import 'package:dungeon_master_tool/domain/services/template_migration/description_generator.dart';

int _failures = 0;

void _check(String label, bool ok, {String? got, String? want}) {
  print('${ok ? 'PASS' : 'FAIL'}  $label');
  if (!ok) {
    _failures++;
    if (want != null) print('        want: ${want.replaceAll('\n', '\\n')}');
    if (got != null) print('        got:  ${got.replaceAll('\n', '\\n')}');
  }
}

void main() {
  // ── 1. §4.2 Athlete worked example — full doc-parity assembly. ──────────
  // The Effects paragraphs are the feat's bespoke `benefits` prose (merged per
  // §4.1); the ASI paragraph is generated; the prereq comes from a clause.
  const athleteIntro =
      'You hone your physique. Climbing and jumping become trivial.';
  final prereqBody = renderPrerequisitesBody([
    {'kind': 'min_character_level', 'value': 4},
  ]);
  const effectsBody =
      "**Climbing.** Climbing doesn't cost you extra movement.\n\n"
      '**Jumping.** You can make a running long jump or high jump after moving '
      'only 5 feet.\n\n'
      '**Standing Up.** Standing up from Prone uses only 5 feet of movement.';
  const asiBody =
      '**Ability Score Increase.** Choose Strength or Dexterity and increase '
      'it by 1 (max 20).';

  final athlete = assembleDescription(
    categorySlug: 'feat',
    intro: athleteIntro,
    sections: {
      'Prerequisites': prereqBody,
      'Effects': effectsBody,
      'When You Gain This Feat': asiBody,
    },
  );

  const athleteExpected =
      'You hone your physique. Climbing and jumping become trivial.\n\n'
      '### Prerequisites\n- Character level 4+\n\n'
      '### Effects\n'
      "**Climbing.** Climbing doesn't cost you extra movement.\n\n"
      '**Jumping.** You can make a running long jump or high jump after moving '
      'only 5 feet.\n\n'
      '**Standing Up.** Standing up from Prone uses only 5 feet of movement.\n\n'
      '### When You Gain This Feat\n'
      '**Ability Score Increase.** Choose Strength or Dexterity and increase '
      'it by 1 (max 20).';

  _check('Athlete §4.2 doc-parity', athlete == athleteExpected,
      got: athlete, want: athleteExpected);

  // ── 2. Section ordering — supplied out of order, emitted canonically; an
  // empty body drops its heading. ─────────────────────────────────────────
  final ordered = assembleDescription(
    categorySlug: 'feat',
    intro: 'Intro.',
    sections: {
      'When You Gain This Feat': 'Z.',
      'Effects': 'Y.',
      'Prerequisites': '   ', // whitespace → dropped (no heading)
    },
  );
  const orderedExpected =
      'Intro.\n\n### Effects\nY.\n\n### When You Gain This Feat\nZ.';
  _check('feat section reorder + empty drop', ordered == orderedExpected,
      got: ordered, want: orderedExpected);

  // ── 3. Parametric effect kinds (content-convert §6). ────────────────────
  _check(
    'ability_score_bonus',
    renderEffect({'kind': 'ability_score_bonus', 'ability': 'str', 'value': 1}) ==
        '**Ability Score Increase.** Your Strength score increases by +1.',
    got: renderEffect(
        {'kind': 'ability_score_bonus', 'ability': 'str', 'value': 1}),
  );
  _check(
    'speed_bonus',
    renderEffect({'kind': 'speed_bonus', 'value': 10}) ==
        '**Speed.** Your walking speed increases by 10 feet.',
    got: renderEffect({'kind': 'speed_bonus', 'value': 10}),
  );
  _check(
    'damage_resistance',
    renderEffect({'kind': 'damage_resistance', 'name': 'fire'}) ==
        '**Resistance.** You have resistance to fire damage.',
    got: renderEffect({'kind': 'damage_resistance', 'name': 'fire'}),
  );
  _check(
    'proficiency_grant skill',
    renderEffect({
          'kind': 'proficiency_grant',
          'target_kind': 'skill',
          'name': 'Athletics'
        }) ==
        '**Proficiency.** You gain proficiency in the Athletics skill.',
    got: renderEffect({
      'kind': 'proficiency_grant',
      'target_kind': 'skill',
      'name': 'Athletics'
    }),
  );
  _check(
    'sense_grant with range',
    renderEffect({
          'kind': 'sense_grant',
          'name': 'Darkvision',
          'payload': {'range_ft': 60}
        }) ==
        '**Sense.** You gain Darkvision out to 60 feet.',
    got: renderEffect({
      'kind': 'sense_grant',
      'name': 'Darkvision',
      'payload': {'range_ft': 60}
    }),
  );

  // ── 4. Authored text wins over the template (never overwrite prose). ────
  final authored = renderEffect({
    'kind': 'ac_bonus',
    'value': 1,
    'text': '**Shield Master.** You can shove as a bonus action.',
  });
  _check(
    'authored text wins',
    authored == '**Shield Master.** You can shove as a bonus action.',
    got: authored,
  );

  // ── 5. Out-of-scope combat kind + unknown kind still render (nothing
  // dropped — content-convert §6). ─────────────────────────────────────────
  final combat = renderEffect({'kind': 'crit_range_extend', 'value': 19});
  _check('combat kind renders', combat.startsWith('**Crit Range Extend.**'),
      got: combat);
  final unknown = renderEffect({'kind': 'totally_made_up_kind'});
  _check('unknown kind renders non-empty', unknown.isNotEmpty, got: unknown);
  _check('null effect → empty', renderEffect(null).isEmpty);

  // ── 6. Prereq clauses. ──────────────────────────────────────────────────
  _check(
    'min_ability_score clause',
    renderPrereqClause(
            {'kind': 'min_ability_score', 'ability': 'dex', 'value': 13}) ==
        'Dexterity 13+',
    got: renderPrereqClause(
        {'kind': 'min_ability_score', 'ability': 'dex', 'value': 13}),
  );
  _check(
    'equipped_armor_kind clause',
    renderPrereqClause({
          'kind': 'equipped_armor_kind',
          'args': {'value': 'medium'}
        }) ==
        'Wearing medium armor',
    got: renderPrereqClause({
      'kind': 'equipped_armor_kind',
      'args': {'value': 'medium'}
    }),
  );

  // ── 7. Determinism — same inputs, identical output across two runs. ─────
  final run1 = assembleDescription(
      categorySlug: 'feat', intro: athleteIntro, sections: {'Effects': effectsBody});
  final run2 = assembleDescription(
      categorySlug: 'feat', intro: athleteIntro, sections: {'Effects': effectsBody});
  _check('deterministic assembly', run1 == run2);

  print('');
  print(_failures == 0
      ? 'OK — all description-generator checks passed.'
      : 'FAILED — $_failures check(s) failed.');
}
