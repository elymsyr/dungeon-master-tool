import 'package:flutter/material.dart';

/// ThemeExtension — Python ThemeManager.DEFAULT_PALETTE'in Flutter karşılığı.
/// Tüm 80+ renk değişkeni burada tanımlanır. Her tema kendi DmToolColors instance'ı sağlar.
class DmToolColors extends ThemeExtension<DmToolColors> {
  // --- Mind Map & Canvas ---
  final Color canvasBg;
  final Color gridColor;
  final Color nodeBgNote;
  final Color nodeBgEntity;
  final Color nodeText;
  final Color lineColor;
  final Color lineSelected;

  // --- Markdown/HTML ---
  final Color htmlText;
  final Color htmlLink;
  final Color htmlHeader;
  final Color htmlCodeBg;

  // --- Floating Controls ---
  final Color uiFloatingBg;
  final Color uiFloatingBorder;
  final Color uiFloatingText;
  final Color uiFloatingHoverBg;
  final Color uiFloatingHoverText;

  // --- Autosave ---
  final Color uiAutosaveTextSaved;
  final Color uiAutosaveTextEditing;

  // --- Combat & Tokens ---
  final Color tokenBorderPlayer;
  final Color tokenBorderHostile;
  final Color tokenBorderFriendly;
  final Color tokenBorderNeutral;
  final Color tokenBorderActive;

  // --- HP Bar ---
  final Color hpBarHigh;
  final Color hpBarMed;
  final Color hpBarLow;
  final Color hpWidgetBg;
  final Color hpBtnDecreaseBg;
  final Color hpBtnIncreaseBg;

  // --- Condition Icons ---
  final Color conditionDefaultBg;
  final Color conditionText;

  // --- Battle Map ---
  final Color fogTempPath;

  // --- Map Pins ---
  final Color pinNpc;
  final Color pinMonster;
  final Color pinLocation;
  final Color pinPlayer;
  final Color pinDefault;

  // --- DM Notes ---
  final Color dmNoteBorder;
  final Color dmNoteTitle;

  // --- Sidebar ---
  final Color sidebarLabelSecondary;
  final Color sidebarDivider;
  final Color sidebarFilterBg;

  // --- Tabs ---
  final Color tabBg;
  final Color tabActiveBg;
  final Color tabHoverBg;
  final Color tabText;
  final Color tabActiveText;
  final Color tabIndicator;

  // --- Action Buttons ---
  final Color dangerBtnBg;
  final Color dangerBtnText;
  final Color successBtnBg;
  final Color successBtnText;
  final Color hpBtnText;

  // --- Popup ---
  final Color uiPopupBg;
  final Color uiPopupBorder;
  final Color uiPopupText;
  final Color uiPopupSelected;

  // --- Feature Card (entity card sections) ---
  final Color featureCardBg;
  final Color featureCardBorder;
  final Color featureCardAccent;   // Sol kenarlık (tek renk, tema accent)

  // --- Style Parameters (tema-spesifik görünüm) ---
  final double borderRadius;
  final double cardBorderRadius;
  final double buttonPaddingH;
  final double buttonPaddingV;
  final bool useBorders;
  final bool useSerif;

  // --- Radius scale (doc51 token set) ---
  // New theme-driven replacements for inline `BorderRadius.circular(N)`.
  // Defaults keep existing rendered pixels identical across palettes.
  final double radiusXs;   // 2
  final double radiusSm;   // 4 — matches `borderRadius`
  final double radiusMd;   // 6
  final double radiusLg;   // 8 — matches `cardBorderRadius`
  final double radiusXl;   // 10
  final double radius2xl;  // 12
  final double radius3xl;  // 16

  // --- Spacing scale ---
  final double gap2;   // 2
  final double gap4;   // 4
  final double gap6;   // 6
  final double gap8;   // 8
  final double gap12;  // 12
  final double gap16;  // 16
  final double gap24;  // 24
  final double gap32;  // 32
  final double padXs;  // 4
  final double padSm;  // 8
  final double padMd;  // 12
  final double padLg;  // 16
  final double padXl;  // 24

