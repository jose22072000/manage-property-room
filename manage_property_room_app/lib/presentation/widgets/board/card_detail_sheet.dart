import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/notifiers/notifiers.dart';
import '../../../core/date_formatters.dart';
import '../../../core/image_storage.dart';
import '../../../core/property_visuals.dart';
import '../../../core/responsive.dart';
import '../../../domain/domain.dart';
import '../../../permissions/policy.dart';

// ─────────────────────────────────────────
//  Entry point — wraps in ProviderScope consumer
// ─────────────────────────────────────────

class CardDetailSheet extends ConsumerStatefulWidget {
  const CardDetailSheet({
    super.key,
    required this.card,
    required this.column,
    required this.allColumns,
    required this.propertyId,
    required this.user,
  });

  final BoardCard card;
  final BoardColumn column;
  final List<BoardColumn> allColumns;
  final String propertyId;
  final AppUser? user;

  @override
  ConsumerState<CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends ConsumerState<CardDetailSheet> {
  // Local mutable copy of the card
  late BoardCard _card;
  bool _editingTitle = false;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _commentCtrl;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _titleCtrl = TextEditingController(text: _card.title);
    _descCtrl = TextEditingController(text: _card.description);
    _commentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  bool _can(CardAction action) =>
      widget.user != null && Policy.canCard(widget.user!, _card, action);

  Future<void> _save(BoardCard updated) async {
    setState(() => _card = updated);
    await ref.read(boardProvider(widget.propertyId).notifier).updateCard(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isTabletOrDesktop(context);

    if (isDesktop) {
      return _buildDialog(context);
    }

    // Mobile: DraggableScrollableSheet inside modal
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, scrollController) => _buildContent(context, scrollController),
    );
  }

