import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/notifiers/notifiers.dart';
import '../../../domain/domain.dart';
import '../../../permissions/policy.dart';
import '../../../core/responsive.dart';
import '../../../core/notification_service.dart';
import '../../../presentation/pages/notifications_page.dart';
import 'toast.dart';
import 'user_selector.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Poll for remote audit events every 30 s
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(notifVersionProvider.notifier).update((v) => v + 1);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBoardPage = widget.location.contains('/board');
    final user = ref.watch(currentUserProvider).valueOrNull;

    // Detect new audit events and show banners (admin/owner only)
    if (user != null && Policy.canSeeNotifications(user)) {
      ref.listen<AsyncValue<List<AuditEvent>>>(notificationsProvider, (_, next) {
        next.whenData((events) {
          if (events.isEmpty) return;
          final latestId = events.first.id;
          final lastSeen = ref.read(notifLastSeenIdProvider);
          if (lastSeen == null) {
            ref.read(notifLastSeenIdProvider.notifier).state = latestId;
            return; // first load — don't show banners
          }
          if (latestId == lastSeen) return;
          final lastIdx = events.indexWhere((e) => e.id == lastSeen);
          final newEvents = lastIdx >= 0 ? events.sublist(0, lastIdx) : [events.first];
          ref.read(notifLastSeenIdProvider.notifier).state = latestId;
          for (final e in newEvents.take(3)) {
            ref.read(notifBannerProvider.notifier).add(e);
            // Fire system notification (sound + vibration)
            NotificationService.instance.showAuditEvent(
              title: 'Actividad reciente',
              body: _auditEventLabel(e),
              id: e.hashCode.abs() % 1000,
            );
          }
        });
      });
    }

    return ToastOverlay(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            body: Column(
              children: [
                _AppHeader(user: user, location: widget.location, ref: ref),
                Expanded(child: widget.child),
              ],
            ),
            bottomNavigationBar: Responsive.isMobile(context) && !isBoardPage
                ? _BottomNav(user: user, location: widget.location)
                : null,
          ),
          _NotifBannerOverlay(user: user),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.user, required this.location, required this.ref});
  final AppUser? user;
  final String location;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isBoardPage = location.contains('/board');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (isBoardPage && isMobile)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF9CA3AF)),
                      onPressed: () => context.go('/'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.home_work_outlined, color: Color(0xFF2563EB), size: 22),
                        if (!isMobile) ...[
                          const SizedBox(width: 8),
                          const Text('Gestion de Propiedades',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 24),
                  _NavLinks(location: location, user: user),
                ],
                const Spacer(),
                const SizedBox(width: 8),
                if (user != null && Policy.canBoard(user!, BoardAction.manageUsers))
                  _HeaderIconBtn(
                    icon: Icons.history_outlined,
                    tooltip: 'Auditoría',
                    onTap: () => context.go('/audit'),
                    active: location.startsWith('/audit'),
                  ),
                _HeaderIconBtn(
                  icon: Icons.settings_outlined,
                  tooltip: 'Configuración',
                  onTap: () => context.go('/settings'),
                  active: location.startsWith('/settings'),
                ),
                if (user case final u? when Policy.canSeeNotifications(u))
                  _NotifBell(location: location),
                UserSelector(compact: isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLinkDef {
  const _NavLinkDef(this.label, this.path);
  final String label;
  final String path;
}

class _NavLinks extends StatelessWidget {
  const _NavLinks({required this.location, required this.user});
  final String location;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final canAdmin = user != null && Policy.canBoard(user!, BoardAction.manageUsers);
    final canUserMgmt = user != null && Policy.canSeeUserManagement(user!);
    final items = <_NavLinkDef>[
      const _NavLinkDef('Propiedades', '/'),
      const _NavLinkDef('Por hacer', '/todo'),
      const _NavLinkDef('Archivo', '/archive'),
      if (canUserMgmt) const _NavLinkDef('Usuarios', '/users'),
    ];
    // silence unused warning
    canAdmin;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        final isActive = item.path == '/'
            ? (location == '/' || location.contains('/board'))
            : location.startsWith(item.path);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go(item.path),
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF2563EB) : const Color(0xFF374151),
                  )),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BNavItem {
  const _BNavItem(this.label, this.icon, this.activeIcon, this.route);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.user, required this.location});
  final AppUser? user;
  final String location;

  @override
  Widget build(BuildContext context) {
    final canAdmin = user != null && Policy.canBoard(user!, BoardAction.manageUsers);
    final canUserMgmt = user != null && Policy.canSeeUserManagement(user!);
    final items = <_BNavItem>[
      const _BNavItem('Inicio', Icons.home_outlined, Icons.home, '/'),
      const _BNavItem('Por hacer', Icons.checklist_outlined, Icons.checklist, '/todo'),
      const _BNavItem('Archivo', Icons.archive_outlined, Icons.archive, '/archive'),
      if (canUserMgmt) const _BNavItem('Usuarios', Icons.group_outlined, Icons.group, '/users'),
    ];
    int idx = items.indexWhere((i) => i.route == location);
    if (idx < 0) idx = 0;
    return NavigationBar(
      selectedIndex: idx,
      backgroundColor: Colors.white,
      onDestinationSelected: (i) => context.go(items[i].route),
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.activeIcon), label: item.label),
      ],
    );
  }
}

