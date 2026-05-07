import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/notifiers/notifiers.dart';
import '../../../core/property_visuals.dart';
import '../../../domain/domain.dart';
import '../../../permissions/policy.dart';
import 'card_item_widget.dart';
import 'card_detail_sheet.dart';
import 'add_card_inline.dart';
import 'column_actions_menu.dart';

class BoardColumnWidget extends ConsumerStatefulWidget {
  const BoardColumnWidget({
    super.key,
    required this.column,
    required this.cards,
    required this.propertyId,
    required this.allColumns,
    required this.user,
    required this.isMobile,
  });

  final BoardColumn column;
  final List<BoardCard> cards;
  final String propertyId;
  final List<BoardColumn> allColumns;
  final AppUser? user;
  final bool isMobile;

  @override
  ConsumerState<BoardColumnWidget> createState() => _BoardColumnWidgetState();
}

class _BoardColumnWidgetState extends ConsumerState<BoardColumnWidget> {
  bool _addingCard = false;
  bool _isRenaming = false;
  late final TextEditingController _renameCtrl;

  @override
  void initState() {
    super.initState();
    _renameCtrl = TextEditingController(text: widget.column.title);
  }

  @override
  void dispose() {
    _renameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.column;
    final cards = widget.cards;
    final user = widget.user;
    final canManage = user != null && Policy.canBoard(user, BoardAction.renameColumn);
    final canAddCard = user != null && Policy.canBoard(user, BoardAction.addCard);

    // On desktop: drop zones between cards handle both reorder and cross-column moves
    final Widget listView = _buildCardList(cards, user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Column header
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: ColumnPalette.headerBg(col.color),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            foregroundDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: ColumnPalette.borderColor(col.color), width: 3)),
            ),
            child: Row(
              children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ColumnPalette.dotColor(col.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _isRenaming
                    ? TextField(
                        controller: _renameCtrl,
                        autofocus: true,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _commitRename(),
                        onEditingComplete: _commitRename,
                      )
                    : GestureDetector(
                        onDoubleTap: canManage ? () => setState(() => _isRenaming = true) : null,
                        child: Text(
                          col.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ColumnPalette.iconColor(col.color),
                          ),
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: ColumnPalette.borderColor(col.color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${cards.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ColumnPalette.iconColor(col.color)),
                ),
              ),
              if (canAddCard) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(() => _addingCard = true),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.add, size: 18, color: ColumnPalette.iconColor(col.color)),
                  ),
                ),
              ],
              if (canManage) ...[
                const SizedBox(width: 2),
                ColumnMenuButton(
                  column: col,
                  allColumns: widget.allColumns,
                  propertyId: widget.propertyId,
                  onAddCard: () => setState(() => _addingCard = true),
                  onOpenConfig: () => _openColumnConfig(col),
                ),
              ],
            ],
          ),
          ),
        ),
        const SizedBox(height: 8),
        // Cards list — slight gray bg so white cards visibly stand out
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored left accent strip (replaces non-uniform border)
                Container(width: 3, color: ColumnPalette.borderColor(col.color)),
                Expanded(child: listView),
              ],
            ),
          ),
        ),
        // Add card button/form
        if (canAddCard) ...[
          const SizedBox(height: 4),
          if (_addingCard)
            AddCardInline(
              onAdd: (title, roomCode) async {
                await ref.read(boardProvider(widget.propertyId).notifier).addCard(
                      columnId: col.id,
                      title: title,
                      roomCode: roomCode,
                    );
                setState(() => _addingCard = false);
              },
              onCancel: () => setState(() => _addingCard = false),
            )
          else
            TextButton.icon(
              onPressed: () => setState(() => _addingCard = true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir tarjeta', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
            ),
        ],
      ],
    );
  }

  Widget _buildCardList(List<BoardCard> cards, AppUser? user) {
    final notifier = ref.read(boardProvider(widget.propertyId).notifier);
    final colId = widget.column.id;

    void handleDrop(BoardCard droppedCard, int insertIndex) {
      if (droppedCard.columnId == colId) {
        final oldIndex = cards.indexWhere((c) => c.id == droppedCard.id);
        if (oldIndex == -1 || insertIndex == oldIndex || insertIndex == oldIndex + 1) return;
        notifier.reorderCardsInColumn(colId, oldIndex, insertIndex);
      } else {
        notifier.moveCard(droppedCard.id, colId, insertIndex);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      children: [
        for (int i = 0; i < cards.length; i++)
          _DndCard(
            key: ValueKey(cards[i].id),
            card: cards[i],
            index: i,
            user: user,
            propertyId: widget.propertyId,
            allColumns: widget.allColumns,
            isMobile: widget.isMobile,
            columnConfig: widget.column.config,
            onTap: () => _openCardDetail(cards[i]),
            onDrop: handleDrop,
          ),
        _TrailingDropZone(
          onAccept: (card) => handleDrop(card, cards.length),
        ),
      ],
    );
  }



  void _openCardDetail(BoardCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CardDetailSheet(
        card: card,
        column: widget.column,
        allColumns: widget.allColumns,
        propertyId: widget.propertyId,
        user: widget.user,
      ),
    );
  }

  void _openColumnConfig(BoardColumn col) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: _ColumnConfigSheet(
          column: col,
          propertyId: widget.propertyId,
        ),
      ),
    );
  }

  void _commitRename() {
    final newTitle = _renameCtrl.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.column.title) {
      ref.read(boardProvider(widget.propertyId).notifier).renameColumn(widget.column.id, newTitle);
    }
    setState(() => _isRenaming = false);
  }
}

