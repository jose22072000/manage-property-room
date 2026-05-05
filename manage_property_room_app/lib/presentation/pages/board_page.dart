import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/notifiers/notifiers.dart';
import '../../core/property_visuals.dart';
import '../../core/responsive.dart';
import '../../domain/domain.dart';
import '../../permissions/policy.dart';
import '../widgets/board/board_column_widget.dart';
import '../widgets/board/add_column_sheet.dart';

class BoardPage extends ConsumerWidget {
  const BoardPage({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(boardProvider(propertyId));
    final propsAsync = ref.watch(propertiesProvider);
    final userAsync = ref.watch(currentUserProvider);

    final prop = propsAsync.valueOrNull?.firstWhere(
      (p) => p.id == propertyId,
      orElse: () => Property(id: propertyId, code: '?', name: propertyId, totalRooms: 0),
    );

    final user = userAsync.valueOrNull;
    final isMobile = Responsive.isMobile(context);
    final canAddColumn = user != null && Policy.canBoard(user, BoardAction.addColumn);

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
                    Text(prop?.name ?? propertyId,
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
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (state) {
              if (state.columns.isEmpty) {
                return _EmptyBoard(
                  canAdd: canAddColumn,
                  onAdd: () => _showAddColumn(context, ref),
                );
              }
              if (isMobile) {
                return _MobileBoard(state: state, propertyId: propertyId, user: user);
              }
              return _DesktopBoard(state: state, propertyId: propertyId, user: user);
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
      builder: (_) => AddColumnSheet(
        propertyId: propertyId,
        onAdd: (title, color) {
          ref.read(boardProvider(propertyId).notifier).addColumn(title, color);
          Navigator.pop(context);
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

class _DesktopBoard extends ConsumerWidget {
  const _DesktopBoard({required this.state, required this.propertyId, required this.user});

  final BoardState state;
  final String propertyId;
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: state.columns.length,
      separatorBuilder: (context, idx) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final col = state.columns[i];
        return SizedBox(
          width: 280,
          child: BoardColumnWidget(
            column: col,
            cards: state.cardsByColumn[col.id] ?? [],
            propertyId: propertyId,
            allColumns: state.columns,
            user: user,
            isMobile: false,
          ),
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