  Widget _buildDialog(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content (left 60%)
            Expanded(
              flex: 3,
              child: _buildContent(context, null),
            ),
            // Sidebar (right 40%)
            Container(
              width: 1,
              height: double.infinity,
              color: const Color(0xFFE2E8F0),
            ),
            SizedBox(
              width: 220,
              child: _Sidebar(
                card: _card,
                allColumns: widget.allColumns,
                users: ref.watch(usersProvider).valueOrNull ?? [],
                canEdit: _can(CardAction.editCustomField),
                canAssign: _can(CardAction.assign),
                canSetPriority: _can(CardAction.setPriority),
                canArchive: _can(CardAction.archive),
                onMoveToColumn: (colId) => _moveToColumn(colId),
                onAssign: (userId) => _save(_card.copyWith(assignedToId: userId, clearAssignee: userId == null)),
                onSetPriority: (p) => _save(_card.copyWith(priority: p)),
                onSetCheckin: (date) => _save(_card.copyWith(checkinDate: date, clearCheckin: date == null)),
                onArchive: _archiveCard,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScrollController? controller) {
    final col = widget.column;
    final config = col.config;
    final fields = ref.watch(fieldsProvider).valueOrNull ?? [];
    final users = ref.watch(usersProvider).valueOrNull ?? [];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomScrollView(
        controller: controller,
        slivers: [
          // Header with drag handle & close
          SliverToBoxAdapter(
            child: _CardHeader(
              card: _card,
              column: col,
              onClose: () => Navigator.pop(context),
              canEdit: _can(CardAction.editCustomField),
            ),
          ),

          // Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _editingTitle && _can(CardAction.editCustomField)
                  ? TextField(
                      controller: _titleCtrl,
                      autofocus: true,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      maxLines: null,
                      onSubmitted: (_) {
                        if (_titleCtrl.text.trim().isNotEmpty) {
                          _save(_card.copyWith(title: _titleCtrl.text.trim()));
                        }
                        setState(() => _editingTitle = false);
                      },
                    )
                  : GestureDetector(
                      onTap: _can(CardAction.editCustomField)
                          ? () => setState(() => _editingTitle = true)
                          : null,
                      child: Text(
                        _card.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
            ),
          ),

          // Room code
          if (_card.roomCode.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_card.roomCode,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Description
          if (config.showDescription)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _SectionLabel(icon: Icons.notes_outlined, label: 'Descripción'),
              ),
            ),
          if (config.showDescription)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _can(CardAction.editCustomField)
                    ? TextField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Añadir descripción...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onChanged: (v) {
                          // Debounced save on change
                          Future.delayed(const Duration(milliseconds: 800), () {
                            if (_descCtrl.text == v) {
                              _save(_card.copyWith(description: v));
                            }
                          });
                        },
                      )
                    : Text(
                        _card.description.isEmpty ? 'Sin descripción' : _card.description,
                        style: TextStyle(
                          color: _card.description.isEmpty ? const Color(0xFF94A3B8) : null,
                        ),
                      ),
              ),
            ),

          // Mobile sidebar actions
          if (!Responsive.isTabletOrDesktop(context))
            SliverToBoxAdapter(
              child: _Sidebar(
                card: _card,
                allColumns: widget.allColumns,
                users: users,
                canEdit: _can(CardAction.editCustomField),
                canAssign: _can(CardAction.assign),
                canSetPriority: _can(CardAction.setPriority),
                canArchive: _can(CardAction.archive),
                onMoveToColumn: (colId) => _moveToColumn(colId),
                onAssign: (userId) => _save(_card.copyWith(assignedToId: userId, clearAssignee: userId == null)),
                onSetPriority: (p) => _save(_card.copyWith(priority: p)),
                onSetCheckin: (date) => _save(_card.copyWith(checkinDate: date, clearCheckin: date == null)),
                onArchive: _archiveCard,
              ),
            ),

          // Custom fields
          if (config.showCustomFields && fields.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _SectionLabel(icon: Icons.tune_outlined, label: 'Campos'),
              ),
            ),
          if (config.showCustomFields)
            SliverList.builder(
              itemCount: fields.where((f) => f.enabled).length,
              itemBuilder: (_, i) {
                final field = fields.where((f) => f.enabled).elementAt(i);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _CustomFieldRow(
                    field: field,
                    value: _card.customFields[field.id],
                    canEdit: _can(CardAction.editCustomField),
                    cardId: _card.id,
                    onChanged: (v) {
                      final updated = Map<String, dynamic>.from(_card.customFields);
                      updated[field.id] = v;
                      _save(_card.copyWith(customFields: updated));
                    },
                  ),
                );
              },
            ),

          // Comments
          if (config.showComments)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _SectionLabel(icon: Icons.chat_bubble_outline, label: 'Comentarios'),
              ),
            ),
          if (config.showComments)
            SliverToBoxAdapter(
              child: _CommentsSection(
                cardId: _card.id,
                users: users,
                canComment: _can(CardAction.comment),
                commentCtrl: _commentCtrl,
                onAddComment: (text) async {
                  await ref.read(boardProvider(widget.propertyId).notifier).addComment(_card.id, text);
                  _commentCtrl.clear();
                  // Refresh comments
                  ref.invalidate(commentsProvider(_card.id));
                },
              ),
            ),

          // Activity
          if (config.showActivity)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _SectionLabel(icon: Icons.history_outlined, label: 'Actividad'),
              ),
            ),
          if (config.showActivity)
            SliverToBoxAdapter(
              child: _ActivitySection(cardId: _card.id, users: users),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _moveToColumn(String colId) {
    ref.read(boardProvider(widget.propertyId).notifier).moveCard(_card.id, colId, 0);
    Navigator.pop(context);
  }

  Future<void> _archiveCard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Archivar tarjeta?'),
        content: const Text('La tarjeta se moverá al archivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(boardProvider(widget.propertyId).notifier).archiveCard(_card.id);
      if (mounted) Navigator.pop(context);
    }
  }
}

