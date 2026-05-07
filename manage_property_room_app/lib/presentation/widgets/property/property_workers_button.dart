import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/notifiers/notifiers.dart';
import '../../../core/responsive.dart';
import '../../../domain/domain.dart';

/// Botón "trabajadores asignados" para mostrar/asignar usuarios a una
/// propiedad. Visible para todos; sólo el admin puede modificar (los demás
/// ven la lista en read-only).
///
/// Equivalente al modal de la app React: icono persona + contador como
/// badge → tap levanta un modal con la lista de usuarios.
class PropertyWorkersButton extends ConsumerWidget {
  const PropertyWorkersButton({
    super.key,
    required this.propertyId,
    this.lightOnDark = true,
  });

  final String propertyId;
  final bool lightOnDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final assigned = usersAsync.valueOrNull
            ?.where((u) => u.assignedPropertyIds.contains(propertyId))
            .toList() ??
        const <AppUser>[];

    final fg = lightOnDark ? Colors.white : const Color(0xFF334155);
    final bg = lightOnDark ? const Color(0x33FFFFFF) : const Color(0xFFF1F5F9);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_outlined, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(
                '${assigned.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showResponsiveModal<void>(
      context: context,
      maxWidth: 460,
      builder: (_) => _WorkersModal(propertyId: propertyId),
    );
  }
}

class _WorkersModal extends ConsumerWidget {
  const _WorkersModal({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = currentUser?.role == UserRole.admin;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: usersAsync.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('Error: $e'),
        data: (users) {
          final sorted = [...users]..sort((a, b) => a.name.compareTo(b.name));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_outlined, size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Trabajadores asignados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (!isAdmin)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 28, right: 4),
                  child: Text(
                    'Sólo lectura · pide a un admin para modificar.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              const SizedBox(height: 8),
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No hay usuarios cargados',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final u in sorted)
                          _WorkerRow(
                            user: u,
                            propertyId: propertyId,
                            isAdmin: isAdmin,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkerRow extends ConsumerWidget {
  const _WorkerRow({
    required this.user,
    required this.propertyId,
    required this.isAdmin,
  });
  final AppUser user;
  final String propertyId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = user.assignedPropertyIds.contains(propertyId);

    Future<void> toggle() async {
      if (!isAdmin) return;
      final next = [...user.assignedPropertyIds];
      if (assigned) {
        next.remove(propertyId);
      } else {
        next.add(propertyId);
      }
      await ref
          .read(usersProvider.notifier)
          .updateUser(user.copyWith(assignedPropertyIds: next));
    }

    return InkWell(
      onTap: isAdmin ? toggle : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE0E7FF),
              child: Text(
                user.initials,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4338CA),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      )),
                  const SizedBox(height: 1),
                  Text(_roleLabel(user.role),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            if (isAdmin)
              Checkbox(
                value: assigned,
                onChanged: (_) => toggle(),
              )
            else
              Icon(
                assigned ? Icons.check_circle : Icons.radio_button_unchecked,
                color: assigned ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(UserRole role) => switch (role) {
        UserRole.admin => 'Admin',
        UserRole.operator => 'Operador',
        UserRole.cleaning => 'Limpieza',
        UserRole.maintenance => 'Mantenimiento',
      };
}
