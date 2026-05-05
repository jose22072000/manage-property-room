import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/notifiers/notifiers.dart';
import '../../../domain/domain.dart';

class UserSelector extends ConsumerWidget {
  const UserSelector({super.key, required this.compact});

  /// When true, shows only an avatar (for NavigationRail header).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final usersAsync = ref.watch(usersProvider);

    final currentUser = userAsync.valueOrNull;
    final users = usersAsync.valueOrNull ?? [];

    if (currentUser == null) return const SizedBox.shrink();

    final avatar = _Avatar(user: currentUser);

    if (compact) {
      return GestureDetector(
        onTap: () => _showPicker(context, ref, currentUser, users),
        child: avatar,
      );
    }

    return PopupMenuButton<AppUser>(
      tooltip: 'Cambiar usuario',
      offset: const Offset(0, 40),
      onSelected: (u) => ref.read(currentUserProvider.notifier).setUser(u),
      itemBuilder: (_) => users
          .map((u) => PopupMenuItem<AppUser>(
                value: u,
                child: Row(
                  children: [
                    _Avatar(user: u, size: 28),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(_roleLabel(u.role), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    if (u.id == currentUser.id) ...[
                      const Spacer(),
                      const Icon(Icons.check, size: 16, color: Color(0xFF2563EB)),
                    ],
                  ],
                ),
              ))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: avatar,
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, AppUser current, List<AppUser> users) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _UserPickerSheet(
        current: current,
        users: users,
        onSelect: (u) => ref.read(currentUserProvider.notifier).setUser(u),
      ),
    );
  }
}

class _UserPickerSheet extends StatelessWidget {
  const _UserPickerSheet({
    required this.current,
    required this.users,
    required this.onSelect,
  });

  final AppUser current;
  final List<AppUser> users;
  final ValueChanged<AppUser> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Cambiar usuario', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          for (final u in users)
            ListTile(
              leading: _Avatar(user: u),
              title: Text(u.name),
              subtitle: Text(_roleLabel(u.role)),
              trailing: u.id == current.id ? const Icon(Icons.check, color: Color(0xFF2563EB)) : null,
              onTap: () {
                onSelect(u);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
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
    case UserRole.cleaning:
      return const Color(0xFF10B981);
    case UserRole.maintenance:
      return const Color(0xFFF59E0B);
  }
}

String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Administrador';
    case UserRole.cleaning:
      return 'Limpieza';
    case UserRole.maintenance:
      return 'Mantenimiento';
  }
}
