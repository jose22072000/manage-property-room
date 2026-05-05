import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/domain.dart';
import '../../permissions/policy.dart';
import '../providers/repo_providers.dart';

const _uuid = Uuid();

// ══════════════════════════════════════════
//  Toast
// ══════════════════════════════════════════

class ToastMessage {
  const ToastMessage({required this.id, required this.message, this.link});
  final String id;
  final String message;
  final String? link;
}

class ToastNotifier extends Notifier<List<ToastMessage>> {
  @override
  List<ToastMessage> build() => [];

  void show(String message, {String? link}) {
    final msg = ToastMessage(id: _uuid.v4(), message: message, link: link);
    state = [...state, msg];
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      dismiss(msg.id);
    });
  }

  void dismiss(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final toastProvider = NotifierProvider<ToastNotifier, List<ToastMessage>>(ToastNotifier.new);

// ══════════════════════════════════════════
//  Confirm dialog
// ══════════════════════════════════════════

class ConfirmState {
  const ConfirmState({
    this.isOpen = false,
    this.message = '',
    this.description,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.isDanger = false,
  });

  final bool isOpen;
  final String message;
  final String? description;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDanger;

  ConfirmState copyWith({
    bool? isOpen,
    String? message,
    String? description,
    String? confirmLabel,
    String? cancelLabel,
    bool? isDanger,
  }) =>
      ConfirmState(
        isOpen: isOpen ?? this.isOpen,
        message: message ?? this.message,
        description: description ?? this.description,
        confirmLabel: confirmLabel ?? this.confirmLabel,
        cancelLabel: cancelLabel ?? this.cancelLabel,
        isDanger: isDanger ?? this.isDanger,
      );
}

// ══════════════════════════════════════════
//  CurrentUser
// ══════════════════════════════════════════

class CurrentUserNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final settings = ref.read(settingsRepoProvider);
    final users = ref.read(userRepoProvider);
    final id = await settings.getCurrentUserId();
    if (id == null) return null;
    return users.getById(id);
  }

  Future<void> setUser(AppUser user) async {
    final settings = ref.read(settingsRepoProvider);
    await settings.setCurrentUserId(user.id);
    state = AsyncData(user);
  }
}

final currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, AppUser?>(CurrentUserNotifier.new);

// ══════════════════════════════════════════
//  Users
// ══════════════════════════════════════════

class UsersNotifier extends AsyncNotifier<List<AppUser>> {
  @override
  Future<List<AppUser>> build() async {
    return ref.read(userRepoProvider).getAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(userRepoProvider).getAll());
  }

  Future<void> saveUser(AppUser user) async {
    await ref.read(userRepoProvider).save(user);
    await reload();
  }

  Future<void> deleteUser(String id) async {
    await ref.read(userRepoProvider).delete(id);
    await reload();
  }
}

final usersProvider =
    AsyncNotifierProvider<UsersNotifier, List<AppUser>>(UsersNotifier.new);

// ══════════════════════════════════════════
//  Properties
// ══════════════════════════════════════════

class PropertiesNotifier extends AsyncNotifier<List<Property>> {
  @override
  Future<List<Property>> build() async {
    return ref.read(propertyRepoProvider).getAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(propertyRepoProvider).getAll());
  }

  Future<void> saveProperty(Property p) async {
    await ref.read(propertyRepoProvider).save(p);
    await reload();
  }
}

final propertiesProvider =
    AsyncNotifierProvider<PropertiesNotifier, List<Property>>(PropertiesNotifier.new);

/// Filtered list of properties the current user can see.
final visiblePropertiesProvider = Provider<List<Property>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final propsAsync = ref.watch(propertiesProvider);

  final user = userAsync.valueOrNull;
  final props = propsAsync.valueOrNull ?? [];

  if (user == null) return [];
  return props.where((p) => Policy.canSeeProperty(user, p.id)).toList();
});

// ══════════════════════════════════════════
//  Fields (custom field definitions)
// ══════════════════════════════════════════

class FieldsNotifier extends AsyncNotifier<List<FieldDef>> {
  @override
  Future<List<FieldDef>> build() async {
    return ref.read(fieldRepoProvider).getAll();
  }

