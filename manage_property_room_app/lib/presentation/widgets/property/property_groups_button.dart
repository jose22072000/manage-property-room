import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/notifiers/notifiers.dart';
import '../../../application/providers/api_providers.dart';
import '../../../core/errors.dart';
import '../../../domain/domain.dart';
import '../../../permissions/policy.dart';

/// Shows the groups linked to a property.
/// Admin/supervisor can toggle group assignment; others see read-only count.
class PropertyGroupsButton extends ConsumerWidget {
  const PropertyGroupsButton({super.key, required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    final groups = groupsAsync.valueOrNull ?? [];
    final assigned = groups.where((g) => g.propertyIds.contains(propertyId)).toList();

    final canManage = currentUser != null &&
        (currentUser.role == UserRole.admin ||
            currentUser.role == UserRole.supervisor);

    return GestureDetector(
      onTap: () => _showModal(context, ref, groups, assigned, canManage),
      child: Container(
        padding: const EdgeInsets.all(7),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: const Color(0x55000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.people_outline, color: Colors.white, size: 18),
      ),
    );
  }

  void _showModal(BuildContext context, WidgetRef ref, List<Group> allGroups,
      List<Group> assigned, bool canManage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => _GroupsModal(
        propertyId: propertyId,
        allGroups: allGroups,
        assignedGroups: assigned,
        canManage: canManage,
        ref: ref,
      ),
    );
  }
}

// ── Modal ─────────────────────────────────────────────────────────────────────

class _GroupsModal extends StatefulWidget {
  const _GroupsModal({
    required this.propertyId,
    required this.allGroups,
    required this.assignedGroups,
    required this.canManage,
    required this.ref,
  });
  final String propertyId;
  final List<Group> allGroups;
  final List<Group> assignedGroups;
  final bool canManage;
  final WidgetRef ref;

  @override
  State<_GroupsModal> createState() => _GroupsModalState();
}

class _GroupsModalState extends State<_GroupsModal> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.assignedGroups.map((g) => g.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.canManage ? 'Asignar grupos' : 'Grupos asignados',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (widget.allGroups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No hay grupos creados',
                    style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                children: widget.allGroups.map((g) {
                  final isSelected = _selected.contains(g.id);
                  final memberCount = g.userIds.length;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    title: Text(g.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text('$memberCount trabajador${memberCount == 1 ? '' : 'es'}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    trailing: widget.canManage
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (v) =>
                                setState(() => v! ? _selected.add(g.id) : _selected.remove(g.id)),
                          )
                        : (isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 18)
                            : null),
                  );
                }).toList(),
              ),
            ),
          if (widget.canManage) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = widget.ref.read(groupsApiProvider);
      // For each group, update its property list
      final allGroups = widget.ref.read(groupsProvider).valueOrNull ?? [];
      for (final g in allGroups) {
        final wasAssigned = g.propertyIds.contains(widget.propertyId);
        final willAssign = _selected.contains(g.id);
        if (wasAssigned == willAssign) continue;
        final newProps = wasAssigned
            ? g.propertyIds.where((id) => id != widget.propertyId).toList()
            : [...g.propertyIds, widget.propertyId];
        await api.setProperties(g.id, newProps);
      }
      widget.ref.invalidate(groupsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
        setState(() => _saving = false);
      }
    }
  }
}
