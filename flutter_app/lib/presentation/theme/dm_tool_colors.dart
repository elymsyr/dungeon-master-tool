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

  // --- SRD Paper Look (entity card) ---
  final Color srdParchment;     // page bg behind entity card
  final Color srdInk;           // body text ink
  final Color srdHeadingRed;    // title + section heads
  final Color srdRule;          // thin divider line under headings
  final Color srdSubtitle;      // italic subtitle muted ink

  // --- Entity Card Style Flags (per-theme look) ---
  final bool cardHeadingUppercase;   // section heads uppercase + letter-spaced
  final bool cardShowRule;           // 1px rule under headings (SRD) vs hidden
  final bool cardBorderlessInputs;   // schema field inputs no border/fill

  // --- Style Parameters (tema-spesifik görünüm) ---
  final double borderRadius;
  final double cardBorderRadius;
  final double chipBorderRadius;
  final double buttonPaddingH;
  final double buttonPaddingV;
  final bool useBorders;
  final bool useSerif;
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
    this.srdParchment = const Color(0xFF1F1F1F),
    this.srdInk = const Color(0xFFE0E0E0),
    this.srdHeadingRed = const Color(0xFF42A5F5),
    this.srdRule = const Color(0xFF42A5F5),
    this.srdSubtitle = const Color(0xFF9CA3AF),
    this.cardHeadingUppercase = false,
    this.cardShowRule = true,
    this.cardBorderlessInputs = true,
    this.borderRadius = 2,
    this.cardBorderRadius = 4,
    this.chipBorderRadius = 6,
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
    required this.mapBg,
  });

  BorderRadius get br => BorderRadius.circular(borderRadius);
  BorderRadius get cbr => BorderRadius.circular(cardBorderRadius);
  BorderRadius get chr => BorderRadius.circular(chipBorderRadius);

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
    Color? srdParchment,
    Color? srdInk,
    Color? srdHeadingRed,
    Color? srdRule,
    Color? srdSubtitle,
    bool? cardHeadingUppercase,
    bool? cardShowRule,
    bool? cardBorderlessInputs,
    double? borderRadius,
    double? cardBorderRadius,
    double? chipBorderRadius,
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
      srdParchment: srdParchment ?? this.srdParchment,
      srdInk: srdInk ?? this.srdInk,
      srdHeadingRed: srdHeadingRed ?? this.srdHeadingRed,
      srdRule: srdRule ?? this.srdRule,
      srdSubtitle: srdSubtitle ?? this.srdSubtitle,
      cardHeadingUppercase: cardHeadingUppercase ?? this.cardHeadingUppercase,
      cardShowRule: cardShowRule ?? this.cardShowRule,
      cardBorderlessInputs: cardBorderlessInputs ?? this.cardBorderlessInputs,
      borderRadius: borderRadius ?? this.borderRadius,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      chipBorderRadius: chipBorderRadius ?? this.chipBorderRadius,
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
      srdParchment: Color.lerp(srdParchment, other.srdParchment, t)!,
      srdInk: Color.lerp(srdInk, other.srdInk, t)!,
      srdHeadingRed: Color.lerp(srdHeadingRed, other.srdHeadingRed, t)!,
      srdRule: Color.lerp(srdRule, other.srdRule, t)!,
      srdSubtitle: Color.lerp(srdSubtitle, other.srdSubtitle, t)!,
      cardHeadingUppercase: t < 0.5 ? cardHeadingUppercase : other.cardHeadingUppercase,
      cardShowRule: t < 0.5 ? cardShowRule : other.cardShowRule,
      cardBorderlessInputs: t < 0.5 ? cardBorderlessInputs : other.cardBorderlessInputs,
      borderRadius: t < 0.5 ? borderRadius : other.borderRadius,
      cardBorderRadius: t < 0.5 ? cardBorderRadius : other.cardBorderRadius,
      chipBorderRadius: t < 0.5 ? chipBorderRadius : other.chipBorderRadius,
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
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
    );
  }
}
