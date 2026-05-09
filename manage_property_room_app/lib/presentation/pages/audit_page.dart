import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/notifiers/notifiers.dart';
import '../../application/providers/api_providers.dart';
import '../../core/errors.dart';
import '../../domain/domain.dart';

// ── providers ────────────────────────────────────────────────────────────────

final _auditRawProvider = FutureProvider<List<AuditEvent>>((ref) async {
  ref.watch(auditVersionProvider);
  await ref.watch(currentUserProvider.future);
  return ref.read(auditApiProvider).list(limit: 1000);
});

// ── filter state ─────────────────────────────────────────────────────────────

enum _DateFilter { today, week, month, all }

// ── helpers (top-level so they can be used from multiple widgets) ─────────────

IconData _actionIcon(String action) {
  return switch (action.toLowerCase()) {
    'create'  => Icons.add_circle_outline,
    'update'  => Icons.edit_outlined,
    'delete'  => Icons.delete_outline,
    'move'    => Icons.swap_horiz,
    'archive' => Icons.archive_outlined,
    'login'   => Icons.login,
    'logout'  => Icons.logout,
    'config'  => Icons.settings_outlined,
    'reorder' => Icons.swap_vert,
    _ => Icons.circle_outlined,
  };
}

String _actionLabel(String action) {
  return switch (action.toLowerCase()) {
    'create'  => 'CREAR',
    'update'  => 'EDITAR',
    'delete'  => 'BORRAR',
    'move'    => 'MOVER',
    'archive' => 'ARCHIVO',
    'login'   => 'INICIO',
    'logout'  => 'CIERRE',
    'config'  => 'CONFIG',
    'reorder' => 'ORDEN',
    _ => action.toUpperCase(),
  };
}

Color _actionColor(String action) {
  return switch (action.toLowerCase()) {
    'create'  => const Color(0xFF16A34A),
    'update'  => const Color(0xFF2563EB),
    'delete'  => const Color(0xFFDC2626),
    'move'    => const Color(0xFFD97706),
    'archive' => const Color(0xFF7C3AED),
    'login'   => const Color(0xFF0891B2),
    'logout'  => const Color(0xFF9F1239),
    'config'  => const Color(0xFF475569),
    'reorder' => const Color(0xFFD97706),
    _ => const Color(0xFF6B7280),
  };
}

