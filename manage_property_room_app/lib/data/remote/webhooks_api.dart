import '../../domain/domain.dart';
import 'api_client.dart';

class WebhooksApi {
  WebhooksApi(this._client);
  final ApiClient _client;

  Future<List<Webhook>> list() async {
    final data = await _client.get<List<dynamic>>('/webhooks');
    return data.map((e) => Webhook.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Webhook> create({
    required String name,
    required String url,
    required List<String> events,
    String? propertyId,
    String? secret,
    bool active = true,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'url': url,
      'events': events,
      'active': active,
      if (propertyId != null && propertyId.isNotEmpty) 'propertyId': propertyId,
      if (secret != null && secret.isNotEmpty) 'secret': secret,
    };
    final data = await _client.post<Map<String, dynamic>>('/webhooks', body: body);
    return Webhook.fromJson(data);
  }

  Future<Webhook> update(String id, Map<String, dynamic> patch) async {
    final data = await _client.patch<Map<String, dynamic>>('/webhooks/$id', body: patch);
    return Webhook.fromJson(data);
  }

  Future<void> delete(String id) => _client.delete<dynamic>('/webhooks/$id');

  Future<List<WebhookDelivery>> deliveries(String id, {int limit = 50}) async {
    final data = await _client.get<List<dynamic>>('/webhooks/$id/deliveries?limit=$limit');
    return data
        .map((e) => WebhookDelivery.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> testFire(String id) =>
      _client.post<dynamic>('/webhooks/$id/test', body: const {});

  // ── inbound hooks ──
  Future<List<InboundHook>> listInbound() async {
    final data = await _client.get<List<dynamic>>('/inbound-hooks');
    return data
        .map((e) => InboundHook.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InboundHook> createInbound({
    required String name,
    required String propertyId,
    required String columnId,
    String? secret,
    bool active = true,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'propertyId': propertyId,
      'columnId': columnId,
      'active': active,
      if (secret != null && secret.isNotEmpty) 'secret': secret,
    };
    final data =
        await _client.post<Map<String, dynamic>>('/inbound-hooks', body: body);
    return InboundHook.fromJson(data);
  }

  Future<void> deleteInbound(String id) =>
      _client.delete<dynamic>('/inbound-hooks/$id');
}
