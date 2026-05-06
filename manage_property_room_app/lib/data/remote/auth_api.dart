import 'api_client.dart';

/// High-level Auth API matching `manage_property_room_api/internal/handlers/auth.go`.
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  /// `POST /auth/login` — returns the parsed body and stores the token in the
  /// underlying [ApiSession].
  Future<Map<String, dynamic>> login(String email, String password) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final token = body['token'] as String?;
    final exp = body['expiresAt'] as String?;
    if (token != null && token.isNotEmpty) {
      _client.session.token = token;
      _client.session.expiresAt = exp == null ? null : DateTime.tryParse(exp);
    }
    return body;
  }

  Future<void> logout() async {
    if (_client.session.isAuthenticated) {
      try {
        await _client.post<dynamic>('/auth/logout');
      } catch (_) {/* ignore — best effort */}
    }
    _client.session.clear();
  }

  Future<Map<String, dynamic>> refresh() async {
    final body = await _client.post<Map<String, dynamic>>('/auth/refresh');
    final token = body['token'] as String?;
    final exp = body['expiresAt'] as String?;
    if (token != null && token.isNotEmpty) {
      _client.session.token = token;
      _client.session.expiresAt = exp == null ? null : DateTime.tryParse(exp);
    }
    return body;
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _client.post<dynamic>(
      '/auth/change-password',
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  Future<Map<String, dynamic>> me() async {
    return _client.get<Map<String, dynamic>>('/me');
  }
}
