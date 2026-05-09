import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors.dart';
import '../../domain/domain.dart';
import '../../permissions/policy.dart';
import '../../data/remote/api_client.dart';
import '../providers/repo_providers.dart';
import '../providers/api_providers.dart';

const _uuid = Uuid();

/// Incremented whenever a board action completes. The audit page watches this
/// to refresh its list automatically without a manual reload.
final auditVersionProvider = StateProvider<int>((ref) => 0);

/// Returns a human-readable Spanish message from any exception.
String _errMsg(Object e) => friendlyError(e);

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
//  Live notification banners
// ══════════════════════════════════════════

class NotifBannerNotifier extends Notifier<List<AuditEvent>> {
  @override
  List<AuditEvent> build() => [];

  void add(AuditEvent event) {
    if (state.any((e) => e.id == event.id)) return; // dedupe
    state = [event, ...state];
    Future.delayed(const Duration(seconds: 5), () => dismiss(event.id));
  }

  void dismiss(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

final notifBannerProvider =
    NotifierProvider<NotifBannerNotifier, List<AuditEvent>>(NotifBannerNotifier.new);

/// Tracks the ID of the most recently seen audit event to detect new ones.
final notifLastSeenIdProvider = StateProvider<String?>((ref) => null);

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

    // 1. Try to restore API session from a previously saved JWT token.
    final savedToken = await settings.getToken();
    if (savedToken != null && savedToken.isNotEmpty) {
      ref.read(apiClientProvider).session.token = savedToken;
      try {
        final me = await ref.read(authApiProvider).me();
        final user = AppUser.fromJson(me);
        // Persist so Hive-backed lookups still work.
        await ref.read(userRepoProvider).save(user);
        await settings.setCurrentUserId(user.id);
        return user;
      } catch (_) {
        // Token expired or invalid — clear and fall through to login.
        await settings.clearToken();
        ref.read(apiClientProvider).session.clear();
      }
    }

    // 2. No valid token — user must log in.
    return null;
  }

  Future<void> setUser(AppUser user) async {
    final settings = ref.read(settingsRepoProvider);
    await settings.setCurrentUserId(user.id);
    // Invalidate all API-backed providers so they rebuild with the new token
    ref.invalidate(usersProvider);
    ref.invalidate(propertiesProvider);
    ref.invalidate(groupsProvider);
    state = AsyncData(user);
  }

