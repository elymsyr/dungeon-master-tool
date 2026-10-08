import 'package:flutter/material.dart';
import '../../application/character_creation/pending_choices.dart';
import '../l10n/app_localizations.dart';
import 'srd_text.dart';

/// Bekleyen seviye seçiminin etiketi ("Wizard L4 · Pick 2 spells"): kalıp
/// arayüz dilinde, sınıf / hüner / özellik adı SRD içerik çevirisiyle.
String pendingChoiceLabel(BuildContext context, PendingChoice p) {
  final l = L10n.of(context)!;
  String cls(String en) => srdText(context, 'class', en);
  final name = p.classLabel ?? (p.classId ?? '');
  final lv = l.pcLevel(p.level);
  final prefix = name.isEmpty ? lv : '${cls(name)} $lv';
  switch (p.kind) {
    case PendingChoiceKind.asiOrFeat:
      return '$prefix · ${l.pcAsiOrFeat}';
    case PendingChoiceKind.fightingStyle:
      return '$prefix · ${l.pcFightingStyle}';
    case PendingChoiceKind.cantrips:
      return '$prefix · ${l.pcCantrips(p.count)}';
    case PendingChoiceKind.spells:
      final max = p.maxSpellLevel > 0
          ? ' (${l.pcUpToLevel(l.pcLevel(p.maxSpellLevel))})'
          : '';
      return '$prefix · ${l.pcSpells(p.count)}$max';
    case PendingChoiceKind.subclass:
      return '$prefix · ${l.pcSubclass}';
    case PendingChoiceKind.weaponMastery:
      return '$prefix · ${l.pcWeaponMastery(p.count)}';
    case PendingChoiceKind.skillProficiency:
      return '$prefix · ${l.pcSkillProficiency(p.count)}';
    case PendingChoiceKind.toolProficiency:
      return '$prefix · ${l.pcToolProficiency(p.count)}';
    case PendingChoiceKind.languages:
      return '$prefix · ${l.pcLanguages(p.count)}';
    case PendingChoiceKind.featChoice:
      // classLabel holds the feat name at finalize; featureName the group label.
      final feat = p.classLabel == null
          ? l.pcFeat
          : srdText(context, 'feat', p.classLabel!);
      final group = p.featureName == null
          ? l.pcFeatureOption
          : srdText(context, 'feat', p.featureName!);
      final suffix = p.count > 1 ? ' (${l.pcPickN(p.count)})' : '';
      return '$lv · $feat: $group$suffix';
    case PendingChoiceKind.expertise:
      return '$prefix · ${l.pcExpertise(p.count)}';
    case PendingChoiceKind.featAsi:
      return '$prefix · ${l.pcFeatAsi}';
    case PendingChoiceKind.divineOrder:
      return '$prefix · ${l.pcDivineOrder}';
    case PendingChoiceKind.featureOption:
      final f = p.featureName;
      if (f == null) return '$prefix · ${l.pcFeatureOption}';
      final c = cls(f);
      return '$prefix · ${c != f ? c : srdText(context, 'subclass', f)}';
  }
}

/// Themed `!` + count badge used on character card headers to surface
/// unresolved level-up choices. Light theme → deep blue text, soft amber
/// glow. Dark theme → warm amber text, soft blue glow. Tap-through.
Widget pendingChoicesBadge(BuildContext context, int count) {
  final scheme = Theme.of(context).colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  final fg = dark
      ? Color.lerp(scheme.primary, Colors.white, 0.45)!
      : Color.lerp(scheme.primary, Colors.black, 0.35)!;
  final glowBase = dark
      ? Color.lerp(scheme.secondary, Colors.white, 0.35)!
      : Color.lerp(scheme.secondary, Colors.black, 0.25)!;
  final glow = glowBase.withValues(alpha: 0.5);
  final shadows = <Shadow>[
    Shadow(color: glow, blurRadius: 4),
    Shadow(color: glow, blurRadius: 8),
  ];
  return Tooltip(
    message:
        L10n.of(context)!.pendingChoicesTooltip(count),
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        '!',
        style: TextStyle(
          color: fg,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: shadows,
        ),
      ),
    ),
  );
}
