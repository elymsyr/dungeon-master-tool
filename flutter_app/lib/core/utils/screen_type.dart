import 'package:flutter/widgets.dart';

enum ScreenType { phone, tablet, desktop }

ScreenType getScreenType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) return ScreenType.phone;
  if (width < 1200) return ScreenType.tablet;
  return ScreenType.desktop;
}

bool isDesktop(BuildContext context) =>
    getScreenType(context) == ScreenType.desktop;

bool isTablet(BuildContext context) =>
    getScreenType(context) == ScreenType.tablet;

bool isPhone(BuildContext context) =>
    getScreenType(context) == ScreenType.phone;