  Future<void> clearUser() async {
    final settings = ref.read(settingsRepoProvider);
    await settings.setCurrentUserId('');
    state = const AsyncData(null);
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
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];
    final list = await ref.read(usersApiProvider).getAll();
    return list.map(AppUser.fromJson).toList();
  }

  Future<void> reload() async {
    final list = await ref.read(usersApiProvider).getAll();
    state = AsyncData(list.map(AppUser.fromJson).toList());
  }

  /// Create a new user via the API. Requires [email] and [password].
  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    required String initials,
    required String role,
    List<String> assignedPropertyIds = const [],
  }) async {
    try {
      await ref.read(usersApiProvider).create(
            email: email,
            password: password,
            name: name,
            initials: initials,
            role: role,
            assignedPropertyIds: assignedPropertyIds,
          );
      await reload();
    } catch (e) {
      ref.read(toastProvider.notifier).show('Error al crear usuario: ${_errMsg(e)}');
      rethrow;
    }
  }

  /// Update an existing user. Only sends mutable fields (no password).
  Future<void> updateUser(AppUser user) async {
    final prev = List<AppUser>.from(state.valueOrNull ?? []);
    final next = [...prev];
    final idx = next.indexWhere((u) => u.id == user.id);
    if (idx >= 0) next[idx] = user;
    state = AsyncData(next);
    try {
      await ref.read(usersApiProvider).update(user.id, {
        'name': user.name,
        'initials': user.initials,
        'role': user.role.name,
        'assignedPropertyIds': user.assignedPropertyIds,
      });
      await reload();
    } catch (e) {
      state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al guardar usuario: ${_errMsg(e)}');
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    final prev = List<AppUser>.from(state.valueOrNull ?? []);
    state = AsyncData(prev.where((u) => u.id != id).toList());
    try {
      await ref.read(usersApiProvider).delete(id);
      await reload();
    } catch (e) {
      state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al eliminar: ${_errMsg(e)}');
      rethrow;
    }
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
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];
    final list = await ref.read(propertiesApiProvider).getAll();
    return list.map(Property.fromJson).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  Future<void> reload() async {
    final list = await ref.read(propertiesApiProvider).getAll();
    state = AsyncData(
      list.map(Property.fromJson).toList()..sort((a, b) => a.code.compareTo(b.code)),
    );
  }

  Future<void> saveProperty(Property p) async {
    final prev = List<Property>.from(state.valueOrNull ?? []);
    final next = [...prev];
    final idx = next.indexWhere((x) => x.id == p.id);
    if (idx >= 0) {
      next[idx] = p;
    } else {
      next.add(p);
    }
    next.sort((a, b) => a.code.compareTo(b.code));
    state = AsyncData(next);
    try {
      if (idx >= 0) {
        await ref.read(propertiesApiProvider).update(p.id, p.toJson());
      } else {
        await ref.read(propertiesApiProvider).create(p.toJson());
      }
      await reload();
    } catch (e) {
      state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error: ${_errMsg(e)}');
      rethrow;
    }
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
  Timer? _timer;

  @override
  Future<List<FieldDef>> build() async {
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];
    // Poll every 10 s so field config changes made on web appear in mobile.
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _reload());
    ref.onDispose(() => _timer?.cancel());
    final list = await ref.read(fieldsApiProvider).getAll();
    return list.map(FieldDef.fromJson).toList();
  }

  Future<void> _reload() async {
    final list = await ref.read(fieldsApiProvider).getAll();
    state = AsyncData(list.map(FieldDef.fromJson).toList());
  }

  /// Invalidates all board providers so boards re-fetch after field changes.
  void _invalidateBoards() {
    final props = ref.read(visiblePropertiesProvider);
    for (final p in props) {
      ref.invalidate(boardProvider(p.id));
    }
  }

  Future<void> addField(FieldDef field) async {
    final prev = List<FieldDef>.from(state.valueOrNull ?? []);
    state = AsyncData([...prev, field]);
    try {
      await ref.read(fieldsApiProvider).create(field.toJson());
      await _reload();
      _invalidateBoards();
    } catch (e) {
      state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al crear campo: ${_errMsg(e)}');
      rethrow;
    }
  }

  Future<void> updateField(FieldDef field) async {
    final prev = List<FieldDef>.from(state.valueOrNull ?? []);
    final next = [...prev];
    final idx = next.indexWhere((f) => f.id == field.id);
    if (idx >= 0) next[idx] = field;
    state = AsyncData(next);
    try {
      await ref.read(fieldsApiProvider).update(field.id, field.toJson());
      await _reload();
      _invalidateBoards();
    } catch (e) {
      state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al guardar: ${_errMsg(e)}');
      rethrow;
    }
  }

  Future<void> removeField(String id) async {
    final prev = List<FieldDef>.from(state.valueOrNull ?? []);
    state = AsyncData(prev.where((f) => f.id != id).toList());
    try {
      await ref.read(fieldsApiProvider).delete(id);
      await _reload();
      _invalidateBoards();
    } catch (e) {
      state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al eliminar: ${_errMsg(e)}');
      rethrow;
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    // Flutter ReorderableListView reports newIndex AFTER the old item is removed;
    // so when moving down the reported index is one too high.
    if (newIndex > oldIndex) newIndex -= 1;
    // Optimistic local update first.
    final current = List<FieldDef>.from(state.valueOrNull ?? []);
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    state = AsyncData(current);
    // Send new order to API.
    await ref.read(fieldsApiProvider).reorder(current.map((f) => f.id).toList());
    _invalidateBoards();
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

class BoardNotifier extends FamilyAsyncNotifier<BoardState, String>
    with WidgetsBindingObserver {
  String get propertyId => arg;
  Timer? _timer;

  @override
  Future<BoardState> build(String arg) async {
    final user = await ref.watch(currentUserProvider.future);
    // If the user is not logged in, return empty state and do not start timer.
    if (user == null) return BoardState(columns: [], cardsByColumn: {});
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    return _load();
  }

  void _startTimer() {
    _timer?.cancel();
    // Poll every 10 s so all devices see changes promptly
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _reload());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _reload(); // immediate refresh when foregrounded
      _startTimer();
    } else if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.detached) {
      _timer?.cancel(); // stop polling when backgrounded
    }
  }

  // ── Load from API ─────────────────────────────────

  Future<BoardState> _load() async {
    final api = ref.read(boardApiProvider);
    final response = await api.getBoard(propertyId);
    final rawColumns = (response['columns'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((j) => j['archived'] != true)
        .toList();
    final columns = rawColumns
        .map((j) => BoardColumn.fromJson(j))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final allCards = (response['cards'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((j) => j['archived'] != true)
        .map((j) => BoardCard.fromJson(j))
        .toList();
    final cardsByColumn = <String, List<BoardCard>>{};
    for (final col in columns) {
      cardsByColumn[col.id] = allCards
          .where((c) => c.columnId == col.id)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    }
    return BoardState(columns: columns, cardsByColumn: cardsByColumn);
  }

  /// Reloads board state from the API.
  /// Pass [userAction] = true when triggered by a real change (not polling)
  /// so the audit page refreshes to show the new entry.
  Future<void> _reload({bool userAction = false}) async {
    // Skip reload if session has no token (e.g. user logged out)
    if (!ref.read(apiClientProvider).session.isAuthenticated) return;
    try {
      state = AsyncData(await _load());
      if (userAction) {
        ref.read(auditVersionProvider.notifier).update((v) => v + 1);
      }
    } catch (_) {
      // Silently ignore polling errors — the next tick will retry.
    }
  }

  // ── Columns ───────────────────────────────────────

  Future<void> addColumn(String title, ColumnColor color) async {
    final position = state.valueOrNull?.columns.length ?? 0;
    await ref.read(boardApiProvider).createColumn(
          propertyId,
          title: title,
          color: color,
          position: position,
        );
    await _reload(userAction: true);
    ref.read(toastProvider.notifier).show('Lista "$title" creada');
  }

  Future<void> renameColumn(String columnId, String newTitle) async {
    await ref.read(boardApiProvider).updateColumn(columnId, {'title': newTitle});
    await _reload(userAction: true);
  }

  Future<void> setColumnColor(String columnId, ColumnColor color) async {
    await ref.read(boardApiProvider).updateColumn(columnId, {'color': color.name});
    await _reload(userAction: true);
  }

  Future<void> updateColumnConfig(String columnId, ColumnConfig config) async {
    // Optimistic update
    final prev = state.valueOrNull;
    if (prev != null) {
      final newCols = prev.columns
          .map((c) => c.id == columnId ? c.copyWith(config: config) : c)
          .toList();
      state = AsyncData(BoardState(columns: newCols, cardsByColumn: prev.cardsByColumn));
    }
    try {
      await ref
          .read(boardApiProvider)
          .updateColumn(columnId, {'columnConfig': config.toJson()});
      await _reload(userAction: true);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error: ${_errMsg(e)}');
    }
  }

  Future<void> updateColumnDescription(String columnId, String description) async {
    await ref
        .read(boardApiProvider)
        .updateColumn(columnId, {'description': description});
    await _reload(userAction: true);
  }

  Future<void> moveColumn(int fromIndex, int toIndex) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final col = current.columns[fromIndex];
    await ref.read(boardApiProvider).moveColumn(col.id, toIndex);
    await _reload(userAction: true);
  }

  Future<void> reorderColumns(int oldIndex, int newIndex) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final cols = [...current.columns]..sort((a, b) => a.position.compareTo(b.position));
    final col = cols.removeAt(oldIndex);
    cols.insert(newIndex, col);
    // Optimistic update
    final reordered = [
      for (var i = 0; i < cols.length; i++) cols[i],
    ];
    state = AsyncData(BoardState(columns: reordered, cardsByColumn: current.cardsByColumn));
    try {
      final api = ref.read(boardApiProvider);
      await api.reorderColumns(propertyId, cols.map((c) => c.id).toList());
      await _reload(userAction: true);
    } catch (e) {
      state = AsyncData(current);
      ref.read(toastProvider.notifier).show('Error al reordenar: ${_errMsg(e)}');
    }
  }

  Future<void> archiveColumn(String columnId) async {
    final col = state.valueOrNull?.columns
        .where((c) => c.id == columnId)
        .firstOrNull;
    await ref.read(boardApiProvider).archiveColumn(columnId);
    ref.read(toastProvider.notifier).show('Lista "${col?.title ?? ''}" archivada');
    await _reload(userAction: true);
  }

  Future<void> copyColumn(String columnId, {String? toPropertyId}) async {
    final api = ref.read(boardApiProvider);
    if (toPropertyId != null && toPropertyId != propertyId) {
      await api.copyColumnToProperty(columnId, toPropertyId);
      ref.invalidate(boardProvider(toPropertyId));
    } else {
      await api.duplicateColumn(columnId);
    }
    ref.read(toastProvider.notifier).show('Lista copiada');
    await _reload(userAction: true);
  }

  Future<void> moveAllCards(String fromColumnId, String toColumnId) async {
    if (fromColumnId == toColumnId) return;
    await ref.read(boardApiProvider).moveAllCardsToColumn(fromColumnId, toColumnId);
    ref.read(toastProvider.notifier).show('Tarjetas movidas');
    await _reload(userAction: true);
  }

  Future<void> archiveAllCardsIn(String columnId) async {
    final count = state.valueOrNull?.cardsByColumn[columnId]?.length ?? 0;
    await ref.read(boardApiProvider).archiveAllCardsInColumn(columnId);
    ref.read(toastProvider.notifier).show('$count tarjetas archivadas');
    await _reload(userAction: true);
  }

  // ── Cards ─────────────────────────────────────────

  Future<BoardCard> addCard({
    required String columnId,
    required String title,
    String roomCode = '',
    CardKind kind = CardKind.room,
  }) async {
    final position = state.valueOrNull?.cardsByColumn[columnId]?.length ?? 0;
    final json = await ref.read(boardApiProvider).createCard(
          columnId,
          title: title,
          roomCode: roomCode,
          kind: kind,
          position: position,
        );
    final card = BoardCard.fromJson(json);
    await _reload(userAction: true);
    return card;
  }

  Future<void> updateCard(BoardCard card) async {
    // Optimistic local update
    final prev = state.valueOrNull;
    if (prev != null) {
      final newMap = <String, List<BoardCard>>{};
      prev.cardsByColumn.forEach((colId, list) {
        newMap[colId] = list.map((c) => c.id == card.id ? card : c).toList();
      });
      state = AsyncData(BoardState(columns: prev.columns, cardsByColumn: newMap));
    }
    final body = <String, dynamic>{
      'title': card.title,
      'description': card.description,
      'roomCode': card.roomCode,
      'priority': card.priority.name,
      'isDone': card.isDone,
      'kind': card.kind.name,
      'customFields': card.customFields,
      if (card.checkinDate != null)
        'checkinDate': card.checkinDate!.toUtc().toIso8601String(),
      if (card.checkinDate == null) 'clearCheckin': true,
      if (card.assignedToId != null) 'assignedToId': card.assignedToId,
    };
    try {
      await ref.read(boardApiProvider).updateCard(card.id, body);
      await _reload(userAction: true);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al guardar tarjeta: ${_errMsg(e)}');
      rethrow;
    }
  }

  Future<void> toggleCardDone(String cardId, {String cleanedBy = ''}) async {
    // Optimistic flip
    final prev = state.valueOrNull;
    final now = DateTime.now();
    if (prev != null) {
      final newMap = <String, List<BoardCard>>{};
      prev.cardsByColumn.forEach((colId, list) {
        newMap[colId] = list
            .map((c) => c.id == cardId
                ? c.copyWith(
                    isDone: !c.isDone,
                    cleanedBy: !c.isDone ? cleanedBy : '',
                    doneAt: !c.isDone ? now : null,
                    clearDoneAt: c.isDone,
                  )
                : c)
            .toList();
      });
      state = AsyncData(BoardState(columns: prev.columns, cardsByColumn: newMap));
    }
    try {
      final result = await ref.read(boardApiProvider).toggleDone(cardId);
      final isNowDone = result['isDone'] as bool? ?? false;
      if (isNowDone && cleanedBy.isNotEmpty) {
        await ref.read(boardApiProvider).updateCard(cardId, {'cleanedBy': cleanedBy});
      }
      await _reload(userAction: true);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error: ${_errMsg(e)}');
    }
  }

  Future<void> reorderCardsInColumn(String columnId, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final prev = state.valueOrNull;
    if (prev == null) return;
    final list = List<BoardCard>.from(prev.cardsByColumn[columnId] ?? []);
    if (oldIndex >= list.length || newIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    // Optimistic update
    final newMap = Map<String, List<BoardCard>>.from(prev.cardsByColumn);
    newMap[columnId] = list;
    state = AsyncData(BoardState(columns: prev.columns, cardsByColumn: newMap));
    try {
      await ref.read(boardApiProvider).reorderCards(columnId, list.map((c) => c.id).toList());
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al reordenar: ${_errMsg(e)}');
    }
  }

  Future<void> moveCard(
      String cardId, String targetColumnId, int targetPosition) async {
    // Optimistic move
    final prev = state.valueOrNull;
    if (prev != null) {
      final newMap = <String, List<BoardCard>>{};
      BoardCard? moving;
      prev.cardsByColumn.forEach((colId, list) {
        final filtered = <BoardCard>[];
        for (final c in list) {
          if (c.id == cardId) {
            moving = c;
          } else {
            filtered.add(c);
          }
        }
        newMap[colId] = filtered;
      });
      if (moving != null) {
        final destList = List<BoardCard>.from(newMap[targetColumnId] ?? []);
        final pos = targetPosition.clamp(0, destList.length);
        destList.insert(pos, moving!.copyWith(columnId: targetColumnId));
        newMap[targetColumnId] = destList;
        state = AsyncData(BoardState(columns: prev.columns, cardsByColumn: newMap));
      }
    }
    try {
      await ref.read(boardApiProvider).moveCard(cardId, targetColumnId, targetPosition);
      await _reload(userAction: true);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al mover: ${_errMsg(e)}');
    }
  }

  Future<void> archiveCard(String cardId) async {
    // Optimistic: remove card from board immediately
    final prev = state.valueOrNull;
    if (prev != null) {
      final newByCol = {
        for (final e in prev.cardsByColumn.entries)
          e.key: e.value.where((c) => c.id != cardId).toList(),
      };
      state = AsyncData(BoardState(columns: prev.columns, cardsByColumn: newByCol));
    }
    try {
      await ref.read(boardApiProvider).archiveCard(cardId);
      ref.read(toastProvider.notifier).show('Tarjeta archivada');
      ref.invalidate(archiveProvider);
      await _reload(userAction: true);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      ref.read(toastProvider.notifier).show('Error al archivar: ${_errMsg(e)}');
      rethrow;
    }
  }

  Future<void> addComment(String cardId, String text) async {
    await ref.read(boardApiProvider).createComment(cardId, text);
  }

  Future<void> resetAll() async {
    // Reload from server — mass delete via API not exposed in a single endpoint
    ref.read(toastProvider.notifier).show('Tablero reiniciado');
    await _reload(userAction: true);
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
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];
    final items = await ref.read(archiveApiProvider).getAll();
    return items
        .where((j) => j['kind'] == 'card')
        .map(ArchivedCard.fromApiArchiveItem)
        .toList();
  }

  Future<void> reload() async {
    final items = await ref.read(archiveApiProvider).getAll();
    state = AsyncData(
      items
          .where((j) => j['kind'] == 'card')
          .map(ArchivedCard.fromApiArchiveItem)
          .toList(),
    );
  }

  Future<void> restoreCard(ArchivedCard card) async {
    // card.id is the archive entry ID (set by fromApiArchiveItem).
    await ref.read(archiveApiProvider).restore(card.id);
    ref.read(toastProvider.notifier).show('Tarjeta restaurada');
    ref.invalidate(boardProvider(card.propertyId));
    await reload();
  }

  Future<void> clearAll() async {
    // Permanently delete all archived items one by one (best-effort).
    final items = state.valueOrNull ?? [];
    for (final card in items) {
      try {
        await ref.read(archiveApiProvider).delete(card.id);
      } catch (_) {
        // best-effort
      }
    }
    ref.read(toastProvider.notifier).show('Archivo vaciado');
    ref.read(auditVersionProvider.notifier).update((v) => v + 1);
    await reload();
  }
}

final archiveProvider =
    AsyncNotifierProvider<ArchiveNotifier, List<ArchivedCard>>(ArchiveNotifier.new);

// ══════════════════════════════════════════
//  Groups
// ══════════════════════════════════════════

class GroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() => ref.read(groupsApiProvider).list();

  Future<void> create(String name) async {
    final g = await ref.read(groupsApiProvider).create(name: name);
    state = AsyncData([...state.valueOrNull ?? [], g]);
  }

  Future<void> updateGroup(String id, {String? name, List<String>? userIds, List<String>? propertyIds}) async {
    final g = await ref.read(groupsApiProvider).update(id, name: name, userIds: userIds, propertyIds: propertyIds);
    state = AsyncData((state.valueOrNull ?? []).map((e) => e.id == id ? g : e).toList());
  }

  Future<void> delete(String id) async {
    await ref.read(groupsApiProvider).delete(id);
    state = AsyncData((state.valueOrNull ?? []).where((e) => e.id != id).toList());
  }
}

