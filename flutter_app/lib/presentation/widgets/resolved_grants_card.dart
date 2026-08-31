import 'package:flutter/material.dart';

import '../../domain/entities/character/effective_character.dart';
import '../../domain/entities/entity.dart';
import '../theme/dm_tool_colors.dart';
import '../screens/database/entity_card.dart';

/// Read-only summary of grants computed by [CharacterResolver] but not always
/// mirrored on the PC entity's raw ref fields — senses, damage resistances /
/// immunities / vulnerabilities, and condition immunities.
///
/// Tamamen pasif: burada tıklanacak bir şey yok. Sayılabilir sınıf kaynakları
/// (Rage, Bardic Inspiration, Sorcery Points…) buradan çıkarıldı, sayfanın
/// "Class Resources" grubunda `ClassResourcesTracker` olarak yaşıyorlar.
class ResolvedGrantsCard extends StatelessWidget {
  final EffectiveCharacter effective;
  final Map<String, Entity> entities;
  final DmToolColors palette;

  /// Character level — drives the per-level HP bonus note (Tough +2/level).
  final int characterLevel;

  /// Resolver-granted skill / tool proficiency ids that are NOT already
  /// checked on the editable proficiency table (e.g. a feat's direct
  /// `proficiency_grant` effect that never wrote back to `skills.rows`).
  /// Pre-diffed by the caller so the card surfaces only the otherwise-hidden
  /// grants instead of duplicating the whole proficiency list.
  final List<String> extraSkillProfIds;
  final List<String> extraToolProfIds;

  const ResolvedGrantsCard({
    super.key,
    required this.effective,
    required this.entities,
    required this.palette,
    this.characterLevel = 1,
    this.extraSkillProfIds = const [],
    this.extraToolProfIds = const [],
  });

  /// Satır rengini temaya oturtur: ham Material tonunun **rengini** korur
  /// (satırlar birbirinden ayırt edilebilsin diye), doygunluk/parlaklığı
  /// kart zeminine göre seçer ve bir miktar tema accent'ine karıştırır.
  /// Böylece koyu/açık her palette aynı okunabilirlikte çıkıyor.
  Color _tone(Color raw) {
    final dark = ThemeData.estimateBrightnessForColor(palette.featureCardBg) ==
        Brightness.dark;
    final h = HSLColor.fromColor(raw);
    final toned = h
        .withSaturation((h.saturation * 0.85).clamp(0.35, 0.8))
        .withLightness(dark ? 0.62 : 0.42)
        .toColor();
    return Color.lerp(toned, palette.featureCardAccent, 0.18)!;
  }

  static final _uuidRe = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  String _nameOf(String id) {
    final e = entities[id];
    if (e != null) return e.name;
    // Unresolved entity ref (e.g. official-package content that hasn't loaded
    // yet) — don't leak a raw UUID onto the sheet. Synthetic ids (`pool:…`,
    // etc.) aren't UUIDs, so they still pass through for prettifying.
    if (_uuidRe.hasMatch(id)) return 'Unknown';
    return id;
  }

  /// Optional range suffix for sense chips (`Darkvision 120 ft`). Returns the
  /// raw name when no override is present so other chip kinds stay untouched.
  String _nameWithRange(String id) {
    final name = _nameOf(id);
    final r = effective.senseRanges[id];
    if (r == null || r <= 0) return name;
    return '$name $r ft';
  }

  String _chipLabel(String id, {bool withRange = false}) {
    final name = withRange ? _nameWithRange(id) : _nameOf(id);
    final sources = effective.grantSources[id];
    if (sources == null || sources.isEmpty) return name;
    return '$name — ${sources.join(', ')}';
  }

  Widget _chipRow(
    String label,
    List<String> ids,
    Color chipColor, {
    bool withRange = false,
  }) {
    if (ids.isEmpty) return const SizedBox.shrink();
    chipColor = _tone(chipColor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final id in ids)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(palette.chipBorderRadius),
                border: Border.all(
                  color: chipColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                _chipLabel(id, withRange: withRange),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.srdInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Extra-speed row (fly/swim/climb/burrow). Renders as text chips of
  /// `mode N ft` since speeds aren't entity ids.
  Widget _extraSpeedsRow(Map<String, int> speeds, Color chipColor) {
    if (speeds.isEmpty) return const SizedBox.shrink();
    chipColor = _tone(chipColor);
    final entries = speeds.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              'Extra Speeds',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final e in entries)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(palette.chipBorderRadius),
                border: Border.all(
                  color: chipColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                '${e.key} ${e.value} ft',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.srdInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Generic label + plain-text chips row (values aren't entity ids). Used for
  /// the HP / initiative bonus notes. Hidden when [chips] is empty.
  Widget _textChipRow(String label, List<String> chips, Color chipColor) {
    if (chips.isEmpty) return const SizedBox.shrink();
    chipColor = _tone(chipColor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final c in chips)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(palette.chipBorderRadius),
                border: Border.all(
                  color: chipColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                c,
                style: TextStyle(fontSize: 12, color: palette.srdInk),
              ),
            ),
        ],
      ),
    );
  }

