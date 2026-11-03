import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_error.dart';

class AppErrorPage extends StatelessWidget {
  const AppErrorPage({
    super.key,
    this.error,
    this.info = const AppErrorInfo(AppErrorKind.server),
  });

  final Object? error;
  final AppErrorInfo info;

  bool get isNotFound => info.kind == AppErrorKind.notFound;

  @override
  Widget build(BuildContext context) {
    final title = switch (info.kind) {
      AppErrorKind.notFound => '¡Ups! Aula equivocada',
      AppErrorKind.forbidden => '¡Ups! No tienes permiso',
      AppErrorKind.connection => '¡Ups! Se perdió la conexión',
      AppErrorKind.server => '¡Ups! El servidor está descansando',
    };
    final message = switch (info.kind) {
      AppErrorKind.notFound =>
        'Parece que esta tutoría está en otra aula. Verifica el enlace e inténtalo de nuevo.',
      AppErrorKind.forbidden =>
        'Esta sección no está disponible para tu rol. Puedes volver al inicio de sesión.',
      AppErrorKind.connection =>
        'No pudimos comunicarnos con SearchTeach. Revisa tu conexión e inténtalo nuevamente.',
      AppErrorKind.server =>
        'El servidor está tomando un descanso. Intenta nuevamente en unos instantes.',
    };
    final canRetry = info.kind == AppErrorKind.connection ||
        info.kind == AppErrorKind.server;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${info.statusCode}',
                      style: const TextStyle(
                        color: Color(0xFFA9154F),
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF202438),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF687083),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => canRetry
                          ? context.go('/session')
                          : context.go('/login'),
                      icon: const Icon(Icons.login_rounded),
                      label: Text(canRetry
                          ? 'Reintentar'
                          : 'Volver al inicio de sesión'),
                    ),
                    if (canRetry)
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Ir al inicio de sesión'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
