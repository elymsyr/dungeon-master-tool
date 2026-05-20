import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum ScreenType { phone, tablet, desktop }

ScreenType getScreenType(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  // Use shortestSide so landscape phones (e.g. 640×360) stay phone layout
  // instead of getting tablet's NavigationRail in a tiny vertical space.
  if (size.shortestSide < 600) return ScreenType.phone;
  if (size.width < 1200) return ScreenType.tablet;
  return ScreenType.desktop;
}

bool isDesktop(BuildContext context) =>
    getScreenType(context) == ScreenType.desktop;

bool isTablet(BuildContext context) =>
    getScreenType(context) == ScreenType.tablet;

bool isPhone(BuildContext context) =>
    getScreenType(context) == ScreenType.phone;

/// True on touch-first platforms (Android/iOS). Size-independent so tablets
/// count too. Use to disable widget-level text selection that would otherwise
/// swallow vertical drag gestures and block parent scroll views.
bool get isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;
