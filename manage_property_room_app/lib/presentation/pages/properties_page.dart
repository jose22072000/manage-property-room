import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../application/notifiers/notifiers.dart';
import '../../application/providers/api_providers.dart';
import '../../core/errors.dart';
import '../../core/property_visuals.dart';
import '../../core/responsive.dart';
import '../../domain/domain.dart';
import '../../permissions/policy.dart';
import '../widgets/property/property_groups_button.dart';

class PropertiesPage extends ConsumerWidget {
  const PropertiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(visiblePropertiesProvider);
    final boardStates = {for (final p in props) p.id: ref.watch(boardProvider(p.id))};
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final canCreate = currentUser != null && Policy.canCreateProperty(currentUser);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tableros',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        SizedBox(height: 2),
                        Text('Selecciona una propiedad para ver su tablero',
                            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  if (canCreate)
                    FilledButton.icon(
                      onPressed: () => _showCreateProperty(context, ref),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nueva'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (props.isEmpty)
                const Center(child: Text('Sin propiedades asignadas', style: TextStyle(color: Color(0xFF6B7280))))
              else
                _PropertyGrid(properties: props, boardStates: boardStates),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateProperty(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => _CreatePropertySheet(ref: ref),
    );
  }
}

class _PropertyGrid extends StatelessWidget {
  const _PropertyGrid({required this.properties, required this.boardStates});

  final List<Property> properties;
  final Map<String, AsyncValue<BoardState>> boardStates;

  @override
  Widget build(BuildContext context) {
    final cols = Responsive.isMobile(context) ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.55,
      ),
      itemCount: properties.length,
      itemBuilder: (_, i) {
        final p = properties[i];
        return _PropertyCard(property: p, boardState: boardStates[p.id]?.valueOrNull);
      },
    );
  }
}

class _PropertyCard extends ConsumerWidget {
  const _PropertyCard({required this.property, this.boardState});

  final Property property;
  final BoardState? boardState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final canAssignSup = currentUser != null && Policy.canAssignSupervisors(currentUser, property);
    final canAssignOwner = currentUser?.role == UserRole.admin;
    final canEdit = currentUser != null && Policy.canEditProperty(currentUser, property);
    final canDelete = currentUser != null && Policy.canDeleteProperty(currentUser, property);
    final total = boardState?.totalCards ?? 0;
    final done = boardState?.doneCards ?? 0;
    final hasData = total > 0;

    final hasImage = property.imageUrl != null && property.imageUrl!.isNotEmpty;

    return GestureDetector(
      // ignore: prefer_interpolation_to_compose_strings
      onTap: () => context.go('/properties/' + property.id + '/board'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: hasImage ? null : propertyGradient(property),
            image: hasImage
                ? DecorationImage(
                    image: NetworkImage(property.imageUrl!),
                    fit: BoxFit.cover,
                    colorFilter: const ColorFilter.mode(Color(0x44000000), BlendMode.darken),
                    onError: (_, __) {},
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Stack(
            children: [
              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0x59000000),
                ),
              ),
              // Top-left: name + stats taking the full width above the icons.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        property.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.15,
                          shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasData) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$done/$total listas',
                          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Bottom: action icons row, full width below the name.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      if (canEdit)
                        _CardIconBtn(
                          icon: Icons.edit_outlined,
                          onTap: () => _showEditProperty(context, ref),
                        ),
                      if (canDelete)
                        _CardIconBtn(
                          icon: Icons.delete_outline,
                          onTap: () => _confirmDelete(context, ref),
                        ),
                      const Spacer(),
                      if (canAssignOwner)
                        _CardIconBtn(
                          icon: Icons.person_pin_outlined,
                          onTap: () => _showAssignOwner(context, ref),
                        ),
                      if (canAssignSup)
                        _CardIconBtn(
                          icon: Icons.manage_accounts_outlined,
                          onTap: () => _showAssignSupervisors(context, ref),
                        ),
                      PropertyGroupsButton(propertyId: property.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignSupervisors(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => _AssignSupervisorsSheet(property: property, ref: ref),
    );
  }

  void _showAssignOwner(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => _AssignOwnerSheet(property: property, ref: ref),
    );
  }