// ── Notification bell with unread badge ──────────────────────────────────────

class _NotifBell extends ConsumerWidget {
  const _NotifBell({required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadCountProvider);
    final count = countAsync.valueOrNull ?? 0;
    final isActive = location.startsWith('/notifications');

    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count',
            style: const TextStyle(fontSize: 9, color: Colors.white)),
        backgroundColor: const Color(0xFFEF4444),
        child: Icon(
          isActive ? Icons.notifications : Icons.notifications_outlined,
          size: 22,
          color: isActive ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
        ),
      ),
      tooltip: 'Notificaciones',
      onPressed: () => context.go('/notifications'),
    );
  }
}

// ── Small header icon button ──────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({required this.icon, required this.tooltip, required this.onTap, this.active = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: active ? const Color(0xFF2563EB) : const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

// ── Live notification banner overlay ─────────────────────────────────────────

class _NotifBannerOverlay extends ConsumerWidget {
  const _NotifBannerOverlay({this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user == null || !Policy.canSeeNotifications(user!)) return const SizedBox.shrink();
    final banners = ref.watch(notifBannerProvider);
    if (banners.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 12 + MediaQuery.paddingOf(context).top,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: banners.take(4).map((e) => _BannerCard(event: e)).toList(),
      ),
    );
  }
}

class _BannerCard extends ConsumerWidget {
  const _BannerCard({super.key, required this.event});
  final AuditEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = _iconAndColor(event.action);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 288,
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(event.detail,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('por ${event.actorName}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => ref.read(notifBannerProvider.notifier).dismiss(event.id),
                child: const Icon(Icons.close, size: 14, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _iconAndColor(String action) => switch (action) {
        'create' => (Icons.add_circle_outline, Color(0xFF16A34A)),
        'update' => (Icons.edit_outlined, Color(0xFF2563EB)),
        'delete' => (Icons.delete_outline, Color(0xFFDC2626)),
        'move' => (Icons.swap_horiz, Color(0xFF7C3AED)),
        'assign' => (Icons.person_add_outlined, Color(0xFF0891B2)),
        'toggle' => (Icons.check_circle_outline, Color(0xFF059669)),
        'archive' => (Icons.archive_outlined, Color(0xFFD97706)),
        _ => (Icons.info_outline, Color(0xFF6B7280)),
      };
}

// ── Helper: human-readable label for an audit event ──────────────────────────

String _auditEventLabel(AuditEvent e) {
  final action = switch (e.action) {
    'create' => 'creó',
    'update' => 'actualizó',
    'delete' => 'eliminó',
    'archive' => 'archivó',
    'move' => 'movió',
    'assign' => 'asignó',
    _ => e.action,
  };
  final entity = switch (e.entity) {
    'card' => 'una tarea',
    'column' => 'una columna',
    'property' => 'una propiedad',
    'user' => 'un usuario',
    _ => e.entity,
  };
  return '${e.actorName} $action $entity';
}
