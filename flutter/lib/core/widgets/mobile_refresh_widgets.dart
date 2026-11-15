import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Breakpoint estándar para considerar la vista como celular/móvil.
const double kMobileViewportBreakpoint = 768.0;

/// Devuelve `true` cuando la app se visualiza en un celular (por ancho de pantalla
/// o por plataforma móvil nativa).
bool isMobileViewport(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < kMobileViewportBreakpoint) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Envoltura global de "Arrastrar hacia abajo para actualizar" (Pull-to-Refresh).
///
/// Usa `AlwaysScrollableScrollPhysics` para garantizar que el gesto de arrastrar
/// hacia abajo funcione INCLUSO cuando la pantalla tiene pocos elementos (como
/// una sola tarjeta de Proyecto de Aula) y no llena todo el alto del celular.
class AppPullToRefresh extends StatelessWidget {
  const AppPullToRefresh({
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.displacement = 36.0,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double displacement;

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).colorScheme.primary;

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      color: primary,
      backgroundColor: backgroundColor ?? Theme.of(context).cardColor,
      displacement: displacement,
      child: child,
    );
  }
}

/// Física de scroll recomendada para todas las listas/pantallas envueltas en
/// [AppPullToRefresh], asegurando que el arrastre hacia abajo siempre responda.
const ScrollPhysics kPullToRefreshPhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

/// Botón de actualización adaptativo:
/// - En celular (`isMobileViewport(context) == true`): se OCULTA por completo
///   porque el usuario actualiza arrastrando hacia abajo (Pull-to-Refresh).
/// - En escritorio/PC (`>= 768px`): muestra el botón clásico de actualizar.
class AdaptiveRefreshButton extends StatelessWidget {
  const AdaptiveRefreshButton({
    required this.onPressed,
    this.isLoading = false,
    this.tooltip = 'Actualizar',
    this.iconColor,
    super.key,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final String tooltip;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    // Ocultar en versión celular para dejar la barra limpia
    if (isMobileViewport(context)) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
              ),
            )
          : Icon(
              Icons.refresh_rounded,
              color: iconColor,
            ),
    );
  }
}

/// Scaffold base reutilizable para cualquier pantalla de SearchTeach que integra:
/// 1) Pull-to-refresh arrastrando hacia abajo (`AppPullToRefresh`).
/// 2) Ocultamiento automático del botón de actualizar en celular (`AdaptiveRefreshButton`).
/// 3) Botón "Volver" que usa `Navigator.maybePop()` / `GoRouter.pop()` sincronizado
///    con el gesto de retroceso del teléfono.
class SearchTeachAdaptiveScaffold extends StatelessWidget {
  const SearchTeachAdaptiveScaffold({
    required this.title,
    required this.onRefresh,
    required this.sliversOrChildren,
    this.subtitle,
    this.isRefreshing = false,
    this.showBackButton = true,
    this.onBackPressed,
    this.extraActions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Future<void> Function() onRefresh;
  final List<Widget> sliversOrChildren;
  final bool isRefreshing;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget> extraActions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                onPressed: onBackPressed ??
                    () async {
                      await Navigator.of(context).maybePop();
                    },
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (subtitle != null && subtitle!.trim().isNotEmpty)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          ...extraActions,
          AdaptiveRefreshButton(
            onPressed: () {
              onRefresh();
            },
            isLoading: isRefreshing,
          ),
        ],
      ),
      body: AppPullToRefresh(
        onRefresh: onRefresh,
        child: ListView(
          physics: kPullToRefreshPhysics,
          padding: padding,
          children: sliversOrChildren,
        ),
      ),
    );
  }
}