  void _showEditProperty(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => _EditPropertySheet(property: property, ref: ref),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar propiedad'),
        content: Text('¿Seguro que deseas eliminar “${property.name}”? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(propertiesApiProvider).delete(property.id);
      ref.invalidate(propertiesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Propiedad “${property.name}” eliminada')),
        );
      }
    } catch (e) {
      debugPrint('DELETE PROPERTY ERROR: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red[700]),
        );
      }
    }
  }
}

// ─────────────────────────────────────────
//  Small icon button for property card
// ─────────────────────────────────────────

class _CardIconBtn extends StatelessWidget {
  const _CardIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: const Color(0x55000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Assign supervisors sheet
// ─────────────────────────────────────────

class _AssignSupervisorsSheet extends StatefulWidget {
  const _AssignSupervisorsSheet({required this.property, required this.ref});
  final Property property;
  final WidgetRef ref;

  @override
  State<_AssignSupervisorsSheet> createState() => _AssignSupervisorsSheetState();
}

class _AssignSupervisorsSheetState extends State<_AssignSupervisorsSheet> {
  Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSupervisors();
  }

  Future<void> _loadCurrentSupervisors() async {
    try {
      final ids = await widget.ref.read(propertiesApiProvider).getSupervisors(widget.property.id);
      if (mounted) setState(() { _selected = ids.toSet(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show only supervisors the current user created
    final users = widget.ref.read(usersProvider).valueOrNull ?? [];
    final supervisors = users.where((u) => u.role == UserRole.supervisor).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

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
              const Icon(Icons.manage_accounts_outlined, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Asignar supervisores',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            widget.property.name,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (supervisors.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No tienes supervisores creados',
                  style: TextStyle(color: Color(0xFF6B7280))),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: supervisors.map((u) {
                    return CheckboxListTile(
                      value: _selected.contains(u.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(u.id);
                        } else {
                          _selected.remove(u.id);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF0891B2),
                            child: Text(u.initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(u.name)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
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
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.ref.read(propertiesApiProvider).assignSupervisors(
          widget.property.id, _selected.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Assign Owner Sheet (admin only) ──────────────────────────────────────────

class _AssignOwnerSheet extends StatefulWidget {
  const _AssignOwnerSheet({required this.property, required this.ref});
  final Property property;
  final WidgetRef ref;

  @override
  State<_AssignOwnerSheet> createState() => _AssignOwnerSheetState();
}

class _AssignOwnerSheetState extends State<_AssignOwnerSheet> {
  String? _selectedOwnerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedOwnerId = widget.property.ownerUserId?.isEmpty == true
        ? null
        : widget.property.ownerUserId;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = widget.ref.watch(usersProvider);

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
              const Icon(Icons.person_pin_outlined, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Asignar propietario',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            widget.property.name,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(e.toString()),
            data: (users) {
              final owners = users.where((u) => u.role == UserRole.owner).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // None option
                  RadioListTile<String?>(
                    title: const Text('Sin propietario'),
                    value: null,
                    groupValue: _selectedOwnerId,
                    onChanged: (v) => setState(() => _selectedOwnerId = v),
                  ),
                  ...owners.map((u) => RadioListTile<String?>(
                        title: Text(u.name),
                        value: u.id,
                        groupValue: _selectedOwnerId,
                        onChanged: (v) => setState(() => _selectedOwnerId = v),
                      )),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
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
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.ref.read(propertiesApiProvider).assignOwner(
          widget.property.id, _selectedOwnerId);
      widget.ref.invalidate(propertiesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Create Property Sheet ────────────────────────────────────────────────────

class _CreatePropertySheet extends StatefulWidget {
  const _CreatePropertySheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_CreatePropertySheet> createState() => _CreatePropertySheetState();
}

class _CreatePropertySheetState extends State<_CreatePropertySheet> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _roomsCtrl = TextEditingController(text: '1');
  int _colorSeed = 0;
  bool _saving = false;
  XFile? _imageFile;
  String? _selectedOwnerId;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _roomsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = currentUser?.role == UserRole.admin;
    final usersAsync = widget.ref.watch(usersProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_work_outlined, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Nueva propiedad',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 16),
            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF1F5F9),
                ),
                child: _imageFile == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 36, color: Color(0xFF94A3B8)),
                          SizedBox(height: 4),
                          Text('Agregar imagen', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      )
                    : _ImageFilePreview(file: _imageFile!),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Código (ej: FN13)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Habitaciones', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Color', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: List.generate(10, (i) {
                final selected = _colorSeed == i;
                return GestureDetector(
                  onTap: () => setState(() => _colorSeed = i),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: propertyGradient(Property(
                          id: '', code: '', name: '', totalRooms: 1, colorSeed: i)),
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.black87, width: 2)
                          : null,
                    ),
                  ),
                );
              }),
            ),
            // Owner dropdown (admin only)
            if (isAdmin) ...[
              const SizedBox(height: 12),
              usersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (users) {
                  final owners = users
                      .where((u) => u.role == UserRole.owner)
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));
                  return DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(
                      labelText: 'Propietario (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedOwnerId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sin propietario')),
                      ...owners.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                    ],
                    onChanged: (v) => setState(() => _selectedOwnerId = v),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Crear propiedad'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null && mounted) setState(() => _imageFile = file);
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final rooms = int.tryParse(_roomsCtrl.text.trim()) ?? 1;
    if (code.isEmpty || name.isEmpty) return;
    setState(() => _saving = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await widget.ref.read(propertiesApiProvider).uploadImage(_imageFile!);
      }
      final body = {
        'code': code,
        'name': name,
        'totalRooms': rooms,
        'colorSeed': _colorSeed,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (_selectedOwnerId != null) 'ownerId': _selectedOwnerId,
      };
      await widget.ref.read(propertiesApiProvider).create(body);
      widget.ref.invalidate(propertiesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('CREATE PROPERTY ERROR: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red[700]),
        );
      }
    }
  }
}

// ─────────────────────────────────────────
//  Edit property sheet (admin or property owner)
// ─────────────────────────────────────────

class _EditPropertySheet extends StatefulWidget {
  const _EditPropertySheet({required this.property, required this.ref});
  final Property property;
  final WidgetRef ref;

  @override
  State<_EditPropertySheet> createState() => _EditPropertySheetState();
}

class _EditPropertySheetState extends State<_EditPropertySheet> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _roomsCtrl;
  late int _colorSeed;
  bool _saving = false;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.property.code);
    _nameCtrl = TextEditingController(text: widget.property.name);
    _roomsCtrl = TextEditingController(text: '${widget.property.totalRooms}');
    _colorSeed = widget.property.colorSeed;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _roomsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null && mounted) setState(() => _imageFile = file);
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final rooms = int.tryParse(_roomsCtrl.text.trim()) ?? 1;
    if (code.isEmpty || name.isEmpty) return;
    setState(() => _saving = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await widget.ref.read(propertiesApiProvider).uploadImage(_imageFile!);
      }
      final body = <String, dynamic>{
        'code': code,
        'name': name,
        'totalRooms': rooms,
        'colorSeed': _colorSeed,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      };
      await widget.ref.read(propertiesApiProvider).update(widget.property.id, body);
      widget.ref.invalidate(propertiesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('UPDATE PROPERTY ERROR: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNetworkImage = _imageFile == null &&
        widget.property.imageUrl != null &&
        widget.property.imageUrl!.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Editar propiedad',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF1F5F9),
                  image: hasNetworkImage
                      ? DecorationImage(
                          image: NetworkImage(widget.property.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imageFile != null
                    ? _ImageFilePreview(file: _imageFile!)
                    : (hasNetworkImage
                        ? null
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 36, color: Color(0xFF94A3B8)),
                              SizedBox(height: 4),
                              Text('Agregar imagen', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            ],
                          )),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Habitaciones', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Color', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: List.generate(10, (i) {
                final selected = _colorSeed == i;
                return GestureDetector(
                  onTap: () => setState(() => _colorSeed = i),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: propertyGradient(Property(
                          id: '', code: '', name: '', totalRooms: 1, colorSeed: i)),
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: Colors.black87, width: 2) : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image file preview (uses Image.file for local path on mobile) ─────────────

class _ImageFilePreview extends StatelessWidget {
  const _ImageFilePreview({required this.file});
  final XFile file;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(file.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 140,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, size: 48, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}
