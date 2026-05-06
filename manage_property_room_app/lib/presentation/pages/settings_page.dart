import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/notifiers/notifiers.dart';
import '../../core/property_visuals.dart';
import '../../core/responsive.dart';
import '../../domain/domain.dart';
import '../widgets/shared/confirm_dialog.dart';

const _uuid = Uuid();

/// Página de configuración — paridad visual con `src/pages/SettingsPage.tsx`.
///
/// Dos secciones:
///   1. Campos personalizados (reordenables, toggles enabled/mostrar-en-card,
///      editar, eliminar, "+ Añadir campo").
///   2. Configurar listas — tabs de propiedades + filas plegables por columna
///      con toggles de [ColumnConfig].
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: 24),
                if (isWide)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(child: _FieldsSection()),
                        SizedBox(width: 24),
                        Expanded(child: _ColumnsSection()),
                      ],
                    ),
                  )
                else
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FieldsSection(),
                      SizedBox(height: 32),
                      _ColumnsSection(),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Row(
      children: [
        if (!isMobile)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.arrow_back, size: 22, color: Color(0xFF475569)),
              ),
            ),
          ),
        if (!isMobile) const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Configuración',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                )),
            SizedBox(height: 2),
            Text('Personaliza campos y comportamiento',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
//  Sección 1 — Campos personalizados
// ──────────────────────────────────────────────────────────

class _FieldsSection extends ConsumerWidget {
  const _FieldsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(fieldsProvider);
    return fieldsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (fields) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, size: 18, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Campos personalizados',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        )),
                    SizedBox(height: 2),
                    Text('Arrastra ☰ para reordenar',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              _AddFieldChip(onPressed: () => _openEditor(context, ref, null)),
            ],
          ),
          const SizedBox(height: 12),
          if (fields.isEmpty)
            const _EmptyState(message: 'Aún no hay campos personalizados')
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: fields.length,
              proxyDecorator: (child, _, _) => Material(
                color: Colors.transparent,
                child: Opacity(opacity: 0.9, child: child),
              ),
              onReorder: (old, neu) =>
                  ref.read(fieldsProvider.notifier).reorder(old, neu),
              itemBuilder: (_, i) => Padding(
                key: ValueKey(fields[i].id),
                padding: const EdgeInsets.only(bottom: 8),
                child: _FieldRow(
                  index: i,
                  field: fields[i],
                  onEdit: () => _openEditor(context, ref, fields[i]),
                  onDelete: () async {
                    final ok = await ConfirmDialog.ask(context,
                        message: '¿Eliminar el campo "${fields[i].label}"?',
                        confirmLabel: 'Eliminar',
                        danger: true);
                    if (ok) {
                      await ref
                          .read(fieldsProvider.notifier)
                          .removeField(fields[i].id);
                    }
                  },
                  onToggleEnabled: () =>
                      ref.read(fieldsProvider.notifier).updateField(
                            fields[i].copyWith(enabled: !fields[i].enabled),
                          ),
                  onToggleShowOnCard: () =>
                      ref.read(fieldsProvider.notifier).updateField(
                            fields[i].copyWith(showOnCard: !fields[i].showOnCard),
                          ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, FieldDef? existing) {
    showResponsiveModal<void>(
      context: context,
      maxWidth: 480,
      builder: (_) => _FieldEditor(existing: existing),
    );
  }
}

class _AddFieldChip extends StatelessWidget {
  const _AddFieldChip({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
              SizedBox(width: 4),
              Text('Añadir campo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
    required this.onToggleShowOnCard,
  });
  final FieldDef field;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleEnabled;
  final VoidCallback onToggleShowOnCard;

  @override
  Widget build(BuildContext context) {
    final disabled = !field.enabled;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_indicator,
                      size: 18, color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_iconFor(field.type),
                  size: 16, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(field.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      )),
                  const SizedBox(height: 2),
                  Text(_subtitleFor(field),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Tooltip(
              message: field.showOnCard ? 'Visible en card' : 'No visible en card',
              child: SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: field.showOnCard,
                  onChanged: (_) => onToggleShowOnCard(),
                  activeColor: const Color(0xFF2563EB),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            _MiniIconButton(
              tooltip: 'Editar',
              icon: Icons.edit_outlined,
              color: const Color(0xFF475569),
              onTap: onEdit,
            ),
            _MiniIconButton(
              tooltip: 'Eliminar',
              icon: Icons.delete_outline,
              color: const Color(0xFFDC2626),
              onTap: onDelete,
            ),
            const SizedBox(width: 4),
            Switch(
              value: field.enabled,
              onChanged: (_) => onToggleEnabled(),
              activeColor: const Color(0xFF2563EB),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(FieldType t) => switch (t) {
        FieldType.text => Icons.text_fields,
        FieldType.select => Icons.list_alt,
        FieldType.checkbox => Icons.toggle_on_outlined,
        FieldType.image => Icons.image_outlined,
      };

  static String _subtitleFor(FieldDef f) => switch (f.type) {
        FieldType.text => 'Texto',
        FieldType.select => f.options.isEmpty
            ? 'Lista de opciones'
            : 'Lista de opciones · ${f.options.join(", ")}',
        FieldType.checkbox => 'Activar / Desactivar',
        FieldType.image => 'Fotos / Imágenes',
      };
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 38,
          height: 22,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 2,
                      offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(message,
          style: const TextStyle(
              color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
    );
  }
}

// ──────────────────────────────────────────────────────────
//  Editor de campo (modal)
// ──────────────────────────────────────────────────────────

class _FieldEditor extends ConsumerStatefulWidget {
  const _FieldEditor({required this.existing});
  final FieldDef? existing;
  @override
  ConsumerState<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends ConsumerState<_FieldEditor> {
  late TextEditingController _labelCtrl;
  late FieldType _type;
  late bool _showOnCard;
  late bool _enabled;
  final List<String> _options = [];
  final TextEditingController _optCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    _labelCtrl = TextEditingController(text: f?.label ?? '');
    _type = f?.type ?? FieldType.text;
    _showOnCard = f?.showOnCard ?? false;
    _enabled = f?.enabled ?? true;
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
            Text(widget.existing == null ? 'Nuevo campo' : 'Editar campo',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Etiqueta',
                hintText: 'Ej. Cobrar, Salida…',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            const Text('Tipo',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: FieldType.values
                  .map((t) => ChoiceChip(
                        label: Text(_typeLabel(t)),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            if (_type == FieldType.select) ...[
              const SizedBox(height: 16),
              const Text('Opciones',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155))),
              const SizedBox(height: 6),
              for (final opt in [..._options])
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(opt)),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 16, color: Color(0xFFDC2626)),
                      onPressed: () => setState(() => _options.remove(opt)),
                    ),
                  ]),
                ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _optCtrl,
                    decoration: const InputDecoration(hintText: 'Nueva opción'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF2563EB)),
                  onPressed: () {
                    final v = _optCtrl.text.trim();
                    if (v.isNotEmpty) {
                      setState(() {
                        _options.add(v);
                        _optCtrl.clear();
                      });
                    }
                  },
                ),
              ]),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showOnCard,
              onChanged: (v) => setState(() => _showOnCard = v),
              title: const Text('Mostrar en tarjeta'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: const Text('Activado'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Guardar'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_labelCtrl.text.trim().isEmpty) return;
    final field = FieldDef(
      id: widget.existing?.id ?? _uuid.v4(),
      label: _labelCtrl.text.trim(),
      type: _type,
      options: _options,
      enabled: _enabled,
      showOnCard: _showOnCard,
    );
    final notifier = ref.read(fieldsProvider.notifier);
    try {
      if (widget.existing == null) {
        await notifier.addField(field);
      } else {
        await notifier.updateField(field);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // toast already shown by notifier; keep drawer open so user can retry
    }
  }

  static String _typeLabel(FieldType t) => switch (t) {
        FieldType.text => 'Texto',
        FieldType.select => 'Lista de opciones',
        FieldType.checkbox => 'Activar / Desactivar',
        FieldType.image => 'Fotos / Imágenes',
      };
}

// ──────────────────────────────────────────────────────────
//  Sección 2 — Configurar listas
// ──────────────────────────────────────────────────────────

class _ColumnsSection extends ConsumerStatefulWidget {
  const _ColumnsSection();
  @override
  ConsumerState<_ColumnsSection> createState() => _ColumnsSectionState();
}

class _ColumnsSectionState extends ConsumerState<_ColumnsSection> {
  String? _activePropId;
  String? _openColId;

  @override
  Widget build(BuildContext context) {
    final propsAsync = ref.watch(propertiesProvider);
    return propsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('Error: $e'),
      data: (properties) {
        final activeId = _activePropId ??
            (properties.isNotEmpty ? properties.first.id : null);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: const [
              Icon(Icons.tune, size: 16, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Configurar listas',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    SizedBox(height: 2),
                    Text('Arrastra ☰ para reordenar',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (properties.length > 1)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: properties.map((p) {
                  final selected = p.id == activeId;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _activePropId = p.id;
                        _openColId = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFF3E8FF)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(p.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF475569),
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            if (activeId == null)
              const _EmptyState(message: 'No hay propiedades cargadas')
            else
              _ColumnsForProperty(
                propertyId: activeId,
                openColId: _openColId,
                onToggle: (id) => setState(() {
                  _openColId = _openColId == id ? null : id;
                }),
              ),
          ],
        );
      },
    );
  }
}

class _ColumnsForProperty extends ConsumerWidget {
  const _ColumnsForProperty({
    required this.propertyId,
    required this.openColId,
    required this.onToggle,
  });
  final String propertyId;
  final String? openColId;
  final ValueChanged<String> onToggle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(boardProvider(propertyId));
    return boardAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('Error: $e'),
      data: (board) {
        final cols = [...board.columns]
          ..sort((a, b) => a.position.compareTo(b.position));
        if (cols.isEmpty) {
          return const _EmptyState(message: 'Esta propiedad no tiene listas aún');
        }
        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: (child, _, _) => Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.9, child: child),
          ),
          onReorder: (old, neu) =>
              ref.read(boardProvider(propertyId).notifier).reorderColumns(old, neu),
          itemCount: cols.length,
          itemBuilder: (_, i) => Padding(
            key: ValueKey(cols[i].id),
            padding: const EdgeInsets.only(bottom: 8),
            child: _ColumnConfigRow(
              column: cols[i],
              index: i,
              isOpen: openColId == cols[i].id,
              onToggle: () => onToggle(cols[i].id),
            ),
          ),
        );
      },
    );
  }
}

