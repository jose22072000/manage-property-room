import 'package:image_picker/image_picker.dart';

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

  Future<void> assignSupervisors(String propertyId, List<String> supervisorIds) async {
    await _client.post<dynamic>('/properties/$propertyId/assign-supervisors',
        body: {'supervisorIds': supervisorIds});
  }

  Future<List<String>> getSupervisors(String propertyId) async {
    final data = await _client.get<List<dynamic>>('/properties/$propertyId/supervisors');
    return data.cast<String>();
  }

  Future<void> assignOwner(String propertyId, String? ownerId) async {
    await _client.post<dynamic>('/properties/$propertyId/assign-owner',
        body: {'ownerId': ownerId ?? ''});
  }

  /// Uploads [file] to /upload and returns the public image URL.
  Future<String> uploadImage(XFile file) async {
    final result = await _client.postMultipart<Map<String, dynamic>>('/upload', file);
    return result['url'] as String;
  }
}
