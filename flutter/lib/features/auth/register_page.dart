import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/neu/neu.dart';
import '../../core/role_theme.dart';
import '../../core/widgets/role_toast.dart';
import '../pa/pa_widgets.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';

const _authAccent = Color(0xFF1E3FA8);

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
  bool _checkingId = false;
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
    _id.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _verifyId(bool loading) async {
    if (loading || _checkingId) return;
    final doc = _id.text.trim();
    if (!RegExp(r'^[0-9]{6,10}$').hasMatch(doc)) {
      setState(() => _validationError = 'El documento debe tener entre 6 y 10 dígitos.');
      return;
    }
    setState(() {
      _validationError = null;
      _checkingId = true;
    });
    try {
      final valid = await ref
          .read(authControllerProvider.notifier)
          .verifyRegistration(doc, '');
      if (valid && mounted) {
        setState(() => _step = 1);
      }
    } finally {
      if (mounted) setState(() => _checkingId = false);
    }
  }

  Future<void> _register() async {
    final p1 = _pass.text;
    final p2 = _pass2.text;
    if (p1.length < 8 || p1.length > 72) {
      setState(() => _validationError = 'La contraseña debe tener entre 8 y 72 caracteres.');
      return;
    }
    if (p1 != p2) {
      setState(() => _validationError = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() => _validationError = null);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(_id.text.trim(), p1);
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
      if (error.isNotEmpty) {
        RoleToast.showSnackBar(
          context,
          SnackBar(content: Text(error)),
        );
      }
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
                              'Registro en SearchTeach',
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
                                  ? 'Ingresa tu identificación para comenzar'
                                  : 'Crea tu nueva contraseña de acceso',
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
                              _stepId(state.isLoading)
                            else
                              _stepPassword(state.isLoading),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('¿Ya tienes una cuenta? ',
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

  Widget _stepId(bool loading) => Form(
        key: _idKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PaFieldLabel('Documento de identificación', first: true),
            NeuField(
              controller: _id,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              hint: 'Tu número de documento',
            ),
            const SizedBox(height: 22),
            NeuButton(
              'Continuar',
              icon: Icons.arrow_forward_rounded,
              loading: loading || _checkingId,
              onPressed: () => _verifyId(loading),
            ),
          ],
        ),
      );

  Widget _stepPassword(bool loading) => Form(
        key: _passKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PaFieldLabel('Nueva contraseña', first: true),
            NeuField(
              controller: _pass,
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
            const PaFieldLabel('Confirmar contraseña'),
            NeuField(
              controller: _pass2,
              obscure: !_showConfirmation,
              hint: 'Repite la contraseña',
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
              'Crear cuenta',
              icon: Icons.check_circle_rounded,
              loading: loading,
              onPressed: _register,
            ),
            const SizedBox(height: 10),
            NeuButton(
              'Atrás',
              kind: NeuButtonKind.alt,
              icon: Icons.arrow_back_rounded,
              onPressed: () => setState(() => _step = 0),
            ),
          ],
        ),
      );
}
