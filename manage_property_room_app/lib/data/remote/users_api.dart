import 'api_client.dart';

/// REST calls for `/users`.
class UsersApi {
  UsersApi(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> getAll() async {
    final list = await _client.get<List<dynamic>>('/users');
    return list.cast<Map<String, dynamic>>();
  }

  /// Create a new user (POST /users). Requires email + password.
  Future<Map<String, dynamic>> create({
    required String email,
    required String password,
    required String name,
    required String initials,
    required String role,
    List<String> assignedPropertyIds = const [],
  }) async {
    return _client.post<Map<String, dynamic>>('/users', body: {
      'email': email,
      'password': password,
      'name': name,
      'initials': initials,
      'role': role,
      'assignedPropertyIds': assignedPropertyIds,
    });
  }

  /// Update an existing user (PATCH /users/:id). Only sends changed fields.
  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    return _client.patch<Map<String, dynamic>>('/users/$id', body: body);
  }

  Future<void> delete(String id) async {
    await _client.delete<dynamic>('/users/$id');
  }
}
