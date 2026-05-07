import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/notifiers/notifiers.dart';
import '../domain/domain.dart';
import '../permissions/policy.dart';
import '../presentation/pages/properties_page.dart';
import '../presentation/pages/board_page.dart';
import '../presentation/pages/todo_page.dart';
import '../presentation/pages/archive_page.dart';
import '../presentation/pages/audit_page.dart';
import '../presentation/pages/settings_page.dart';
import '../presentation/pages/users_page.dart';
import '../presentation/pages/api_debug_page.dart';
import '../presentation/pages/login_page.dart';
import '../presentation/widgets/shared/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(WidgetRef ref) {
    _sub = ref.listenManual(currentUserProvider, (prev, next) => notifyListeners());
  }

  ProviderSubscription<AsyncValue<AppUser?>>? _sub;

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final userAsync = ref.read(currentUserProvider);
      // Still loading Hive — don't redirect yet
      if (userAsync is AsyncLoading) return null;

      final user = userAsync.valueOrNull;
      final onLogin = state.matchedLocation == '/login';

      if (user == null && !onLogin) return '/login';
      if (user != null && onLogin) return '/';

      // Admin-only pages
      if (user != null) {
        final isAdminOnly = state.matchedLocation.startsWith('/settings') ||
            state.matchedLocation.startsWith('/users') ||
            state.matchedLocation.startsWith('/audit');
        if (isAdminOnly && !Policy.canBoard(user, BoardAction.manageUsers)) {
          return '/';
        }
      }
      return null;
    },
    routes: [
      // Login — outside shell
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => const NoTransitionPage(child: LoginPage()),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => const NoTransitionPage(child: PropertiesPage()),
          ),
          GoRoute(
            path: '/todo',
            pageBuilder: (_, state) => const NoTransitionPage(child: TodoPage()),
          ),
          GoRoute(
            path: '/archive',
            pageBuilder: (_, state) => const NoTransitionPage(child: ArchivePage()),
          ),
          GoRoute(
            path: '/audit',
            pageBuilder: (_, state) => const NoTransitionPage(child: AuditPage()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, state) => const NoTransitionPage(child: SettingsPage()),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (_, state) => const NoTransitionPage(child: UsersPage()),
          ),
          GoRoute(
            path: '/api-debug',
            pageBuilder: (_, state) => const NoTransitionPage(child: ApiDebugPage()),
          ),
          // Board page INSIDE the shell (like React — AppShell wraps all pages)
          GoRoute(
            path: '/properties/:id/board',
            pageBuilder: (_, state) => NoTransitionPage(
              child: BoardPage(
                propertyId: state.pathParameters['id']!,
                highlightCardId: state.extra as String?,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
