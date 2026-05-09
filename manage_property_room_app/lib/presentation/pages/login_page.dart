import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/notifiers/notifiers.dart';
import '../../application/providers/api_providers.dart';
import '../../application/providers/repo_providers.dart';
import '../../core/background_notif_service.dart';
import '../../core/errors.dart';
import '../../data/remote/api_client.dart';
import '../../domain/domain.dart';

/// Pantalla de login — autentica contra el backend Go.
/// Tras el login exitoso busca el usuario admin en Hive y lo activa.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'maria@app.local');
  final _passCtrl = TextEditingController(text: 'admin123');
  bool _busy = false;
  bool _showPass = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 1. Call API login → stores JWT in ApiSession, returns full response
      final response = await ref.read(authApiProvider).login(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );

      // 2. Build AppUser directly from the API response user object
      final userMap = response['user'] as Map<String, dynamic>?;
      if (userMap == null) {
        throw ApiException('NO_USER', 'Respuesta inesperada del servidor');
      }
      final appUser = AppUser.fromJson(userMap);

      // 3. Persist in local Hive so CurrentUserNotifier.build() finds it on reload
      await ref.read(userRepoProvider).save(appUser);

      // 4. Save JWT token to Hive so it survives page reload.
      final token = ref.read(apiClientProvider).session.token;
      if (token != null && token.isNotEmpty) {
        await ref.read(settingsRepoProvider).saveToken(token);
        // Schedule background notification polling (mobile only)
        if (!kIsWeb) {
          final baseUrl = ref.read(apiClientProvider).baseUrl;
          await _scheduleBackgroundNotifs(baseUrl, token);
        }
      }

      // 5. Set as current user (stores id in settings + updates state)
      await ref.read(currentUserProvider.notifier).setUser(appUser);

      // 5. Navigate directly (belt + suspenders alongside router redirect)
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() {
        _error = friendlyError(e);
        _busy = false;
      });
    } catch (e, st) {
      debugPrint('LOGIN ERROR: $e\n$st');
      setState(() {
        _error = friendlyError(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / brand
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x402563EB), blurRadius: 20, offset: Offset(0, 8)),
                    ],
                  ),
                  child: const Icon(Icons.home_work_outlined, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Gestión de Propiedades',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Inicia sesión para continuar',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 32),
                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'email@ejemplo.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 18),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Introduce tu email' : null,
                        ),
                        const SizedBox(height: 16),
                        // Password
                        const Text(
                          'Contraseña',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: !_showPass,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _busy ? null : _submit(),
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _showPass = !_showPass),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Introduce tu contraseña' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline,
                                  size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 44,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
Future<void> _scheduleBackgroundNotifs(String baseUrl, String token) async {
  try {
    await BackgroundNotifService.instance.schedule(
      baseUrl: baseUrl,
      token: token,
    );
  } catch (_) {
    // Non-fatal — background polling is best-effort
  }
}