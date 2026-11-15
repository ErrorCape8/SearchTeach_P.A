import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/neu/neu.dart';
import '../../core/widgets/brand_logo.dart';
import 'auth_repository.dart';
import 'startup_loading_page.dart';

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
        setState(() => _error = 'No se pudo verificar la sesión. Revisa tu conexión e intenta de nuevo.');
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
      backgroundColor: Neu.bg,
      body: Center(
        child: error == null
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(width: 120, height: 74, accentColor: Color(0xFF1E3FA8)),
                      const SizedBox(height: 20),
                      Text(
                        'Restaurando sesión...',
                        style: neuPoppins(size: 16, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 18),
                      const NeuLinearProgressBar(
                        color: Color(0xFF1E3FA8),
                        height: 10,
                      ),
                    ],
                  ),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: NeuSurface(
                    radius: 20,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, color: Neu.error, size: 36),
                        const SizedBox(height: 12),
                        Text(error, textAlign: TextAlign.center, style: neuBody(size: 13.5)),
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
                          child: const Text('Ir al inicio de sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}