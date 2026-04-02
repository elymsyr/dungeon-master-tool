import 'package:flutter/material.dart';

import 'dm_tool_colors.dart';

/// Python ThemeManager.DEFAULT_PALETTE birebir karşılığı.
const _dark = DmToolColors(
  canvasBg: Color(0xFF181818),
  gridColor: Color(0xFF2B2B2B),
  nodeBgNote: Color(0xFFFFF9C4),
  nodeBgEntity: Color(0xFF2B2B2B),
  nodeText: Color(0xFF212121),
  lineColor: Color(0xFF787878),
  lineSelected: Color(0xFF42A5F5),
  htmlText: Color(0xFFE0E0E0),
  htmlLink: Color(0xFF42A5F5),
  htmlHeader: Color(0xFFFFB74D),
  htmlCodeBg: Color(0x4D808080),
  uiFloatingBg: Color(0xE6282828),
  uiFloatingBorder: Color(0xFF555555),
  uiFloatingText: Color(0xFFEEEEEE),
  uiFloatingHoverBg: Color(0xFF42A5F5),
  uiFloatingHoverText: Color(0xFFFFFFFF),
  uiAutosaveTextSaved: Color(0xFF81C784),
  uiAutosaveTextEditing: Color(0xFFFFB74D),
  tokenBorderPlayer: Color(0xFF4CAF50),
  tokenBorderHostile: Color(0xFFEF5350),
  tokenBorderFriendly: Color(0xFF42A5F5),
  tokenBorderNeutral: Color(0xFFBDBDBD),
  tokenBorderActive: Color(0xFFFFB74D),
  hpBarHigh: Color(0xFF2E7D32),
  hpBarMed: Color(0xFFFBC02D),
  hpBarLow: Color(0xFFC62828),
  hpWidgetBg: Color(0x4D000000),
  hpBtnDecreaseBg: Color(0xFFC62828),
  hpBtnIncreaseBg: Color(0xFF2E7D32),
  conditionDefaultBg: Color(0xFF5C6BC0),
  conditionText: Color(0xFFFFFFFF),
  fogTempPath: Color(0xFFFFFF00),
  pinNpc: Color(0xFFFF9800),
  pinMonster: Color(0xFFD32F2F),
  pinLocation: Color(0xFF2E7D32),
  pinPlayer: Color(0xFF4CAF50),
  pinDefault: Color(0xFF007ACC),
  dmNoteBorder: Color(0xFFD32F2F),
  dmNoteTitle: Color(0xFFE57373),
  sidebarLabelSecondary: Color(0xFF888888),
  sidebarDivider: Color(0xFF444444),
  sidebarFilterBg: Color(0xFF3A3A3A),
  tabBg: Color(0xFF2D2D2D),
  tabActiveBg: Color(0xFF1E1E1E),
  tabHoverBg: Color(0xFF3E3E3E),
  tabText: Color(0xFFAAAAAA),
  tabActiveText: Color(0xFFFFFFFF),
  tabIndicator: Color(0xFF007ACC),
  dangerBtnBg: Color(0xFFD32F2F),
  successBtnBg: Color(0xFF388E3C),
  uiPopupBg: Color(0xFF252526),
  uiPopupBorder: Color(0xFF444444),
  uiPopupText: Color(0xFFCCCCCC),
  uiPopupSelected: Color(0xFF094771),
  featureCardBg: Color(0xFF1E1E1E),       // dark.qss: #1e1e1e
  featureCardBorder: Color(0xFF3E3E3E),   // dark.qss: #3e3e3e
  featureCardAccent: Color(0xFF42A5F5),   // dark.qss: #42a5f5
  mapBg: Color(0xFF000000),
);

