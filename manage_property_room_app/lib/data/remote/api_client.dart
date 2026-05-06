import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Typed errors produced by [ApiClient].
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.statusCode = 0});
  final String code;
  final String message;
  final int statusCode;
  @override
  String toString() => 'ApiException($statusCode $code): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message)
      : super('UNAUTHORIZED', message, statusCode: 401);
}

class NetworkException extends ApiException {
  NetworkException(String message)
      : super('NETWORK', message, statusCode: 0);
}

/// Holds the current bearer token. Updated by login/refresh/logout.
class ApiSession {
  String? token;
  DateTime? expiresAt;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  void clear() {
    token = null;
    expiresAt = null;
  }
}

/// Thin wrapper over `package:http` providing JSON helpers, bearer-token
/// injection, and error envelope decoding for the property-room backend.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    ApiSession? session,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  })  : _session = session ?? ApiSession(),
        _http = httpClient ?? http.Client(),
        _timeout = timeout;

  String baseUrl;
  final ApiSession _session;
  final http.Client _http;
  final Duration _timeout;

  ApiSession get session => _session;

  bool get isConfigured => baseUrl.isNotEmpty;

  // ── public ────────────────────────────────────────────────────────────────

  Future<T> get<T>(String path) => _send<T>('GET', path);
  Future<T> delete<T>(String path) => _send<T>('DELETE', path);
  Future<T> post<T>(String path, {Object? body}) => _send<T>('POST', path, body: body);
  Future<T> patch<T>(String path, {Object? body}) => _send<T>('PATCH', path, body: body);
  Future<T> put<T>(String path, {Object? body}) => _send<T>('PUT', path, body: body);

  /// Quick connectivity probe used by Settings → Probar conexión.
  Future<bool> ping() async {
    try {
      await get<dynamic>('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  void close() => _http.close();

  // ── internal ──────────────────────────────────────────────────────────────

  Future<T> _send<T>(String method, String path, {Object? body}) async {
    if (baseUrl.isEmpty) {
      throw ApiException('NOT_CONFIGURED', 'API base URL is empty');
    }
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      if (_session.isAuthenticated) 'Authorization': 'Bearer ${_session.token}',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await _http.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'DELETE':
          res = await _http.delete(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          res = await _http.post(uri, headers: headers, body: encodedBody).timeout(_timeout);
          break;
        case 'PATCH':
          res = await _http.patch(uri, headers: headers, body: encodedBody).timeout(_timeout);
          break;
        case 'PUT':
          res = await _http.put(uri, headers: headers, body: encodedBody).timeout(_timeout);
          break;
        default:
          throw ApiException('BAD_METHOD', 'unsupported method $method');
      }
    } on TimeoutException {
      throw NetworkException('Request timed out after ${_timeout.inSeconds}s');
    } catch (e) {
      throw NetworkException(e.toString());
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null as T;
      final decoded = jsonDecode(res.body);
      return decoded as T;
    }
    if (res.statusCode == 401) {
      _session.clear();
      throw UnauthorizedException(_extractMessage(res) ?? 'Unauthorized');
    }
    final msg = _extractMessage(res) ?? 'HTTP ${res.statusCode}';
    final code = _extractCode(res) ?? 'HTTP_${res.statusCode}';
    throw ApiException(code, msg, statusCode: res.statusCode);
  }

  String? _extractMessage(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is Map) {
        return (j['error']['message'] ?? '').toString();
      }
    } catch (_) {}
    return null;
  }

  String? _extractCode(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is Map) {
        return (j['error']['code'] ?? '').toString();
      }
    } catch (_) {}
    return null;
  }
}