  Future<void> _save(List<FieldDef> fields) async {
    await ref.read(fieldRepoProvider).saveAll(fields);
    state = AsyncData(fields);
  }

  Future<void> addField(FieldDef field) async {
    final current = state.valueOrNull ?? [];
    await _save([...current, field]);
  }

  Future<void> updateField(FieldDef field) async {
    final current = state.valueOrNull ?? [];
    await _save(current.map((f) => f.id == field.id ? field : f).toList());
  }

  Future<void> removeField(String id) async {
    final current = state.valueOrNull ?? [];
    await _save(current.where((f) => f.id != id).toList());
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = List<FieldDef>.from(state.valueOrNull ?? []);
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    await _save(current);
  }
}

final fieldsProvider =
    AsyncNotifierProvider<FieldsNotifier, List<FieldDef>>(FieldsNotifier.new);

// ══════════════════════════════════════════
//  Board (columns + cards) per property
// ══════════════════════════════════════════

class BoardState {
  const BoardState({
    this.columns = const [],
    this.cardsByColumn = const {},
  });

  final List<BoardColumn> columns;
  /// columnId → sorted cards
  final Map<String, List<BoardCard>> cardsByColumn;

  BoardState copyWith({
    List<BoardColumn>? columns,
    Map<String, List<BoardCard>>? cardsByColumn,
  }) =>
      BoardState(
        columns: columns ?? this.columns,
        cardsByColumn: cardsByColumn ?? this.cardsByColumn,
      );

  int get totalCards =>
      cardsByColumn.values.fold(0, (sum, list) => sum + list.length);

  int get doneCards => cardsByColumn.values
      .fold(0, (sum, list) => sum + list.where((c) => c.isDone).length);
}

class BoardNotifier extends FamilyAsyncNotifier<BoardState, String> {
  String get propertyId => arg;

  @override
  Future<BoardState> build(String arg) async {
    return _load();
  }

  Future<BoardState> _load() async {
    final colRepo = ref.read(columnRepoProvider);
    final cardRepo = ref.read(cardRepoProvider);
    final columns = await colRepo.getByProperty(propertyId);
    final cardsByColumn = <String, List<BoardCard>>{};
    for (final col in columns) {
      cardsByColumn[col.id] = await cardRepo.getByColumn(col.id);
    }
    return BoardState(columns: columns, cardsByColumn: cardsByColumn);
  }

  Future<void> _reload() async {
    state = AsyncData(await _load());
  }

  // ── Columns ───────────────────────────────────────

  Future<void> addColumn(String title, ColumnColor color) async {
    final current = state.valueOrNull;
    final position = (current?.columns.length ?? 0);
    final col = BoardColumn(
      id: _uuid.v4(),
      propertyId: propertyId,
      title: title,
      color: color,
      position: position,
    );
    await ref.read(columnRepoProvider).save(col);
    await _reload();
    ref.read(toastProvider.notifier).show('Lista "$title" creada');
  }

  Future<void> renameColumn(String columnId, String newTitle) async {
    final col = state.valueOrNull?.columns.firstWhere((c) => c.id == columnId);
    if (col == null) return;
    await ref.read(columnRepoProvider).save(col.copyWith(title: newTitle));
    await _reload();
  }

  Future<void> setColumnColor(String columnId, ColumnColor color) async {
    final col = state.valueOrNull?.columns.firstWhere((c) => c.id == columnId);
    if (col == null) return;
    await ref.read(columnRepoProvider).save(col.copyWith(color: color));
    await _reload();
  }

  Future<void> updateColumnConfig(String columnId, ColumnConfig config) async {
    final col = state.valueOrNull?.columns.firstWhere((c) => c.id == columnId);
    if (col == null) return;
    await ref.read(columnRepoProvider).save(col.copyWith(config: config));
    await _reload();
  }

  Future<void> updateColumnDescription(String columnId, String description) async {
    final col = state.valueOrNull?.columns.firstWhere((c) => c.id == columnId);
    if (col == null) return;
    await ref.read(columnRepoProvider).save(col.copyWith(description: description));
    await _reload();
  }

