# 30 — Responsive Design System

> **For Claude.** Breakpoints, adaptive widget pattern, touch vs mouse.
> **Target:** `flutter_app/lib/presentation/responsive/`

## Breakpoints

```dart
// flutter_app/lib/presentation/responsive/breakpoints.dart

class Breakpoints {
  static const double mobileMax = 600;        // <600 = mobile
  static const double tabletMax = 1200;       // 600..1200 = tablet
  // >1200 = desktop
}

enum DeviceClass { mobile, tablet, desktop }

class ResponsiveBreakpoint {
  final DeviceClass device;
  final Orientation orientation;
  final InputMode primaryInput;     // touch | mouse | stylus

  bool get isMobile => device == DeviceClass.mobile;
  bool get isTablet => device == DeviceClass.tablet;
  bool get isDesktop => device == DeviceClass.desktop;
  bool get isCompact => isMobile;
  bool get isMedium => isTablet;
  bool get isExpanded => isDesktop;

  static ResponsiveBreakpoint of(BuildContext ctx) {
    final width = MediaQuery.sizeOf(ctx).width;
    final orientation = MediaQuery.orientationOf(ctx);
    final isTouchPlatform = Platform.isAndroid || Platform.isIOS;
    return ResponsiveBreakpoint(
      device: width < Breakpoints.mobileMax ? DeviceClass.mobile
            : width < Breakpoints.tabletMax ? DeviceClass.tablet
            : DeviceClass.desktop,
      orientation: orientation,
      primaryInput: isTouchPlatform ? InputMode.touch : InputMode.mouse,
    );
  }
}

enum InputMode { touch, mouse, stylus }
```

## Adaptive Widget Pattern

```dart
// flutter_app/lib/presentation/responsive/adaptive.dart

class Adaptive extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const Adaptive({super.key, required this.mobile, this.tablet, this.desktop});

  @override
  Widget build(BuildContext ctx) {
    final bp = ResponsiveBreakpoint.of(ctx);
    if (bp.isDesktop && desktop != null) return desktop!(ctx);
    if (bp.isTablet && tablet != null) return tablet!(ctx);
    if (bp.isDesktop && tablet != null) return tablet!(ctx);   // fallback desktop→tablet
    return mobile(ctx);
  }
}

// Usage:
Adaptive(
  mobile: (_) => MobileLayout(),
  tablet: (_) => TabletLayout(),
  desktop: (_) => DesktopLayout(),
)
```

## Layout Templates

### Mobile (`<600w`)

- Single column, full-width content.
- Bottom navigation bar (Material 3 `NavigationBar`) for primary tabs.
- Sheets / dialogs full-screen.
- Compact app bar (no extra controls; overflow menu).

### Tablet (`600..1200w`)

- Navigation rail (Material 3 `NavigationRail`) on the left.
- Two-pane patterns where applicable (master-detail).
- Side sheets instead of dialogs for non-critical interactions.
- Standard app bar with primary actions.

### Desktop (`>1200w`)

- Persistent left sidebar.
- Three-pane patterns where useful (list + detail + auxiliary).
- Hover effects, tooltips, keyboard shortcuts visible.
- Right-click context menus.
- App bar: full action set + search.

## Token Sizing

```dart
class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class TouchTargets {
  static const double minTouch = 48;     // Material guideline
  static const double minMouse = 32;
}

class TextScale {
  // All typography uses Theme TextTheme; multiplier per breakpoint.
  static double scale(BuildContext ctx) {
    final bp = ResponsiveBreakpoint.of(ctx);
    return bp.isMobile ? 0.95 : 1.0;
  }
}
```

## Input-Mode-Aware Components

```dart
class AdaptiveTooltip extends StatelessWidget {
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext ctx) {
    final bp = ResponsiveBreakpoint.of(ctx);
    if (bp.primaryInput == InputMode.touch) return child;     // no hover, skip tooltip
    return Tooltip(message: message, child: child);
  }
}

class AdaptiveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget label;

  @override
  Widget build(BuildContext ctx) {
    final bp = ResponsiveBreakpoint.of(ctx);
    final minSize = bp.primaryInput == InputMode.touch
      ? TouchTargets.minTouch
      : TouchTargets.minMouse;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minSize, minWidth: minSize),
      child: ElevatedButton(onPressed: onPressed, child: label),
    );
  }
}
```

