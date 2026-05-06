import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/notifiers/notifiers.dart';
import '../../../core/property_visuals.dart';
import '../../../core/responsive.dart';
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

    // On desktop/tablet: DragTarget for receiving dragged cards
    final cardBody = _buildCardList(cards, user); // capture BEFORE reassignment
    Widget listView = cardBody;

    if (!widget.isMobile) {
      listView = DragTarget<BoardCard>(
        builder: (_, candidateData, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? ColumnPalette.headerBg(col.color).withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: cardBody, // use captured original, never the DragTarget itself
        ),
        onWillAcceptWithDetails: (details) => details.data.columnId != col.id,
        onAcceptWithDetails: (details) {
          final card = details.data;
          ref.read(boardProvider(widget.propertyId).notifier).moveCard(
                card.id,
                col.id,
                cards.length,
              );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Column header
        Container(
          decoration: BoxDecoration(
            color: ColumnPalette.headerBg(col.color),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: ColumnPalette.borderColor(col.color), width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        const SizedBox(height: 8),
        // Cards list — white background with visible left border matching column color
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: ColumnPalette.borderColor(col.color),
                  width: 3,
                ),
                top: BorderSide(color: const Color(0xFFE2E8F0)),
                right: BorderSide(color: const Color(0xFFE2E8F0)),
                bottom: BorderSide(color: const Color(0xFFE2E8F0)),
              ),
            ),
            child: listView,
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
    if (widget.isMobile) {
      // Mobile: plain list with move buttons; no drag-and-drop
      return ListView.builder(
        itemCount: cards.length,
        padding: EdgeInsets.zero,
        itemBuilder: (_, i) => _buildCardItem(cards[i], user),
      );
    }

    // Desktop: ReorderableListView for within-column reorder.
    // Each card also has a Draggable for between-column moves.
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: false,
      padding: EdgeInsets.zero,
      proxyDecorator: (child, _, animation) => Material(
        color: Colors.transparent,
        elevation: 8,
        child: child,
      ),
      onReorder: (old, neu) {
        ref
            .read(boardProvider(widget.propertyId).notifier)
            .reorderCardsInColumn(widget.column.id, old, neu);
      },
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final card = cards[i];
        final cardWidget = CardItemWidget(
          card: card,
          user: user,
          propertyId: widget.propertyId,
          isMobile: false,
          onTap: () => _openCardDetail(card),
          allColumns: widget.allColumns,
        );
        final feedback = Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 240,
            child: Opacity(opacity: 0.9, child: cardWidget),
          ),
        );
        final draggingPlaceholder = Opacity(
          opacity: 0.3,
          child: Padding(padding: const EdgeInsets.only(bottom: 8), child: cardWidget),
        );

        return KeyedSubtree(
          key: ValueKey(card.id),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle for within-column reorder
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8, left: 2),
                child: ReorderableDragStartListener(
                  index: i,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                      child: const Icon(Icons.drag_handle,
                          size: 15, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
              // Card body — also Draggable for between-column moves
              Expanded(
                child: Draggable<BoardCard>(
                  data: card,
                  feedback: feedback,
                  childWhenDragging: draggingPlaceholder,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 4),
                    child: cardWidget,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardItem(BoardCard card, AppUser? user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardItemWidget(
        card: card,
        user: user,
        propertyId: widget.propertyId,
        isMobile: widget.isMobile,
        onTap: () => _openCardDetail(card),
        allColumns: widget.allColumns,
      ),
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

    final cardPrefs = ref.watch(cardDisplayPrefsProvider(col.id));
    void setCardPrefs(CardDisplayPrefs next) {
      ref.read(cardDisplayPrefsProvider(col.id).notifier).state = next;
    }

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
                cardPrefs.showDone, (v) => setCardPrefs(cardPrefs.copyWith(showDone: v))),
            _buildToggle('Descripción', Icons.notes_outlined,
                cardPrefs.showDescription, (v) => setCardPrefs(cardPrefs.copyWith(showDescription: v))),
            _buildToggle('Quién completó', Icons.how_to_reg_outlined,
                cardPrefs.showCleanedBy, (v) => setCardPrefs(cardPrefs.copyWith(showCleanedBy: v))),
            _buildToggle('Prioridad', Icons.flag_outlined,
                cardPrefs.showPriority, (v) => setCardPrefs(cardPrefs.copyWith(showPriority: v))),
            _buildToggle('Fecha de checkin', Icons.login_outlined,
                cardPrefs.showCheckin, (v) => setCardPrefs(cardPrefs.copyWith(showCheckin: v))),
            _buildToggle('Código de habitación', Icons.meeting_room_outlined,
                cardPrefs.showRoomCode, (v) => setCardPrefs(cardPrefs.copyWith(showRoomCode: v))),
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

