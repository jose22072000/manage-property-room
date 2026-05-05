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
    final pending = ref.watch(todoPendingProvider);
    final props = ref.watch(visiblePropertiesProvider);

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

class _TodoCardTile extends StatelessWidget {
  const _TodoCardTile({required this.card, required this.property});

  final BoardCard card;
  final Property property;

  bool get _isUrgent =>
      card.priority == CardPriority.high || isCheckinTomorrow(card.checkinDate);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/properties/${property.id}/board'),
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
          ],
        ),
      ),
    );
  }
}
