import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/auth_shell.dart';
import '../../core/widgets/role_toast.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';

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

    return AuthShell(
      title: 'Registro en SearchTeach',
      subtitle: _step == 0
          ? 'Ingresa tu identificación para comenzar'
          : 'Crea tu nueva contraseña de acceso',
      footer: AuthFooterLine(
        '¿Ya tienes una cuenta?',
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
            _stepId(state.isLoading)
          else
            _stepPassword(state.isLoading),
        ],
      ),
    );
  }

  Widget _stepId(bool loading) => Form(
        key: _idKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthLabel('Documento de identificación', first: true),
            AuthField(
              controller: _id,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              hint: 'Tu número de documento',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verifyId(loading),
            ),
            const SizedBox(height: 22),
            AuthPrimaryButton(
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
            const AuthLabel('Nueva contraseña', first: true),
            AuthField(
              controller: _pass,
              password: true,
              hint: 'Mínimo 8 caracteres',
              textInputAction: TextInputAction.next,
            ),
            const AuthLabel('Confirmar contraseña'),
            AuthField(
              controller: _pass2,
              password: true,
              hint: 'Repite la contraseña',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!loading) _register();
              },
            ),
            const SizedBox(height: 22),
            AuthPrimaryButton(
              'Crear cuenta',
              icon: Icons.check_circle_rounded,
              loading: loading,
              onPressed: _register,
            ),
            const SizedBox(height: 12),
            AuthSecondaryButton(
              'Atrás',
              icon: Icons.arrow_back_rounded,
              onPressed: () => setState(() => _step = 0),
            ),
          ],
        ),
      );
}
