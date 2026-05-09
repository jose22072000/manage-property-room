import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../application/notifiers/notifiers.dart';
import '../../application/providers/api_providers.dart';
import '../../core/errors.dart';
import '../../data/remote/sse_client.dart';
import '../../domain/domain.dart';

// ── Local "last-read" timestamp stored in Hive ───────────────────────────────

const _kBoxName = 'app_prefs';
const _kLastReadKey = 'notifications_last_read';

Future<DateTime> _loadLastRead() async {
  final box = await Hive.openBox<String>(_kBoxName);
  final ts = box.get(_kLastReadKey);
  if (ts == null) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

Future<void> _saveLastRead(DateTime dt) async {
  final box = await Hive.openBox<String>(_kBoxName);
  await box.put(_kLastReadKey, dt.toIso8601String());
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Raw list of audit events used as notifications. Reloads whenever the
/// server pushes an SSE event (any entity), so new actions appear instantly
/// without any polling timer.
class NotificationsNotifier extends AsyncNotifier<List<AuditEvent>> {
  @override
  Future<List<AuditEvent>> build() async {
    ref.watch(auditVersionProvider); // full rebuild when board actions happen
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];
    // React to any server event — new audit records arrive with every mutation.
    ref.listen<AsyncValue<SseEvent>>(sseProvider, (_, next) {
      next.whenData((_) => _silentRefresh());
    });
    return ref.read(auditApiProvider).list(limit: 500);
  }

  Future<void> _silentRefresh() async {
    try {
      final list = await ref.read(auditApiProvider).list(limit: 500);
      state = AsyncData(list);
    } catch (_) {}
  }

  Future<void> forceRefresh() => _silentRefresh();
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AuditEvent>>(NotificationsNotifier.new);

/// Number of unread notifications (events newer than lastRead).
final unreadCountProvider = FutureProvider<int>((ref) async {
  final events = await ref.watch(notificationsProvider.future);
  final lastRead = await _loadLastRead();
  return events.where((e) => e.createdAt.isAfter(lastRead)).length;
});

// ── Page ─────────────────────────────────────────────────────────────────────

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  String _actionFilter = 'all';
  String _search = '';
  DateTime _lastRead = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadLastRead().then((dt) {
      if (mounted) setState(() => _lastRead = dt);
    });
  }

  List<AuditEvent> _filtered(List<AuditEvent> all) {
    final q = _search.toLowerCase().trim();
    return all.where((e) {
      if (_actionFilter != 'all' && !e.action.toLowerCase().startsWith(_actionFilter)) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.actorName.toLowerCase().contains(q) ||
          e.action.toLowerCase().contains(q) ||
          e.entity.toLowerCase().contains(q) ||
          e.detail.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _markAllRead(List<AuditEvent> events) async {
    if (events.isEmpty) return;
    final latest = events.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    await _saveLastRead(latest);
    setState(() => _lastRead = latest);
    ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
        actions: [
          notifAsync.when(
            data: (events) => TextButton.icon(
              onPressed: () => _markAllRead(events),
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Marcar todo leído', style: TextStyle(fontSize: 12)),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Actualizar',
            onPressed: () {
              ref.read(notificationsProvider.notifier).forceRefresh();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (all) {
          final filtered = _filtered(all);
          return Column(
            children: [
              _FilterBar(
                actionFilter: _actionFilter,
                search: _search,
                total: filtered.length,
                unread: all.where((e) => e.createdAt.isAfter(_lastRead)).length,
                onActionFilter: (v) => setState(() => _actionFilter = v),
                onSearch: (v) => setState(() => _search = v),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('Sin notificaciones',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _NotifCard(
                          event: filtered[i],
                          isUnread: filtered[i].createdAt.isAfter(_lastRead),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatefulWidget {
  const _FilterBar({
    required this.actionFilter,
    required this.search,
    required this.total,
    required this.unread,
    required this.onActionFilter,
    required this.onSearch,
  });
  final String actionFilter;
  final String search;
  final int total;
  final int unread;
  final ValueChanged<String> onActionFilter;
  final ValueChanged<String> onSearch;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.search);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _actions = [
    ('all', 'Todo'),
    ('create', 'Crear'),
    ('update', 'Actualizar'),
    ('delete', 'Eliminar'),
    ('move', 'Mover'),
    ('assign', 'Asignar'),
    ('toggle', 'Completar'),
    ('archive', 'Archivar'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: 'Buscar notificaciones…',
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixText: widget.unread > 0
                  ? '${widget.unread} nuevas'
                  : '${widget.total} total',
              suffixStyle: TextStyle(
                fontSize: 11,
                color: widget.unread > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: widget.onSearch,
          ),
          const SizedBox(height: 8),
          // Action type chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _actions.map((entry) {
                final (key, label) = entry;
                final selected = widget.actionFilter == key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 10),
                  child: FilterChip(
                    label: Text(label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF374151),
                        )),
                    selected: selected,
                    onSelected: (_) => widget.onActionFilter(key),
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF2563EB),
                    checkmarkColor: Colors.white,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.event, required this.isUnread});
  final AuditEvent event;
  final bool isUnread;

  static const _actionColors = {
    'create': Color(0xFF22C55E),
    'update': Color(0xFF2563EB),
    'delete': Color(0xFFEF4444),
    'move': Color(0xFF8B5CF6),
    'assign': Color(0xFFF59E0B),
    'toggle': Color(0xFF10B981),
    'archive': Color(0xFF64748B),
  };

  static const _actionIcons = {
    'create': Icons.add_circle_outline,
    'update': Icons.edit_outlined,
    'delete': Icons.delete_outline,
    'move': Icons.swap_horiz,
    'assign': Icons.person_add_outlined,
    'toggle': Icons.check_circle_outline,
    'archive': Icons.archive_outlined,
  };

  static String _actionLabel(String action) => switch (action) {
        'create' => 'Creó',
        'update' => 'Actualizó',
        'delete' => 'Eliminó',
        'move' => 'Movió',
        'assign-workers' || 'assign-supervisors' || 'assign-owner' => 'Asignó',
        'toggle-done' => 'Completó',
        'archive' => 'Archivó',
        _ => action,
      };

  static String _entityLabel(String entity) => switch (entity) {
        'card' => 'tarjeta',
        'column' => 'columna',
        'property' => 'propiedad',
        'user' => 'usuario',
        'group' => 'grupo',
        'field' => 'campo',
        _ => entity,
      };

  Color get _color {
    for (final key in _actionColors.keys) {
      if (event.action.startsWith(key)) return _actionColors[key]!;
    }
    return const Color(0xFF64748B);
  }

  IconData get _icon {
    for (final key in _actionIcons.keys) {
      if (event.action.startsWith(key)) return _actionIcons[key]!;
    }
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM, HH:mm', 'es');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUnread ? _color.withOpacity(0.4) : const Color(0xFFE2E8F0),
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: isUnread
            ? [BoxShadow(color: _color.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon, size: 18, color: _color),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _actionLabel(event.action),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _color,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _entityLabel(event.entity),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        fmt.format(event.createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (event.detail.isNotEmpty)
                    Text(
                      event.detail,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Text(
                        event.actorName,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