final groupsProvider = AsyncNotifierProvider<GroupsNotifier, List<Group>>(GroupsNotifier.new);

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

// ══════════════════════════════════════════
//  Card display preferences (per column, in-memory)
// ══════════════════════════════════════════

class CardDisplayPrefs {
  const CardDisplayPrefs({
    this.showDone = true,
    this.showDescription = true,
    this.showCleanedBy = true,
    this.showPriority = true,
    this.showCheckin = true,
    this.showRoomCode = true,
    this.showPriorityBorder = true,
  });

  final bool showDone;
  final bool showDescription;
  final bool showCleanedBy;
  final bool showPriority;
  final bool showCheckin;
  final bool showRoomCode;
  final bool showPriorityBorder;

  CardDisplayPrefs copyWith({
    bool? showDone,
    bool? showDescription,
    bool? showCleanedBy,
    bool? showPriority,
    bool? showCheckin,
    bool? showRoomCode,
    bool? showPriorityBorder,
  }) =>
      CardDisplayPrefs(
        showDone: showDone ?? this.showDone,
        showDescription: showDescription ?? this.showDescription,
        showCleanedBy: showCleanedBy ?? this.showCleanedBy,
        showPriority: showPriority ?? this.showPriority,
        showCheckin: showCheckin ?? this.showCheckin,
        showRoomCode: showRoomCode ?? this.showRoomCode,
        showPriorityBorder: showPriorityBorder ?? this.showPriorityBorder,
      );
}

final cardDisplayPrefsProvider =
    StateProvider.family<CardDisplayPrefs, String>(
  (ref, columnId) => const CardDisplayPrefs(),
);
