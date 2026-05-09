import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

const _bgTaskName = 'pmr_audit_check';
const _bgTaskTag = 'pmr_bg';

/// Dispatch-handler called by WorkManager in an isolate.
/// Must be a top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _bgTaskName) return Future.value(true);

    try {
      final baseUrl = inputData?['baseUrl'] as String? ?? '';
      final token = inputData?['token'] as String? ?? '';
      if (baseUrl.isEmpty || token.isEmpty) return Future.value(true);

      // Poll /audit
      final uri = Uri.parse('$baseUrl/audit?limit=5');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return Future.value(true);

      final events = (jsonDecode(res.body) as List<dynamic>);
      if (events.isEmpty) return Future.value(true);

      // Find last-seen ID from Hive
      await Hive.initFlutter();
      final box = await Hive.openBox<String>('app_prefs');
      final lastId = box.get('bg_last_event_id', defaultValue: '');

      // newest first — first element is latest
      final latest = events.first as Map<String, dynamic>;
      final latestId = latest['id'] as String? ?? '';

      if (latestId == lastId) return Future.value(true); // nothing new

      // Count new events since lastId
      int newCount = 0;
      for (final e in events) {
        final id = (e as Map<String, dynamic>)['id'] as String? ?? '';
        if (id == lastId) break;
        newCount++;
      }

      await box.put('bg_last_event_id', latestId);

      // Show system notification
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      final body = newCount == 1
          ? _eventLabel(latest)
          : '$newCount nuevas actividades';

      await plugin.show(
        1,
        'Actividad reciente',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'pmr_audit',
            'Actividad',
            channelDescription: 'Notificaciones de actividad en propiedades',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
          ),
        ),
      );
    } catch (_) {
      // Swallow errors — don't fail the task
    }

    return Future.value(true);
  });
}

String _eventLabel(Map<String, dynamic> e) {
  final action = e['action'] as String? ?? '';
  final entity = e['entity'] as String? ?? '';
  return '${_actionLabel(action)} ${_entityLabel(entity)}';
}

String _actionLabel(String a) {
  switch (a) {
    case 'create': return 'Creó';
    case 'update': return 'Actualizó';
    case 'delete': return 'Eliminó';
    case 'archive': return 'Archivó';
    default: return a;
  }
}

String _entityLabel(String e) {
  switch (e) {
    case 'card': return 'una tarea';
    case 'column': return 'una columna';
    case 'property': return 'una propiedad';
    case 'user': return 'un usuario';
    default: return e;
  }
}

/// Register or cancel the periodic background task.
class BackgroundNotifService {
  BackgroundNotifService._();
  static final instance = BackgroundNotifService._();

  Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  /// Schedule a periodic 15-min background check.
  Future<void> schedule({
    required String baseUrl,
    required String token,
  }) async {
    await Workmanager().cancelAll();
    await Workmanager().registerPeriodicTask(
      _bgTaskTag,
      _bgTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      inputData: {'baseUrl': baseUrl, 'token': token},
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> cancel() async {
    await Workmanager().cancelAll();
  }
}
