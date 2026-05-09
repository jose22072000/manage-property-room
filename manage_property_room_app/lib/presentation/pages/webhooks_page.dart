import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/api_providers.dart';
import '../../application/notifiers/notifiers.dart';
import '../../core/errors.dart';
import '../../data/remote/api_endpoints.dart';
import '../../domain/domain.dart';

/// Admin/owner UI to manage outbound + inbound webhooks. Outbound webhooks
/// fire HMAC-signed POSTs whenever cards are completed, created, archived,
/// etc. Inbound hooks expose a public token URL that external systems can
/// POST to in order to create a card in a chosen column.
class WebhooksPage extends ConsumerWidget {
  const WebhooksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(webhooksApiProvider);
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('Webhooks',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Recibe notificaciones HTTP cuando cambian las tareas y permite a sistemas externos crear tareas vía URL.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 24),
                _OutboundSection(api: api),
                const SizedBox(height: 32),
                _InboundSection(api: api),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── outbound ──────────────────────────────────────────────────────────────

class _OutboundSection extends ConsumerStatefulWidget {
  const _OutboundSection({required this.api});
  final dynamic api;

  @override
  ConsumerState<_OutboundSection> createState() => _OutboundSectionState();
}

class _OutboundSectionState extends ConsumerState<_OutboundSection> {
  late Future<List<Webhook>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.list();
  }

  void _refresh() => setState(() => _future = widget.api.list());

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Salientes',
      subtitle: 'POST a un endpoint externo cuando ocurre un evento.',
      action: TextButton.icon(
        onPressed: () => _showCreate(),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Nuevo'),
      ),
      child: FutureBuilder<List<Webhook>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(friendlyError(snap.error!),
                  style: const TextStyle(color: Color(0xFFB91C1C))),
            );
          }
          final items = snap.data ?? const <Webhook>[];
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Sin webhooks salientes.',
                  style: TextStyle(color: Color(0xFF64748B))),
            );
          }
          return Column(
            children: items
                .map((w) => _OutboundTile(
                      hook: w,
                      api: widget.api,
                      onChanged: _refresh,
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _showCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _OutboundDialog(api: widget.api),
    );
    if (created == true) _refresh();
  }
}

class _OutboundTile extends ConsumerWidget {
  const _OutboundTile({
    required this.hook,
    required this.api,
    required this.onChanged,
  });
  final Webhook hook;
  final dynamic api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hook.active ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hook.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(hook.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: hook.events
                      .map((e) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              WebhookEvents.labels[e] ?? e,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF1D4ED8)),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Probar',
            onPressed: () async {
              try {
                await api.testFire(hook.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ping enviado')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(friendlyError(e))),
                  );
                }
              }
            },
            icon: const Icon(Icons.play_arrow_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('¿Eliminar webhook?'),
                  content: Text(hook.name),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar')),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  await api.delete(hook.id);
                  onChanged();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyError(e))),
                    );
                  }
                }
              }
            },
            icon: const Icon(Icons.delete_outline,
                size: 20, color: Color(0xFFB91C1C)),
          ),
        ],
      ),
    );
  }
}

class _OutboundDialog extends ConsumerStatefulWidget {
  const _OutboundDialog({required this.api});
  final dynamic api;

  @override
  ConsumerState<_OutboundDialog> createState() => _OutboundDialogState();
}

class _OutboundDialogState extends ConsumerState<_OutboundDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final Set<String> _events = {WebhookEvents.cardCompleted};
  String? _propertyId;
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propsAsync = ref.watch(propertiesProvider);
    return AlertDialog(
      title: const Text('Nuevo webhook saliente'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                    labelText: 'URL', hintText: 'https://example.com/hook'),
              ),
              const SizedBox(height: 12),
              const Text('Eventos',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              ...WebhookEvents.all.map((e) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(WebhookEvents.labels[e] ?? e),
                    value: _events.contains(e),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _events.add(e);
                      } else {
                        _events.remove(e);
                      }
                    }),
                  )),
              const SizedBox(height: 8),
              propsAsync.maybeWhen(
                data: (props) => DropdownButtonFormField<String?>(
                  value: _propertyId,
                  decoration: const InputDecoration(
                      labelText: 'Propiedad (opcional — todas si vacío)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Todas las propiedades')),
                    ...props.map((p) => DropdownMenuItem(
                        value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (v) => setState(() => _propertyId = v),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(_err!, style: const TextStyle(color: Color(0xFFB91C1C))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando…' : 'Crear'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    if (name.isEmpty || url.isEmpty || _events.isEmpty) {
      setState(() => _err = 'Nombre, URL y al menos un evento son obligatorios');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _err = 'URL debe empezar con http:// o https://');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await widget.api.create(
        name: name,
        url: url,
        events: _events.toList(),
        propertyId: _propertyId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _err = friendlyError(e);
      });
    }
  }
}

