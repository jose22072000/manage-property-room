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
import '../presentation/pages/settings_page.dart';
import '../presentation/pages/users_page.dart';
import '../presentation/widgets/shared/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return null;

      final isAdminOnly = state.matchedLocation.startsWith('/settings') ||
          state.matchedLocation.startsWith('/users');
      if (isAdminOnly && !Policy.canBoard(user, BoardAction.manageUsers)) {
        return '/';
      }
      return null;
    },
    routes: [
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
            path: '/settings',
            pageBuilder: (_, state) => const NoTransitionPage(child: SettingsPage()),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (_, state) => const NoTransitionPage(child: UsersPage()),
          ),
          // Board page INSIDE the shell (like React — AppShell wraps all pages)
          GoRoute(
            path: '/properties/:id/board',
            pageBuilder: (_, state) => NoTransitionPage(
              child: BoardPage(propertyId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
}
