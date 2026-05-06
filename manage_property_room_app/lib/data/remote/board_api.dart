import 'api_client.dart';
import '../../domain/domain.dart';

/// Thin wrapper over [ApiClient] for all board-related endpoints.
class BoardApi {
  BoardApi(this._client);
  final ApiClient _client;

  // ── Board ─────────────────────────────────────────────────────────────────

  /// GET /properties/:id/board — returns { columns: [], cards: [] }
  Future<Map<String, dynamic>> getBoard(String propertyId) =>
      _client.get<Map<String, dynamic>>('/properties/$propertyId/board');

  // ── Columns ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createColumn(
    String propertyId, {
    required String title,
    required ColumnColor color,
    required int position,
    String description = '',
  }) =>
      _client.post<Map<String, dynamic>>(
        '/properties/$propertyId/columns',
        body: {
          'title': title,
          'color': color.name,
          'position': position,
          'description': description,
        },
      );

  Future<Map<String, dynamic>> updateColumn(
          String columnId, Map<String, dynamic> body) =>
      _client.patch<Map<String, dynamic>>('/columns/$columnId', body: body);

  Future<void> deleteColumn(String columnId) =>
      _client.delete<dynamic>('/columns/$columnId');

  /// POST /columns/:id/move — moves column to [newPosition]
  Future<void> moveColumn(String columnId, int newPosition) =>
      _client.post<dynamic>('/columns/$columnId/move',
          body: {'newPosition': newPosition});

  /// PATCH /columns/:id — updates position for each column to reorder them
  Future<void> updateColumnPosition(String columnId, int position) =>
      _client.patch<Map<String, dynamic>>('/columns/$columnId',
          body: {'position': position});

  /// POST /columns/:id/move-cards-to/:targetId
  Future<void> moveAllCardsToColumn(
          String fromColumnId, String toColumnId) =>
      _client.post<dynamic>(
          '/columns/$fromColumnId/move-cards-to/$toColumnId');

  /// POST /columns/:id/archive-all-cards
  Future<void> archiveAllCardsInColumn(String columnId) =>
      _client.post<dynamic>('/columns/$columnId/archive-all-cards');

  /// POST /columns/:id/archive
  Future<void> archiveColumn(String columnId) =>
      _client.post<dynamic>('/columns/$columnId/archive');

  /// POST /columns/:id/duplicate
  Future<Map<String, dynamic>> duplicateColumn(String columnId) =>
      _client.post<Map<String, dynamic>>('/columns/$columnId/duplicate');

  /// POST /columns/:id/copy-to/:propertyId
  Future<Map<String, dynamic>> copyColumnToProperty(
          String columnId, String targetPropertyId) =>
      _client.post<Map<String, dynamic>>(
          '/columns/$columnId/copy-to/$targetPropertyId');

  // ── Cards ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCard(
    String columnId, {
    required String title,
    String roomCode = '',
    CardKind kind = CardKind.room,
    CardPriority priority = CardPriority.normal,
    int position = 0,
    String description = '',
  }) =>
      _client.post<Map<String, dynamic>>(
        '/columns/$columnId/cards',
        body: {
          'title': title,
          'description': description,
          'roomCode': roomCode,
          'kind': kind.name,
          'priority': priority.name,
          'position': position,
          'customFields': <String, dynamic>{},
        },
      );

  Future<Map<String, dynamic>> updateCard(
          String cardId, Map<String, dynamic> body) =>
      _client.patch<Map<String, dynamic>>('/cards/$cardId', body: body);

  Future<void> deleteCard(String cardId) =>
      _client.delete<dynamic>('/cards/$cardId');

  /// POST /cards/:id/move  { targetColumnId, position }
  Future<Map<String, dynamic>> moveCard(
          String cardId, String targetColumnId, int position) =>
      _client.post<Map<String, dynamic>>(
        '/cards/$cardId/move',
        body: {'targetColumnId': targetColumnId, 'position': position},
      );

  /// POST /cards/:id/toggle-done
  Future<Map<String, dynamic>> toggleDone(String cardId) =>
      _client.post<Map<String, dynamic>>('/cards/$cardId/toggle-done');

  /// POST /cards/reorder — { columnId, ids: [...] }
  Future<void> reorderCards(String columnId, List<String> ids) =>
      _client.post<dynamic>('/cards/reorder', body: {'columnId': columnId, 'ids': ids});

  /// POST /cards/:id/archive
  Future<void> archiveCard(String cardId) =>
      _client.post<dynamic>('/cards/$cardId/archive');

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<void> createComment(String cardId, String text) =>
      _client.post<dynamic>('/cards/$cardId/comments', body: {'text': text});
}