// ── inbound ───────────────────────────────────────────────────────────────

class _InboundSection extends ConsumerStatefulWidget {
  const _InboundSection({required this.api});
  final dynamic api;

  @override
  ConsumerState<_InboundSection> createState() => _InboundSectionState();
}

class _InboundSectionState extends ConsumerState<_InboundSection> {
  late Future<List<InboundHook>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listInbound();
  }

  void _refresh() => setState(() => _future = widget.api.listInbound());

  String _baseUrl(WidgetRef ref) => ref.read(apiBaseUrlProvider).isNotEmpty
      ? ref.read(apiBaseUrlProvider)
      : ApiEndpoints.defaultBaseUrl();

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Entrantes',
      subtitle: 'URLs públicas que reciben POST y crean tareas.',
      action: TextButton.icon(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (_) => _InboundDialog(api: widget.api),
          );
          if (created == true) _refresh();
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Nuevo'),
      ),
      child: FutureBuilder<List<InboundHook>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(friendlyError(snap.error!),
                  style: const TextStyle(color: Color(0xFFB91C1C))),
            );
          }
          final items = snap.data ?? const <InboundHook>[];
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Sin webhooks entrantes.',
                  style: TextStyle(color: Color(0xFF64748B))),
            );
          }
          final base = _baseUrl(ref);
          return Column(
            children: items.map((h) {
              final url = '$base/hooks/inbound/${h.token}';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          SelectableText(url,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copiar URL',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('URL copiada')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('¿Eliminar webhook entrante?'),
                            content: Text(h.name),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Eliminar')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          try {
                            await widget.api.deleteInbound(h.id);
                            _refresh();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(friendlyError(e))),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Color(0xFFB91C1C)),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _InboundDialog extends ConsumerStatefulWidget {
  const _InboundDialog({required this.api});
  final dynamic api;
  @override
  ConsumerState<_InboundDialog> createState() => _InboundDialogState();
}

class _InboundDialogState extends ConsumerState<_InboundDialog> {
  final _name = TextEditingController();
  String? _propertyId;
  String? _columnId;
  bool _saving = false;
  String? _err;
  List<BoardColumn> _columns = const [];
  bool _loadingCols = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadColumns(String propertyId) async {
    setState(() {
      _loadingCols = true;
      _columns = const [];
      _columnId = null;
    });
    try {
      final api = ref.read(boardApiProvider);
      final board = await api.getBoard(propertyId);
      final cols = (board['columns'] as List? ?? [])
          .map((e) => BoardColumn.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _columns = cols;
        _loadingCols = false;
      });
    } catch (e) {
      setState(() {
        _loadingCols = false;
        _err = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final propsAsync = ref.watch(propertiesProvider);
    return AlertDialog(
      title: const Text('Nuevo webhook entrante'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            propsAsync.maybeWhen(
              data: (props) => DropdownButtonFormField<String>(
                value: _propertyId,
                decoration: const InputDecoration(labelText: 'Propiedad'),
                items: props
                    .map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _propertyId = v);
                  if (v != null) _loadColumns(v);
                },
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            if (_loadingCols)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_columns.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _columnId,
                decoration: const InputDecoration(labelText: 'Lista destino'),
                items: _columns
                    .map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.title)))
                    .toList(),
                onChanged: (v) => setState(() => _columnId = v),
              ),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando…' : 'Crear'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _propertyId == null || _columnId == null) {
      setState(() => _err = 'Nombre, propiedad y lista son obligatorios');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await widget.api.createInbound(
        name: _name.text.trim(),
        propertyId: _propertyId!,
        columnId: _columnId!,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _err = friendlyError(e);
      });
    }
  }
}

// ── shared layout helpers ─────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
