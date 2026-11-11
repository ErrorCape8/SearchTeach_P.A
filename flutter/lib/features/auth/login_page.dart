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
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _rememberMe = false;
  bool _startupLoading = false;
  bool _retryLoginOnSplash = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    // Al entrar a la pantalla no debe quedar un error de otra pantalla.
    Future.microtask(() => ref.read(authControllerProvider.notifier).reset());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _startupLoading = true;
      _startupError = null;
    });
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(_id.text.trim(), _pass.text, rememberMe: _rememberMe);
    if (!mounted) return;
    if (!ok) {
      final loginError = ref.read(authControllerProvider.notifier).errorMessage;
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
            'No pudimos cargar tu perfil. Revisa tu conexi\u{00F3}n e intenta de nuevo.');
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
    final error = ref.read(authControllerProvider.notifier).errorMessage;

    if (_startupLoading) {
      return StartupLoadingPage(
        error: _startupError,
        onRetry: _retryLoginOnSplash ? _submit : _loadLandingPage,
        onBack: _returnToLogin,
      );
    }

    return AuthShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Inicio de sesión',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w900, color: kInk)),
            const SizedBox(height: 8),
            const Text('Inicia para continuar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5B6270))),
            const SizedBox(height: 32),
            if (error != null) ErrorBanner(error),
            const FieldLabel('Documento'),
            TextFormField(
              controller: _id,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fieldDecoration('Tu número de documento'),
              validator: (v) => RegExp(r'^[0-9]{6,10}$').hasMatch(v ?? '')
                  ? null
                  : 'Debe tener entre 6 y 10 dígitos',
            ),
            const SizedBox(height: 20),
            const FieldLabel('Contraseña'),
            TextFormField(
              controller: _pass,
              obscureText: _hide,
              decoration: fieldDecoration('••••••••',
                  suffix: IconButton(
                    icon: Icon(_hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  )),
              validator: (v) => (v ?? '').length >= 8 && v!.length <= 72
                  ? null
                  : 'Debe tener entre 8 y 72 caracteres',
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _rememberMe,
                onChanged: state.isLoading
                    ? null
                    : (value) => setState(() => _rememberMe = value ?? false),
                title: const Text('Mantener sesión iniciada'),
              ),
            ),
            DarkButton('Iniciar sesión',
                loading: state.isLoading, onPressed: _submit),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).reset();
                context.go('/forgot-password');
              },
              child: const Text('¿Olvidaste la contraseña?'),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('¿Sin cuenta? '),
              GestureDetector(
                onTap: () {
                  ref.read(authControllerProvider.notifier).reset();
                  context.go('/register');
                },
                child: const Text('Regístrate aquí',
                    style:
                        TextStyle(color: kBlue, fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
