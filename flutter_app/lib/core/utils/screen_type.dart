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
