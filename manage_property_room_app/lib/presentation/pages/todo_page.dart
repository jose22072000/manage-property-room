import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/notifiers/notifiers.dart';
import '../../core/property_visuals.dart';
import '../../core/date_formatters.dart';
import '../../domain/domain.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(visiblePropertiesProvider);

    // Trigger board loads and check if any are still loading
    final anyLoading = props.any((p) => ref.watch(boardProvider(p.id)).isLoading);
    if (anyLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pending = ref.watch(todoPendingProvider);

    return pending.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF22C55E)),
                  SizedBox(height: 12),
                  Text('Todo al día 🎉', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('No hay tareas pendientes', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: props.length,
              itemBuilder: (_, i) {
                final prop = props[i];
                final cards = pending.where((c) => c.propertyId == prop.id).toList();
                if (cards.isEmpty) return const SizedBox.shrink();
                return _PropertySection(property: prop, cards: cards);
              },
            );
  }
}

class _PropertySection extends StatelessWidget {
  const _PropertySection({required this.property, required this.cards});

  final Property property;
  final List<BoardCard> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: propertyColor(property),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                property.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${cards.length}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        for (final card in cards) _TodoCardTile(card: card, property: property),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TodoCardTile extends ConsumerWidget {
  const _TodoCardTile({required this.card, required this.property});

  final BoardCard card;
  final Property property;

  bool get _isUrgent =>
      card.priority == CardPriority.high || isCheckinTomorrow(card.checkinDate);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showDetail(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isUrgent ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (card.roomCode.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  card.roomCode,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ),
            Expanded(
              child: Text(
                card.title,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isUrgent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'URGENTE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                ),
              ),
            ],
            if (card.checkinDate != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.login_outlined, size: 13, color: _isUrgent ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
              const SizedBox(width: 2),
              Text(
                formatRelativeDate(card.checkinDate!),
                style: TextStyle(
                  fontSize: 11,
                  color: _isUrgent ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    // Find the column name for this card
    final boardState = ref.read(boardProvider(property.id)).valueOrNull;
    final columnTitle = boardState?.columns
            .where((c) => c.id == card.columnId)
            .map((c) => c.title)
            .firstOrNull ??
        '';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      enableDrag: false,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => _TodoDetailSheet(
        card: card,
        property: property,
        columnTitle: columnTitle,
        onGoToBoard: () {
          Navigator.of(sheetCtx, rootNavigator: true).pop();
          context.go('/properties/${property.id}/board', extra: card.id);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Todo detail sheet
// ─────────────────────────────────────────

class _TodoDetailSheet extends ConsumerWidget {
  const _TodoDetailSheet({
    required this.card,
    required this.property,
    required this.columnTitle,
    required this.onGoToBoard,
  });

  final BoardCard card;
  final Property property;
  final String columnTitle;
  final VoidCallback onGoToBoard;

  bool get _isUrgent =>
      card.priority == CardPriority.high || isCheckinTomorrow(card.checkinDate);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: propertyColor(property),
                  ),
                ),
                Expanded(
                  child: Text(
                    property.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Room code badge
            if (card.roomCode.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    card.roomCode,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ),
            if (card.roomCode.isNotEmpty) const SizedBox(height: 8),
            // Title
            Text(
              card.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if (card.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                card.description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),
            // Meta chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (columnTitle.isNotEmpty)
                  _MetaChip(icon: Icons.view_column_outlined, label: columnTitle, color: const Color(0xFF2563EB)),
                if (_isUrgent)
                  _MetaChip(icon: Icons.warning_amber_outlined, label: 'URGENTE', color: const Color(0xFFEF4444)),
                if (card.priority != CardPriority.normal)
                  _MetaChip(
                    icon: Icons.flag_outlined,
                    label: card.priority == CardPriority.high ? 'Alta prioridad' : 'Baja prioridad',
                    color: card.priority == CardPriority.high ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                  ),
                if (card.checkinDate != null)
                  _MetaChip(
                    icon: Icons.login_outlined,
                    label: formatRelativeDate(card.checkinDate!),
                    color: _isUrgent ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Completar button
            OutlinedButton.icon(
              onPressed: () async {
                final user = ref.read(currentUserProvider).valueOrNull;
                await ref
                    .read(boardProvider(property.id).notifier)
                    .toggleCardDone(card.id, cleanedBy: user?.initials ?? '');
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Completar', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF22C55E),
                side: const BorderSide(color: Color(0xFF22C55E)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            // Go to board button
            ElevatedButton.icon(
              onPressed: onGoToBoard,
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text('Ir al tablero', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
