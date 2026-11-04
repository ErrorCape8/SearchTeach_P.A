import 'package:flutter/material.dart';
import '../../core/widgets/role_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/auth_shell.dart';
import 'auth_repository.dart';
import 'auth_controller.dart';

/// Registro con verificación previa del correo institucional.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _idKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<FormState>();
  final _passKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  int _step = 0;
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _checkingId = false;
  bool _codeVerified = false;

  @override
  void dispose() {
    _id.dispose();
    _email.dispose();
    _code.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).reset());
  }

  Future<void> _sendCode(bool loading) async {
    if (loading || _checkingId) return;
    if (_step == 0 && !_idKey.currentState!.validate()) return;
    setState(() => _checkingId = true);
    try {
      final valid = await ref
          .read(authControllerProvider.notifier)
          .verifyRegistration(_id.text.trim(), _email.text.trim());
      if (valid && mounted) {
        setState(() {
          _step = 1;
          _codeVerified = false;
        });
      }
    } finally {
      if (mounted) setState(() => _checkingId = false);
    }
  }

  Future<void> _verifyCode(bool loading) async {
    if (_codeVerified) {
      if (mounted) setState(() => _step = 2);
      return;
    }
    if (loading || !_codeKey.currentState!.validate()) return;
    final valid = await ref
        .read(authControllerProvider.notifier)
        .verifyRegistrationCode(_id.text.trim(), _code.text.trim());
    if (valid && mounted) {
      setState(() {
        _step = 2;
        _codeVerified = true;
      });
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
          RoleToast.showSnackBar(
            context,
            SnackBar(content: Text(error.message)),
          );
        }
      }
    } else if (mounted) {
      final error =
          ref.read(authControllerProvider.notifier).errorMessage ?? '';
      if (error.contains('Verifica primero') ||
          error.contains('correo institucional cambió')) {
        setState(() {
          _step = 1;
          _codeVerified = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final error = ref.read(authControllerProvider.notifier).errorMessage;

    return AuthShell(
      onBack: () {
        ref.read(authControllerProvider.notifier).reset();
        if (_step > 0) {
          setState(() => _step--);
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
                ? 'Ingresa tu identificación y correo electrónico institucional.'
                : _step == 1
                    ? 'Escribe el código de seis dígitos enviado a tu correo.'
                    : 'Crea una contraseña para tu cuenta.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5B6270)),
          ),
          const SizedBox(height: 28),
          if (error != null) ErrorBanner(error),
          if (_step == 0)
            _stepDocument(state.isLoading)
          else if (_step == 1)
            _stepCode(state.isLoading)
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
            onFieldSubmitted: (_) => _sendCode(loading),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Correo electrónico institucional'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: fieldDecoration('nombre@institucion.edu.co'),
            validator: (value) {
              final email = (value ?? '').trim();
              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                  ? null
                  : 'Escribe un correo electrónico válido';
            },
            enabled: !loading && !_checkingId,
            onFieldSubmitted: (_) => _sendCode(loading),
          ),
          const SizedBox(height: 24),
          DarkButton(
            'Enviar código',
            loading: loading || _checkingId,
            loadingLabel: 'Validando y enviando correo...',
            onPressed: () => _sendCode(loading),
          ),
        ]),
      );

  Widget _stepCode(bool loading) => Form(
        key: _codeKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Código de verificación'),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: fieldDecoration('123456'),
            validator: (value) => RegExp(r'^[0-9]{6}$').hasMatch(value ?? '')
                ? null
                : 'Ingresa los seis dígitos del correo',
            onFieldSubmitted: (_) => _verifyCode(loading),
          ),
          const SizedBox(height: 18),
          DarkButton(_codeVerified ? 'Continuar' : 'Verificar código',
              loading: loading,
              loadingLabel: 'Verificando...',
              onPressed: () => _verifyCode(loading)),
          if (!_codeVerified)
            TextButton(
              onPressed: loading ? null : () => _sendCode(false),
              child: const Text('Enviar otro código'),
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
                tooltip:
                    _showPassword ? 'Ocultar contraseña' : 'Ver contraseña',
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
                tooltip:
                    _showConfirmation ? 'Ocultar contraseña' : 'Ver contraseña',
                onPressed: () =>
                    setState(() => _showConfirmation = !_showConfirmation),
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
