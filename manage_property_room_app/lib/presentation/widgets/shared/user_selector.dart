import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/notifiers/notifiers.dart';
import '../../../application/providers/api_providers.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../domain/domain.dart';

/// Shows the logged-in user's avatar. Tapping opens a profile + logout menu.
class UserSelector extends ConsumerWidget {
  const UserSelector({super.key, required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    return PopupMenuButton<_Action>(
      tooltip: 'Perfil',
      offset: const Offset(0, 44),
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (_) => [
        PopupMenuItem<_Action>(
          enabled: false,
          child: _ProfileHeader(user: user),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_Action>(
          value: _Action.logout,
          child: Row(
            children: [
              Icon(Icons.logout, size: 16, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Text('Cerrar sesión',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: _Avatar(user: user, size: compact ? 30 : 32),
      ),
    );
  }

  Future<void> _handle(
      BuildContext context, WidgetRef ref, _Action action) async {
    switch (action) {
      case _Action.logout:
        try {
          await ref.read(authApiProvider).logout();
        } catch (_) {
          // best-effort — ignore server-side errors
        }
        await ref.read(settingsRepoProvider).clearToken();
        await ref.read(currentUserProvider.notifier).clearUser();
        if (context.mounted) context.go('/login');
    }
  }
}

enum _Action { logout }

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(user: user, size: 36),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF111827))),
            Text(_roleLabel(user.role),
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, this.size = 32});
  final AppUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _roleColor(user.role),
      child: Text(
        user.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _roleColor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const Color(0xFF2563EB);
    case UserRole.operator:
      return const Color(0xFF7C3AED);
    case UserRole.cleaning:
      return const Color(0xFF10B981);
    case UserRole.maintenance:
      return const Color(0xFFF59E0B);
    case UserRole.owner:
      return const Color(0xFF0891B2);
    case UserRole.supervisor:
      return const Color(0xFFD97706);
  }
}

String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Administrador';
    case UserRole.operator:
      return 'Operador';
    case UserRole.cleaning:
      return 'Limpieza';
    case UserRole.maintenance:
      return 'Mantenimiento';
    case UserRole.owner:
      return 'Propietario';
    case UserRole.supervisor:
      return 'Supervisor';
  }
}