  Future<void> moveColumn(int fromIndex, int toIndex) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final cols = [...current.columns];
    final item = cols.removeAt(fromIndex);
    cols.insert(toIndex, item);
    final updated = [for (var i = 0; i < cols.length; i++) cols[i].copyWith(position: i)];
    await ref.read(columnRepoProvider).saveAll(updated);
    await _reload();
  }

  Future<void> archiveColumn(String columnId) async {
    final colRepo = ref.read(columnRepoProvider);
    final cardRepo = ref.read(cardRepoProvider);
    final archiveRepo = ref.read(archiveRepoProvider);
    final activityRepo = ref.read(activityRepoProvider);

    final col = state.valueOrNull?.columns.firstWhere((c) => c.id == columnId);
    if (col == null) return;

    final cards = await cardRepo.getByColumn(columnId);
    final now = DateTime.now();
    final user = ref.read(currentUserProvider).valueOrNull;

    for (final card in cards) {
      final archived = ArchivedCard.fromCard(
        card,
        archivedAt: now,
        archivedById: user?.id,
        sourceColumnTitle: col.title,
      );
      await archiveRepo.save(archived);
      await cardRepo.delete(card.id);
      await activityRepo.save(ActivityEvent(
        id: _uuid.v4(),
        cardId: card.id,
        type: ActivityType.archived,
        message: 'Archivada junto con la lista "${col.title}"',
        createdAt: now,
        authorId: user?.id,
      ));
    }
    await colRepo.delete(columnId);
    ref.read(toastProvider.notifier).show('Lista "${col.title}" archivada');
    await _reload();
  }

  Future<void> copyColumn(String columnId, {String? toPropertyId}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final col = current.columns.firstWhere((c) => c.id == columnId);
    final cards = current.cardsByColumn[columnId] ?? [];
    final targetPropertyId = toPropertyId ?? propertyId;

    // Count existing columns in target to set position
    int position;
    if (toPropertyId != null) {
      final targetCols = await ref.read(columnRepoProvider).getByProperty(targetPropertyId);
      position = targetCols.length;
    } else {
      position = current.columns.length;
    }

    final newColId = _uuid.v4();
    final newCol = BoardColumn(
      id: newColId,
      propertyId: targetPropertyId,
      title: '${col.title} (copia)',
      color: col.color,
      position: position,
      description: col.description,
      fieldIds: col.fieldIds,
      config: col.config,
    );
    await ref.read(columnRepoProvider).save(newCol);

    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      await ref.read(cardRepoProvider).save(card.copyWith(
            id: _uuid.v4(),
            columnId: newColId,
            propertyId: targetPropertyId,
            position: i,
            isDone: false,
            createdAt: DateTime.now(),
          ));
    }

    ref.read(toastProvider.notifier).show('Lista copiada');
    await _reload();
    if (toPropertyId != null) {
      // Invalidate target board if open
      ref.invalidate(boardProvider(toPropertyId));
    }
  }

  // ── Cards ─────────────────────────────────────────

  Future<BoardCard> addCard({
    required String columnId,
    required String title,
    String roomCode = '',
    CardKind kind = CardKind.room,
  }) async {
    final current = state.valueOrNull;
    final position = (current?.cardsByColumn[columnId]?.length ?? 0);
    final user = ref.read(currentUserProvider).valueOrNull;
    final now = DateTime.now();
    final card = BoardCard(
      id: _uuid.v4(),
      propertyId: propertyId,
      columnId: columnId,
      title: title,
      roomCode: roomCode,
      kind: kind,
      position: position,
      createdAt: now,
    );
    await ref.read(cardRepoProvider).save(card);
    await ref.read(activityRepoProvider).save(ActivityEvent(
          id: _uuid.v4(),
          cardId: card.id,
          type: ActivityType.created,
          message: 'Tarjeta creada',
          createdAt: now,
          authorId: user?.id,
        ));
    await _reload();
    return card;
  }

  Future<void> updateCard(BoardCard card) async {
    final existing = state.valueOrNull?.cardsByColumn.values
        .expand((c) => c)
        .firstWhere((c) => c.id == card.id, orElse: () => card);

    await ref.read(cardRepoProvider).save(card);

    // Log edit activity if title changed
    if (existing?.title != card.title) {
      final user = ref.read(currentUserProvider).valueOrNull;
      await ref.read(activityRepoProvider).save(ActivityEvent(
            id: _uuid.v4(),
            cardId: card.id,
            type: ActivityType.edited,
            message: 'Título actualizado',
            createdAt: DateTime.now(),
            authorId: user?.id,
          ));
    }

    await _reload();
  }

  Future<void> toggleCardDone(String cardId) async {
    final card = state.valueOrNull?.cardsByColumn.values
        .expand((c) => c)
        .firstWhere((c) => c.id == cardId);
    if (card == null) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    final now = DateTime.now();
    final updated = card.copyWith(isDone: !card.isDone);
    await ref.read(cardRepoProvider).save(updated);
    await ref.read(activityRepoProvider).save(ActivityEvent(
          id: _uuid.v4(),
          cardId: cardId,
          type: updated.isDone ? ActivityType.done : ActivityType.undone,
          message: updated.isDone ? 'Marcada como lista' : 'Marcada como pendiente',
          createdAt: now,
          authorId: user?.id,
        ));
    await _reload();
  }

  Future<void> moveCard(String cardId, String targetColumnId, int targetPosition) async {
    final card = state.valueOrNull?.cardsByColumn.values
        .expand((c) => c)
        .firstWhere((c) => c.id == cardId);
    if (card == null) return;

    final currentState = state.valueOrNull;
    final user = ref.read(currentUserProvider).valueOrNull;
    final now = DateTime.now();

    final sourceColumnId = card.columnId;

    // Re-index source column
    if (sourceColumnId != targetColumnId) {
      final sourceCards = [...(currentState?.cardsByColumn[sourceColumnId] ?? [])]
        ..removeWhere((c) => c.id == cardId);
      for (var i = 0; i < sourceCards.length; i++) {
        await ref.read(cardRepoProvider).save(sourceCards[i].copyWith(position: i));
      }
    }

    // Re-index target column
    final targetCards = [...(currentState?.cardsByColumn[targetColumnId] ?? [])]
      ..removeWhere((c) => c.id == cardId);
    final movedCard = card.copyWith(columnId: targetColumnId, position: targetPosition);
    targetCards.insert(targetPosition.clamp(0, targetCards.length), movedCard);
    for (var i = 0; i < targetCards.length; i++) {
      await ref.read(cardRepoProvider).save(targetCards[i].copyWith(position: i));
    }

    if (sourceColumnId != targetColumnId) {
      final targetCol = currentState?.columns.firstWhere(
        (c) => c.id == targetColumnId,
        orElse: () => BoardColumn(id: targetColumnId, propertyId: propertyId, title: '?'),
      );
      await ref.read(activityRepoProvider).save(ActivityEvent(
            id: _uuid.v4(),
            cardId: cardId,
            type: ActivityType.moved,
            message: 'Movida a "${targetCol?.title ?? targetColumnId}"',
            createdAt: now,
            authorId: user?.id,
          ));
    }

    await _reload();
  }

  Future<void> archiveCard(String cardId) async {
    final card = state.valueOrNull?.cardsByColumn.values
        .expand((c) => c)
        .firstWhere((c) => c.id == cardId);
    if (card == null) return;

    final col = state.valueOrNull?.columns.firstWhere(
      (c) => c.id == card.columnId,
      orElse: () => BoardColumn(id: card.columnId, propertyId: propertyId, title: ''),
    );

    final user = ref.read(currentUserProvider).valueOrNull;
    final now = DateTime.now();
    final archived = ArchivedCard.fromCard(
      card,
      archivedAt: now,
      archivedById: user?.id,
      sourceColumnTitle: col?.title ?? '',
    );
    await ref.read(archiveRepoProvider).save(archived);
    await ref.read(cardRepoProvider).delete(cardId);
    await ref.read(activityRepoProvider).save(ActivityEvent(
          id: _uuid.v4(),
          cardId: cardId,
          type: ActivityType.archived,
          message: 'Tarjeta archivada',
          createdAt: now,
          authorId: user?.id,
        ));
    ref.read(toastProvider.notifier).show('Tarjeta archivada');
    await _reload();
  }

  Future<void> addComment(String cardId, String text) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final comment = Comment(
      id: _uuid.v4(),
      cardId: cardId,
      authorId: user.id,
      text: text,
      createdAt: DateTime.now(),
    );
    await ref.read(commentRepoProvider).save(comment);
    await ref.read(activityRepoProvider).save(ActivityEvent(
          id: _uuid.v4(),
          cardId: cardId,
          type: ActivityType.commented,
          message: 'Comentario añadido',
          createdAt: DateTime.now(),
          authorId: user.id,
        ));
  }

  Future<void> resetAll() async {
    final current = state.valueOrNull;
    if (current == null) return;
    for (final col in current.columns) {
      await ref.read(cardRepoProvider).deleteByColumn(col.id);
      await ref.read(columnRepoProvider).delete(col.id);
    }
    ref.read(toastProvider.notifier).show('Tablero reiniciado');
    await _reload();
  }
}

