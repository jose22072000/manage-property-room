import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton that manages system notifications (sound + vibration).
///
/// Call [NotificationService.init] once at startup.
/// Call [NotificationService.showAuditEvent] when a new audit event arrives.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'pmr_audit';
  static const _channelName = 'Actividad';
  static const _channelDesc = 'Notificaciones de actividad en propiedades';
  static final _vibrationPattern = Int64List.fromList([0, 250, 250, 250]);

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings,
        onDidReceiveNotificationResponse: (_) {});

    // Create high-importance channel on Android (required for sound + vibration)
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
          ));

      // Request POST_NOTIFICATIONS permission (Android 13+)
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _ready = true;
  }

  /// Show a system notification with sound and vibration.
  Future<void> showAuditEvent({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!_ready) return;

    // Also trigger haptic feedback (works in foreground)
    HapticFeedback.heavyImpact();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      ticker: 'Nueva actividad',
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }
}
