import 'api_client.dart';

/// REST calls for `/properties`.
class PropertiesApi {
  PropertiesApi(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> getAll() async {
    final list = await _client.get<List<dynamic>>('/properties');
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    return _client.post<Map<String, dynamic>>('/properties', body: body);
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    return _client.patch<Map<String, dynamic>>('/properties/$id', body: body);
  }

  Future<void> delete(String id) async {
    await _client.delete<dynamic>('/properties/$id');
  }
}
