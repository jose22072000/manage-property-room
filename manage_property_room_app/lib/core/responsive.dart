import 'package:flutter/material.dart';

/// Breakpoints matching the web app's Tailwind responsive design.
const _kMobileBreak = 600.0;
const _kTabletBreak = 1024.0;

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