  // --- Semantic text colors ---
  /// Muted inline-link color (EntityLinkChip text, etc.). Reads as "linked
  /// but quiet" — same size/family as surroundings, just slightly grayed.
  final Color linkMuted;

  /// Neutral category fallback (e.g. when a schema category is missing).
  /// Replaces the hardcoded `0xFF808080` in the database screen.
  final Color categoryNeutral;

  /// Overlay scrim for modals / fog-of-war / drop-zones. Replaces
  /// scattered hardcoded `Colors.black54` / `0xFF000000` alpha variants.
  final Color overlayScrim;
  final Color primaryBtnBg;
  final Color primaryBtnText;
  final Color actionBtnBg;
  final Color actionBtnText;
  // Default buton renkleri (gri, renkli değil)
  final Color buttonDefaultBg;
  final Color buttonDefaultText;
  final Color buttonHoverBg;
  final Color buttonPressBg;

  // --- Misc ---
  final Color mapBg;

  const DmToolColors({
    required this.canvasBg,
    required this.gridColor,
    required this.nodeBgNote,
    required this.nodeBgEntity,
    required this.nodeText,
    required this.lineColor,
    required this.lineSelected,
    required this.htmlText,
    required this.htmlLink,
    required this.htmlHeader,
    required this.htmlCodeBg,
    required this.uiFloatingBg,
    required this.uiFloatingBorder,
    required this.uiFloatingText,
    required this.uiFloatingHoverBg,
    required this.uiFloatingHoverText,
    required this.uiAutosaveTextSaved,
    required this.uiAutosaveTextEditing,
    required this.tokenBorderPlayer,
    required this.tokenBorderHostile,
    required this.tokenBorderFriendly,
    required this.tokenBorderNeutral,
    required this.tokenBorderActive,
    required this.hpBarHigh,
    required this.hpBarMed,
    required this.hpBarLow,
    required this.hpWidgetBg,
    required this.hpBtnDecreaseBg,
    required this.hpBtnIncreaseBg,
    required this.conditionDefaultBg,
    required this.conditionText,
    required this.fogTempPath,
    required this.pinNpc,
    required this.pinMonster,
    required this.pinLocation,
    required this.pinPlayer,
    required this.pinDefault,
    required this.dmNoteBorder,
    required this.dmNoteTitle,
    required this.sidebarLabelSecondary,
    required this.sidebarDivider,
    required this.sidebarFilterBg,
    required this.tabBg,
    required this.tabActiveBg,
    required this.tabHoverBg,
    required this.tabText,
    required this.tabActiveText,
    required this.tabIndicator,
    required this.dangerBtnBg,
    this.dangerBtnText = Colors.white,
    required this.successBtnBg,
    this.successBtnText = Colors.white,
    this.hpBtnText = Colors.white,
    required this.uiPopupBg,
    required this.uiPopupBorder,
    required this.uiPopupText,
    required this.uiPopupSelected,
    required this.featureCardBg,
    required this.featureCardBorder,
    required this.featureCardAccent,
    this.borderRadius = 4,
    this.cardBorderRadius = 8,
    this.buttonPaddingH = 10,
    this.buttonPaddingV = 4,
    this.useBorders = true,
    this.useSerif = false,
    this.primaryBtnBg = const Color(0xFF1565C0),
    this.primaryBtnText = Colors.white,
    this.actionBtnBg = const Color(0xFFF9A825),
    this.actionBtnText = Colors.black,
    this.buttonDefaultBg = const Color(0xFF3C3F41),
    this.buttonDefaultText = const Color(0xFFE0E0E0),
    this.buttonHoverBg = const Color(0xFF4E5254),
    this.buttonPressBg = const Color(0xFF2B2B2B),
    this.radiusXs = 2,
    this.radiusSm = 4,
    this.radiusMd = 6,
    this.radiusLg = 8,
    this.radiusXl = 10,
    this.radius2xl = 12,
    this.radius3xl = 16,
    this.gap2 = 2,
    this.gap4 = 4,
    this.gap6 = 6,
    this.gap8 = 8,
    this.gap12 = 12,
    this.gap16 = 16,
    this.gap24 = 24,
    this.gap32 = 32,
    this.padXs = 4,
    this.padSm = 8,
    this.padMd = 12,
    this.padLg = 16,
    this.padXl = 24,
    this.linkMuted = const Color(0xFF8A8A8A),
    this.categoryNeutral = const Color(0xFF808080),
    this.overlayScrim = const Color(0x8A000000),
    required this.mapBg,
  });

