import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/notifiers/notifiers.dart';
import '../../application/providers/api_providers.dart';
import '../../core/errors.dart';
import '../../domain/domain.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final usersAsync = ref.watch(usersProvider);
    final propsAsync = ref.watch(propertiesProvider);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (groups) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('Grupos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showEditor(context, ref, null, usersAsync.valueOrNull ?? [], propsAsync.valueOrNull ?? []),
                  icon: const Icon(Icons.group_add_outlined, size: 16),
                  label: const Text('Nuevo grupo'),
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
            child: groups.isEmpty
                ? const Center(child: Text('No hay grupos', style: TextStyle(color: Color(0xFF94A3B8))))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _GroupTile(
                      group: groups[i],
                      users: usersAsync.valueOrNull ?? [],
                      properties: propsAsync.valueOrNull ?? [],
                      onEdit: () => _showEditor(context, ref, groups[i], usersAsync.valueOrNull ?? [], propsAsync.valueOrNull ?? []),
                      onDelete: () => ref.read(groupsProvider.notifier).delete(groups[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref, Group? existing, List<AppUser> users, List<Property> props) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => _GroupEditorSheet(existing: existing, users: users, properties: props, ref: ref),
    );
  }
}

// ─────────────────────────────────────────

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.users,
    required this.properties,
    required this.onEdit,
    required this.onDelete,
  });

  final Group group;
  final List<AppUser> users;
  final List<Property> properties;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final memberNames = users.where((u) => group.userIds.contains(u.id)).map((u) => u.name).toList();
    final propCodes = properties.where((p) => group.propertyIds.contains(p.id)).map((p) => p.code).toList();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF2563EB),
        child: Text(
          group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (memberNames.isNotEmpty)
            Text(memberNames.join(', '), style: const TextStyle(fontSize: 12)),
          if (propCodes.isNotEmpty)
            Text(propCodes.join(', '), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
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

class _GroupEditorSheet extends StatefulWidget {
  const _GroupEditorSheet({
    required this.existing,
    required this.users,
    required this.properties,
    required this.ref,
  });

  final Group? existing;
  final List<AppUser> users;
  final List<Property> properties;
  final WidgetRef ref;

  @override
  State<_GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends State<_GroupEditorSheet> {
  late final TextEditingController _nameCtrl;
  late Set<String> _selectedUsers;
  late Set<String> _selectedProps;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedUsers = Set.from(widget.existing?.userIds ?? []);
    _selectedProps = Set.from(widget.existing?.propertyIds ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (widget.existing == null) {
        final g = await widget.ref.read(groupsApiProvider).create(
          name: name,
          userIds: _selectedUsers.toList(),
          propertyIds: _selectedProps.toList(),
        );
        widget.ref.read(groupsProvider.notifier).state =
            AsyncData([...widget.ref.read(groupsProvider).valueOrNull ?? [], g]);
      } else {
        await widget.ref.read(groupsProvider.notifier).updateGroup(
          widget.existing!.id,
          name: name,
          userIds: _selectedUsers.toList(),
          propertyIds: _selectedProps.toList(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Nuevo grupo' : 'Editar grupo',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del grupo', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Usuarios', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.users.map((u) {
                final sel = _selectedUsers.contains(u.id);
                return FilterChip(
                  label: Text(u.name, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: (v) => setState(() => v ? _selectedUsers.add(u.id) : _selectedUsers.remove(u.id)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Propiedades', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.properties.map((p) {
                final sel = _selectedProps.contains(p.id);
                return FilterChip(
                  label: Text(p.code, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: (v) => setState(() => v ? _selectedProps.add(p.id) : _selectedProps.remove(p.id)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