## Gesture Matrix

| Gesture | Touch | Mouse | Stylus |
|---|---|---|---|
| Tap / click | tap | left-click | tap |
| Long-press | long-press | right-click | long-press |
| Drag | one-finger drag | left-drag | drag |
| Pan map | two-finger drag | middle-drag OR space+left-drag | two-finger drag |
| Zoom map | pinch | scroll wheel OR ctrl+scroll | pinch |
| Multi-select | long-press first + tap others | shift+click OR ctrl+click | long-press first |
| Context menu | long-press | right-click | long-press |
| Hover preview | (none) | hover | (none) |

Use Flutter `Listener` widget + `PointerDeviceKind` to detect input type per gesture.

## Orientation Considerations

- **Portrait mobile:** vertical scroll for character sheet sections.
- **Landscape mobile:** horizontal swipe between sections.
- **Tablet either orientation:** master-detail with adaptive split ratio.
- **Desktop:** orientation rare; treat all as landscape.

## Theme

Material 3 with seed color from app brand. Both light + dark mode. Respects platform's system theme by default.

```dart
final themeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

ThemeData _buildLight() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
  useMaterial3: true,
);
ThemeData _buildDark() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
  useMaterial3: true,
);
```

## Safe Areas & Insets

```dart
SafeArea(
  child: Padding(
    padding: EdgeInsets.symmetric(horizontal: Spacing.md),
    child: ...,
  ),
)
```

For mobile: respect notch/dynamic island (use `MediaQuery.viewPaddingOf`). For desktop windowed: respect title bar.

## Keyboard Shortcuts (Desktop)

```dart
// flutter_app/lib/presentation/shortcuts/app_shortcuts.dart

class AppShortcuts {
  static Map<ShortcutActivator, Intent> get bindings => {
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const NewCharacterIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ): const UndoIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyZ): const RedoIntent(),
    LogicalKeySet(LogicalKeyboardKey.space): const NextTurnIntent(),  // in combat tracker
    LogicalKeySet(LogicalKeyboardKey.escape): const CancelIntent(),
  };
}

// Wrap MaterialApp:
Shortcuts(
  shortcuts: AppShortcuts.bindings,
  child: Actions(
    actions: { /* intent → action */ },
    child: MaterialApp.router(...),
  ),
)
```

Shortcuts only enabled when desktop OR external keyboard detected on mobile/tablet.

## Density

```dart
class DensityConfig {
  static VisualDensity forDevice(DeviceClass d) => switch (d) {
    DeviceClass.mobile => VisualDensity.standard,
    DeviceClass.tablet => VisualDensity.comfortable,
    DeviceClass.desktop => VisualDensity.compact,
  };
}
```

Applied via `ThemeData.visualDensity`.

## Accessibility

- All interactive elements have `Semantics` labels.
- Touch targets ≥ 48dp (Material guideline).
- Text scaling respects `MediaQuery.textScalerOf`.
- Color contrast ratio ≥ 4.5:1 for body text.
- Focus traversal order logical for keyboard nav.

## Acceptance

- App opens on iOS/Android (mobile), iPad/Android tablet, Windows/Mac/Linux (desktop).
- All primary flows usable with touch only on mobile.
- All primary flows usable with mouse + keyboard only on desktop.
- Hover tooltips appear on desktop, suppressed on mobile.
- Right-click context menu appears on desktop, replaced by long-press on mobile.
- Window resize on desktop reflows layout instantly across breakpoints.

## Open Questions

1. Foldables (Galaxy Fold, Surface Duo) — treat as tablet? → Yes; width-based detection auto-handles.
2. Custom font scaling for accessibility (large text mode)? → Use Flutter built-in `MediaQuery.textScaler`. No custom scaling.
3. Stylus pressure sensitivity for drawing? → Detect `PointerEvent.pressure`; use for stroke width if available.
