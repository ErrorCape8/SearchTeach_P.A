import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/auth_shell.dart';
import 'auth_controller.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _identityForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  int _step = 0;
  bool _codeVerified = false;
  bool _sendingCode = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).reset());
  }

  @override
  void dispose() {
    _identifier.dispose();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _sendCode(bool loading) async {
    if (loading || _sendingCode) return;
    if (_step == 0 && !_identityForm.currentState!.validate()) return;
    setState(() => _sendingCode = true);
    try {
      final sent = await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(_identifier.text.trim(), _email.text.trim());
      if (sent && mounted) {
        setState(() {
          _step = 1;
          _codeVerified = false;
        });
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyCode(bool loading) async {
    if (_codeVerified) {
      if (mounted) setState(() => _step = 2);
      return;
    }
    if (loading || !_codeForm.currentState!.validate()) return;
    final verified = await ref
        .read(authControllerProvider.notifier)
        .verifyPasswordResetCode(_identifier.text.trim(), _code.text.trim());
    if (verified && mounted) {
      setState(() {
        _step = 2;
        _codeVerified = true;
      });
    }
  }

  Future<void> _resetPassword(bool loading) async {
    if (loading || !_passwordForm.currentState!.validate()) return;
    final reset = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(_identifier.text.trim(), _password.text);
    if (reset && mounted) {
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada. Inicia sesión.')),
      );
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
          const Text('Recuperar contraseña',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 8),
          Text(
            _step == 0
                ? 'Ingresa tu identificación y correo institucional.'
                : _step == 1
                    ? 'Escribe el código de seis dígitos enviado a tu correo.'
                    : 'Crea una contraseña nueva para tu cuenta.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5B6270)),
          ),
          const SizedBox(height: 24),
          if (error != null) ErrorBanner(error),
          if (_step == 0)
            _identityFields(state.isLoading)
          else if (_step == 1)
            _codeFields(state.isLoading)
          else
            _passwordFields(state.isLoading),
        ],
      ),
    );
  }

  Widget _identityFields(bool loading) => Form(
        key: _identityForm,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Identificación'),
          TextFormField(
            controller: _identifier,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: fieldDecoration('Tu número de documento'),
            validator: (value) => RegExp(r'^[0-9]{6,10}$').hasMatch(value ?? '')
                ? null
                : 'Debe tener entre 6 y 10 dígitos',
            enabled: !loading && !_sendingCode,
          ),
          const SizedBox(height: 18),
          const FieldLabel('Correo electrónico institucional'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: fieldDecoration('nombre@institucion.edu.co'),
            validator: (value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                    .hasMatch((value ?? '').trim())
                ? null
                : 'Escribe un correo electrónico válido',
            enabled: !loading && !_sendingCode,
            onFieldSubmitted: (_) => _sendCode(loading),
          ),
          const SizedBox(height: 24),
          DarkButton('Enviar código',
              loading: loading || _sendingCode,
              loadingLabel: 'Enviando código...',
              onPressed: () => _sendCode(loading)),
        ]),
      );

  Widget _codeFields(bool loading) => Form(
        key: _codeForm,
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

  Widget _passwordFields(bool loading) => Form(
        key: _passwordForm,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Nueva contraseña'),
          TextFormField(
            controller: _password,
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
            validator: (value) =>
                (value ?? '').length >= 8 && value!.length <= 72
                    ? null
                    : 'Debe tener entre 8 y 72 caracteres',
          ),
          const SizedBox(height: 18),
          const FieldLabel('Confirmar contraseña'),
          TextFormField(
            controller: _confirmation,
            obscureText: true,
            decoration: fieldDecoration('Repite la nueva contraseña'),
            validator: (value) =>
                value == _password.text ? null : 'Las contraseñas no coinciden',
            onFieldSubmitted: (_) => _resetPassword(loading),
          ),
          const SizedBox(height: 24),
          DarkButton('Guardar contraseña',
              loading: loading,
              loadingLabel: 'Actualizando contraseña...',
              onPressed: () => _resetPassword(loading)),
        ]),
      );
}
