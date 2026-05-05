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
    Widget listView = _buildCardList(cards, user);

    if (!widget.isMobile) {
      listView = DragTarget<BoardCard>(
        builder: (_, candidateData, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? ColumnPalette.headerBg(col.color).withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: listView,
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
              if (canManage) ...[
                const SizedBox(width: 4),
                _ColumnMenu(
                  column: col,
                  propertyId: widget.propertyId,
                  allColumns: widget.allColumns,
                  onRename: () => setState(() => _isRenaming = true),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Cards list
        Expanded(child: listView),
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
      return ListView.builder(
        itemCount: cards.length,
        padding: EdgeInsets.zero,
        itemBuilder: (_, i) => _buildCardItem(cards[i], user),
      );
    }

    // Desktop: LongPressDraggable cards
    return ListView.builder(
      itemCount: cards.length,
      padding: EdgeInsets.zero,
      itemBuilder: (_, i) {
        final card = cards[i];
        return LongPressDraggable<BoardCard>(
          data: card,
          delay: const Duration(milliseconds: 300),
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 240,
              child: Opacity(
                opacity: 0.9,
                child: CardItemWidget(card: card, user: user, propertyId: widget.propertyId, isMobile: false),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: _buildCardItem(card, user)),
          child: _buildCardItem(card, user),
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
    if (Responsive.isTabletOrDesktop(context)) {
      showDialog(
        context: context,
        builder: (_) => CardDetailSheet(
          card: card,
          column: widget.column,
          allColumns: widget.allColumns,
          propertyId: widget.propertyId,
          user: widget.user,
        ),
      );
    } else {
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
//  Column context menu
// ─────────────────────────────────────────

class _ColumnMenu extends ConsumerWidget {
  const _ColumnMenu({
    required this.column,
    required this.propertyId,
    required this.allColumns,
    required this.onRename,
  });

  final BoardColumn column;
  final String propertyId;
  final List<BoardColumn> allColumns;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF94A3B8)),
      tooltip: 'Opciones de lista',
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
        const PopupMenuItem(value: 'color', child: Text('Cambiar color')),
        const PopupMenuItem(value: 'archive', child: Text('Archivar lista')),
      ],
      onSelected: (action) {
        switch (action) {
          case 'rename':
            onRename();
            break;
          case 'color':
            _showColorPicker(context, ref);
            break;
          case 'archive':
            _archiveColumn(context, ref);
            break;
        }
      },
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Color de la lista', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ColumnColor.values.map((c) {
                return GestureDetector(
                  onTap: () {
                    ref.read(boardProvider(propertyId).notifier).setColumnColor(column.id, c);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ColumnPalette.dotColor(c),
                      shape: BoxShape.circle,
                      border: column.color == c ? Border.all(color: Colors.black87, width: 2.5) : null,
                    ),
                    child: column.color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _archiveColumn(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Archivar lista?'),
        content: const Text('Se archivarán todas las tarjetas de esta lista.'),
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
    if (confirmed == true) {
      ref.read(boardProvider(propertyId).notifier).archiveColumn(column.id);
    }
  }
}
