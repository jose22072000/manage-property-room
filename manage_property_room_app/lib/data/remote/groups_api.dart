import 'api_client.dart';
import '../../domain/domain.dart';

class GroupsApi {
  GroupsApi(this._client);
  final ApiClient _client;

  Future<List<Group>> list() async {
    final data = await _client.get<List<dynamic>>('/groups');
    return data.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Group> create({required String name, List<String>? userIds, List<String>? propertyIds}) async {
    final data = await _client.post<Map<String, dynamic>>('/groups', body: {
      'name': name,
      if (userIds != null) 'userIds': userIds,
      if (propertyIds != null) 'propertyIds': propertyIds,
    });
    return Group.fromJson(data);
  }

  Future<Group> update(String id, {String? name, List<String>? userIds, List<String>? propertyIds}) async {
    final data = await _client.patch<Map<String, dynamic>>('/groups/$id', body: {
      if (name != null) 'name': name,
      if (userIds != null) 'userIds': userIds,
      if (propertyIds != null) 'propertyIds': propertyIds,
    });
    return Group.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.delete('/groups/$id');
  }

  Future<void> setUsers(String id, List<String> userIds) async {
    await _client.put('/groups/$id/users', body: {'userIds': userIds});
  }

  Future<void> setProperties(String id, List<String> propertyIds) async {
    await _client.put('/groups/$id/properties', body: {'propertyIds': propertyIds});
  }
}
