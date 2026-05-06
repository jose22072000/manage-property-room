import 'enums.dart';

// ─────────────────────────────────────────
//  AppUser
// ─────────────────────────────────────────

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
    this.assignedPropertyIds = const [],
  });

  final String id;
  final String name;
  final String initials;
  final UserRole role;
  final List<String> assignedPropertyIds;

  AppUser copyWith({
    String? id,
    String? name,
    String? initials,
    UserRole? role,
    List<String>? assignedPropertyIds,
  }) =>
      AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        initials: initials ?? this.initials,
        role: role ?? this.role,
        assignedPropertyIds: assignedPropertyIds ?? this.assignedPropertyIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'role': role.name,
        'assignedPropertyIds': assignedPropertyIds,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        initials: j['initials'] as String,
        role: UserRole.values.byName(j['role'] as String),
        assignedPropertyIds: List<String>.from(j['assignedPropertyIds'] as List? ?? []),
      );

  @override
  bool operator ==(Object other) => other is AppUser && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────
//  Property
// ─────────────────────────────────────────

class Property {
  const Property({
    required this.id,
    required this.code,
    required this.name,
    required this.totalRooms,
    this.colorSeed = 0,
  });

  final String id;
  final String code;
  final String name;
  final int totalRooms;
  /// Seed for deterministic gradient (0-9).
  final int colorSeed;

  Property copyWith({
    String? id,
    String? code,
    String? name,
    int? totalRooms,
    int? colorSeed,
  }) =>
      Property(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        totalRooms: totalRooms ?? this.totalRooms,
        colorSeed: colorSeed ?? this.colorSeed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'totalRooms': totalRooms,
        'colorSeed': colorSeed,
      };

  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        totalRooms: j['totalRooms'] as int? ?? 0,
        colorSeed: j['colorSeed'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) => other is Property && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────
//  FieldDef — custom field definition
// ─────────────────────────────────────────

class FieldDef {
  const FieldDef({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
    this.enabled = true,
    this.showOnCard = false,
    this.icon = '',
  });

  final String id;
  final String label;
  final FieldType type;
  final List<String> options;
  final bool enabled;
  final bool showOnCard;
  final String icon;

  FieldDef copyWith({
    String? id,
    String? label,
    FieldType? type,
    List<String>? options,
    bool? enabled,
    bool? showOnCard,
    String? icon,
  }) =>
      FieldDef(
        id: id ?? this.id,
        label: label ?? this.label,
        type: type ?? this.type,
        options: options ?? this.options,
        enabled: enabled ?? this.enabled,
        showOnCard: showOnCard ?? this.showOnCard,
        icon: icon ?? this.icon,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'options': options,
        'enabled': enabled,
        'showOnCard': showOnCard,
        'icon': icon,
      };

