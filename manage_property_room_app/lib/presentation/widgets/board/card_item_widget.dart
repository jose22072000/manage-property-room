import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/notifiers/notifiers.dart';
import '../../../core/property_visuals.dart';
import '../../../core/date_formatters.dart';
import '../../../domain/domain.dart';
import '../../../permissions/policy.dart';

class CardItemWidget extends ConsumerWidget {
  const CardItemWidget({
    super.key,
    required this.card,
    required this.user,
    required this.propertyId,
    required this.isMobile,
    this.onTap,
    this.allColumns = const [],
  });

  final BoardCard card;
  final AppUser? user;
  final String propertyId;
  final bool isMobile;
  final VoidCallback? onTap;
  final List<BoardColumn> allColumns;

  bool get _isUrgent =>
      card.priority == CardPriority.high || isCheckinTomorrow(card.checkinDate);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canToggle = user != null && Policy.canCard(user!, card, CardAction.toggleDone);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: _isUrgent ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
              width: _isUrgent ? 3 : 1,
            ),
            top: const BorderSide(color: Color(0xFFE2E8F0)),
            right: const BorderSide(color: Color(0xFFE2E8F0)),
            bottom: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Checkbox / done toggle
                if (canToggle)
                  GestureDetector(
                    onTap: () => ref
                        .read(boardProvider(propertyId).notifier)
                        .toggleCardDone(card.id),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: card.isDone ? const Color(0xFF22C55E) : Colors.transparent,
                          border: Border.all(
                            color: card.isDone ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                        child: card.isDone
                            ? const Icon(Icons.check, size: 11, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                if (card.roomCode.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      card.roomCode,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                Expanded(
                  child: Text(
                    card.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: card.isDone ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                      decoration: card.isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (card.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                card.description,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            // Footer chips
            Row(
              children: [
                if (card.priority == CardPriority.high)
                  _Chip(
                    label: 'ALTA',
                    color: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEE2E2),
                  ),
                if (card.checkinDate != null)
                  _Chip(
                    icon: Icons.login_outlined,
                    label: formatRelativeDate(card.checkinDate!),
                    color: _isUrgent ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                    bgColor: _isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                  ),
                const Spacer(),
                if (isMobile && allColumns.length > 1)
                  GestureDetector(
                    onTap: () => _showMoveDialog(context, ref),
                    child: const Icon(Icons.open_with, size: 14, color: Color(0xFFCBD5E1)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _MoveCardSheet(
        card: card,
        allColumns: allColumns,
        propertyId: propertyId,
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Small chip label
// ─────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.bgColor, this.icon});

  final String label;
  final Color color;
  final Color bgColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 2),
          ],
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  "Move to column" sheet (mobile)
// ─────────────────────────────────────────

class _MoveCardSheet extends ConsumerWidget {
  const _MoveCardSheet({
    required this.card,
    required this.allColumns,
    required this.propertyId,
  });

  final BoardCard card;
  final List<BoardColumn> allColumns;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Mover a lista', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          for (final col in allColumns)
            ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColumnPalette.dotColor(col.color),
                ),
              ),
              title: Text(col.title),
              trailing: col.id == card.columnId ? const Icon(Icons.check, color: Color(0xFF2563EB)) : null,
              onTap: col.id == card.columnId
                  ? null
                  : () {
                      ref.read(boardProvider(propertyId).notifier).moveCard(card.id, col.id, 0);
                      Navigator.pop(context);
                    },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
