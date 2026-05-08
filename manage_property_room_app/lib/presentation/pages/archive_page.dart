import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/notifiers/notifiers.dart';
import '../../core/date_formatters.dart';
import '../../core/errors.dart';
import '../../domain/domain.dart';
import '../widgets/shared/toast.dart';

class ArchivePage extends ConsumerWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(archiveProvider);

    return archiveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (cards) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const Text('Archivo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const Spacer(),
                    if (cards.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _clearAll(context, ref),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                        label: const Text('Vaciar'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: cards.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.archive_outlined, size: 64, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 12),
                    Text('Archivo vacío', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Las tarjetas archivadas aparecerán aquí', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              )
            : _ArchiveList(cards: cards),
              ),
            ],
          );
        },
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirm(
      context,
      message: '¿Vaciar el archivo?',
      description: 'Esta acción eliminará permanentemente todas las tarjetas archivadas.',
      confirmLabel: 'Vaciar',
      isDanger: true,
    );
    if (confirmed) await ref.read(archiveProvider.notifier).clearAll();
  }
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList({required this.cards});

  final List<ArchivedCard> cards;

  @override
  Widget build(BuildContext context) {
    // Group by day
    final grouped = <String, List<ArchivedCard>>{};
    for (final card in cards) {
      final key = formatDate(card.archivedAt);
      grouped.putIfAbsent(key, () => []).add(card);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          for (final card in entry.value) _ArchivedCardTile(card: card),
        ],
      ],
    );
  }
}

class _ArchivedCardTile extends ConsumerWidget {
  const _ArchivedCardTile({required this.card});

  final ArchivedCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(propertiesProvider);
    final propertyName = propsAsync.valueOrNull
            ?.where((p) => p.id == card.propertyId)
            .map((p) => p.name)
            .firstOrNull ??
        '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: card.roomCode.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(card.roomCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              )
            : const Icon(Icons.archive_outlined, color: Color(0xFF94A3B8)),
        title: Text(card.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (propertyName.isNotEmpty)
              Text(
                propertyName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
              ),
            if (card.sourceColumnTitle.isNotEmpty)
              Text(card.sourceColumnTitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            if (card.priority == CardPriority.high)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Alta prioridad', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.restore_outlined, color: Color(0xFF2563EB)),
          tooltip: 'Restaurar',
          onPressed: () => ref.read(archiveProvider.notifier).restoreCard(card),
        ),
      ),
    );
  }
}
