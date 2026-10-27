import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_repository.dart';

class SessionRestorePage extends ConsumerStatefulWidget {
  const SessionRestorePage({super.key});

  @override
  ConsumerState<SessionRestorePage> createState() => _SessionRestorePageState();
}

class _SessionRestorePageState extends ConsumerState<SessionRestorePage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_restore);
  }

  Future<void> _restore() async {
    final auth = ref.read(authRepositoryProvider);
    if (!await auth.hasSession()) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final route = await auth.landingRoute();
      if (mounted) context.go(route);
    } on FormatException {
      await auth.logout();
      if (mounted) context.go('/login');
    } on AuthFailure catch (error) {
      if (!await auth.hasSession()) {
        if (mounted) context.go('/login');
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (!await auth.hasSession()) {
        if (mounted) context.go('/login');
        return;
      }
      if (mounted) {
        setState(() => _error = 'No se pudo verificar la sesion. Revisa tu conexion e intenta de nuevo.');
      }
    }
  }

  Future<void> _forgetSession() async {
    await ref.read(authRepositoryProvider).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() => _error = null);
                          _restore();
                        },
                        child: const Text('Reintentar'),
                      ),
                      TextButton(
                        onPressed: _forgetSession,
                        child: const Text('Ir al inicio de sesion'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}