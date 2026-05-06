import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/api_providers.dart';
import '../../data/remote/api_client.dart';

/// Diagnostic page for the Go backend connection (FASE 7-LINK).
///
/// Reachable at `/api-debug` while the new auth + Settings UI is being
/// rolled out. Lets the user verify the API URL, test connectivity, and
/// log in to obtain a JWT.
class ApiDebugPage extends ConsumerStatefulWidget {
  const ApiDebugPage({super.key});

  @override
  ConsumerState<ApiDebugPage> createState() => _ApiDebugPageState();
}

class _ApiDebugPageState extends ConsumerState<ApiDebugPage> {
  late final TextEditingController _urlCtrl;
  final _emailCtrl = TextEditingController(text: 'maria@app.local');
  final _passCtrl = TextEditingController(text: 'admin123');
  String _output = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    ref.read(apiBaseUrlProvider.notifier).state = _urlCtrl.text.trim();
    setState(() => _output = 'URL set to ${_urlCtrl.text.trim()}');
  }

  Future<void> _ping() async {
    setState(() { _busy = true; _output = 'Pinging…'; });
    final client = ref.read(apiClientProvider);
    final ok = await client.ping();
    ref.read(apiHealthProvider.notifier).state = ok;
    setState(() {
      _busy = false;
      _output = ok ? '✅ /health OK' : '❌ unreachable';
    });
  }

  Future<void> _login() async {
    setState(() { _busy = true; _output = 'Logging in…'; });
    try {
      final body = await ref.read(authApiProvider).login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      final user = body['user'] as Map<String, dynamic>?;
      setState(() => _output = '✅ logged in as ${user?['email']} (role=${user?['role']}). '
          'Token stored in ApiSession.');
    } on ApiException catch (e) {
      setState(() => _output = '❌ ${e.code}: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _fetchMe() async {
    setState(() { _busy = true; _output = 'GET /me…'; });
    try {
      final body = await ref.read(authApiProvider).me();
      setState(() => _output = '✅ /me → ${body.toString()}');
    } on ApiException catch (e) {
      setState(() => _output = '❌ ${e.code}: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _fetchProperties() async {
    setState(() { _busy = true; _output = 'GET /properties…'; });
    try {
      final list = await ref.read(apiClientProvider).get<List<dynamic>>('/properties');
      final names = list.map((p) => (p as Map)['name']).toList();
      setState(() => _output = '✅ ${list.length} properties: $names');
    } on ApiException catch (e) {
      setState(() => _output = '❌ ${e.code}: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(apiClientProvider).session;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('API debug · FASE 7-LINK')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Backend URL', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _urlCtrl)),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _busy ? null : _saveUrl,
                      child: const Text('Guardar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _ping,
                      child: const Text('Probar conexión'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Login', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'password'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _login,
                        child: const Text('Login'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy || !session.isAuthenticated ? null : _fetchMe,
                        child: const Text('GET /me'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy || !session.isAuthenticated ? null : _fetchProperties,
                        child: const Text('GET /properties'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: SelectableText(
                    _output.isEmpty ? '(esperando acción…)' : _output,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Token: ${session.isAuthenticated ? "${session.token!.substring(0, 32)}…" : "(none)"}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
