import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/auth_shell.dart';
import 'auth_repository.dart';
import 'auth_controller.dart';

/// Paso 1: documento  ->  Paso 2: crear contraseña (aquí se llama a /api/auth/register).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _idKey = GlobalKey<FormState>();
  final _passKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  int _step = 0;
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _checkingId = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).reset());
  }

  Future<void> _next(bool loading) async {
    if (loading || _checkingId || !_idKey.currentState!.validate()) return;
    setState(() => _checkingId = true);
    try {
      final valid = await ref
          .read(authControllerProvider.notifier)
          .verifyRegistration(_id.text.trim());
      if (valid && mounted) setState(() => _step = 1);
    } finally {
      if (mounted) setState(() => _checkingId = false);
    }
  }

  Future<void> _register() async {
    if (!_passKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(_id.text.trim(), _pass.text);
    if (ok && mounted) {
      try {
        final route = await ref.read(authRepositoryProvider).landingRoute();
        if (mounted) context.go(route);
      } on AuthFailure catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    } else if (mounted) {
      // Conserva el paso para corregir o reintentar la creación de contraseña.
      setState(() => _step = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final error = ref.read(authControllerProvider.notifier).errorMessage;

    return AuthShell(
      onBack: () {
        ref.read(authControllerProvider.notifier).reset();
        if (_step == 1) {
          setState(() => _step = 0);
        } else {
          context.go('/login');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Registrarse en SearchTeach',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 8),
          Text(
            _step == 0
                ? 'Escribe tu documento para confirmar que tienes una cuenta autorizada.'
                : 'Crea una contraseña para tu cuenta.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5B6270)),
          ),
          const SizedBox(height: 28),
          if (error != null) ErrorBanner(error),
          if (_step == 0)
            _stepDocument(state.isLoading)
          else
            _stepPassword(state.isLoading),
        ],
      ),
    );
  }

  Widget _stepDocument(bool loading) => Form(
        key: _idKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Documento'),
          TextFormField(
            controller: _id,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: fieldDecoration('Tu número de documento'),
            validator: (v) => RegExp(r'^[0-9]{6,10}$').hasMatch(v ?? '')
                ? null
                : 'Debe tener entre 6 y 10 dígitos',
            enabled: !loading && !_checkingId,
            onFieldSubmitted: (_) => _next(loading),
          ),
          const SizedBox(height: 24),
          DarkButton(
            'Continuar',
            loading: loading || _checkingId,
            loadingLabel: 'Verificando documento...',
            onPressed: () => _next(loading),
          ),
        ]),
      );

  Widget _stepPassword(bool loading) => Form(
        key: _passKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Contraseña'),
          TextFormField(
            controller: _pass,
            obscureText: !_showPassword,
            decoration: fieldDecoration('Mínimo 8 caracteres').copyWith(
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Ocultar contraseña' : 'Ver contraseña',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            validator: (v) => (v ?? '').length >= 8 && v!.length <= 72
                ? null
                : 'Debe tener entre 8 y 72 caracteres',
          ),
          const SizedBox(height: 20),
          const FieldLabel('Confirmar contraseña'),
          TextFormField(
            controller: _pass2,
            obscureText: !_showConfirmation,
            decoration: fieldDecoration('Repite la contraseña').copyWith(
              suffixIcon: IconButton(
                tooltip: _showConfirmation
                    ? 'Ocultar contraseña'
                    : 'Ver contraseña',
                onPressed: () => setState(
                    () => _showConfirmation = !_showConfirmation),
                icon: Icon(_showConfirmation
                    ? Icons.visibility_off
                    : Icons.visibility),
              ),
            ),
            validator: (v) =>
                v == _pass.text ? null : 'Las contraseñas no coinciden',
            onFieldSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 24),
          DarkButton(
            'Crear cuenta',
            loading: loading,
            loadingLabel: 'Creando cuenta...',
            onPressed: _register,
          ),
        ]),
      );
}
