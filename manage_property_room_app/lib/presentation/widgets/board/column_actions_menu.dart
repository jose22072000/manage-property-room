import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/notifiers/notifiers.dart';
import '../../../core/property_visuals.dart';
import '../../../core/responsive.dart';
import '../../../domain/domain.dart';
import '../shared/confirm_dialog.dart';

/// "Acciones de lista" — paridad con `src/components/board/ColumnActionsMenu.tsx`.
///
/// Muestra 9 acciones en un popover (desktop) / bottom sheet (mobile), cada
/// una con sub-secciones expandibles (copiar a propiedad, mover, color, …).
class ColumnActionsMenu extends ConsumerStatefulWidget {
  const ColumnActionsMenu({
    super.key,
    required this.column,
    required this.allColumns,
    required this.propertyId,
    required this.onClose,
    required this.onAddCard,
    required this.onOpenConfig,
    this.inSheet = false,
  });

  final BoardColumn column;
  final List<BoardColumn> allColumns;
  final String propertyId;
  final VoidCallback onClose;
  final VoidCallback onAddCard;
  final VoidCallback onOpenConfig;
  final bool inSheet;

  @override
  ConsumerState<ColumnActionsMenu> createState() => _ColumnActionsMenuState();
}

enum _Section { none, copyTo, description, movePos, moveCards, colors }

