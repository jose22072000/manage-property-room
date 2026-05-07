import 'api_client.dart';
import '../../domain/domain.dart';

class AuditApi {
  AuditApi(this._client);
  final ApiClient _client;

  Future<List<AuditEvent>> list({int limit = 200}) async {
    final data = await _client.get<List<dynamic>>('/audit?limit=$limit');
    return data.map((e) => AuditEvent.fromJson(e as Map<String, dynamic>)).toList();
  }
}
