import '../data/remote/api_client.dart';

/// Converts any exception into a human-readable Spanish message suitable for
/// displaying directly to the user (toast, error widget, form field, etc.).
///
/// Rules:
///  - [NetworkException] (NETWORK code) → connectivity message
///  - [UnauthorizedException] (401)      → session-expired message
///  - Other [ApiException]               → server message as-is (already human)
///  - Raw socket / timeout / TLS errors  → friendly connectivity messages
///  - Anything else                       → generic fallback
String friendlyError(Object e) {
  if (e is ApiException) {
    if (e.code == 'NETWORK') {
      final s = e.message;
      if (s.contains('Connection refused') || s.contains('errno = 111')) {
        return 'No se puede conectar al servidor. Verifica tu conexión de red.';
      }
      if (s.contains('timed out') || s.contains('TimeoutException')) {
        return 'El servidor tardó demasiado. Inténtalo de nuevo.';
      }
      if (s.contains('HandshakeException') || s.contains('certificate')) {
        return 'Error de seguridad en la conexión.';
      }
      return 'Error de red. Comprueba tu conexión e inténtalo de nuevo.';
    }
    if (e.code == 'INVALID_CREDENTIALS') {
      return 'Email o contraseña incorrectos.';
    }
    if (e.statusCode == 401 || e.code == 'UNAUTHORIZED') {
      return 'Tu sesión ha expirado. Inicia sesión de nuevo.';
    }
    if (e.statusCode == 403) {
      return 'No tienes permisos para realizar esta acción.';
    }
    if (e.statusCode == 404) {
      return 'El elemento solicitado no fue encontrado.';
    }
    if (e.statusCode >= 500) {
      return 'Error en el servidor. Inténtalo más tarde.';
    }
    // Server returned a descriptive message — show it directly.
    return e.message.isNotEmpty ? e.message : 'Ocurrió un error inesperado.';
  }

  final s = e.toString();
  if (s.contains('Connection refused') || s.contains('errno = 111')) {
    return 'No se puede conectar al servidor. Verifica tu conexión de red.';
  }
  if (s.contains('SocketException') || s.contains('ClientException')) {
    return 'Error de red. Comprueba tu conexión e inténtalo de nuevo.';
  }
  if (s.contains('TimeoutException') || s.contains('timed out')) {
    return 'El servidor tardó demasiado. Inténtalo de nuevo.';
  }
  if (s.contains('HandshakeException') || s.contains('certificate')) {
    return 'Error de seguridad en la conexión.';
  }
  return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
}
