/// Webhook event constants — mirror `internal/domain/webhooks.go`.
abstract final class WebhookEvents {
  static const cardCompleted = 'card.completed';
  static const cardUncompleted = 'card.uncompleted';
  static const cardCreated = 'card.created';
  static const cardArchived = 'card.archived';
  static const cardMoved = 'card.moved';

  static const all = <String>[
    cardCompleted,
    cardUncompleted,
    cardCreated,
    cardArchived,
    cardMoved,
  ];

  static const labels = <String, String>{
    cardCompleted: 'Tarea completada',
    cardUncompleted: 'Tarea reabierta',
    cardCreated: 'Tarea creada',
    cardArchived: 'Tarea archivada',
    cardMoved: 'Tarea movida',
  };
}

class Webhook {
  final String id;
  final String name;
  final String url;
  final String secret;
  final List<String> events;
  final String? propertyId;
  final bool active;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Webhook({
    required this.id,
    required this.name,
    required this.url,
    required this.secret,
    required this.events,
    required this.propertyId,
    required this.active,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Webhook.fromJson(Map<String, dynamic> j) => Webhook(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        secret: j['secret'] as String? ?? '',
        events: (j['events'] as List?)?.map((e) => e as String).toList() ?? const [],
        propertyId: (j['propertyId'] as String?)?.let((s) => s.isEmpty ? null : s),
        active: j['active'] as bool? ?? false,
        createdBy: j['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class WebhookDelivery {
  final String id;
  final String webhookId;
  final String event;
  final String payload;
  final String status; // pending|success|failed
  final int httpCode;
  final int attempts;
  final String lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WebhookDelivery({
    required this.id,
    required this.webhookId,
    required this.event,
    required this.payload,
    required this.status,
    required this.httpCode,
    required this.attempts,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WebhookDelivery.fromJson(Map<String, dynamic> j) => WebhookDelivery(
        id: j['id'] as String,
        webhookId: j['webhookId'] as String? ?? '',
        event: j['event'] as String? ?? '',
        payload: j['payload'] as String? ?? '',
        status: j['status'] as String? ?? '',
        httpCode: (j['httpCode'] as num?)?.toInt() ?? 0,
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        lastError: j['lastError'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class InboundHook {
  final String id;
  final String name;
  final String token;
  final String secret;
  final String propertyId;
  final String columnId;
  final bool active;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InboundHook({
    required this.id,
    required this.name,
    required this.token,
    required this.secret,
    required this.propertyId,
    required this.columnId,
    required this.active,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InboundHook.fromJson(Map<String, dynamic> j) => InboundHook(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        token: j['token'] as String? ?? '',
        secret: j['secret'] as String? ?? '',
        propertyId: j['propertyId'] as String? ?? '',
        columnId: j['columnId'] as String? ?? '',
        active: j['active'] as bool? ?? false,
        createdBy: j['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

extension _LetX<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