final boardProvider =
    AsyncNotifierProviderFamily<BoardNotifier, BoardState, String>(BoardNotifier.new);

// ══════════════════════════════════════════
//  Archive
// ══════════════════════════════════════════

class ArchiveNotifier extends AsyncNotifier<List<ArchivedCard>> {
  @override
  Future<List<ArchivedCard>> build() async {
    return ref.read(archiveRepoProvider).getAll();
  }

  Future<void> reload() async {
    state = AsyncData(await ref.read(archiveRepoProvider).getAll());
  }

  Future<void> restoreCard(ArchivedCard card) async {
    final restored = BoardCard(
      id: card.id,
      propertyId: card.propertyId,
      columnId: card.columnId,
      title: card.title,
      description: card.description,
      isDone: false,
      position: 0,
      customFields: card.customFields,
      roomCode: card.roomCode,
      cleanedBy: card.cleanedBy,
      priority: card.priority,
      checkinDate: card.checkinDate,
      assignedToId: card.assignedToId,
      kind: card.kind,
      createdAt: card.createdAt,
    );
    await ref.read(cardRepoProvider).save(restored);
    await ref.read(archiveRepoProvider).delete(card.id);
    ref.read(toastProvider.notifier).show('Tarjeta restaurada');

    // Refresh board if loaded
    ref.invalidate(boardProvider(card.propertyId));
    await reload();
  }

