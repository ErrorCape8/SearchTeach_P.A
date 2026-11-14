import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/role_theme.dart';
import '../../core/tutoring_updates.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import '../pa/pa_widgets.dart';
import 'attendance_prediction_page.dart';
import 'director_dashboard_provider.dart';
import 'director_perfil.dart';
import 'director_views.dart';
import 'director_widgets.dart';
import 'proyectos_aula_page.dart';

const _purple = Color(0xFF6337BF);

const _navItems = <(String, IconData)>[
  ('Inicio', Icons.home_outlined),
  ('Tutorías', Icons.book_outlined),
  ('Calidad', Icons.star_border_rounded),
  ('Pronóstico', Icons.bar_chart_rounded),
  ('Perfil', Icons.person_outline_rounded),
];

const _subtitles = <String>[
  '',
  'Información por materia',
  'Calificaciones anónimas',
  'Demanda de tutorías',
  '',
];

String? _nonEmpty(Map<String, dynamic>? data, String key) {
  final value = data?[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  static const _profileTab = 4;
  int _tab = 0;

  void _select(int index) {
    if (index != _tab) setState(() => _tab = index);
  }

  Future<void> _refresh() async {
    ref.invalidate(directorDashboardProvider);
    ref.invalidate(proyectosAulaProvider);
    ref.invalidate(directorProfileProvider);
    ref.invalidate(notificationUnreadCountProvider);
    try {
      await ref.read(directorDashboardProvider.future);
    } catch (_) {
      // El estado de error se muestra en la propia pantalla.
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) {
        ref.invalidate(directorDashboardProvider);
        ref.invalidate(proyectosAulaProvider);
      }
    });

    final profile = ref.watch(directorProfileProvider).asData?.value;
    final fullName = _nonEmpty(profile, 'nombre');
    final roleText = _nonEmpty(profile, 'rol') ?? 'Dirección de programa';
    final theme = Theme.of(context);

    return Theme(
      data: withRoleAccent(
        theme.copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _purple,
            brightness: theme.brightness,
          ).copyWith(primary: _purple),
        ),
        _purple,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark
            .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: Neu.bg,
          body: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 900;
            final content = Column(children: [
              _header(
                wide: wide,
                width: box.maxWidth,
                fullName: fullName,
                roleText: roleText,
              ),
              Expanded(child: _body(wide)),
            ]);
            if (!wide) return content;
            return Row(children: [
              _Sidebar(
                width: box.maxWidth >= 1100 ? 280 : 236,
                selected: _tab,
                onSelect: _select,
                name: fullName ?? 'Líder del programa',
                role: roleText,
                initials: initialsOf(fullName),
                onLogout: _logout,
              ),
              Expanded(child: content),
            ]);
          }),
          bottomNavigationBar: MediaQuery.sizeOf(context).width >= 900
              ? null
              : NeuBottomBar(
                  index: _tab,
                  onSelect: _select,
                  items: [
                    for (final item in _navItems)
                      NeuNavItem(item.$2, item.$1),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Cabecera ──────────────────────────────────────────────────────────────

  Widget _header({
    required bool wide,
    required double width,
    required String? fullName,
    required String roleText,
  }) {
    final firstName = fullName?.split(RegExp(r'\s+')).first;
    final title = switch (_tab) {
      0 => firstName == null ? 'Hola, líder del programa' : 'Hola, $firstName',
      _profileTab => fullName ?? 'Mi perfil',
      _ => _navItems[_tab].$1,
    };
    final subtitle = switch (_tab) {
      0 => '$roleText · solo lectura',
      _profileTab => roleText,
      _ => _subtitles[_tab],
    };
    final unread =
        ref.watch(notificationUnreadCountProvider).asData?.value ?? 0;
    final compact = width < 430;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 28 : 18,
        wide ? 22 : MediaQuery.paddingOf(context).top + 14,
        wide ? 28 : 18,
        16,
      ),
      child: Row(children: [
        SizedBox(
          width: 46,
          height: 46,
          child: NeuSurface(
            radius: 46,
            shadows: Neu.raiseS,
            onTap: () => _select(_profileTab),
            child: Center(
              child: Text(initialsOf(fullName),
                  style: neuPoppins(
                      size: 15, weight: FontWeight.w700, color: _purple)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: neuPoppins(
                      size: wide ? 26 : 20,
                      weight: FontWeight.w700,
                      color: Neu.heading,
                      height: 1.2)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: neuBody(size: 13.5, color: Neu.muted)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (compact)
          NeuCircleButton(
              icon: Icons.sync_rounded,
              tooltip: 'Actualizar',
              onTap: _refresh)
        else
          SizedBox(
            height: 42,
            child: NeuSurface(
              radius: 22,
              shadows: Neu.raiseS,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              onTap: _refresh,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sync_rounded, size: 19, color: _purple),
                const SizedBox(width: 8),
                Text('Actualizar',
                    style: neuPoppins(
                        size: 14, weight: FontWeight.w600, color: _purple)),
              ]),
            ),
          ),
        const SizedBox(width: 12),
        NeuCircleButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Avisos',
          badge: unread,
          onTap: () => context.push('/notificaciones', extra: _purple),
        ),
      ]),
    );
  }

  // ── Contenido ─────────────────────────────────────────────────────────────

  Widget _body(bool wide) {
    final Widget child;
    if (_tab == _profileTab) {
      child = DirPerfilView(onLogout: _logout);
    } else {
      child = ref.watch(directorDashboardProvider).when(
            loading: () => const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _errorState(error),
            data: (data) => switch (_tab) {
              0 => DirHomeView(
                  data: data,
                  onOpenForecast: () => _select(3),
                  onOpenProjects: () => paPush(
                    context,
                    const ProyectosAulaPage(),
                    accent: _purple,
                  ),
                ),
              1 => DirTutoriasView(data: data),
              2 => DirCalidadView(data: data),
              _ => DirForecastView(
                  data: data,
                  onOpenAttendance: () => paPush(
                    context,
                    AttendancePredictionPage(dashboard: data),
                    accent: _purple,
                  ),
                ),
            },
          );
    }

    final side = wide ? 28.0 : 18.0;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: PageStorageKey<int>(_tab),
        padding: EdgeInsets.fromLTRB(
          side,
          4,
          side,
          28 + (wide ? 0 : 8),
        ),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1000 : 760),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Object error) {
    final forbidden =
        error is DioException && error.response?.statusCode == 403;
    return SizedBox(
      height: 420,
      child: DirMessage(
        icon: forbidden ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
        title: forbidden
            ? 'Acceso exclusivo para el líder del programa'
            : 'No se pudo cargar el resumen',
        message: forbidden
            ? 'Esta cuenta no está autorizada como líder del programa. Solicita al administrador que registre tu cédula.'
            : 'Verifica que el servidor esté activo e inténtalo de nuevo.',
        actionLabel: forbidden ? 'Cerrar sesión' : 'Reintentar',
        onAction: forbidden
            ? _logout
            : () => ref.invalidate(directorDashboardProvider),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  BARRA LATERAL (escritorio)
// ═════════════════════════════════════════════════════════════════════════════

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.width,
    required this.selected,
    required this.onSelect,
    required this.name,
    required this.role,
    required this.initials,
    required this.onLogout,
  });

  final double width;
  final int selected;
  final ValueChanged<int> onSelect;
  final String name;
  final String role;
  final String initials;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Neu.bg,
        boxShadow: [
          BoxShadow(color: Neu.shadowDark, offset: Offset(4, 0), blurRadius: 12),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 22),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Image.asset(
                  'assets/images/logo_dir.png',
                  width: 52,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo de SearchTeach',
                  errorBuilder: (_, __, ___) => const SizedBox(width: 52),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(
                              text: 'Search',
                              style: neuPoppins(
                                  size: 21,
                                  weight: FontWeight.w700,
                                  color: Neu.text)),
                          TextSpan(
                              text: 'Teach',
                              style: neuPoppins(
                                  size: 21,
                                  weight: FontWeight.w700,
                                  color: _purple)),
                        ])),
                        Text('CONNECT · LEARN · GROW',
                            style: neuBody(
                                size: 8.5,
                                color: Neu.muted,
                                letterSpacing: 1.6,
                                height: 1.4)),
                        const SizedBox(height: 4),
                        Text('DIRECCIÓN DE PROGRAMA',
                            style: neuBody(
                                size: 11.5,
                                weight: FontWeight.w700,
                                color: _purple,
                                letterSpacing: .8,
                                height: 1.25)),
                      ]),
                ),
              ]),
            ),
            for (var i = 0; i < _navItems.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: NeuSurface(
                    radius: 18,
                    shadows: i == selected ? Neu.raiseS : const [],
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    onTap: () => onSelect(i),
                    child: Row(children: [
                      Icon(_navItems[i].$2,
                          size: 24,
                          color: i == selected ? _purple : Neu.muted),
                      const SizedBox(width: 14),
                      Text(_navItems[i].$1,
                          style: neuPoppins(
                              size: 15.5,
                              weight: FontWeight.w600,
                              color: i == selected ? _purple : Neu.muted)),
                    ]),
                  ),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: Row(children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: NeuSurface(
                    radius: 42,
                    shadows: Neu.raiseS,
                    child: Center(
                      child: Text(initials,
                          style: neuPoppins(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Neu.muted)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: neuPoppins(size: 13.5)),
                        Text(role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: neuBody(size: 12, color: Neu.muted)),
                      ]),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded,
                      size: 22, color: Neu.muted),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