  /// Compose the feat HP-bonus note chips from the per-level + flat bonuses.
  /// Empty when the character carries no feat HP bonus.
  List<String> _hpBonusChips() {
    final perLevel = effective.hpBonusPerLevel;
    final flat = effective.hpBonusFlat;
    final total = perLevel * characterLevel + flat;
    if (total == 0) return const [];
    final sign = total > 0 ? '+' : '';
    if (perLevel != 0 && flat != 0) {
      return ['$sign$total max HP ($flat + $perLevel/level × $characterLevel)'];
    }
    if (perLevel != 0) {
      return ['$sign$total max HP ($perLevel/level × $characterLevel)'];
    }
    return ['$sign$total max HP'];
  }

  /// "Other Effects" — the `mechanicalNotes` lines collected from every
  /// granted card. These are the rules the engine does not compute
  /// (advantage riders, rerolls, reaction abilities, …) surfaced verbatim so
  /// the player still sees them on the sheet.
  Widget _mechanicalNotesBlock(List<String> notes) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Other Effects',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 4),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                '• $note',
                style: TextStyle(fontSize: 12, color: palette.srdInk),
              ),
            ),
        ],
      ),
    );
  }

  /// Render unarmored AC formula entries (Barbarian/Monk/Sorcerer Draconic
  /// Resilience). Sheet's AC field is manual — this row surfaces the formula
  /// so the player knows what to set it to when not wearing armor.
  Widget _unarmoredFormulasBlock(List<Map<String, dynamic>> formulas) {
    if (formulas.isEmpty) return const SizedBox.shrink();
    final unarmoredColor = _tone(Colors.blueGrey);
    String describe(Map<String, dynamic> eff) {
      final payload = eff['payload'];
      if (payload is! Map) return 'Unarmored AC';
      final base = payload['base'];
      final mods = payload['ability_mods'];
      final shield = payload['shield_allowed'] == true;
      final parts = <String>[];
      if (base != null) parts.add('$base');
      if (mods is List) {
        for (final m in mods) {
          parts.add('${m.toString()}_mod');
        }
      }
      final formula = parts.join(' + ');
      return shield ? '$formula (+shield)' : formula;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              'Unarmored AC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final eff in formulas)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: unarmoredColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(palette.chipBorderRadius),
                border: Border.all(
                  color: unarmoredColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                describe(eff),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.srdInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Render each conditionalGrants entry as a chip prefixed by the gating
  /// state. Groups entries by `kind` so the player sees one labelled row per
  /// (kind, state) bucket. Uses the kind's normal chip colour.
  Widget _conditionalGrantsBlock(List<Map<String, dynamic>> grants) {
    if (grants.isEmpty) return const SizedBox.shrink();
    const colourForKind = <String, Color>{
      'damage_resistance': Colors.green,
      'damage_immunity': Colors.blue,
      'damage_vulnerability': Colors.deepOrange,
      'condition_immunity_grant': Colors.purple,
    };
    const labelForKind = <String, String>{
      'damage_resistance': 'Resistances',
      'damage_immunity': 'Immunities',
      'damage_vulnerability': 'Vulnerabilities',
      'condition_immunity_grant': 'Condition Imm.',
    };
    // Bucket by (kind, state) → ordered id list.
    final buckets = <String, List<String>>{};
    final order = <String>[];
    for (final g in grants) {
      final kind = g['kind']?.toString() ?? '';
      final state = g['state']?.toString() ?? '';
      final ids = g['ids'];
      if (ids is! List) continue;
      final key = '$kind|$state';
      final list = buckets.putIfAbsent(key, () {
        order.add(key);
        return <String>[];
      });
      for (final id in ids) {
        if (id is String && !list.contains(id)) list.add(id);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in order)
          () {
            final parts = key.split('|');
            final kind = parts[0];
            final state = parts.length > 1 ? parts[1] : '';
            final label = labelForKind[kind] ?? kind;
            final stateLabel = state.replaceFirst('state:', '');
            final fullLabel =
                stateLabel.isEmpty ? label : '$label (while $stateLabel)';
            return _chipRow(
              fullLabel,
              buckets[key]!,
              colourForKind[kind] ?? Colors.grey,
            );
          }(),
      ],
    );
  }

  /// Resolver warnings (unapplied effect kinds, dropped rows). Rendered so
  /// "I authored an effect and nothing happened" is visible instead of silent.
  Widget _warningsBlock(List<String> warnings) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rule Warnings',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 4),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w,
                      style: TextStyle(fontSize: 12, color: palette.srdInk),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final senses = effective.senseEntityIds;
    final res = effective.damageResistanceIds;
    final imm = effective.damageImmunityIds;
    final vuln = effective.damageVulnerabilityIds;
    final cimm = effective.conditionImmunityIds;
    final traits = effective.autoGrantedTraitIds;
    final actions = effective.grantedActionIds;
    final bonusActions = effective.grantedBonusActionIds;
    final reactions = effective.grantedReactionIds;
    final extraSpeeds = effective.extraSpeeds;
    final conditional = effective.conditionalGrants;
    final mechanicalNotes = effective.mechanicalNotes;
    final unarmoredFormulas = effective.unarmoredFormulas;
    final freeCast = effective.freeCastSpellIds;
    final ritualBook = effective.ritualBookSpellIds;
    final activeConditions = effective.activeConditionIds;
    final hpChips = _hpBonusChips();
    final initiative = effective.initiativeBonus;
    final initChips = initiative != 0
        ? <String>['${initiative > 0 ? '+' : ''}$initiative initiative']
        : const <String>[];
    final armorProf = effective.proficiencies.armorCategoryIds;
    final weaponProf = effective.proficiencies.weaponCategoryIds;
    final warnings = effective.warnings;
    if (senses.isEmpty &&
        warnings.isEmpty &&
        res.isEmpty &&
        imm.isEmpty &&
        vuln.isEmpty &&
        cimm.isEmpty &&
        traits.isEmpty &&
        actions.isEmpty &&
        bonusActions.isEmpty &&
        reactions.isEmpty &&
        extraSpeeds.isEmpty &&
        conditional.isEmpty &&
        mechanicalNotes.isEmpty &&
        unarmoredFormulas.isEmpty &&
        freeCast.isEmpty &&
        ritualBook.isEmpty &&
        activeConditions.isEmpty &&
        hpChips.isEmpty &&
        initChips.isEmpty &&
        extraSkillProfIds.isEmpty &&
        extraToolProfIds.isEmpty &&
        armorProf.isEmpty &&
        weaponProf.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: BorderRadius.circular(palette.cardBorderRadius),
          border: Border.all(color: palette.featureCardBorder, width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntityCardSectionHeading(
              title: 'Resolved Grants',
              palette: palette,
              leadingIcon: Icons.shield_outlined,
            ),
            const SizedBox(height: 8),
            _chipRow('Senses', senses, Colors.indigo, withRange: true),
            _extraSpeedsRow(extraSpeeds, Colors.lightBlue),
            _textChipRow('HP Bonus', hpChips, Colors.pink),
            _textChipRow('Initiative', initChips, Colors.lightGreen),
            _chipRow('Skill Prof.', extraSkillProfIds, Colors.lime),
            _chipRow('Tool Prof.', extraToolProfIds, Colors.brown),
            _chipRow('Armor Prof.', armorProf, Colors.blueGrey),
            _chipRow('Weapon Prof.', weaponProf, Colors.orange),
            _chipRow('Resistances', res, Colors.green),
            _chipRow('Immunities', imm, Colors.blue),
            _chipRow('Vulnerabilities', vuln, Colors.deepOrange),
            _chipRow('Condition Imm.', cimm, Colors.purple),
            _conditionalGrantsBlock(conditional),
            _chipRow('Traits', traits, Colors.teal),
            _chipRow('Actions', actions, Colors.red),
            _chipRow('Bonus Actions', bonusActions, Colors.amber),
            _chipRow('Reactions', reactions, Colors.cyan),
            _mechanicalNotesBlock(mechanicalNotes),
            _unarmoredFormulasBlock(unarmoredFormulas),
            _chipRow('Free Casts', freeCast, Colors.deepPurple),
            _chipRow('Ritual Book', ritualBook, Colors.brown),
            _chipRow('Active Conditions', activeConditions, Colors.redAccent),
            if (warnings.isNotEmpty) _warningsBlock(warnings),
          ],
        ),
      ),
    );
  }
}