  Future<void> clearAll() async {
    await ref.read(archiveRepoProvider).clear();
    state = const AsyncData([]);
    ref.read(toastProvider.notifier).show('Archivo vaciado');
  }
}

final archiveProvider =
    AsyncNotifierProvider<ArchiveNotifier, List<ArchivedCard>>(ArchiveNotifier.new);

// ══════════════════════════════════════════
//  Comments per card (family)
// ══════════════════════════════════════════

final commentsProvider = FutureProvider.family<List<Comment>, String>((ref, cardId) async {
  return ref.read(commentRepoProvider).getByCard(cardId);
});

// ══════════════════════════════════════════
//  Activity per card (family)
// ══════════════════════════════════════════

final activityProvider = FutureProvider.family<List<ActivityEvent>, String>((ref, cardId) async {
  return ref.read(activityRepoProvider).getByCard(cardId);
});

// ══════════════════════════════════════════
//  Todo — aggregated pending cards across all properties
// ══════════════════════════════════════════

final todoPendingProvider = Provider<List<BoardCard>>((ref) {
  final props = ref.watch(visiblePropertiesProvider);
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  final List<BoardCard> pending = [];
  for (final prop in props) {
    final boardAsync = ref.watch(boardProvider(prop.id));
    final cards = boardAsync.valueOrNull?.cardsByColumn.values.expand((c) => c).toList() ?? [];
    pending.addAll(cards.where((c) => !c.isDone));
  }

  // Sort: urgent (high priority or checkin tomorrow) first, then by property + position
  pending.sort((a, b) {
    bool aUrgent = a.priority == CardPriority.high ||
        (a.checkinDate != null &&
            a.checkinDate!.year == tomorrow.year &&
            a.checkinDate!.month == tomorrow.month &&
            a.checkinDate!.day == tomorrow.day);
    bool bUrgent = b.priority == CardPriority.high ||
        (b.checkinDate != null &&
            b.checkinDate!.year == tomorrow.year &&
            b.checkinDate!.month == tomorrow.month &&
            b.checkinDate!.day == tomorrow.day);
    if (aUrgent && !bUrgent) return -1;
    if (!aUrgent && bUrgent) return 1;
    return 0;
  });

  return pending;
});