// ── page ────────────────────────────────────────────────────────────────────

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});
  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  _DateFilter _dateFilter = _DateFilter.all;
  String _search = '';
  int _page = 0;
  static const _pageSize = 50;

  List<AuditEvent> _filtered(List<AuditEvent> all) {
    final now = DateTime.now();
    final cutoff = switch (_dateFilter) {
      _DateFilter.today => DateTime(now.year, now.month, now.day),
      _DateFilter.week  => now.subtract(const Duration(days: 7)),
      _DateFilter.month => now.subtract(const Duration(days: 30)),
      _DateFilter.all   => null,
    };
    final q = _search.toLowerCase().trim();
    return all.where((e) {
      if (cutoff != null && e.createdAt.toLocal().isBefore(cutoff)) return false;
      if (q.isEmpty) return true;
      return e.actorName.toLowerCase().contains(q) ||
          e.actorIp.toLowerCase().contains(q) ||
          e.action.toLowerCase().contains(q) ||
          e.entity.toLowerCase().contains(q) ||
          e.detail.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _deleteEvent(AuditEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "${_actionLabel(event.action)}" de ${event.actorName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(auditApiProvider).delete(event.id);
      ref.invalidate(_auditRawProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(_auditRawProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Auditoría'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Actualizar',
            onPressed: () {
              setState(() { _page = 0; });
              ref.invalidate(_auditRawProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (all) {
          final filtered = _filtered(all);
          final totalPages = ((filtered.length - 1) ~/ _pageSize) + 1;
          final safePage = _page.clamp(0, (totalPages - 1).clamp(0, 999));
          final pageEvents = filtered.skip(safePage * _pageSize).take(_pageSize).toList();
          final isMobile = MediaQuery.sizeOf(context).width < 600;

          return Column(
            children: [
              _Toolbar(
                dateFilter: _dateFilter,
                search: _search,
                total: filtered.length,
                onDateFilter: (f) => setState(() { _dateFilter = f; _page = 0; }),
                onSearch: (v) => setState(() { _search = v; _page = 0; }),
              ),
              // Table header — only on desktop
              if (!isMobile) ...[
                Container(
                  color: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(children: [
                    _hd('', 18),   // icon
                    _hd('Acción', 72),
                    _hd('Entidad', 26),
                    const SizedBox(width: 8),
                    Expanded(child: _hd('Detalle', null)),
                    _hd('Usuario / IP', 150),
                    _hd('Fecha', 120),
                    const SizedBox(width: 32), // delete icon space
                  ]),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ],
              // Event rows
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history, size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('Sin eventos', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: pageEvents.length,
                        itemBuilder: (ctx, i) => _AuditRow(
                          event: pageEvents[i],
                          isEven: i.isEven,
                          isMobile: isMobile,
                          onDelete: () => _deleteEvent(pageEvents[i]),
                        ),
                      ),
              ),
              // Pagination bar
              if (filtered.isNotEmpty)
                _PaginationBar(
                  currentPage: safePage,
                  totalPages: totalPages,
                  totalItems: filtered.length,
                  pageSize: _pageSize,
                  onPage: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _hd(String label, double? width) {
    final t = Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
    if (width == null) return t;
    return SizedBox(width: width, child: t);
  }
}

// ── toolbar ──────────────────────────────────────────────────────────────────

class _Toolbar extends StatefulWidget {
  const _Toolbar({
    required this.dateFilter,
    required this.search,
    required this.total,
    required this.onDateFilter,
    required this.onSearch,
  });
  final _DateFilter dateFilter;
  final String search;
  final int total;
  final ValueChanged<_DateFilter> onDateFilter;
  final ValueChanged<String> onSearch;

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // Date filter chips
          _chip('Hoy', _DateFilter.today),
          const SizedBox(width: 6),
          _chip('7 días', _DateFilter.week),
          const SizedBox(width: 6),
          _chip('30 días', _DateFilter.month),
          const SizedBox(width: 6),
          _chip('Todo', _DateFilter.all),
          const SizedBox(width: 12),
          // Search
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: _ctrl,
                onChanged: widget.onSearch,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por usuario, IP, acción, entidad…',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _ctrl.clear();
                            widget.onSearch('');
                          },
                          child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${widget.total} eventos',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _DateFilter f) {
    final active = widget.dateFilter == f;
    return GestureDetector(
      onTap: () => widget.onDateFilter(f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

// ── event row ────────────────────────────────────────────────────────────────

class _AuditRow extends StatelessWidget {
  const _AuditRow({
    required this.event,
    required this.isEven,
    this.isMobile = false,
    required this.onDelete,
  });
  final AuditEvent event;
  final bool isEven;
  final bool isMobile;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ts = DateFormat('dd/MM/yy HH:mm').format(event.createdAt.toLocal());
    final color = _actionColor(event.action);
    final actionIcon = _actionIcon(event.action);

    if (isMobile) {
      return Container(
        color: isEven ? Colors.white : const Color(0xFFFAFAFA),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: icon+badge + entity + delete + timestamp
            Row(
              children: [
                Icon(actionIcon, size: 13, color: color),
                const SizedBox(width: 4),
                _Badge(label: _actionLabel(event.action), color: color),
                const SizedBox(width: 6),
                _EntityBadge(entity: event.entity),
                const Spacer(),
                Text(ts, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 17, color: Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
            // Row 2: detail
            if (event.detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.detail,
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Row 3: actor + IP
            const SizedBox(height: 4),
            Row(
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor: const Color(0xFFDDE8FF),
                  child: Text(
                    event.actorName.isNotEmpty ? event.actorName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 4),
                Text(event.actorName, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                if (event.actorIp.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.lan_outlined, size: 10, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 2),
                  Text(event.actorIp, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ],
            ),
            const Divider(height: 12, color: Color(0xFFE2E8F0)),
          ],
        ),
      );
    }

    // Desktop row
    return Container(
      color: isEven ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          // Action icon
          SizedBox(width: 18, child: Icon(actionIcon, size: 14, color: color)),
          // Action badge
          _Badge(label: _actionLabel(event.action), color: color),
          const SizedBox(width: 4),
          // Entity badge
          _EntityBadge(entity: event.entity),
          const SizedBox(width: 8),
          // Detail
          Expanded(
            child: Text(
              event.detail.isNotEmpty ? event.detail : '—',
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Actor + IP
          SizedBox(
            width: 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: const Color(0xFFDDE8FF),
                      child: Text(
                        event.actorName.isNotEmpty ? event.actorName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.actorName,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (event.actorIp.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 1),
                    child: Row(
                      children: [
                        const Icon(Icons.lan_outlined, size: 10, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            event.actorIp,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Timestamp
          SizedBox(
            width: 120,
            child: Text(
              ts,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.right,
            ),
          ),
          // Delete button
          SizedBox(
            width: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFCBD5E1)),
              tooltip: 'Eliminar',
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EntityBadge extends StatelessWidget {
  const _EntityBadge({required this.entity});
  final String entity;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (entity.toLowerCase()) {
      'card'     => (Icons.view_kanban_outlined, const Color(0xFF0891B2)),
      'column'   => (Icons.view_column_outlined, const Color(0xFF7C3AED)),
      'user'     => (Icons.person_outline, const Color(0xFF16A34A)),
      'property' => (Icons.home_work_outlined, const Color(0xFFD97706)),
      'group'    => (Icons.group_outlined, const Color(0xFF7C3AED)),
      _ => (Icons.circle_outlined, const Color(0xFF94A3B8)),
    };
    return Tooltip(
      message: entity,
      child: SizedBox(
        width: 20,
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ── pagination bar ────────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPage,
  });
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final from = currentPage * pageSize + 1;
    final to = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '$from–$to de $totalItems',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          // Page buttons
          _pageBtn(Icons.first_page, currentPage > 0, () => onPage(0)),
          _pageBtn(Icons.chevron_left, currentPage > 0, () => onPage(currentPage - 1)),
          ...List.generate(totalPages, (i) {
            if (totalPages <= 7 ||
                i == 0 || i == totalPages - 1 ||
                (i >= currentPage - 1 && i <= currentPage + 1)) {
              return _numBtn(i);
            }
            if (i == 1 || i == totalPages - 2) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text('…', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              );
            }
            return const SizedBox.shrink();
          }),
          _pageBtn(Icons.chevron_right, currentPage < totalPages - 1, () => onPage(currentPage + 1)),
          _pageBtn(Icons.last_page, currentPage < totalPages - 1, () => onPage(totalPages - 1)),
        ],
      ),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: enabled ? const Color(0xFFF1F5F9) : Colors.transparent,
        ),
        child: Icon(icon, size: 16, color: enabled ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  Widget _numBtn(int page) {
    final active = page == currentPage;
    return GestureDetector(
      onTap: active ? null : () => onPage(page),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: active ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
        ),
        child: Center(
          child: Text(
            '${page + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}



