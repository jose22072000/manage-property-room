import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/notifiers/notifiers.dart';
import '../../core/errors.dart';
import '../../domain/domain.dart';
import '../../permissions/policy.dart';
import 'groups_page.dart';

bool _isWorkerRole(UserRole r) =>
    r == UserRole.cleaning || r == UserRole.maintenance || r == UserRole.operator;

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final showGroups = currentUser != null && Policy.canManageGroups(currentUser);

    if (!showGroups) {
      // Owner: only shows their supervisors — single tab view
      return _UsersTab(tabController: null);
    }

    return Column(
      children: [
        Container(
          color: const Color(0xFF1E293B),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF2563EB),
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF94A3B8),
            tabs: const [
              Tab(text: 'Usuarios'),
              Tab(text: 'Grupos'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UsersTab(tabController: _tabController),
              const GroupsPage(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  Users tab content
// ─────────────────────────────────────────

class _UsersTab extends ConsumerWidget {
  const _UsersTab({required this.tabController});
  final TabController? tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final propsAsync = ref.watch(propertiesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    // Owners only see/assign their own properties; admin sees all
    final allProps = propsAsync.valueOrNull ?? [];
    final visibleProps = (currentUser?.role == UserRole.owner)
        ? allProps.where((p) =>
              currentUser!.assignedPropertyIds.contains(p.id) ||
              p.ownerUserId == currentUser.id).toList()
        : allProps;

    return usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (users) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text('Usuarios',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showEditor(context, ref, null, visibleProps, groupsAsync.valueOrNull ?? []),
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Añadir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: users.length,
                separatorBuilder: (context, idx) => const Divider(height: 1),
                itemBuilder: (_, i) => _UserTile(
                  user: users[i],
                  properties: allProps,
                  groups: groupsAsync.valueOrNull ?? [],
                  onEdit: () => _showEditor(context, ref, users[i], visibleProps, groupsAsync.valueOrNull ?? []),
                  onDelete: () => ref.read(usersProvider.notifier).deleteUser(users[i].id),
                ),
              ),
            ),
          ],
        ),
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref, AppUser? existing, List<Property> props, List<Group> groups) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => _UserEditorSheet(existing: existing, properties: props, groups: groups, ref: ref),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.properties,
    required this.groups,
    required this.onEdit,
    required this.onDelete,
  });

  final AppUser user;
  final List<Property> properties;
  final List<Group> groups;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Workers: show groups. Owner: properties they own. Supervisor: properties they supervise. Admin: nothing.
    final String subtitle;
    if (_isWorkerRole(user.role)) {
      final userGroups = groups.where((g) => g.userIds.contains(user.id)).toList();
      subtitle = userGroups.isEmpty ? '' : userGroups.map((g) => g.name).join(', ');
    } else if (user.role == UserRole.owner) {
      final owned = properties.where((p) => p.ownerUserId == user.id).toList();
      subtitle = owned.isEmpty ? '' : owned.map((p) => p.code).join(', ');
    } else if (user.role == UserRole.supervisor) {
      final supervised = properties.where((p) => p.supervisorIds.contains(user.id)).toList();
      subtitle = supervised.isEmpty ? '' : supervised.map((p) => p.code).join(', ');
    } else {
      subtitle = '';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _roleColor(user.role),
        child: Text(user.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_roleLabel(user.role), style: const TextStyle(fontSize: 12)),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
      isThreeLine: subtitle.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  User editor bottom sheet
// ─────────────────────────────────────────

class _UserEditorSheet extends StatefulWidget {
  const _UserEditorSheet({required this.existing, required this.properties, required this.groups, required this.ref});

  final AppUser? existing;
  final List<Property> properties;
  final List<Group> groups;
  final WidgetRef ref;

  @override
  State<_UserEditorSheet> createState() => _UserEditorSheetState();
}

class _UserEditorSheetState extends State<_UserEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _initialsCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late UserRole _role;
  late Set<String> _assignedIds;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _initialsCtrl = TextEditingController(text: u?.initials ?? '');
    _emailCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _role = u?.role ?? UserRole.cleaning;
    // For workers: pre-select groups they belong to.
    // For owner/supervisor: derive from the properties list (source of truth).
    if (u == null) {
      _assignedIds = {};
    } else if (_isWorkerRole(u.role)) {
      _assignedIds = widget.groups
          .where((g) => g.userIds.contains(u.id))
          .map((g) => g.id)
          .toSet();
    } else if (u.role == UserRole.owner) {
      _assignedIds = widget.properties
          .where((p) => p.ownerUserId == u.id)
          .map((p) => p.id)
          .toSet();
    } else if (u.role == UserRole.supervisor) {
      _assignedIds = widget.properties
          .where((p) => p.supervisorIds.contains(u.id))
          .map((p) => p.id)
          .toSet();
    } else {
      _assignedIds = {};
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _initialsCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isNew ? 'Nuevo usuario' : 'Editar usuario',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (_isNew) ...[
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _initialsCtrl,
              decoration: const InputDecoration(labelText: 'Iniciales (2 caracteres)'),
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 4),
            const Text('Rol', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: UserRole.values.map((r) {
                return ChoiceChip(
                  label: Text(_roleLabel(r)),
                  selected: _role == r,
                  onSelected: (_) => setState(() {
                    _role = r;
                    // Reset selection when switching between worker/non-worker
                    _assignedIds = {};
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (_isWorkerRole(_role)) ...[
              const Text('Grupos asignados', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              widget.groups.isEmpty
                  ? const Text('No hay grupos creados aún.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.groups.map((g) {
                        final sel = _assignedIds.contains(g.id);
                        return FilterChip(
                          label: Text(g.name),
                          selected: sel,
                          onSelected: (v) => setState(() {
                            if (v) _assignedIds.add(g.id); else _assignedIds.remove(g.id);
                          }),
                        );
                      }).toList(),
                    ),
            ] else ...[
              const Text('Propiedades asignadas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.properties.map((p) {
                  final sel = _assignedIds.contains(p.id);
                  return FilterChip(
                    label: Text(p.code),
                    selected: sel,
                    onSelected: (v) => setState(() {
                      if (v) _assignedIds.add(p.id); else _assignedIds.remove(p.id);
                    }),
                  );
                }).toList(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    if (_isNew && _emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'El email es obligatorio');
      return;
    }
    if (_isNew && _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'La contraseña es obligatoria');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final isWorker = _isWorkerRole(_role);
      if (_isNew) {
        await widget.ref.read(usersProvider.notifier).createUser(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
              name: _nameCtrl.text.trim(),
              initials: _initialsCtrl.text.trim().toUpperCase(),
              role: _role.name,
              assignedPropertyIds: isWorker ? [] : _assignedIds.toList(),
            );
        // For workers: find the newly created user and add to selected groups
        if (isWorker && _assignedIds.isNotEmpty) {
          final users = widget.ref.read(usersProvider).valueOrNull ?? [];
          final created = users.where((u) => u.name == _nameCtrl.text.trim()).firstOrNull;
          if (created != null) {
            await _syncGroupMembership(created.id, {});
          }
        }
      } else {
        final updated = AppUser(
          id: widget.existing!.id,
          name: _nameCtrl.text.trim(),
          initials: _initialsCtrl.text.trim().toUpperCase(),
          role: _role,
          assignedPropertyIds: isWorker ? [] : _assignedIds.toList(),
        );
        await widget.ref.read(usersProvider.notifier).updateUser(updated);
        // For workers: sync group membership
        if (isWorker) {
          // Previous groups this user was in
          final prevGroupIds = widget.groups
              .where((g) => g.userIds.contains(widget.existing!.id))
              .map((g) => g.id)
              .toSet();
          await _syncGroupMembership(widget.existing!.id, prevGroupIds);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _saving = false; _error = friendlyError(e); });
    }
  }

  /// Adds/removes this user from groups based on [_assignedIds] vs [prevGroupIds].
  Future<void> _syncGroupMembership(String userId, Set<String> prevGroupIds) async {
    final newGroupIds = _assignedIds;
    for (final group in widget.groups) {
      final wasIn = prevGroupIds.contains(group.id);
      final nowIn = newGroupIds.contains(group.id);
      if (wasIn == nowIn) continue;
      final updatedUserIds = nowIn
          ? [...group.userIds, userId]
          : group.userIds.where((id) => id != userId).toList();
      await widget.ref.read(groupsProvider.notifier).updateGroup(group.id, userIds: updatedUserIds);
    }
  }
}

// ─────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────

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
      return const Color(0xFFEA580C);
    case UserRole.supervisor:
      return const Color(0xFF0891B2);
  }
}

String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
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
