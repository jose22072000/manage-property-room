import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../application/notifiers/notifiers.dart';
import '../../domain/domain.dart';

const _uuid = Uuid();

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Ajustes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                ),
                const TabBar(
                  labelColor: Color(0xFF2563EB),
                  unselectedLabelColor: Color(0xFF6B7280),
                  indicatorColor: Color(0xFF2563EB),
                  tabs: [
                    Tab(text: 'Campos'),
                    Tab(text: 'Acerca de'),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FieldsTab(),
                _AboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Fields tab — reorderable list of custom field definitions
// ─────────────────────────────────────────

class _FieldsTab extends ConsumerWidget {
  const _FieldsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(fieldsProvider);

    return fieldsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (fields) => Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: fields.length,
              itemBuilder: (_, i) {
                final f = fields[i];
                return _FieldTile(key: ValueKey(f.id), field: f, index: i);
              },
              onReorder: (old, newIdx) {
                ref.read(fieldsProvider.notifier).reorder(old, newIdx);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _showFieldEditor(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Añadir campo'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFieldEditor(BuildContext context, WidgetRef ref, FieldDef? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FieldEditorSheet(existing: existing, ref: ref),
    );
  }
}

class _FieldTile extends ConsumerWidget {
  const _FieldTile({super.key, required this.field, required this.index});

  final FieldDef field;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(_typeIcon(field.type), color: const Color(0xFF64748B)),
      title: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(_typeLabel(field.type), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
            onPressed: () => _showFieldEditor(context, ref, field),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
            onPressed: () => ref.read(fieldsProvider.notifier).removeField(field.id),
          ),
          const Icon(Icons.drag_handle, color: Color(0xFFCBD5E1)),
        ],
      ),
    );
  }

  void _showFieldEditor(BuildContext context, WidgetRef ref, FieldDef? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FieldEditorSheet(existing: existing, ref: ref),
    );
  }
}

// ─────────────────────────────────────────
//  Field editor bottom sheet
// ─────────────────────────────────────────

class _FieldEditorSheet extends StatefulWidget {
  const _FieldEditorSheet({required this.existing, required this.ref});

  final FieldDef? existing;
  final WidgetRef ref;

  @override
  State<_FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _FieldEditorSheetState extends State<_FieldEditorSheet> {
  late final TextEditingController _labelCtrl;
  late FieldType _type;
  late bool _showOnCard;
  final List<String> _options = [];
  final TextEditingController _optCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    _labelCtrl = TextEditingController(text: f?.label ?? '');
    _type = f?.type ?? FieldType.text;
    _showOnCard = f?.showOnCard ?? false;
    if (f != null) _options.addAll(f.options);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _optCtrl.dispose();
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
              widget.existing == null ? 'Nuevo campo' : 'Editar campo',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(labelText: 'Etiqueta', hintText: 'Ej: Cobrar, Salida...'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: FieldType.values.map((t) {
                return ChoiceChip(
                  label: Text(_typeLabel(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            if (_type == FieldType.select) ...[
              const SizedBox(height: 12),
              const Text('Opciones', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              for (final opt in _options)
                ListTile(
                  dense: true,
                  title: Text(opt),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFEF4444)),
                    onPressed: () => setState(() => _options.remove(opt)),
                  ),
                ),
              Row(
                children: [
                  Expanded(child: TextField(controller: _optCtrl, decoration: const InputDecoration(hintText: 'Nueva opción'))),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF2563EB)),
                    onPressed: () {
                      if (_optCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          _options.add(_optCtrl.text.trim());
                          _optCtrl.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Mostrar en tarjeta', style: TextStyle(fontSize: 13)),
              value: _showOnCard,
              onChanged: (v) => setState(() => _showOnCard = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_labelCtrl.text.trim().isEmpty) return;
    final field = FieldDef(
      id: widget.existing?.id ?? _uuid.v4(),
      label: _labelCtrl.text.trim(),
      type: _type,
      options: _options,
      showOnCard: _showOnCard,
      enabled: widget.existing?.enabled ?? true,
    );
    if (widget.existing == null) {
      widget.ref.read(fieldsProvider.notifier).addField(field);
    } else {
      widget.ref.read(fieldsProvider.notifier).updateField(field);
    }
    Navigator.pop(context);
  }
}

// ─────────────────────────────────────────
//  About tab
// ─────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment_outlined, size: 64, color: Color(0xFF2563EB)),
          SizedBox(height: 12),
          Text('Manage Property Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          SizedBox(height: 4),
          Text('v1.0.0 — Multi-platform', style: TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────

IconData _typeIcon(FieldType t) {
  switch (t) {
    case FieldType.text:
      return Icons.text_fields_outlined;
    case FieldType.select:
      return Icons.list_outlined;
    case FieldType.checkbox:
      return Icons.check_box_outlined;
    case FieldType.image:
      return Icons.photo_camera_outlined;
  }
}

String _typeLabel(FieldType t) {
  switch (t) {
    case FieldType.text:
      return 'Texto';
    case FieldType.select:
      return 'Selector';
    case FieldType.checkbox:
      return 'Casilla';
    case FieldType.image:
      return 'Imagen';
  }
}
