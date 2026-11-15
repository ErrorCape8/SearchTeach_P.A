import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';

/// Envoltura global para toda la aplicación que intercepta el gesto/botón de
/// retroceso del celular (Android Predictive Back, iOS edge-swipe y PWA Web)
/// para que funcione como botón "Volver" dentro de la app y NO cierre la app
/// accidentalmente.
///
/// Orden de prioridad al retroceder:
/// 1. Si hay un diálogo, bottomSheet o Drawer abierto en el Navigator raíz -> lo cierra.
/// 2. Si existe un callback [onCustomBack] activo (ej. limpiar filtro, volver a tab 0) -> lo ejecuta.
/// 3. Si GoRouter o el Navigator actual puede hacer pop (`canPop()`) -> navega atrás (`pop()`).
/// 4. Si ya está en la pantalla principal (`#/home`) -> pide confirmar deslizando/presionando
///    atrás una segunda vez dentro de 2 segundos antes de salir de la app.
class AppGlobalBackHandler extends StatefulWidget {
  const AppGlobalBackHandler({
    required this.child,
    this.onCustomBack,
    this.homeRoute = '/home',
    this.exitWarningText = 'Desliza o presiona atrás otra vez para salir',
    super.key,
  });

  final Widget child;

  /// Callback opcional para retroceso interno (por ejemplo, volver al tab inicial
  /// o cerrar un panel lateral). Debe devolver `true` si consumió el gesto.
  final bool Function()? onCustomBack;

  /// Ruta principal de inicio. Si el usuario está en otra ruta sin historial previo
  /// (ej. entró por enlace directo), lo redirige aquí antes de salir.
  final String homeRoute;

  final String exitWarningText;

  @override
  State<AppGlobalBackHandler> createState() => _AppGlobalBackHandlerState();
}

class _AppGlobalBackHandlerState extends State<AppGlobalBackHandler> {
  DateTime? _lastBackPressedAt;

  Future<void> _handleBackNavigation(BuildContext context) async {
    // 1. Cerrar modales, bottom sheets o drawers abiertos en el Navigator raíz
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
      return;
    }

    // 2. Ejecutar retroceso personalizado si la pantalla actual lo registró
    if (widget.onCustomBack != null && widget.onCustomBack!()) {
      return;
    }

    // 3. Retroceder en la pila de GoRouter si hay historial disponible
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
        return;
      }

      // Si estamos en una subruta profunda sin pila (ej. recarga en navegador móvil),
      // volver primero a #/home en lugar de cerrar la app.
      final currentLocation =
          router.routerDelegate.currentConfiguration.uri.path;
      if (currentLocation.isNotEmpty &&
          currentLocation != '/' &&
          currentLocation != widget.homeRoute) {
        router.go(widget.homeRoute);
        return;
      }
    }

    // 4. Retroceder en Navigator estándar si aplica
    final localNavigator = Navigator.maybeOf(context);
    if (localNavigator != null && localNavigator.canPop()) {
      localNavigator.pop();
      return;
    }

    // 5. En la raíz (#/home): evitar cierre accidental exigiendo doble gesto
    final now = DateTime.now();
    final isSecondPress = _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);

    if (!isSecondPress) {
      _lastBackPressedAt = now;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(widget.exitWarningText),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      return;
    }

    // Segundo gesto confirmado: permitir salir en móvil nativo
    if (!kIsWeb) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _handleBackNavigation(context);
      },
      child: widget.child,
    );
  }
}

/// Configura el comportamiento de scroll global para que el gesto de arrastrar
/// funcione tanto con touch en celular como con mouse/trackpad en web.
class AppTouchScrollBehavior extends MaterialScrollBehavior {
  const AppTouchScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