// ─────────────────────────────────────────
//  Card header (colored strip + handle)
// ─────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.card,
    required this.column,
    required this.onClose,
    required this.canEdit,
  });

  final BoardCard card;
  final BoardColumn column;
  final VoidCallback onClose;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColumnPalette.headerBg(column.color),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: ColumnPalette.borderColor(column.color),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              column.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: ColumnPalette.iconColor(column.color),
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            style: IconButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Sidebar — actions (desktop right panel / mobile inline)
// ─────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.card,
    required this.allColumns,
    required this.users,
    required this.canEdit,
    required this.canAssign,
    required this.canSetPriority,
    required this.canArchive,
    required this.onMoveToColumn,
    required this.onAssign,
    required this.onSetPriority,
    required this.onSetCheckin,
    required this.onArchive,
  });

  final BoardCard card;
  final List<BoardColumn> allColumns;
  final List<AppUser> users;
  final bool canEdit;
  final bool canAssign;
  final bool canSetPriority;
  final bool canArchive;
  final void Function(String colId) onMoveToColumn;
  final void Function(String? userId) onAssign;
  final void Function(CardPriority) onSetPriority;
  final void Function(DateTime?) onSetCheckin;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final assignedUser = users.firstWhere(
      (u) => u.id == card.assignedToId,
      orElse: () => const AppUser(id: '', name: 'Sin asignar', initials: '?', role: UserRole.cleaning),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Move to column
          _SidebarSection(
            icon: Icons.swap_horiz,
            label: 'Mover a',
            child: DropdownButtonFormField<String>(
              initialValue: allColumns.any((c) => c.id == card.columnId) ? card.columnId : null,
              isDense: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              items: allColumns.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: canEdit ? (v) { if (v != null && v != card.columnId) onMoveToColumn(v); } : null,
            ),
          ),

          // Assignee
          if (canAssign)
            _SidebarSection(
              icon: Icons.person_outline,
              label: 'Asignado a',
              child: InkWell(
                onTap: () => _showAssigneePicker(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          assignedUser.initials.isEmpty ? '?' : assignedUser.initials,
                          style: const TextStyle(fontSize: 9, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(assignedUser.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Priority
          if (canSetPriority)
            _SidebarSection(
              icon: Icons.flag_outlined,
              label: 'Prioridad',
              child: Wrap(
                spacing: 4,
                children: CardPriority.values.map((p) {
                  return ChoiceChip(
                    label: Text(PriorityPalette.label(p), style: const TextStyle(fontSize: 11)),
                    selected: card.priority == p,
                    selectedColor: PriorityPalette.color(p).withValues(alpha: 0.2),
                    onSelected: (_) => onSetPriority(p),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ),

          // Check-in date
          _SidebarSection(
            icon: Icons.login_outlined,
            label: 'Entrada',
            child: InkWell(
              onTap: () => _showDatePicker(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.checkinDate != null ? formatRelativeDate(card.checkinDate!) : 'Sin fecha',
                  style: TextStyle(
                    fontSize: 13,
                    color: card.checkinDate != null ? null : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Archive
          if (canArchive)
            OutlinedButton.icon(
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined, size: 16),
              label: const Text('Archivar', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444))),
            ),
        ],
      ),
    );
  }

  void _showAssigneePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Asignar a', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          ListTile(
            leading: const CircleAvatar(radius: 14, child: Icon(Icons.person_off_outlined, size: 16)),
            title: const Text('Sin asignar'),
            onTap: () {
              onAssign(null);
              Navigator.pop(context);
            },
          ),
          ...users.map((u) => ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(u.initials, style: const TextStyle(fontSize: 10, color: Colors.white)),
                ),
                title: Text(u.name),
                trailing: u.id == card.assignedToId ? const Icon(Icons.check, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  onAssign(u.id);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: card.checkinDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (picked != null) {
      onSetCheckin(picked);
    }
  }
}

// ─────────────────────────────────────────
//  Sidebar section wrapper
// ─────────────────────────────────────────

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Custom field row
// ─────────────────────────────────────────

class _CustomFieldRow extends StatefulWidget {
  const _CustomFieldRow({
    required this.field,
    required this.value,
    required this.canEdit,
    required this.onChanged,
    required this.cardId,
  });

  final FieldDef field;
  final dynamic value;
  final bool canEdit;
  final void Function(dynamic) onChanged;
  final String cardId;

  @override
  State<_CustomFieldRow> createState() => _CustomFieldRowState();
}

class _CustomFieldRowState extends State<_CustomFieldRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;

    switch (field.type) {
      case FieldType.text:
        return _buildText();
      case FieldType.select:
        return _buildSelect();
      case FieldType.checkbox:
        return _buildCheckbox();
      case FieldType.image:
        return _buildImage();
    }
  }

  Widget _buildText() {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(widget.field.label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: widget.canEdit
              ? TextField(
                  controller: _ctrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8)),
                  onChanged: (v) => Future.delayed(const Duration(milliseconds: 600), () {
                    if (_ctrl.text == v) widget.onChanged(v);
                  }),
                )
              : Text(widget.value?.toString() ?? '—', style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildSelect() {
    final current = widget.value?.toString();
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(widget.field.label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: widget.field.options.contains(current) ? current : null,
            isDense: true,
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
            items: [
              const DropdownMenuItem(value: null, child: Text('—', style: TextStyle(fontSize: 13))),
              ...widget.field.options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: widget.canEdit ? (v) => widget.onChanged(v) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox() {
    final checked = widget.value == true || widget.value == 'true';
    return Row(
      children: [
        Checkbox(
          value: checked,
          onChanged: widget.canEdit ? (v) => widget.onChanged(v) : null,
        ),
        const SizedBox(width: 4),
        Text(widget.field.label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildImage() {
    final paths = widget.value is List ? List<String>.from(widget.value as List) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.field.label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...paths.map((p) => _ImageThumb(
                  path: p,
                  onDelete: widget.canEdit
                      ? () {
                          final updated = [...paths]..remove(p);
                          widget.onChanged(updated);
                        }
                      : null,
                )),
            if (widget.canEdit && !kIsWeb)
              GestureDetector(
                onTap: () => _pickImage(paths),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF94A3B8)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage(List<String> existing) async {
    // image_picker not available in this build — show informational message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selección de imágenes no disponible en esta plataforma.')),
      );
    }
  }
}

// ─────────────────────────────────────────
//  Image thumbnail
// ─────────────────────────────────────────

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.path, required this.onDelete});

  final String path;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (kIsWeb) {
      image = const Icon(Icons.image_outlined, size: 32, color: Color(0xFF94A3B8));
    } else {
      image = FutureBuilder<String?>(
        future: resolveCardImage(path),
        builder: (_, snap) {
          final resolved = snap.data;
          if (resolved == null) {
            return const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8));
          }
          return Image.file(
            File(resolved),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
          );
        },
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 72, height: 72, child: image),
        ),
        if (onDelete != null)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  Comments section
// ─────────────────────────────────────────

class _CommentsSection extends ConsumerWidget {
  const _CommentsSection({
    required this.cardId,
    required this.users,
    required this.canComment,
    required this.commentCtrl,
    required this.onAddComment,
  });

  final String cardId;
  final List<AppUser> users;
  final bool canComment;
  final TextEditingController commentCtrl;
  final Future<void> Function(String text) onAddComment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentsProvider(cardId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          commentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (comments) => ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (_, i) {
                final c = comments[i];
                final author = users.firstWhere(
                  (u) => u.id == c.authorId,
                  orElse: () => const AppUser(id: '', name: 'Desconocido', initials: '?', role: UserRole.cleaning),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(author.initials, style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(author.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                const SizedBox(width: 8),
                                Text(formatTime(c.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(c.text, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (canComment)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) onAddComment(v.trim());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () {
                    if (commentCtrl.text.trim().isNotEmpty) {
                      onAddComment(commentCtrl.text.trim());
                    }
                  },
                ),
              ],
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Activity section
// ─────────────────────────────────────────

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection({required this.cardId, required this.users});

  final String cardId;
  final List<AppUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityProvider(cardId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: activityAsync.when(
        loading: () => const CircularProgressIndicator(strokeWidth: 2),
        error: (_, _) => const SizedBox.shrink(),
        data: (events) => ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (_, i) {
            final e = events[i];
            final author = users.firstWhere(
              (u) => u.id == e.authorId,
              orElse: () => const AppUser(id: '', name: 'Sistema', initials: 'S', role: UserRole.admin),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 6, color: Color(0xFFCBD5E1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        children: [
                          TextSpan(
                            text: author.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' ${e.message}'),
                          TextSpan(
                            text: '  ${formatRelativeDate(e.createdAt)}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Section label
// ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151)),
        ),
      ],
    );
  }
}
