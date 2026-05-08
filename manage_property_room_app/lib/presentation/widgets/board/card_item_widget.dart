import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/notifiers/notifiers.dart';
import '../../../core/image_storage.dart';
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
    this.columnConfig = const ColumnConfig(),
  });

  final BoardCard card;
  final AppUser? user;
  final String propertyId;
  final bool isMobile;
  final VoidCallback? onTap;
  final List<BoardColumn> allColumns;
  final ColumnConfig columnConfig;

  bool get _isUrgent =>
      card.priority == CardPriority.high || isCheckinTomorrow(card.checkinDate);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canToggle = user != null && Policy.canCard(user!, card, CardAction.toggleDone);
    final prefs = columnConfig;

    // Collect all image field values for this card.
    String? _firstImagePath;
    if (prefs.cardShowImage) {
      final fields = ref.watch(fieldsProvider).valueOrNull ?? [];
      final imageFields = fields.where((f) => f.type == FieldType.image && f.enabled);
      for (final f in imageFields) {
        final val = card.customFields[f.id];
        if (val is List && (val as List).isNotEmpty) {
          _firstImagePath = (val as List).first as String?;
          break;
        }
      }
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (_isUrgent && prefs.cardShowPriorityBorder)
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            Row(
              children: [
                // Checkbox / done toggle
                if (canToggle && prefs.cardShowDone)
                  GestureDetector(
                    onTap: () {
                      final willBeDone = !card.isDone;
                      final markedBy = willBeDone ? (user?.initials ?? '') : '';
                      ref
                          .read(boardProvider(propertyId).notifier)
                          .toggleCardDone(card.id, cleanedBy: markedBy);
                    },
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
                if (card.roomCode.isNotEmpty && prefs.cardShowRoomCode)
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
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (card.description.isNotEmpty && prefs.cardShowDescription) ...[
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
                if (prefs.cardShowPriority && card.priority != CardPriority.normal)
                  _Chip(
                    label: PriorityPalette.label(card.priority).toUpperCase(),
                    color: PriorityPalette.color(card.priority),
                    bgColor: card.priority == CardPriority.high
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFF3F4F6),
                  ),
                if (card.checkinDate != null && prefs.cardShowCheckin)
                  _Chip(
                    icon: Icons.login_outlined,
                    label: formatRelativeDate(card.checkinDate!),
                    color: _isUrgent ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                    bgColor: _isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                  ),
                if (card.isDone && prefs.cardShowCleanedBy && (card.cleanedBy.isNotEmpty || card.doneAt != null))
                  _Chip(
                    icon: Icons.check_circle_outline,
                    label: _doneLabel(card),
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                const Spacer(),
                if (isMobile && allColumns.length > 1)
                  GestureDetector(
                    onTap: () => _showMoveDialog(context, ref),
                    child: const Icon(Icons.open_with, size: 14, color: Color(0xFFCBD5E1)),
                  ),
              ],
            ),
            // Image thumbnail (optional, controlled by cardShowImage toggle)
            if (prefs.cardShowImage && _firstImagePath != null) ...[
              const SizedBox(height: 6),
              _CardImageThumb(path: _firstImagePath!),
            ],
          ],
        ),
        ),
      ),
    );
  }

  void _showMoveDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      enableDrag: false,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (_) => _MoveCardSheet(
        card: card,
        allColumns: allColumns,
        propertyId: propertyId,
      ),
    );
  }

  static String _doneLabel(BoardCard card) {
    final parts = <String>[];
    if (card.cleanedBy.isNotEmpty) parts.add(card.cleanedBy);
    if (card.doneAt != null) parts.add(formatDoneAt(card.doneAt!));
    return parts.isEmpty ? 'Completado' : parts.join(' · ');
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

// ─────────────────────────────────────────
//  Image thumbnail for card compact view
// ─────────────────────────────────────────

class _CardImageThumb extends StatelessWidget {
  const _CardImageThumb({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (kIsWeb) {
      if (path.startsWith('blob:') || path.startsWith('http') || path.startsWith('data:')) {
        image = Image.network(path, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 16, color: Color(0xFF94A3B8)));
      } else {
        image = const Icon(Icons.image_outlined, size: 16, color: Color(0xFF94A3B8));
      }
    } else {
      image = FutureBuilder<String?>(
        future: resolveCardImage(path),
        builder: (_, snap) {
          final resolved = snap.data;
          if (resolved == null) return const SizedBox.shrink();
          return Image.file(File(resolved), fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 16, color: Color(0xFF94A3B8)));
        },
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: double.infinity, height: 80, child: image),
    );
  }
}