// ─────────────────────────────────────────
//  Column config bottom sheet (from board menu)
// ─────────────────────────────────────────

class _ColumnConfigSheet extends ConsumerWidget {
  const _ColumnConfigSheet({required this.column, required this.propertyId});

  final BoardColumn column;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the board so config changes reflect live
    final boardAsync = ref.watch(boardProvider(propertyId));
    final col = boardAsync.valueOrNull?.columns
            .where((c) => c.id == column.id)
            .firstOrNull ??
        column;
    final cfg = col.config;

    void setCfg(ColumnConfig next) {
      ref.read(boardProvider(propertyId).notifier).updateColumnConfig(col.id, next);
    }

    final cardPrefs = cfg;
    void setCardPrefs(ColumnConfig next) => setCfg(next);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColumnPalette.dotColor(col.color),
              ),
            ),
            Expanded(
              child: Text(
                'Configurar: ${col.title}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildGroup(context, 'Secciones del formulario', [
            _buildToggle('Descripción', Icons.text_snippet_outlined,
                cfg.showDescription, (v) => setCfg(cfg.copyWith(showDescription: v))),
            _buildToggle('Campos personalizados', Icons.text_fields,
                cfg.showCustomFields, (v) => setCfg(cfg.copyWith(showCustomFields: v))),
            _buildToggle('Comentarios', Icons.chat_bubble_outline,
                cfg.showComments, (v) => setCfg(cfg.copyWith(showComments: v))),
          ]),
          const SizedBox(height: 14),
          _buildGroup(context, 'Barra lateral del formulario', [
            _buildToggle('Asignar', Icons.person_add_alt_1_outlined,
                cfg.showAssign, (v) => setCfg(cfg.copyWith(showAssign: v))),
            _buildToggle('Prioridad', Icons.label_outline,
                cfg.showPriority, (v) => setCfg(cfg.copyWith(showPriority: v))),
            _buildToggle('Fecha de checkin', Icons.calendar_today_outlined,
                cfg.showCheckin, (v) => setCfg(cfg.copyWith(showCheckin: v))),
          ]),
          const SizedBox(height: 14),
          _buildGroup(context, 'Tarjeta (vista compacta)', [
            _buildToggle('Check completado', Icons.check_circle_outline,
                cardPrefs.cardShowDone, (v) => setCardPrefs(cardPrefs.copyWith(cardShowDone: v))),
            _buildToggle('Descripción', Icons.notes_outlined,
                cardPrefs.cardShowDescription, (v) => setCardPrefs(cardPrefs.copyWith(cardShowDescription: v))),
            _buildToggle('Quién completó', Icons.how_to_reg_outlined,
                cardPrefs.cardShowCleanedBy, (v) => setCardPrefs(cardPrefs.copyWith(cardShowCleanedBy: v))),
            _buildToggle('Prioridad', Icons.flag_outlined,
                cardPrefs.cardShowPriority, (v) => setCardPrefs(cardPrefs.copyWith(cardShowPriority: v))),
            _buildToggle('Borde de prioridad', Icons.border_color_outlined,
                cardPrefs.cardShowPriorityBorder, (v) => setCardPrefs(cardPrefs.copyWith(cardShowPriorityBorder: v))),
            _buildToggle('Fecha de checkin', Icons.login_outlined,
                cardPrefs.cardShowCheckin, (v) => setCardPrefs(cardPrefs.copyWith(cardShowCheckin: v))),
            _buildToggle('Código de habitación', Icons.meeting_room_outlined,
                cardPrefs.cardShowRoomCode, (v) => setCardPrefs(cardPrefs.copyWith(cardShowRoomCode: v))),
            _buildToggle('Miniatura de imagen', Icons.image_outlined,
                cardPrefs.cardShowImage, (v) => setCardPrefs(cardPrefs.copyWith(cardShowImage: v))),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String label, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                items[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF2563EB),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
//  DnD card — draggable + full-card drop target
// ─────────────────────────────────────────

enum _DropEdge { top, bottom }

class _DndCard extends StatefulWidget {
  const _DndCard({
    super.key,
    required this.card,
    required this.index,
    required this.user,
    required this.propertyId,
    required this.allColumns,
    required this.onTap,
    required this.onDrop,
    required this.isMobile,
    required this.columnConfig,
  });

  final BoardCard card;
  final int index;
  final AppUser? user;
  final String propertyId;
  final List<BoardColumn> allColumns;
  final VoidCallback onTap;
  final void Function(BoardCard card, int insertIndex) onDrop;
  final bool isMobile;
  final ColumnConfig columnConfig;

  @override
  State<_DndCard> createState() => _DndCardState();
}

class _DndCardState extends State<_DndCard> {
  _DropEdge? _dropEdge;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final cardWidget = CardItemWidget(
      card: card,
      user: widget.user,
      propertyId: widget.propertyId,
      isMobile: widget.isMobile,
      onTap: widget.onTap,
      allColumns: widget.allColumns,
      columnConfig: widget.columnConfig,
    );
    final feedbackWidth = widget.isMobile ? 300.0 : 230.0;
    final feedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: feedbackWidth,
        child: Opacity(
          opacity: 0.9,
          child: CardItemWidget(
            card: card,
            user: widget.user,
            propertyId: widget.propertyId,
            isMobile: widget.isMobile,
            allColumns: widget.allColumns,
            columnConfig: widget.columnConfig,
          ),
        ),
      ),
    );

    // On mobile use LongPressDraggable (tap-friendly), on desktop use Draggable.
    final draggableChild = widget.isMobile
        ? LongPressDraggable<BoardCard>(
            data: card,
            feedback: feedback,
            childWhenDragging: Opacity(opacity: 0.3, child: cardWidget),
            child: cardWidget,
          )
        : MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Draggable<BoardCard>(
              data: card,
              feedback: feedback,
              childWhenDragging: Opacity(opacity: 0.3, child: cardWidget),
              child: cardWidget,
            ),
          );

    // Single DragTarget covering the whole card. Edge (top/bottom) is computed
    // from the cursor Y position vs the card's vertical midpoint in onMove, then
    // stored in _dropEdge. onAcceptWithDetails reads _dropEdge to get the correct
    // insertIndex. One target = one onAccept = no duplicate calls.
    return DragTarget<BoardCard>(
      onWillAcceptWithDetails: (d) => d.data.id != card.id,
      onMove: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final mid = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
        final edge = d.offset.dy < mid ? _DropEdge.top : _DropEdge.bottom;
        if (_dropEdge != edge) setState(() => _dropEdge = edge);
      },
      // Do NOT reset _dropEdge on leave — the value must survive until
      // onAcceptWithDetails fires. The indicator hides because candidates
      // becomes empty, but the edge is preserved for the accept callback.
      onLeave: (_) => setState(() {}),
      onAcceptWithDetails: (d) {
        final insertIndex =
            (_dropEdge ?? _DropEdge.bottom) == _DropEdge.top
                ? widget.index
                : widget.index + 1;
        widget.onDrop(d.data, insertIndex);
        setState(() => _dropEdge = null);
      },
      builder: (_, candidates, __) {
        final isOver = candidates.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                height: isOver && _dropEdge == _DropEdge.top ? 4 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              draggableChild,
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                height: isOver && _dropEdge == _DropEdge.bottom ? 4 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Trailing drop zone after the last card (or for empty columns)
class _TrailingDropZone extends StatefulWidget {
  const _TrailingDropZone({required this.onAccept});
  final void Function(BoardCard) onAccept;

  @override
  State<_TrailingDropZone> createState() => _TrailingDropZoneState();
}

class _TrailingDropZoneState extends State<_TrailingDropZone> {
  @override
  Widget build(BuildContext context) {
    return DragTarget<BoardCard>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => widget.onAccept(d.data),
      // Always at least 56px so the user doesn't have to scroll to the very
      // bottom of the list to drop at the last position.
      builder: (_, candidates, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: candidates.isNotEmpty ? 64 : 56,
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? const Color(0xFF2563EB).withValues(alpha: 0.15)
              : null,
          borderRadius: BorderRadius.circular(6),
          border: candidates.isNotEmpty
              ? Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
      ),
    );
  }
}