  BorderRadius get br => BorderRadius.circular(borderRadius);
  BorderRadius get cbr => BorderRadius.circular(cardBorderRadius);

  @override
  ThemeExtension<DmToolColors> copyWith({
    Color? canvasBg,
    Color? gridColor,
    Color? nodeBgNote,
    Color? nodeBgEntity,
    Color? nodeText,
    Color? lineColor,
    Color? lineSelected,
    Color? htmlText,
    Color? htmlLink,
    Color? htmlHeader,
    Color? htmlCodeBg,
    Color? uiFloatingBg,
    Color? uiFloatingBorder,
    Color? uiFloatingText,
    Color? uiFloatingHoverBg,
    Color? uiFloatingHoverText,
    Color? uiAutosaveTextSaved,
    Color? uiAutosaveTextEditing,
    Color? tokenBorderPlayer,
    Color? tokenBorderHostile,
    Color? tokenBorderFriendly,
    Color? tokenBorderNeutral,
    Color? tokenBorderActive,
    Color? hpBarHigh,
    Color? hpBarMed,
    Color? hpBarLow,
    Color? hpWidgetBg,
    Color? hpBtnDecreaseBg,
    Color? hpBtnIncreaseBg,
    Color? conditionDefaultBg,
    Color? conditionText,
    Color? fogTempPath,
    Color? pinNpc,
    Color? pinMonster,
    Color? pinLocation,
    Color? pinPlayer,
    Color? pinDefault,
    Color? dmNoteBorder,
    Color? dmNoteTitle,
    Color? sidebarLabelSecondary,
    Color? sidebarDivider,
    Color? sidebarFilterBg,
    Color? tabBg,
    Color? tabActiveBg,
    Color? tabHoverBg,
    Color? tabText,
    Color? tabActiveText,
    Color? tabIndicator,
    Color? dangerBtnBg,
    Color? dangerBtnText,
    Color? successBtnBg,
    Color? successBtnText,
    Color? hpBtnText,
    Color? uiPopupBg,
    Color? uiPopupBorder,
    Color? uiPopupText,
    Color? uiPopupSelected,
    Color? featureCardBg,
    Color? featureCardBorder,
    Color? featureCardAccent,
    double? borderRadius,
    double? cardBorderRadius,
    double? buttonPaddingH,
    double? buttonPaddingV,
    bool? useBorders,
    bool? useSerif,
    Color? primaryBtnBg,
    Color? primaryBtnText,
    Color? actionBtnBg,
    Color? actionBtnText,
    Color? buttonDefaultBg,
    Color? buttonDefaultText,
    Color? buttonHoverBg,
    Color? buttonPressBg,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radius2xl,
    double? radius3xl,
    double? gap2,
    double? gap4,
    double? gap6,
    double? gap8,
    double? gap12,
    double? gap16,
    double? gap24,
    double? gap32,
    double? padXs,
    double? padSm,
    double? padMd,
    double? padLg,
    double? padXl,
    Color? linkMuted,
    Color? categoryNeutral,
    Color? overlayScrim,
    Color? mapBg,
  }) {
    return DmToolColors(
      canvasBg: canvasBg ?? this.canvasBg,
      gridColor: gridColor ?? this.gridColor,
      nodeBgNote: nodeBgNote ?? this.nodeBgNote,
      nodeBgEntity: nodeBgEntity ?? this.nodeBgEntity,
      nodeText: nodeText ?? this.nodeText,
      lineColor: lineColor ?? this.lineColor,
      lineSelected: lineSelected ?? this.lineSelected,
      htmlText: htmlText ?? this.htmlText,
      htmlLink: htmlLink ?? this.htmlLink,
      htmlHeader: htmlHeader ?? this.htmlHeader,
      htmlCodeBg: htmlCodeBg ?? this.htmlCodeBg,
      uiFloatingBg: uiFloatingBg ?? this.uiFloatingBg,
      uiFloatingBorder: uiFloatingBorder ?? this.uiFloatingBorder,
      uiFloatingText: uiFloatingText ?? this.uiFloatingText,
      uiFloatingHoverBg: uiFloatingHoverBg ?? this.uiFloatingHoverBg,
      uiFloatingHoverText: uiFloatingHoverText ?? this.uiFloatingHoverText,
      uiAutosaveTextSaved: uiAutosaveTextSaved ?? this.uiAutosaveTextSaved,
      uiAutosaveTextEditing: uiAutosaveTextEditing ?? this.uiAutosaveTextEditing,
      tokenBorderPlayer: tokenBorderPlayer ?? this.tokenBorderPlayer,
      tokenBorderHostile: tokenBorderHostile ?? this.tokenBorderHostile,
      tokenBorderFriendly: tokenBorderFriendly ?? this.tokenBorderFriendly,
      tokenBorderNeutral: tokenBorderNeutral ?? this.tokenBorderNeutral,
      tokenBorderActive: tokenBorderActive ?? this.tokenBorderActive,
      hpBarHigh: hpBarHigh ?? this.hpBarHigh,
      hpBarMed: hpBarMed ?? this.hpBarMed,
      hpBarLow: hpBarLow ?? this.hpBarLow,
      hpWidgetBg: hpWidgetBg ?? this.hpWidgetBg,
      hpBtnDecreaseBg: hpBtnDecreaseBg ?? this.hpBtnDecreaseBg,
      hpBtnIncreaseBg: hpBtnIncreaseBg ?? this.hpBtnIncreaseBg,
      conditionDefaultBg: conditionDefaultBg ?? this.conditionDefaultBg,
      conditionText: conditionText ?? this.conditionText,
      fogTempPath: fogTempPath ?? this.fogTempPath,
      pinNpc: pinNpc ?? this.pinNpc,
      pinMonster: pinMonster ?? this.pinMonster,
      pinLocation: pinLocation ?? this.pinLocation,
      pinPlayer: pinPlayer ?? this.pinPlayer,
      pinDefault: pinDefault ?? this.pinDefault,
      dmNoteBorder: dmNoteBorder ?? this.dmNoteBorder,
      dmNoteTitle: dmNoteTitle ?? this.dmNoteTitle,
      sidebarLabelSecondary: sidebarLabelSecondary ?? this.sidebarLabelSecondary,
      sidebarDivider: sidebarDivider ?? this.sidebarDivider,
      sidebarFilterBg: sidebarFilterBg ?? this.sidebarFilterBg,
      tabBg: tabBg ?? this.tabBg,
      tabActiveBg: tabActiveBg ?? this.tabActiveBg,
      tabHoverBg: tabHoverBg ?? this.tabHoverBg,
      tabText: tabText ?? this.tabText,
      tabActiveText: tabActiveText ?? this.tabActiveText,
      tabIndicator: tabIndicator ?? this.tabIndicator,
      dangerBtnBg: dangerBtnBg ?? this.dangerBtnBg,
      dangerBtnText: dangerBtnText ?? this.dangerBtnText,
      successBtnBg: successBtnBg ?? this.successBtnBg,
      successBtnText: successBtnText ?? this.successBtnText,
      hpBtnText: hpBtnText ?? this.hpBtnText,
      uiPopupBg: uiPopupBg ?? this.uiPopupBg,
      uiPopupBorder: uiPopupBorder ?? this.uiPopupBorder,
      uiPopupText: uiPopupText ?? this.uiPopupText,
      uiPopupSelected: uiPopupSelected ?? this.uiPopupSelected,
      featureCardBg: featureCardBg ?? this.featureCardBg,
      featureCardBorder: featureCardBorder ?? this.featureCardBorder,
      featureCardAccent: featureCardAccent ?? this.featureCardAccent,
      borderRadius: borderRadius ?? this.borderRadius,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      buttonPaddingH: buttonPaddingH ?? this.buttonPaddingH,
      buttonPaddingV: buttonPaddingV ?? this.buttonPaddingV,
      useBorders: useBorders ?? this.useBorders,
      useSerif: useSerif ?? this.useSerif,
      primaryBtnBg: primaryBtnBg ?? this.primaryBtnBg,
      primaryBtnText: primaryBtnText ?? this.primaryBtnText,
      actionBtnBg: actionBtnBg ?? this.actionBtnBg,
      actionBtnText: actionBtnText ?? this.actionBtnText,
      buttonDefaultBg: buttonDefaultBg ?? this.buttonDefaultBg,
      buttonDefaultText: buttonDefaultText ?? this.buttonDefaultText,
      buttonHoverBg: buttonHoverBg ?? this.buttonHoverBg,
      buttonPressBg: buttonPressBg ?? this.buttonPressBg,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radius2xl: radius2xl ?? this.radius2xl,
      radius3xl: radius3xl ?? this.radius3xl,
      gap2: gap2 ?? this.gap2,
      gap4: gap4 ?? this.gap4,
      gap6: gap6 ?? this.gap6,
      gap8: gap8 ?? this.gap8,
      gap12: gap12 ?? this.gap12,
      gap16: gap16 ?? this.gap16,
      gap24: gap24 ?? this.gap24,
      gap32: gap32 ?? this.gap32,
      padXs: padXs ?? this.padXs,
      padSm: padSm ?? this.padSm,
      padMd: padMd ?? this.padMd,
      padLg: padLg ?? this.padLg,
      padXl: padXl ?? this.padXl,
      linkMuted: linkMuted ?? this.linkMuted,
      categoryNeutral: categoryNeutral ?? this.categoryNeutral,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      mapBg: mapBg ?? this.mapBg,
    );
  }

