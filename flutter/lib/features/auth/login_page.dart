import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/role_theme.dart';
import '../pa/pa_widgets.dart';
import 'auth_repository.dart';
import 'auth_controller.dart';
import 'startup_loading_page.dart';

const _loginAccent = Color(0xFF1E3FA8);

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _rememberMe = false;
  bool _startupLoading = false;
  bool _retryLoginOnSplash = false;
  String? _startupError;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).reset());
  }

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final doc = _id.text.trim();
    final pass = _pass.text;
    if (!RegExp(r'^[0-9]{6,10}$').hasMatch(doc)) {
      setState(() =>
          _validationError = 'El documento debe tener entre 6 y 10 dígitos.');
      return;
    }
    if (pass.length < 8 || pass.length > 72) {
      setState(() => _validationError =
          'La contraseña debe tener entre 8 y 72 caracteres.');
      return;
    }
    setState(() {
      _validationError = null;
      _startupLoading = true;
      _startupError = null;
    });
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(doc, pass, rememberMe: _rememberMe);
    if (!mounted) return;
    if (!ok) {
      final loginError =
          ref.read(authControllerProvider.notifier).errorMessage;
      if (loginError?.startsWith('No se pudo conectar con el servidor') ??
          false) {
        setState(() {
          _retryLoginOnSplash = true;
          _startupError = loginError;
        });
        return;
      }
      setState(() => _startupLoading = false);
      return;
    }
    _retryLoginOnSplash = false;
    await _loadLandingPage();
  }

  Future<void> _loadLandingPage() async {
    setState(() => _startupError = null);
    try {
      final route = await ref.read(authRepositoryProvider).landingRoute();
      if (mounted) context.go(route);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _startupError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _startupError =
            'No pudimos cargar tu perfil. Revisa tu conexión e intenta de nuevo.');
      }
    }
  }

  Future<void> _returnToLogin() async {
    await ref.read(authRepositoryProvider).clearLocalSession();
    if (mounted) {
      setState(() {
        _startupLoading = false;
        _retryLoginOnSplash = false;
        _startupError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final error =
        _validationError ?? ref.read(authControllerProvider.notifier).errorMessage;

    if (_startupLoading) {
      return StartupLoadingPage(
        error: _startupError,
        onRetry: _retryLoginOnSplash ? _submit : _loadLandingPage,
        onBack: _returnToLogin,
      );
    }

    final theme = Theme.of(context);
    return Theme(
      data: withRoleAccent(
        theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(primary: _loginAccent),
          scaffoldBackgroundColor: Neu.bg,
        ),
        _loginAccent,
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.5),
              radius: 1.2,
              colors: [
                Neu.bg.withOpacity(0.9),
                Neu.bg.withOpacity(0.7),
                Neu.bg.withOpacity(0.5),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _loginAccent.withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo_login.png',
                              width: 56,
                              height: 56,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.school_rounded,
                                size: 48,
                                color: _loginAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Search',
                                      style: neuPoppins(
                                        size: 28,
                                        weight: FontWeight.w800,
                                        color: Neu.heading,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Teach',
                                      style: neuPoppins(
                                        size: 28,
                                        weight: FontWeight.w800,
                                        color: _loginAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'CONNECT · LEARN · GROW',
                                style: neuBody(
                                  size: 9,
                                  color: Neu.muted,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      NeuSurface(
                        radius: 26,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Inicio de sesión',
                              textAlign: TextAlign.center,
                              style: neuPoppins(
                                size: 22,
                                weight: FontWeight.w700,
                                color: Neu.heading,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Inicia para continuar en tu espacio',
                              textAlign: TextAlign.center,
                              style: neuBody(size: 13, color: Neu.muted),
                            ),
                            const SizedBox(height: 20),
                            if (error != null) ...[
                              PaInfo(
                                error,
                                tone: PaTone.error,
                                icon: Icons.error_outline_rounded,
                              ),
                              const SizedBox(height: 8),
                            ],
                            const PaFieldLabel('Documento', first: true),
                            NeuField(
                              controller: _id,
                              hint: 'Tu número de documento',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                            const SizedBox(height: 14),
                            const PaFieldLabel('Contraseña'),
                            NeuField(
                              controller: _pass,
                              obscure: _hide,
                              hint: '••••••••',
                              suffix: IconButton(
                                icon: Icon(
                                  _hide
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Neu.muted,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _hide = !_hide),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: state.isLoading
                                      ? null
                                      : () => setState(
                                          () => _rememberMe = !_rememberMe),
                                  child: Row(
                                    children: [
                                      NeuSunken(
                                        radius: 8,
                                        padding: const EdgeInsets.all(3),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: _rememberMe
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 15,
                                                  color: _loginAccent,
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Recordarme',
                                        style: neuBody(
                                            size: 13, color: Neu.text),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    ref
                                        .read(authControllerProvider.notifier)
                                        .reset();
                                    context.go('/forgot-password');
                                  },
                                  child: Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: neuBody(
                                      size: 12.5,
                                      weight: FontWeight.w600,
                                      color: _loginAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            NeuButton(
                              'Iniciar sesión',
                              loading: state.isLoading,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('¿No tienes cuenta? ',
                              style:
                                  neuBody(size: 13.5, color: Neu.muted)),
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .reset();
                              context.go('/register');
                            },
                            child: Text(
                              'Regístrate aquí',
                              style: neuBody(
                                size: 13.5,
                                weight: FontWeight.w700,
                                color: _loginAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
