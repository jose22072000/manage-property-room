import 'package:flutter/material.dart';

/// Breakpoints matching the web app's Tailwind responsive design.
const _kMobileBreak = 600.0;
const _kTabletBreak = 1024.0;

enum ScreenSize { mobile, tablet, desktop }

ScreenSize screenSizeOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < _kMobileBreak) return ScreenSize.mobile;
  if (w < _kTabletBreak) return ScreenSize.tablet;
  return ScreenSize.desktop;
}

bool isMobileSize(BuildContext context) =>
    screenSizeOf(context) == ScreenSize.mobile;

/// Always shows [showModalBottomSheet] for consistent drawer behaviour across
/// all screen sizes.
Future<T?> showResponsiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 480,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(child: builder(ctx)),
  );
}

class Responsive {
  Responsive._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _kMobileBreak;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= _kMobileBreak && w < _kTabletBreak;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _kTabletBreak;

  static bool isTabletOrDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _kMobileBreak;

  /// Returns [mobile] value on small screens, [tablet] on medium,
  /// [desktop] on large. Falls back upwards if not provided.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}
