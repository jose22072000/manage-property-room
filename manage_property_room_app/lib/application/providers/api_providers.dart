import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/api_client.dart';
import '../../data/remote/api_endpoints.dart';
import '../../data/remote/auth_api.dart';
import '../../data/remote/board_api.dart';
import '../../data/remote/properties_api.dart';
import '../../data/remote/users_api.dart';
import '../../data/remote/fields_api.dart';
import '../../data/remote/archive_api.dart';
import '../../data/remote/audit_api.dart';
import '../../data/remote/groups_api.dart';
import '../../data/remote/webhooks_api.dart';

/// Currently configured backend URL. UI may override via Settings → Avanzado.
final apiBaseUrlProvider = StateProvider<String>(
  (_) => ApiEndpoints.defaultBaseUrl(),
);

/// Singleton [ApiClient]. Rebuilds when [apiBaseUrlProvider] changes.
final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final client = ApiClient(baseUrl: baseUrl);
  ref.onDispose(client.close);
  return client;
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final boardApiProvider = Provider<BoardApi>(
  (ref) => BoardApi(ref.watch(apiClientProvider)),
);

final propertiesApiProvider = Provider<PropertiesApi>(
  (ref) => PropertiesApi(ref.watch(apiClientProvider)),
);

final usersApiProvider = Provider<UsersApi>(
  (ref) => UsersApi(ref.watch(apiClientProvider)),
);

final fieldsApiProvider = Provider<FieldsApi>(
  (ref) => FieldsApi(ref.watch(apiClientProvider)),
);

final archiveApiProvider = Provider<ArchiveApi>(
  (ref) => ArchiveApi(ref.watch(apiClientProvider)),
);

final auditApiProvider = Provider<AuditApi>(
  (ref) => AuditApi(ref.watch(apiClientProvider)),
);

final groupsApiProvider = Provider<GroupsApi>(
  (ref) => GroupsApi(ref.watch(apiClientProvider)),
);

final webhooksApiProvider = Provider<WebhooksApi>(
  (ref) => WebhooksApi(ref.watch(apiClientProvider)),
);

/// Reactive snapshot of the current backend connectivity.
/// `null` = unknown, `true` = healthy, `false` = unreachable.
final apiHealthProvider = StateProvider<bool?>((_) => null);