  factory FieldDef.fromJson(Map<String, dynamic> j) => FieldDef(
        id: j['id'] as String,
        label: j['label'] as String,
        type: FieldType.values.byName(j['type'] as String),
        options: List<String>.from(j['options'] as List? ?? []),
        enabled: j['enabled'] as bool? ?? true,
        showOnCard: j['showOnCard'] as bool? ?? false,
        icon: j['icon'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) => other is FieldDef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────
//  ColumnConfig — visibility toggles per column
// ─────────────────────────────────────────

class ColumnConfig {
  const ColumnConfig({
    this.showDescription = true,
    this.showCustomFields = true,
    this.showComments = true,
    this.showAssign = true,
    this.showPriority = true,
    this.showCheckin = true,
  });

  final bool showDescription;
  final bool showCustomFields;
  final bool showComments;
  final bool showAssign;
  final bool showPriority;
  final bool showCheckin;

  ColumnConfig copyWith({
    bool? showDescription,
    bool? showCustomFields,
    bool? showComments,
    bool? showAssign,
    bool? showPriority,
    bool? showCheckin,
  }) =>
      ColumnConfig(
        showDescription: showDescription ?? this.showDescription,
        showCustomFields: showCustomFields ?? this.showCustomFields,
        showComments: showComments ?? this.showComments,
        showAssign: showAssign ?? this.showAssign,
        showPriority: showPriority ?? this.showPriority,
        showCheckin: showCheckin ?? this.showCheckin,
      );

  Map<String, dynamic> toJson() => {
        'showDescription': showDescription,
        'showCustomFields': showCustomFields,
        'showComments': showComments,
        'showAssign': showAssign,
        'showPriority': showPriority,
        'showCheckin': showCheckin,
      };

  factory ColumnConfig.fromJson(Map<String, dynamic> j) => ColumnConfig(
        showDescription: j['showDescription'] as bool? ?? true,
        showCustomFields: j['showCustomFields'] as bool? ?? true,
        showComments: j['showComments'] as bool? ?? true,
        showAssign: j['showAssign'] as bool? ?? true,
        showPriority: j['showPriority'] as bool? ?? true,
        showCheckin: j['showCheckin'] as bool? ?? true,
      );
}

// ─────────────────────────────────────────
//  BoardColumn
// ─────────────────────────────────────────

class BoardColumn {
  const BoardColumn({
    required this.id,
    required this.propertyId,
    required this.title,
    this.color = ColumnColor.blue,
    this.position = 0,
    this.description = '',
    this.fieldIds = const [],
    this.config = const ColumnConfig(),
  });

  final String id;
  final String propertyId;
  final String title;
  final ColumnColor color;
  final int position;
  final String description;
  final List<String> fieldIds;
  final ColumnConfig config;

  BoardColumn copyWith({
    String? id,
    String? propertyId,
    String? title,
    ColumnColor? color,
    int? position,
    String? description,
    List<String>? fieldIds,
    ColumnConfig? config,
  }) =>
      BoardColumn(
        id: id ?? this.id,
        propertyId: propertyId ?? this.propertyId,
        title: title ?? this.title,
        color: color ?? this.color,
        position: position ?? this.position,
        description: description ?? this.description,
        fieldIds: fieldIds ?? this.fieldIds,
        config: config ?? this.config,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'title': title,
        'color': color.name,
        'position': position,
        'description': description,
        'fieldIds': fieldIds,
        'config': config.toJson(),
      };

  factory BoardColumn.fromJson(Map<String, dynamic> j) => BoardColumn(
        id: j['id'] as String,
        propertyId: j['propertyId'] as String,
        title: j['title'] as String,
        color: ColumnColor.values.byName(j['color'] as String? ?? 'blue'),
        position: j['position'] as int? ?? 0,
        description: j['description'] as String? ?? '',
        fieldIds: List<String>.from(j['fieldIds'] as List? ?? []),
        config: (j['columnConfig'] ?? j['config']) != null
            ? ColumnConfig.fromJson(Map<String, dynamic>.from(
                (j['columnConfig'] ?? j['config']) as Map))
            : const ColumnConfig(),
      );

  @override
  bool operator ==(Object other) => other is BoardColumn && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────
//  BoardCard
// ─────────────────────────────────────────

class BoardCard {
  const BoardCard({
    required this.id,
    required this.propertyId,
    required this.columnId,
    required this.title,
    this.description = '',
    this.isDone = false,
    this.position = 0,
    this.customFields = const {},
    this.roomCode = '',
    this.cleanedBy = '',
    this.priority = CardPriority.normal,
    this.checkinDate,
    this.assignedToId,
    this.kind = CardKind.room,
    required this.createdAt,
    this.doneAt,
  });

  final String id;
  final String propertyId;
  final String columnId;
  final String title;
  final String description;
  final bool isDone;
  final int position;
  /// Map of fieldId → value (String | bool | `List<String>` for image paths).
  final Map<String, dynamic> customFields;
  final String roomCode;
  final String cleanedBy;
  final CardPriority priority;
  final DateTime? checkinDate;
  final String? assignedToId;
  final CardKind kind;
  final DateTime createdAt;
  /// Set by toggle-done API. Null when not done.
  final DateTime? doneAt;

  BoardCard copyWith({
    String? id,
    String? propertyId,
    String? columnId,
    String? title,
    String? description,
    bool? isDone,
    int? position,
    Map<String, dynamic>? customFields,
    String? roomCode,
    String? cleanedBy,
    CardPriority? priority,
    DateTime? checkinDate,
    String? assignedToId,
    CardKind? kind,
    DateTime? createdAt,
    DateTime? doneAt,
    bool clearCheckin = false,
    bool clearAssignee = false,
    bool clearDoneAt = false,
  }) =>
      BoardCard(
        id: id ?? this.id,
        propertyId: propertyId ?? this.propertyId,
        columnId: columnId ?? this.columnId,
        title: title ?? this.title,
        description: description ?? this.description,
        isDone: isDone ?? this.isDone,
        position: position ?? this.position,
        customFields: customFields ?? this.customFields,
        roomCode: roomCode ?? this.roomCode,
        cleanedBy: cleanedBy ?? this.cleanedBy,
        priority: priority ?? this.priority,
        checkinDate: clearCheckin ? null : (checkinDate ?? this.checkinDate),
        assignedToId: clearAssignee ? null : (assignedToId ?? this.assignedToId),
        kind: kind ?? this.kind,
        createdAt: createdAt ?? this.createdAt,
        doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'columnId': columnId,
        'title': title,
        'description': description,
        'isDone': isDone,
        'position': position,
        'customFields': customFields,
        'roomCode': roomCode,
        'cleanedBy': cleanedBy,
        'priority': priority.name,
        'checkinDate': checkinDate?.toIso8601String(),
        'assignedToId': assignedToId,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BoardCard.fromJson(Map<String, dynamic> j) => BoardCard(
        id: j['id'] as String,
        propertyId: j['propertyId'] as String,
        columnId: j['columnId'] as String,
        title: j['title'] as String,
        description: j['description'] as String? ?? '',
        isDone: j['isDone'] as bool? ?? false,
        position: j['position'] as int? ?? 0,
        customFields: Map<String, dynamic>.from(j['customFields'] as Map? ?? {}),
        roomCode: j['roomCode'] as String? ?? '',
        cleanedBy: j['cleanedBy'] as String? ?? '',
        priority: CardPriority.values.byName(j['priority'] as String? ?? 'normal'),
        checkinDate: j['checkinDate'] != null ? DateTime.parse(j['checkinDate'] as String) : null,
        assignedToId: j['assignedToId'] as String?,
        kind: CardKind.values.byName(j['kind'] as String? ?? 'room'),
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
        doneAt: j['doneAt'] != null ? DateTime.parse(j['doneAt'] as String) : null,
      );

  @override
  bool operator ==(Object other) => other is BoardCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────
//  ArchivedCard
// ─────────────────────────────────────────

class ArchivedCard extends BoardCard {
  const ArchivedCard({
    required super.id,
    required super.propertyId,
    required super.columnId,
    required super.title,
    super.description,
    super.isDone,
    super.position,
    super.customFields,
    super.roomCode,
    super.cleanedBy,
    super.priority,
    super.checkinDate,
    super.assignedToId,
    super.kind,
    required super.createdAt,
    required this.archivedAt,
    this.archivedById,
    this.sourceColumnTitle = '',
  });

  final DateTime archivedAt;
  final String? archivedById;
  final String sourceColumnTitle;

  factory ArchivedCard.fromCard(
    BoardCard card, {
    required DateTime archivedAt,
    String? archivedById,
    String sourceColumnTitle = '',
  }) =>
      ArchivedCard(
        id: card.id,
        propertyId: card.propertyId,
        columnId: card.columnId,
        title: card.title,
        description: card.description,
        isDone: card.isDone,
        position: card.position,
        customFields: card.customFields,
        roomCode: card.roomCode,
        cleanedBy: card.cleanedBy,
        priority: card.priority,
        checkinDate: card.checkinDate,
        assignedToId: card.assignedToId,
        kind: card.kind,
        createdAt: card.createdAt,
        archivedAt: archivedAt,
        archivedById: archivedById,
        sourceColumnTitle: sourceColumnTitle,
      );

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'archivedAt': archivedAt.toIso8601String(),
        'archivedById': archivedById,
        'sourceColumnTitle': sourceColumnTitle,
      };

  factory ArchivedCard.fromJson(Map<String, dynamic> j) => ArchivedCard(
        id: j['id'] as String,
        propertyId: j['propertyId'] as String,
        columnId: j['columnId'] as String,
        title: j['title'] as String,
        description: j['description'] as String? ?? '',
        isDone: j['isDone'] as bool? ?? false,
        position: j['position'] as int? ?? 0,
        customFields: Map<String, dynamic>.from(j['customFields'] as Map? ?? {}),
        roomCode: j['roomCode'] as String? ?? '',
        cleanedBy: j['cleanedBy'] as String? ?? '',
        priority: CardPriority.values.byName(j['priority'] as String? ?? 'normal'),
        checkinDate: j['checkinDate'] != null ? DateTime.parse(j['checkinDate'] as String) : null,
        assignedToId: j['assignedToId'] as String?,
        kind: CardKind.values.byName(j['kind'] as String? ?? 'room'),
        createdAt: DateTime.parse(j['createdAt'] as String),
        archivedAt: DateTime.parse(j['archivedAt'] as String),
        archivedById: j['archivedById'] as String?,
        sourceColumnTitle: j['sourceColumnTitle'] as String? ?? '',
      );

  /// Parses from the API `/archive` list response shape:
  ///   { "id": "<archiveEntryId>", "kind": "card", "payload": {...}, "archivedAt": "..." }
  /// [id] is set to the archive entry id so `restore(id)` works correctly.
  factory ArchivedCard.fromApiArchiveItem(Map<String, dynamic> j) {
    final payload = Map<String, dynamic>.from(j['payload'] as Map);
    final archivedAt = DateTime.parse(j['archivedAt'] as String);
    return ArchivedCard(
      id: j['id'] as String, // archive entry ID used for restore
      propertyId: payload['propertyId'] as String? ?? '',
      columnId: payload['columnId'] as String? ?? '',
      title: payload['title'] as String? ?? '',
      description: payload['description'] as String? ?? '',
      isDone: payload['isDone'] as bool? ?? false,
      position: payload['position'] as int? ?? 0,
      customFields: Map<String, dynamic>.from(payload['customFields'] as Map? ?? {}),
      roomCode: payload['roomCode'] as String? ?? '',
      cleanedBy: payload['cleanedBy'] as String? ?? '',
      priority: CardPriority.values.byName(payload['priority'] as String? ?? 'normal'),
      checkinDate: payload['checkinDate'] != null ? DateTime.parse(payload['checkinDate'] as String) : null,
      assignedToId: payload['assignedToId'] as String?,
      kind: CardKind.values.byName(payload['kind'] as String? ?? 'room'),
      createdAt: payload['createdAt'] != null
          ? DateTime.parse(payload['createdAt'] as String)
          : archivedAt,
      archivedAt: archivedAt,
      sourceColumnTitle: '',
    );
  }
}

// ─────────────────────────────────────────
//  Comment
// ─────────────────────────────────────────

class Comment {
  const Comment({
    required this.id,
    required this.cardId,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String cardId;
  final String authorId;
  final String text;
  final DateTime createdAt;

  Comment copyWith({
    String? id,
    String? cardId,
    String? authorId,
    String? text,
    DateTime? createdAt,
  }) =>
      Comment(
        id: id ?? this.id,
        cardId: cardId ?? this.cardId,
        authorId: authorId ?? this.authorId,
        text: text ?? this.text,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardId': cardId,
        'authorId': authorId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as String,
        cardId: j['cardId'] as String,
        authorId: j['authorId'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) => other is Comment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────
//  ActivityEvent
// ─────────────────────────────────────────

enum ActivityType { created, moved, archived, restored, done, undone, commented, edited }

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.cardId,
    required this.type,
    required this.message,
    required this.createdAt,
    this.authorId,
  });

  final String id;
  final String cardId;
  final ActivityType type;
  final String message;
  final DateTime createdAt;
  final String? authorId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardId': cardId,
        'type': type.name,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'authorId': authorId,
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> j) => ActivityEvent(
        id: j['id'] as String,
        cardId: j['cardId'] as String,
        type: ActivityType.values.byName(j['type'] as String),
        message: j['message'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        authorId: j['authorId'] as String?,
      );

  @override
  bool operator ==(Object other) => other is ActivityEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
