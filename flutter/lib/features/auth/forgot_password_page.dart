import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/neu/neu.dart';
import '../../core/role_theme.dart';
import '../../core/widgets/role_toast.dart';
import '../pa/pa_widgets.dart';
import 'auth_controller.dart';

const _authAccent = Color(0xFF1E3FA8);

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
  bool _showPassword = false;
  bool _showConfirmation = false;
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
          roleColor: _authAccent,
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
    final theme = Theme.of(context);

    return Theme(
      data: withRoleAccent(
        theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(primary: _authAccent),
          scaffoldBackgroundColor: Neu.bg,
        ),
        _authAccent,
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
                                  color: _authAccent.withOpacity(0.4),
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
                                color: _authAccent,
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
                                        color: _authAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Aprende y enseña, cuando y donde quieras.',
                                style: neuBody(size: 11.5, color: Neu.muted),
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
                              'Recuperar contraseña',
                              textAlign: TextAlign.center,
                              style: neuPoppins(
                                size: 22,
                                weight: FontWeight.w700,
                                color: Neu.heading,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _step == 0
                                  ? 'Ingresa tu identificación y correo institucional'
                                  : _step == 1
                                      ? 'Escribe el código de seis dígitos de tu correo'
                                      : 'Crea una nueva contraseña segura',
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
                              const SizedBox(height: 12),
                            ],
                            if (_step == 0)
                              _stepIdentity(state.isLoading)
                            else if (_step == 1)
                              _stepCode(state.isLoading)
                            else
                              _stepNewPassword(state.isLoading),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('¿Recordaste tu contraseña? ',
                              style:
                                  neuBody(size: 13.5, color: Neu.muted)),
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .reset();
                              context.go('/login');
                            },
                            child: Text(
                              'Inicia sesión aquí',
                              style: neuBody(
                                size: 13.5,
                                weight: FontWeight.w700,
                                color: _authAccent,
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

  Widget _stepIdentity(bool loading) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PaFieldLabel('Identificación', first: true),
          NeuField(
            controller: _identifier,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            hint: 'Tu número de documento',
          ),
          const SizedBox(height: 14),
          const PaFieldLabel('Correo institucional'),
          NeuField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            hint: 'nombre@institucion.edu.co',
          ),
          const SizedBox(height: 22),
          NeuButton(
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
          const PaFieldLabel('Código de verificación', first: true),
          NeuField(
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            hint: '123456',
          ),
          const SizedBox(height: 22),
          NeuButton(
            'Verificar código',
            icon: Icons.check_circle_outline_rounded,
            loading: loading || _verifyingCode,
            onPressed: () => _verifyCode(loading),
          ),
          const SizedBox(height: 10),
          NeuButton(
            'Reenviar otro código',
            kind: NeuButtonKind.alt,
            icon: Icons.refresh_rounded,
            onPressed: loading || _sendingCode ? null : () => _sendCode(false),
          ),
          const SizedBox(height: 10),
          NeuButton(
            'Atrás',
            kind: NeuButtonKind.alt,
            icon: Icons.arrow_back_rounded,
            onPressed: () => setState(() => _step = 0),
          ),
        ],
      );

  Widget _stepNewPassword(bool loading) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PaFieldLabel('Nueva contraseña', first: true),
          NeuField(
            controller: _password,
            obscure: !_showPassword,
            hint: 'Mínimo 8 caracteres',
            suffix: IconButton(
              onPressed: () =>
                  setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Neu.navIdle,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const PaFieldLabel('Confirmar nueva contraseña'),
          NeuField(
            controller: _confirmation,
            obscure: !_showConfirmation,
            hint: 'Repite la nueva contraseña',
            suffix: IconButton(
              onPressed: () =>
                  setState(() => _showConfirmation = !_showConfirmation),
              icon: Icon(
                _showConfirmation
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Neu.navIdle,
              ),
            ),
          ),
          const SizedBox(height: 22),
          NeuButton(
            'Guardar contraseña',
            icon: Icons.lock_reset_rounded,
            loading: loading,
            onPressed: () => _resetPassword(loading),
          ),
        ],
      );
}
