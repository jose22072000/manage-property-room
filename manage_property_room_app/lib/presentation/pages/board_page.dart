import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/notifiers/notifiers.dart';
import '../../core/errors.dart';
import '../../core/property_visuals.dart';
import '../../core/responsive.dart';
import '../../domain/domain.dart';
import '../../permissions/policy.dart';
import '../widgets/board/board_column_widget.dart';
import '../widgets/board/add_column_sheet.dart';
import '../widgets/board/card_detail_sheet.dart';

class BoardPage extends ConsumerStatefulWidget {
  const BoardPage({super.key, required this.propertyId, this.highlightCardId});

  final String propertyId;
  final String? highlightCardId;

  @override
  ConsumerState<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends ConsumerState<BoardPage> {
  bool _cardOpened = false;

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(boardProvider(widget.propertyId));
    final propsAsync = ref.watch(propertiesProvider);
    final userAsync = ref.watch(currentUserProvider);

    final prop = propsAsync.valueOrNull?.firstWhere(
      (p) => p.id == widget.propertyId,
      orElse: () => Property(id: widget.propertyId, code: '?', name: widget.propertyId, totalRooms: 0),
    );

    final user = userAsync.valueOrNull;
    final isMobile = Responsive.isMobile(context);
    final canAddColumn = user != null && Policy.canBoard(user, BoardAction.addColumn);

    // Open card detail if navigated here with a highlight card ID
    if (!_cardOpened && widget.highlightCardId != null) {
      boardAsync.whenData((board) {
        BoardCard? target;
        BoardColumn? targetColumn;
        for (final col in board.columns) {
          final cards = board.cardsByColumn[col.id] ?? [];
          for (final c in cards) {
            if (c.id == widget.highlightCardId) {
              target = c;
              targetColumn = col;
              break;
            }
          }
          if (target != null) break;
        }
        if (target != null && targetColumn != null) {
          _cardOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              enableDrag: false,
              useRootNavigator: true,
              barrierColor: Colors.black54,
              builder: (_) => CardDetailSheet(
                card: target!,
                column: targetColumn!,
                allColumns: board.columns,
                propertyId: widget.propertyId,
                user: user,
              ),
            );
          });
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sub-header row (matches React board header) ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              if (!isMobile) ...[
                GestureDetector(
                  onTap: () => context.go('/'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: Color(0xFF6B7280)),
                      SizedBox(width: 4),
                      Text('Propiedades',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('/', style: TextStyle(color: Color(0xFFD1D5DB))),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prop?.name ?? widget.propertyId,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    boardAsync.maybeWhen(
                      data: (state) => state.totalCards > 0
                          ? Text('${state.doneCards} de ${state.totalCards} tarjetas completadas',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              if (canAddColumn)
                TextButton.icon(
                  onPressed: () => _showAddColumn(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Lista', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
        ),
        // ── Board content ──
        Expanded(
          child: boardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyError(e))),
            data: (state) {
              if (state.columns.isEmpty) {
                return _EmptyBoard(
                  canAdd: canAddColumn,
                  onAdd: () => _showAddColumn(context, ref),
                );
              }
              if (isMobile) {
                return _MobileBoard(state: state, propertyId: widget.propertyId, user: user);
              }
              return _DesktopBoard(state: state, propertyId: widget.propertyId, user: user);
            },
          ),
        ),
      ],
    );
  }

  void _showAddColumn(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (sheetCtx) => AddColumnSheet(
        propertyId: widget.propertyId,
        onAdd: (title, color) {
          ref.read(boardProvider(widget.propertyId).notifier).addColumn(title, color);
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Mobile board — PageView (one column at a time)
// ─────────────────────────────────────────

class _MobileBoard extends StatefulWidget {
  const _MobileBoard({required this.state, required this.propertyId, required this.user});

  final BoardState state;
  final String propertyId;
  final AppUser? user;

  @override
  State<_MobileBoard> createState() => _MobileBoardState();
}

class _MobileBoardState extends State<_MobileBoard> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final columns = widget.state.columns;

    return Column(
      children: [
        // Column indicator dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < columns.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _page
                        ? ColumnPalette.dotColor(columns[i].color)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
            ],
          ),
        ),
        // Column title bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                columns[_page].title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ColumnPalette.iconColor(columns[_page].color),
                ),
              ),
              Text(
                '${widget.state.cardsByColumn[columns[_page].id]?.length ?? 0} tarjetas',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // PageView of columns
        Expanded(
          child: PageView.builder(
            itemCount: columns.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final col = columns[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: BoardColumnWidget(
                  column: col,
                  cards: widget.state.cardsByColumn[col.id] ?? [],
                  propertyId: widget.propertyId,
                  allColumns: columns,
                  user: widget.user,
                  isMobile: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  Desktop/Tablet board — horizontal scroll with drag & drop
// ─────────────────────────────────────────

class _DesktopBoard extends ConsumerStatefulWidget {
  const _DesktopBoard({required this.state, required this.propertyId, required this.user});

  final BoardState state;
  final String propertyId;
  final AppUser? user;

  @override
  ConsumerState<_DesktopBoard> createState() => _DesktopBoardState();
}

class _DesktopBoardState extends ConsumerState<_DesktopBoard> {
  // Index of column that is currently being hovered by a dragged column
  int? _hoverTargetIndex;

  @override
  Widget build(BuildContext context) {
    final columns = widget.state.columns;
    final canReorder = widget.user != null &&
        Policy.canBoard(widget.user!, BoardAction.moveColumn);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns.length; i++)
              _buildColumnSlot(columns, i, canReorder),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnSlot(List<BoardColumn> columns, int index, bool canReorder) {
    final col = columns[index];
    final isHoverTarget = _hoverTargetIndex == index;

    final columnWidget = Padding(
      key: ValueKey(col.id),
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 280,
        child: BoardColumnWidget(
          column: col,
          cards: widget.state.cardsByColumn[col.id] ?? [],
          propertyId: widget.propertyId,
          allColumns: columns,
          user: widget.user,
          isMobile: false,
        ),
      ),
    );

    if (!canReorder) return columnWidget;

    return DragTarget<BoardColumn>(
      onWillAcceptWithDetails: (details) {
        if (details.data.id != col.id) {
          setState(() => _hoverTargetIndex = index);
        }
        return details.data.id != col.id;
      },
      onLeave: (_) => setState(() {
        if (_hoverTargetIndex == index) _hoverTargetIndex = null;
      }),
      onAcceptWithDetails: (details) {
        setState(() => _hoverTargetIndex = null);
        final fromIndex = columns.indexWhere((c) => c.id == details.data.id);
        if (fromIndex == -1 || fromIndex == index) return;
        ref.read(boardProvider(widget.propertyId).notifier)
            .reorderColumns(fromIndex, index);
      },
      builder: (context, candidates, rejected) {
        return Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: isHoverTarget
                    ? Border.all(color: const Color(0xFF2563EB), width: 2)
                    : null,
              ),
              child: Opacity(
                opacity: candidates.isNotEmpty ? 0.7 : 1.0,
                child: Draggable<BoardColumn>(
                  data: col,
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 280,
                      height: 80,
                      child: Opacity(
                        opacity: 0.85,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2563EB)),
                          ),
                          child: Text(col.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 280,
                      child: Opacity(
                        opacity: 0.3,
                        child: BoardColumnWidget(
                          column: col,
                          cards: widget.state.cardsByColumn[col.id] ?? [],
                          propertyId: widget.propertyId,
                          allColumns: columns,
                          user: widget.user,
                          isMobile: false,
                        ),
                      ),
                    ),
                  ),
                  child: columnWidget,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  Empty board state
// ─────────────────────────────────────────

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.canAdd, required this.onAdd});

  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_kanban_outlined, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text('Sin listas todavía', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Crea la primera lista para empezar', style: TextStyle(color: Color(0xFF64748B))),
          if (canAdd) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Añadir lista'),
            ),
          ],
        ],
      ),
    );
  }
}
