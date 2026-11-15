import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/auth_shell.dart';
import 'auth_repository.dart';
import 'auth_controller.dart';
import 'startup_loading_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
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

    return AuthShell(
      title: 'Inicio de sesión',
      subtitle: 'Inicia para continuar',
      footer: AuthFooterLine(
        '¿Sin cuenta?',
        'Regístrate aquí',
        onTap: () {
          ref.read(authControllerProvider.notifier).reset();
          context.go('/register');
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) AuthNotice(error),
          const AuthLabel('Documento', first: true),
          AuthField(
            controller: _id,
            hint: 'Tu número de documento',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
          ),
          const AuthLabel('Contraseña'),
          AuthField(
            controller: _pass,
            hint: 'Mínimo 8 caracteres',
            password: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!state.isLoading) _submit();
            },
          ),
          const SizedBox(height: 10),
          AuthCheck(
            label: 'Mantener sesión iniciada',
            value: _rememberMe,
            onChanged: state.isLoading
                ? null
                : (v) => setState(() => _rememberMe = v),
          ),
          const SizedBox(height: 12),
          AuthPrimaryButton(
            'Iniciar sesión',
            loading: state.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 10),
          Center(
            child: AuthLink(
              '¿Olvidaste la contraseña?',
              color: kAuthCrimson,
              weight: FontWeight.w500,
              onTap: () {
                ref.read(authControllerProvider.notifier).reset();
                context.go('/forgot-password');
              },
            ),
          ),
        ],
      ),
    );
  }
}