class _ColumnConfigRow extends ConsumerWidget {
  const _ColumnConfigRow({
    required this.column,
    required this.index,
    required this.isOpen,
    required this.onToggle,
  });
  final BoardColumn column;
  final int index;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = column.config;
    final notifier = ref.read(boardProvider(column.propertyId).notifier);
    final cardPrefs = ref.watch(cardDisplayPrefsProvider(column.id));

    void setCfg(ColumnConfig next) {
      notifier.updateColumnConfig(column.id, next);
    }

    void setCardPrefs(CardDisplayPrefs next) {
      ref.read(cardDisplayPrefsProvider(column.id).notifier).state = next;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.drag_indicator,
                            size: 18, color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ColumnPalette.dotColor(column.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(column.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        )),
                  ),
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: const Color(0xFF94A3B8)),
                ]),
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ConfigGroup(label: 'Secciones del formulario', items: [
                    _ConfigItem(
                        'Descripci\u00f3n',
                        Icons.text_snippet_outlined,
                        cfg.showDescription,
                        (v) => setCfg(cfg.copyWith(showDescription: v))),
                    _ConfigItem(
                        'Campos personalizados',
                        Icons.text_fields,
                        cfg.showCustomFields,
                        (v) => setCfg(cfg.copyWith(showCustomFields: v))),
                    _ConfigItem(
                        'Comentarios',
                        Icons.chat_bubble_outline,
                        cfg.showComments,
                        (v) => setCfg(cfg.copyWith(showComments: v))),
                  ]),
                  const SizedBox(height: 14),
                  _ConfigGroup(label: 'Barra lateral del formulario', items: [
                    _ConfigItem(
                        'Asignar',
                        Icons.person_add_alt_1_outlined,
                        cfg.showAssign,
                        (v) => setCfg(cfg.copyWith(showAssign: v))),
                    _ConfigItem(
                        'Prioridad',
                        Icons.label_outline,
                        cfg.showPriority,
                        (v) => setCfg(cfg.copyWith(showPriority: v))),
                    _ConfigItem(
                        'Fecha de checkin',
                        Icons.calendar_today_outlined,
                        cfg.showCheckin,
                        (v) => setCfg(cfg.copyWith(showCheckin: v))),
                  ]),
                  const SizedBox(height: 14),
                  _ConfigGroup(label: 'Tarjeta (vista compacta)', items: [
                    _ConfigItem(
                        'Check completado',
                        Icons.check_circle_outline,
                        cardPrefs.showDone,
                        (v) => setCardPrefs(cardPrefs.copyWith(showDone: v))),
                    _ConfigItem(
                        'Descripci\u00f3n',
                        Icons.notes_outlined,
                        cardPrefs.showDescription,
                        (v) => setCardPrefs(cardPrefs.copyWith(showDescription: v))),
                    _ConfigItem(
                        'Qui\u00e9n complet\u00f3',
                        Icons.how_to_reg_outlined,
                        cardPrefs.showCleanedBy,
                        (v) => setCardPrefs(cardPrefs.copyWith(showCleanedBy: v))),
                    _ConfigItem(
                        'Prioridad',
                        Icons.flag_outlined,
                        cardPrefs.showPriority,
                        (v) => setCardPrefs(cardPrefs.copyWith(showPriority: v))),
                    _ConfigItem(
                        'Fecha de checkin',
                        Icons.login_outlined,
                        cardPrefs.showCheckin,
                        (v) => setCardPrefs(cardPrefs.copyWith(showCheckin: v))),
                    _ConfigItem(
                        'C\u00f3digo habitaci\u00f3n',
                        Icons.meeting_room_outlined,
                        cardPrefs.showRoomCode,
                        (v) => setCardPrefs(cardPrefs.copyWith(showRoomCode: v))),
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfigGroup extends StatelessWidget {
  const _ConfigGroup({required this.label, required this.items});
  final String label;
  final List<_ConfigItem> items;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Color(0xFF64748B),
              )),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Icon(items[i].icon,
                        size: 14, color: const Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(items[i].label,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF1F2937))),
                    ),
                    _Toggle(
                        value: items[i].value,
                        onChanged: items[i].onChanged),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfigItem {
  const _ConfigItem(this.label, this.icon, this.value, this.onChanged);
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
}
