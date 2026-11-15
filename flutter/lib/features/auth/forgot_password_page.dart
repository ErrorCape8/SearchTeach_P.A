import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/auth_shell.dart';
import '../../core/widgets/role_toast.dart';
import 'auth_controller.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _identifier = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  int _step = 0;
  bool _codeVerified = false;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  String? _validationError;

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
    final idText = _identifier.text.trim();
    final emailText = _email.text.trim();
    if (!RegExp(r'^[0-9]{6,10}$').hasMatch(idText)) {
      setState(() => _validationError =
          'La identificación debe tener entre 6 y 10 dígitos.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailText)) {
      setState(() => _validationError =
          'Escribe un correo electrónico institucional válido.');
      return;
    }
    setState(() {
      _validationError = null;
      _sendingCode = true;
    });
    try {
      final sent = await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(idText, emailText);
      if (sent && mounted) {
        setState(() {
          _step = 1;
          _codeVerified = false;
        });
        RoleToast.show(
          context,
          message: 'Tu código de verificación se envió a tu correo.',
          roleColor: kAuthBlue,
        );
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
    final codeText = _code.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(codeText)) {
      setState(() => _validationError =
          'Escribe bien el código de seis dígitos numéricos.');
      return;
    }
    setState(() {
      _validationError = null;
      _verifyingCode = true;
    });
    try {
      final verified = await ref
          .read(authControllerProvider.notifier)
          .verifyPasswordResetCode(_identifier.text.trim(), codeText);
      if (verified && mounted) {
        setState(() {
          _step = 2;
          _codeVerified = true;
        });
      } else if (mounted) {
        setState(() {
          _validationError =
              'Ese no es el código o no coincide. Escríbelo bien o solicita uno nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  Future<void> _resetPassword(bool loading) async {
    final p1 = _password.text;
    final p2 = _confirmation.text;
    if (p1.length < 8 || p1.length > 72) {
      setState(() => _validationError =
          'La contraseña debe tener entre 8 y 72 caracteres.');
      return;
    }
    if (p1 != p2) {
      setState(() => _validationError = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() => _validationError = null);
    final reset = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(_identifier.text.trim(), p1);
    if (reset && mounted) {
      context.go('/login');
      RoleToast.showSnackBar(
        context,
        const SnackBar(
            content: Text('Contraseña actualizada. Inicia sesión.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final error =
        _validationError ?? ref.read(authControllerProvider.notifier).errorMessage;

    return AuthShell(
      title: 'Recuperar contraseña',
      subtitle: _step == 0
          ? 'Ingresa tu identificación y correo institucional'
          : _step == 1
              ? 'Escribe el código de seis dígitos de tu correo'
              : 'Crea una nueva contraseña segura',
      footer: AuthFooterLine(
        '¿Recordaste tu contraseña?',
        'Inicia sesión aquí',
        onTap: () {
          ref.read(authControllerProvider.notifier).reset();
          context.go('/login');
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) AuthNotice(error),
          if (_step == 0)
            _stepIdentity(state.isLoading)
          else if (_step == 1)
            _stepCode(state.isLoading)
          else
            _stepNewPassword(state.isLoading),
        ],
      ),
    );
  }

  Widget _stepIdentity(bool loading) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthLabel('Identificación', first: true),
          AuthField(
            controller: _identifier,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            hint: 'Tu número de documento',
            textInputAction: TextInputAction.next,
          ),
          const AuthLabel('Correo institucional'),
          AuthField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            hint: 'nombre@institucion.edu.co',
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendCode(loading),
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            'Enviar código',
            icon: Icons.send_rounded,
            loading: loading || _sendingCode,
            onPressed: () => _sendCode(loading),
          ),
        ],
      );

  Widget _stepCode(bool loading) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthLabel('Código de verificación', first: true),
          AuthField(
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            hint: '123456',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifyCode(loading),
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            'Verificar código',
            icon: Icons.check_circle_outline_rounded,
            loading: loading || _verifyingCode,
            onPressed: () => _verifyCode(loading),
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            'Reenviar otro código',
            icon: Icons.refresh_rounded,
            onPressed: loading || _sendingCode ? null : () => _sendCode(false),
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            'Atrás',
            icon: Icons.arrow_back_rounded,
            onPressed: () => setState(() => _step = 0),
          ),
        ],
      );

  Widget _stepNewPassword(bool loading) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthLabel('Nueva contraseña', first: true),
          AuthField(
            controller: _password,
            password: true,
            hint: 'Mínimo 8 caracteres',
            textInputAction: TextInputAction.next,
          ),
          const AuthLabel('Confirmar nueva contraseña'),
          AuthField(
            controller: _confirmation,
            password: true,
            hint: 'Repite la nueva contraseña',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _resetPassword(loading),
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            'Guardar contraseña',
            icon: Icons.lock_reset_rounded,
            loading: loading,
            onPressed: () => _resetPassword(loading),
          ),
        ],
      );
}