class _ColumnActionsMenuState extends ConsumerState<ColumnActionsMenu> {
  _Section _section = _Section.none;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.column.description);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _toggle(_Section s) {
    setState(() => _section = _section == s ? _Section.none : s);
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.column;
    final sortedCols = [...widget.allColumns]
      ..sort((a, b) => a.position.compareTo(b.position));
    final allProps = ref.watch(propertiesProvider).valueOrNull ?? const [];
    final otherProps = allProps.where((p) => p.id != widget.propertyId).toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: widget.inSheet
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onClose: widget.onClose),
          _MenuItem(
            label: 'Añadir tarjeta',
            icon: Icons.add,
            onTap: () { widget.onAddCard(); widget.onClose(); },
          ),

          _MenuItem(
            label: 'Copiar lista',
            icon: Icons.content_copy_outlined,
            onTap: () => _toggle(_Section.copyTo),
            expanded: _section == _Section.copyTo,
          ),
          if (_section == _Section.copyTo)
            _SubPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SubLabel('COPIAR A'),
                _SubButton(
                  label: 'Esta propiedad (copia)',
                  icon: Icons.home_outlined,
                  onTap: () {
                    ref.read(boardProvider(widget.propertyId).notifier)
                        .copyColumn(col.id);
                    widget.onClose();
                  },
                ),
                for (final p in otherProps)
                  _SubButton(
                    label: p.name,
                    icon: Icons.swap_horiz,
                    iconColor: const Color(0xFF60A5FA),
                    onTap: () {
                      ref.read(boardProvider(widget.propertyId).notifier)
                          .copyColumn(col.id, toPropertyId: p.id);
                      widget.onClose();
                    },
                  ),
              ],
            )),

          _MenuItem(
            label: 'Configurar lista',
            icon: Icons.tune,
            onTap: widget.onOpenConfig,
          ),

          _MenuItem(
            label: col.description.isEmpty ? 'Añadir descripción' : 'Editar descripción',
            icon: Icons.text_snippet_outlined,
            onTap: () => _toggle(_Section.description),
            expanded: _section == _Section.description,
          ),
          if (_section == _Section.description)
            _SubPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Para qué sirve esta lista…',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        ref.read(boardProvider(widget.propertyId).notifier)
                            .updateColumnDescription(col.id, _descCtrl.text.trim());
                        widget.onClose();
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => setState(() => _section = _Section.none),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ],
            )),

          _MenuItem(
            label: 'Mover lista',
            icon: Icons.swap_horiz,
            onTap: () => _toggle(_Section.movePos),
            expanded: _section == _Section.movePos,
          ),
          if (_section == _Section.movePos)
            _SubPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SubLabel('MOVER A POSICIÓN'),
                for (var i = 0; i < sortedCols.length; i++)
                  _SubButton(
                    label: '${i + 1}. ${sortedCols[i].title}',
                    highlighted: sortedCols[i].id == col.id,
                    onTap: () {
                      final fromIndex = sortedCols.indexWhere((c) => c.id == col.id);
                      if (fromIndex >= 0 && fromIndex != i) {
                        ref.read(boardProvider(widget.propertyId).notifier)
                            .moveColumn(fromIndex, i);
                      }
                      widget.onClose();
                    },
                  ),
              ],
            )),

          _MenuItem(
            label: 'Mover todas las tarjetas de esta lista',
            icon: Icons.move_to_inbox_outlined,
            onTap: () => _toggle(_Section.moveCards),
            expanded: _section == _Section.moveCards,
          ),
          if (_section == _Section.moveCards)
            _SubPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SubLabel('MOVER A LISTA'),
                for (final other in sortedCols.where((c) => c.id != col.id))
                  _SubButton(
                    label: other.title,
                    onTap: () {
                      ref.read(boardProvider(widget.propertyId).notifier)
                          .moveAllCards(col.id, other.id);
                      widget.onClose();
                    },
                  ),
              ],
            )),

          const _Divider(),

          _MenuItem(
            label: 'Cambiar color de lista',
            icon: Icons.palette_outlined,
            onTap: () => _toggle(_Section.colors),
            expanded: _section == _Section.colors,
          ),
          if (_section == _Section.colors)
            _SubPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ColumnColor.values.map((c) {
                    final selected = col.color == c;
                    return GestureDetector(
                      onTap: () {
                        ref.read(boardProvider(widget.propertyId).notifier)
                            .setColumnColor(col.id, c);
                        widget.onClose();
                      },
                      child: Container(
                        width: 40,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ColumnPalette.dotColor(c),
                          borderRadius: BorderRadius.circular(8),
                          border: selected
                              ? Border.all(color: const Color(0xFF334155), width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            )),

          _MenuItem(
            label: 'Archivar todas las tarjetas de esta lista',
            icon: Icons.inbox_outlined,
            onTap: () async {
              final ok = await ConfirmDialog.ask(
                context,
                message: '¿Archivar todas las tarjetas de "${col.title}"?',
                description: 'La lista se conserva, pero las tarjetas pasan al archivo.',
                confirmLabel: 'Archivar',
                danger: true,
              );
              if (ok) {
                await ref.read(boardProvider(widget.propertyId).notifier)
                    .archiveAllCardsIn(col.id);
              }
              widget.onClose();
            },
          ),

          _MenuItem(
            label: 'Archivar esta lista',
            icon: Icons.archive_outlined,
            danger: true,
            onTap: () async {
              final ok = await ConfirmDialog.ask(
                context,
                message: '¿Archivar lista "${col.title}"?',
                description: 'Se archivarán todas las tarjetas y la lista desaparecerá.',
                confirmLabel: 'Archivar',
                danger: true,
              );
              if (ok) {
                await ref.read(boardProvider(widget.propertyId).notifier)
                    .archiveColumn(col.id);
              }
              widget.onClose();
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Botón ⋯ que abre `ColumnActionsMenu` como popover (desktop) o sheet (mobile).
class ColumnMenuButton extends StatefulWidget {
  const ColumnMenuButton({
    super.key,
    required this.column,
    required this.allColumns,
    required this.propertyId,
    required this.onAddCard,
    required this.onOpenConfig,
  });

  final BoardColumn column;
  final List<BoardColumn> allColumns;
  final String propertyId;
  final VoidCallback onAddCard;
  final VoidCallback onOpenConfig;

  @override
  State<ColumnMenuButton> createState() => _ColumnMenuButtonState();
}

class _ColumnMenuButtonState extends State<ColumnMenuButton> {
  void _open() {
    if (isMobileSize(context)) {
    var _configAfter = false;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        enableDrag: false,
        isDismissible: true,
        useRootNavigator: true,
        barrierColor: Colors.black54,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetCtx) => SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: ColumnActionsMenu(
            column: widget.column,
            allColumns: widget.allColumns,
            propertyId: widget.propertyId,
            inSheet: true,
            onClose: () => Navigator.of(sheetCtx).pop(),
            onAddCard: widget.onAddCard,
            onOpenConfig: () {
              _configAfter = true;
              Navigator.of(sheetCtx).pop();
            },
          ),
        ),
      ).then((_) {
        if (_configAfter && mounted) widget.onOpenConfig();
      });
    } else {
      // Desktop / tablet: dropdown anchored below the button, right-aligned.
      final box = context.findRenderObject() as RenderBox?;
      final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
      if (box == null || overlay == null) return;
      final btnTopLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
      final btnBottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
      // Right-align menu to button's right edge, open downward.
      final menuWidth = 280.0;
      final menuLeft = (btnBottomRight.dx - menuWidth).clamp(8.0, overlay.size.width - menuWidth - 8);
      final menuTop = btnBottomRight.dy + 4;
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (dlgCtx) => Stack(children: [
          // Tap outside to close
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(dlgCtx).pop(),
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: menuLeft,
            top: menuTop,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: menuWidth,
                  maxHeight: overlay.size.height - menuTop - 16,
                ),
                child: SingleChildScrollView(
                  child: ColumnActionsMenu(
                    column: widget.column,
                    allColumns: widget.allColumns,
                    propertyId: widget.propertyId,
                    onClose: () => Navigator.of(dlgCtx).pop(),
                    onAddCard: widget.onAddCard,
                    onOpenConfig: () {
                      Navigator.of(dlgCtx).pop();
                      widget.onOpenConfig();
                    },
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _open,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.more_horiz, size: 18, color: Color(0xFF475569)),
        ),
      ),
    );
  }
}

// ─── interna piezas de UI ────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 6),
      child: Row(children: [
        const Expanded(
          child: Text('ACCIONES DE LISTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.6,
              )),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: onClose,
        ),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.expanded = false,
    this.danger = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool expanded;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF1F2937);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        color: expanded ? const Color(0xFFF1F5F9) : Colors.transparent,
        child: Row(children: [
          Icon(icon, size: 16, color: danger ? const Color(0xFFDC2626) : const Color(0xFF475569)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}

class _SubPanel extends StatelessWidget {
  const _SubPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          )),
    );
  }
}

class _SubButton extends StatelessWidget {
  const _SubButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.highlighted = false,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool highlighted;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFDBEAFE) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                  color: highlighted ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                )),
          ),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
    );
  }
}