final Map<String, DmToolColors> themePalettes = {
  'dark': _dark,

  'light': _dark.copyWith(
    featureCardBg: const Color(0xFFF8F9FA),
    featureCardBorder: const Color(0xFFE2E8F0),
    featureCardAccent: const Color(0xFF3182CE),
    canvasBg: const Color(0xFFF5F7FA),
    gridColor: const Color(0xFFCBD5E0),
    nodeBgNote: const Color(0xFFFFFFFF),
    nodeBgEntity: const Color(0xFFFFFFFF),
    nodeText: const Color(0xFF2D3748),
    lineColor: const Color(0xFFA0AEC0),
    lineSelected: const Color(0xFF3182CE),
    htmlText: const Color(0xFF2D3748),
    htmlLink: const Color(0xFF3182CE),
    htmlHeader: const Color(0xFF2B6CB0),
    uiFloatingBg: const Color(0xE6FFFFFF),
    uiFloatingBorder: const Color(0xFFCBD5E0),
    uiFloatingText: const Color(0xFF2D3748),
    hpWidgetBg: const Color(0x1A000000),
    sidebarLabelSecondary: const Color(0xFF666666),
    sidebarDivider: const Color(0xFFCCCCCC),
    sidebarFilterBg: const Color(0xFFE8E8E8),
    tabBg: const Color(0xFFE0E0E0),
    tabActiveBg: const Color(0xFFF5F5F5),
    tabHoverBg: const Color(0xFFD0D0D0),
    tabText: const Color(0xFF555555),
    tabActiveText: const Color(0xFF111111),
    tabIndicator: const Color(0xFF1565C0),
    mapBg: const Color(0xFF222222),
    uiPopupBg: const Color(0xFFFFFFFF),
    uiPopupBorder: const Color(0xFFCBD5E0),
    uiPopupText: const Color(0xFF2D3748),
    uiPopupSelected: const Color(0xFFBEE3F8),
  ) as DmToolColors,

  'parchment': _dark.copyWith(
    featureCardBg: const Color(0xFFEBDCC6),
    featureCardBorder: const Color(0xFFBCAAA4),
    featureCardAccent: const Color(0xFF795548),
    canvasBg: const Color(0xFFDCCDB5),
    gridColor: const Color(0x263E2723),
    nodeBgNote: const Color(0xFFFDFBF7),
    nodeBgEntity: const Color(0xFFE5DACE),
    nodeText: const Color(0xFF3E2723),
    lineColor: const Color(0xFF8D6E63),
    lineSelected: const Color(0xFF5D4037),
    htmlText: const Color(0xFF3E2723),
    htmlLink: const Color(0xFF1565C0),
    htmlHeader: const Color(0xFF5D4037),
    uiFloatingBg: const Color(0xE6E5DACE),
    uiFloatingBorder: const Color(0xFF8D6E63),
    uiFloatingText: const Color(0xFF3E2723),
    uiFloatingHoverBg: const Color(0xFF8D6E63),
    dmNoteBorder: const Color(0xFF8D6E63),
    dmNoteTitle: const Color(0xFF5D4037),
  ) as DmToolColors,

  'ocean': _dark.copyWith(
    featureCardBg: const Color(0xFF0A131A),
    featureCardBorder: const Color(0xFF37474F),
    featureCardAccent: const Color(0xFF00BCD4),
    canvasBg: const Color(0xFF0F1B26),
    gridColor: const Color(0xFF1C313A),
    nodeBgNote: const Color(0xFFE0F7FA),
    nodeBgEntity: const Color(0xFF162533),
    nodeText: const Color(0xFF006064),
    lineColor: const Color(0xFF4DD0E1),
    lineSelected: const Color(0xFF00BCD4),
    htmlText: const Color(0xFFE0F7FA),
    htmlLink: const Color(0xFF26C6DA),
    htmlHeader: const Color(0xFF00BCD4),
    uiFloatingBg: const Color(0xE6162533),
    uiFloatingBorder: const Color(0xFF37474F),
    uiFloatingText: const Color(0xFFE0F7FA),
    uiFloatingHoverBg: const Color(0xFF00BCD4),
  ) as DmToolColors,

  'emerald': _dark.copyWith(
    featureCardBg: const Color(0xFF00150A),
    featureCardBorder: const Color(0xFF1B5E20),
    featureCardAccent: const Color(0xFF00E676),
    canvasBg: const Color(0xFF051E12),
    gridColor: const Color(0xFF1B5E20),
    nodeBgNote: const Color(0xFFE8F5E9),
    nodeBgEntity: const Color(0xFF0A2718),
    nodeText: const Color(0xFF1B5E20),
    lineColor: const Color(0xFF2E7D32),
    lineSelected: const Color(0xFF00E676),
    htmlText: const Color(0xFFE8F5E9),
    htmlLink: const Color(0xFF66BB6A),
    htmlHeader: const Color(0xFF00E676),
    uiFloatingBg: const Color(0xE60A2718),
    uiFloatingHoverBg: const Color(0xFF00E676),
  ) as DmToolColors,

  'midnight': _dark.copyWith(
    featureCardBg: const Color(0xFF1E1E1E),
    featureCardBorder: const Color(0xFF333333),
    featureCardAccent: const Color(0xFF7C4DFF),
    canvasBg: const Color(0xFF000000),
    gridColor: const Color(0xFF1A1A1A),
    nodeBgNote: const Color(0xFFE1BEE7),
    nodeBgEntity: const Color(0xFF121212),
    nodeText: const Color(0xFF4A148C),
    lineColor: const Color(0xFF7C4DFF),
    lineSelected: const Color(0xFFB388FF),
    htmlText: const Color(0xFFB0BEC5),
    htmlLink: const Color(0xFF7C4DFF),
    htmlHeader: const Color(0xFF651FFF),
    uiFloatingBg: const Color(0xE6141414),
    uiFloatingHoverBg: const Color(0xFF651FFF),
  ) as DmToolColors,

  'discord': _dark.copyWith(
    featureCardBg: const Color(0xFF2F3136),
    featureCardBorder: Colors.transparent,
    featureCardAccent: const Color(0xFF5865F2),
    canvasBg: const Color(0xFF202225),
    gridColor: const Color(0xFF2F3136),
    nodeBgNote: const Color(0xFF36393F),
    nodeBgEntity: const Color(0xFF2F3136),
    nodeText: const Color(0xFFDCDDDE),
    lineColor: const Color(0xFF40444B),
    lineSelected: const Color(0xFF5865F2),
    htmlText: const Color(0xFFDCDDDE),
    htmlLink: const Color(0xFF00B0F4),
    htmlHeader: const Color(0xFFFFFFFF),
    uiFloatingBg: const Color(0xFF2F3136),
    uiFloatingHoverBg: const Color(0xFF5865F2),
  ) as DmToolColors,

  'baldur': _dark.copyWith(
    featureCardBg: const Color(0xFF241B14),
    featureCardBorder: const Color(0xFF3D2E22),
    featureCardAccent: const Color(0xFFB88E4A),
    canvasBg: const Color(0xFF110B09),
    gridColor: const Color(0xFF3E2723),
    nodeBgNote: const Color(0xFFE0D8C8),
    nodeBgEntity: const Color(0xFF1A120B),
    nodeText: const Color(0xFF3E2723),
    lineColor: const Color(0xFF8D6E63),
    lineSelected: const Color(0xFFFFD700),
    htmlText: const Color(0xFFC8B696),
    htmlLink: const Color(0xFFFFD700),
    htmlHeader: const Color(0xFFB88E4A),
    uiFloatingBg: const Color(0xE61A120B),
    uiFloatingHoverBg: const Color(0xFFB88E4A),
    uiFloatingHoverText: const Color(0xFF000000),
  ) as DmToolColors,

  'grim': _dark.copyWith(
    featureCardBg: const Color(0xFF3E3B36),
    featureCardBorder: const Color(0xFF111111),
    featureCardAccent: const Color(0xFFA63A28),
    canvasBg: const Color(0xFF1C1C1C),
    gridColor: const Color(0xFF333333),
    nodeBgNote: const Color(0xFFD7CCC8),
    nodeBgEntity: const Color(0xFF262626),
    nodeText: const Color(0xFF3E2723),
    lineColor: const Color(0xFF555555),
    lineSelected: const Color(0xFFA63A28),
    htmlText: const Color(0xFFD7D7D7),
    htmlLink: const Color(0xFFA63A28),
    htmlHeader: const Color(0xFF8C2323),
    uiFloatingBg: const Color(0xFF333333),
    uiFloatingHoverBg: const Color(0xFFA63A28),
  ) as DmToolColors,

  'frost': _dark.copyWith(
    featureCardBg: const Color(0xFFFFFFFF),
    featureCardBorder: const Color(0xFFB2F5EA),
    featureCardAccent: const Color(0xFF319795),
    canvasBg: const Color(0xFFE6FFFA),
    gridColor: const Color(0xFFB2F5EA),
    nodeBgNote: const Color(0xFFFFFFFF),
    nodeBgEntity: const Color(0xFFF0FFF4),
    nodeText: const Color(0xFF234E52),
    lineColor: const Color(0xFF81E6D9),
    lineSelected: const Color(0xFF319795),
    htmlText: const Color(0xFF2C7A7B),
    htmlLink: const Color(0xFF319795),
    htmlHeader: const Color(0xFF285E61),
    uiFloatingBg: const Color(0xE6E6FFFA),
    uiFloatingBorder: const Color(0xFF81E6D9),
    uiFloatingText: const Color(0xFF234E52),
    uiFloatingHoverBg: const Color(0xFF319795),
  ) as DmToolColors,

  'amethyst': _dark.copyWith(
    featureCardBg: const Color(0xFF18121C),
    featureCardBorder: const Color(0xFF4A148C),
    featureCardAccent: const Color(0xFFBA68C8),
    canvasBg: const Color(0xFF211A26),
    gridColor: const Color(0xFF4A148C),
    nodeBgNote: const Color(0xFFF3E5F5),
    nodeBgEntity: const Color(0xFF2D2436),
    nodeText: const Color(0xFF4A148C),
    lineColor: const Color(0xFF7B1FA2),
    lineSelected: const Color(0xFFEA80FC),
    htmlText: const Color(0xFFF3E5F5),
    htmlLink: const Color(0xFFAB47BC),
    htmlHeader: const Color(0xFFEA80FC),
    uiFloatingBg: const Color(0xE62D2436),
    uiFloatingHoverBg: const Color(0xFFAB47BC),
  ) as DmToolColors,
};

