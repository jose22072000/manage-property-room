import 'api_client.dart';

/// REST calls for `/fields`.
class FieldsApi {
  FieldsApi(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> getAll() async {
    final list = await _client.get<List<dynamic>>('/fields');
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    // API rejects unknown field 'id' on POST too
    final clean = Map<String, dynamic>.from(body)..remove('id');
    return _client.post<Map<String, dynamic>>('/fields', body: clean);
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    // The API rejects unknown field 'id' in PATCH body
    final clean = Map<String, dynamic>.from(body)..remove('id');
    return _client.patch<Map<String, dynamic>>('/fields/$id', body: clean);
  }

  Future<void> delete(String id) async {
    await _client.delete<dynamic>('/fields/$id');
  }

  Future<void> reorder(List<String> ids) async {
    await _client.post<dynamic>('/fields/reorder', body: {'ids': ids});
  }
}
