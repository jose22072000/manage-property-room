import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A parsed event pushed from the backend `/events` SSE endpoint.
class SseEvent {
  const SseEvent({
    required this.type,
    required this.entity,
    required this.entityId,
    this.propertyId = '',
    this.actorId = '',
  });

  /// e.g. "card.updated", "property.created", "user.deleted"
  final String type;

  /// Broad category: "card" | "column" | "property" | "user" | "group" | "field"
  final String entity;
  final String entityId;

  /// Non-empty for board-scoped events (cards, columns).
  final String propertyId;
  final String actorId;

  factory SseEvent.fromJson(Map<String, dynamic> j) => SseEvent(
        type: j['type'] as String? ?? '',
        entity: j['entity'] as String? ?? '',
        entityId: j['entityId'] as String? ?? '',
        propertyId: j['propertyId'] as String? ?? '',
        actorId: j['actorId'] as String? ?? '',
      );

  @override
  String toString() => 'SseEvent($type, $entityId)';
}

/// Connects to [baseUrl]/events and yields [SseEvent]s as they arrive.
///
/// On any network error or server disconnect the stream automatically
/// reconnects using exponential back-off (1 s → 30 s max).
///
/// Lifecycle: the stream is alive as long as there is a subscriber.
/// Cancel the subscription (or let the provider dispose) to disconnect.
Stream<SseEvent> connectSse({
  required String baseUrl,
  required String Function() getToken,
}) async* {
  var delay = const Duration(seconds: 1);
  const maxDelay = Duration(seconds: 30);

  while (true) {
    http.Client? client;
    try {
      client = http.Client();
      final uri = Uri.parse('$baseUrl/events');
      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer ${getToken()}'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        // Not ready yet — back off and retry.
        await Future<void>.delayed(delay);
        delay = _clamp(delay * 2, maxDelay);
        continue;
      }

      // Successful connection — reset back-off.
      delay = const Duration(seconds: 1);

      // Parse the chunked text/event-stream line-by-line.
      String? pendingData;
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          pendingData = chunk.substring(6);
        } else if (chunk.isEmpty && pendingData != null) {
          try {
            final json = jsonDecode(pendingData) as Map<String, dynamic>;
            yield SseEvent.fromJson(json);
          } catch (_) {
            // Malformed JSON — ignore.
          }
          pendingData = null;
        }
        // Comment lines (': ping', ': connected') are ignored.
      }
      // Stream ended — server closed connection. Reconnect immediately.
    } catch (_) {
      // Network / timeout error.
    } finally {
      client?.close();
    }

    await Future<void>.delayed(delay);
    delay = _clamp(delay * 2, maxDelay);
  }
}

Duration _clamp(Duration d, Duration max) => d < max ? d : max;