/// Tema adından ThemeData oluşturur. Butonlar, card'lar, divider'lar palette'e uyar.
ThemeData buildThemeData(String themeName) {
  final palette = themePalettes[themeName] ?? _dark;
  final isDark = !_lightThemes.contains(themeName);
  final brightness = isDark ? Brightness.dark : Brightness.light;

  final base = ThemeData(
    brightness: brightness,
    colorSchemeSeed: palette.tabIndicator,
    useMaterial3: true,
  );

  return base.copyWith(
    scaffoldBackgroundColor: palette.canvasBg,
    cardColor: palette.tabActiveBg,
    dividerColor: palette.sidebarDivider,
    extensions: [palette],

    // AppBar
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: palette.tabBg,
      foregroundColor: palette.tabActiveText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    // Card
    cardTheme: base.cardTheme.copyWith(
      color: palette.nodeBgEntity,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      elevation: isDark ? 0 : 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),

    // FilledButton (primary actions)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.tabIndicator,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.tabActiveText,
        side: BorderSide(color: palette.sidebarDivider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontSize: 13),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.htmlLink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontSize: 13),
      ),
    ),

    // IconButton
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.tabText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? palette.canvasBg.withValues(alpha: 0.5)
          : palette.nodeBgNote.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.sidebarDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.sidebarDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.featureCardBorder),
      ),
      labelStyle: TextStyle(color: palette.tabText, fontSize: 13),
      hintStyle: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 13),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),

    // Chip
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: palette.sidebarFilterBg,
      labelStyle: TextStyle(color: palette.tabText, fontSize: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: palette.sidebarDivider),
    ),

    // ListTile
    listTileTheme: base.listTileTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      dense: true,
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: palette.sidebarDivider,
      thickness: 1,
      space: 1,
    ),

    // Dialog
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: palette.tabActiveBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // NavigationBar (mobile bottom nav)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.tabBg,
      indicatorColor: palette.tabIndicator.withValues(alpha: 0.2),
      surfaceTintColor: Colors.transparent,
    ),

    // NavigationRail (tablet)
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.tabBg,
      indicatorColor: palette.tabIndicator.withValues(alpha: 0.2),
      selectedIconTheme: IconThemeData(color: palette.tabIndicator),
      unselectedIconTheme: IconThemeData(color: palette.tabText),
    ),

    // PopupMenu
    popupMenuTheme: PopupMenuThemeData(
      color: palette.uiPopupBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: palette.uiPopupText, fontSize: 13),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.tabBg,
      contentTextStyle: TextStyle(color: palette.tabActiveText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),

    // TabBar (unused currently but for future)
    tabBarTheme: TabBarThemeData(
      labelColor: palette.tabActiveText,
      unselectedLabelColor: palette.tabText,
      indicatorColor: palette.tabIndicator,
    ),
  );
}

const _lightThemes = {'light', 'parchment', 'frost'};

/// Tüm tema isimlerinin listesi.
const themeNames = [
  'dark', 'light', 'parchment', 'ocean', 'emerald',
  'midnight', 'discord', 'baldur', 'grim', 'frost', 'amethyst',
];
