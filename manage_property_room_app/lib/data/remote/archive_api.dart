import 'api_client.dart';

/// REST calls for `/archive`.
/// The API returns archive items shaped as:
///   { "id": "<archiveEntryId>", "kind": "card"|"column", "payload": {...}, "archivedAt": "..." }
class ArchiveApi {
  ArchiveApi(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> getAll() async {
    final list = await _client.get<List<dynamic>>('/archive');
    return list.cast<Map<String, dynamic>>();
  }

  /// Restore an archived item. [archiveEntryId] is the outer `id` from the
  /// archive list response (not the card/column id inside payload).
  Future<void> restore(String archiveEntryId) async {
    await _client.post<dynamic>('/archive/$archiveEntryId/restore');
  }
}