  @override
  ThemeExtension<DmToolColors> lerp(covariant DmToolColors? other, double t) {
    if (other == null) return this;
    return DmToolColors(
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t)!,
      gridColor: Color.lerp(gridColor, other.gridColor, t)!,
      nodeBgNote: Color.lerp(nodeBgNote, other.nodeBgNote, t)!,
      nodeBgEntity: Color.lerp(nodeBgEntity, other.nodeBgEntity, t)!,
      nodeText: Color.lerp(nodeText, other.nodeText, t)!,
      lineColor: Color.lerp(lineColor, other.lineColor, t)!,
      lineSelected: Color.lerp(lineSelected, other.lineSelected, t)!,
      htmlText: Color.lerp(htmlText, other.htmlText, t)!,
      htmlLink: Color.lerp(htmlLink, other.htmlLink, t)!,
      htmlHeader: Color.lerp(htmlHeader, other.htmlHeader, t)!,
      htmlCodeBg: Color.lerp(htmlCodeBg, other.htmlCodeBg, t)!,
      uiFloatingBg: Color.lerp(uiFloatingBg, other.uiFloatingBg, t)!,
      uiFloatingBorder: Color.lerp(uiFloatingBorder, other.uiFloatingBorder, t)!,
      uiFloatingText: Color.lerp(uiFloatingText, other.uiFloatingText, t)!,
      uiFloatingHoverBg: Color.lerp(uiFloatingHoverBg, other.uiFloatingHoverBg, t)!,
      uiFloatingHoverText: Color.lerp(uiFloatingHoverText, other.uiFloatingHoverText, t)!,
      uiAutosaveTextSaved: Color.lerp(uiAutosaveTextSaved, other.uiAutosaveTextSaved, t)!,
      uiAutosaveTextEditing: Color.lerp(uiAutosaveTextEditing, other.uiAutosaveTextEditing, t)!,
      tokenBorderPlayer: Color.lerp(tokenBorderPlayer, other.tokenBorderPlayer, t)!,
      tokenBorderHostile: Color.lerp(tokenBorderHostile, other.tokenBorderHostile, t)!,
      tokenBorderFriendly: Color.lerp(tokenBorderFriendly, other.tokenBorderFriendly, t)!,
      tokenBorderNeutral: Color.lerp(tokenBorderNeutral, other.tokenBorderNeutral, t)!,
      tokenBorderActive: Color.lerp(tokenBorderActive, other.tokenBorderActive, t)!,
      hpBarHigh: Color.lerp(hpBarHigh, other.hpBarHigh, t)!,
      hpBarMed: Color.lerp(hpBarMed, other.hpBarMed, t)!,
      hpBarLow: Color.lerp(hpBarLow, other.hpBarLow, t)!,
      hpWidgetBg: Color.lerp(hpWidgetBg, other.hpWidgetBg, t)!,
      hpBtnDecreaseBg: Color.lerp(hpBtnDecreaseBg, other.hpBtnDecreaseBg, t)!,
      hpBtnIncreaseBg: Color.lerp(hpBtnIncreaseBg, other.hpBtnIncreaseBg, t)!,
      conditionDefaultBg: Color.lerp(conditionDefaultBg, other.conditionDefaultBg, t)!,
      conditionText: Color.lerp(conditionText, other.conditionText, t)!,
      fogTempPath: Color.lerp(fogTempPath, other.fogTempPath, t)!,
      pinNpc: Color.lerp(pinNpc, other.pinNpc, t)!,
      pinMonster: Color.lerp(pinMonster, other.pinMonster, t)!,
      pinLocation: Color.lerp(pinLocation, other.pinLocation, t)!,
      pinPlayer: Color.lerp(pinPlayer, other.pinPlayer, t)!,
      pinDefault: Color.lerp(pinDefault, other.pinDefault, t)!,
      dmNoteBorder: Color.lerp(dmNoteBorder, other.dmNoteBorder, t)!,
      dmNoteTitle: Color.lerp(dmNoteTitle, other.dmNoteTitle, t)!,
      sidebarLabelSecondary: Color.lerp(sidebarLabelSecondary, other.sidebarLabelSecondary, t)!,
      sidebarDivider: Color.lerp(sidebarDivider, other.sidebarDivider, t)!,
      sidebarFilterBg: Color.lerp(sidebarFilterBg, other.sidebarFilterBg, t)!,
      tabBg: Color.lerp(tabBg, other.tabBg, t)!,
      tabActiveBg: Color.lerp(tabActiveBg, other.tabActiveBg, t)!,
      tabHoverBg: Color.lerp(tabHoverBg, other.tabHoverBg, t)!,
      tabText: Color.lerp(tabText, other.tabText, t)!,
      tabActiveText: Color.lerp(tabActiveText, other.tabActiveText, t)!,
      tabIndicator: Color.lerp(tabIndicator, other.tabIndicator, t)!,
      dangerBtnBg: Color.lerp(dangerBtnBg, other.dangerBtnBg, t)!,
      dangerBtnText: Color.lerp(dangerBtnText, other.dangerBtnText, t)!,
      successBtnBg: Color.lerp(successBtnBg, other.successBtnBg, t)!,
      successBtnText: Color.lerp(successBtnText, other.successBtnText, t)!,
      hpBtnText: Color.lerp(hpBtnText, other.hpBtnText, t)!,
      uiPopupBg: Color.lerp(uiPopupBg, other.uiPopupBg, t)!,
      uiPopupBorder: Color.lerp(uiPopupBorder, other.uiPopupBorder, t)!,
      uiPopupText: Color.lerp(uiPopupText, other.uiPopupText, t)!,
      uiPopupSelected: Color.lerp(uiPopupSelected, other.uiPopupSelected, t)!,
      featureCardBg: Color.lerp(featureCardBg, other.featureCardBg, t)!,
      featureCardBorder: Color.lerp(featureCardBorder, other.featureCardBorder, t)!,
      featureCardAccent: Color.lerp(featureCardAccent, other.featureCardAccent, t)!,
      borderRadius: t < 0.5 ? borderRadius : other.borderRadius,
      cardBorderRadius: t < 0.5 ? cardBorderRadius : other.cardBorderRadius,
      buttonPaddingH: t < 0.5 ? buttonPaddingH : other.buttonPaddingH,
      buttonPaddingV: t < 0.5 ? buttonPaddingV : other.buttonPaddingV,
      useBorders: t < 0.5 ? useBorders : other.useBorders,
      useSerif: t < 0.5 ? useSerif : other.useSerif,
      primaryBtnBg: Color.lerp(primaryBtnBg, other.primaryBtnBg, t)!,
      primaryBtnText: Color.lerp(primaryBtnText, other.primaryBtnText, t)!,
      actionBtnBg: Color.lerp(actionBtnBg, other.actionBtnBg, t)!,
      actionBtnText: Color.lerp(actionBtnText, other.actionBtnText, t)!,
      buttonDefaultBg: Color.lerp(buttonDefaultBg, other.buttonDefaultBg, t)!,
      buttonDefaultText: Color.lerp(buttonDefaultText, other.buttonDefaultText, t)!,
      buttonHoverBg: Color.lerp(buttonHoverBg, other.buttonHoverBg, t)!,
      buttonPressBg: Color.lerp(buttonPressBg, other.buttonPressBg, t)!,
      radiusXs: t < 0.5 ? radiusXs : other.radiusXs,
      radiusSm: t < 0.5 ? radiusSm : other.radiusSm,
      radiusMd: t < 0.5 ? radiusMd : other.radiusMd,
      radiusLg: t < 0.5 ? radiusLg : other.radiusLg,
      radiusXl: t < 0.5 ? radiusXl : other.radiusXl,
      radius2xl: t < 0.5 ? radius2xl : other.radius2xl,
      radius3xl: t < 0.5 ? radius3xl : other.radius3xl,
      gap2: t < 0.5 ? gap2 : other.gap2,
      gap4: t < 0.5 ? gap4 : other.gap4,
      gap6: t < 0.5 ? gap6 : other.gap6,
      gap8: t < 0.5 ? gap8 : other.gap8,
      gap12: t < 0.5 ? gap12 : other.gap12,
      gap16: t < 0.5 ? gap16 : other.gap16,
      gap24: t < 0.5 ? gap24 : other.gap24,
      gap32: t < 0.5 ? gap32 : other.gap32,
      padXs: t < 0.5 ? padXs : other.padXs,
      padSm: t < 0.5 ? padSm : other.padSm,
      padMd: t < 0.5 ? padMd : other.padMd,
      padLg: t < 0.5 ? padLg : other.padLg,
      padXl: t < 0.5 ? padXl : other.padXl,
      linkMuted: Color.lerp(linkMuted, other.linkMuted, t)!,
      categoryNeutral: Color.lerp(categoryNeutral, other.categoryNeutral, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
    );
  }
}
