import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// API base URL resolution.
///
/// Priority:
/// 1. `--dart-define=API_BASE_URL=...` build arg
/// 2. Platform-specific dev default:
///    - Web / Linux desktop / macOS / Windows → http://localhost:8080
///    - Android emulator                       → http://10.0.2.2:8080
///    - iOS simulator                          → http://localhost:8080
/// 3. Empty string (offline-only mode)
class ApiEndpoints {
  ApiEndpoints._();

  static const _defineUrl = String.fromEnvironment('API_BASE_URL');

  /// Returns the resolved base URL (no trailing slash) or empty string
  /// if not configured.
  static String defaultBaseUrl() {
    if (_defineUrl.isNotEmpty) return _stripTrailing(_defineUrl);
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  static String _stripTrailing(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
