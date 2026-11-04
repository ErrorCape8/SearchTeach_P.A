import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import '../../core/widgets/sliding_pill_navigation_bar.dart';
import '../../core/tutoring_updates.dart';
import 'director_dashboard_provider.dart';

const _purple = Color(0xFF6337BF);
const _ink = Color(0xFF28243A);
const _muted = Color(0xFF777487);
const _canvas = Color(0xFFF4F5FA);

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) {
        ref.invalidate(directorDashboardProvider);
      }
    });
    final dashboard = ref.watch(directorDashboardProvider);
    final screen = switch (_selectedTab) {
      0 => _home(dashboard),
      1 => _quality(),
      2 => _forecast(),
      _ => _profile(),
    };

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _purple,
          brightness: Theme.of(context).brightness,
        ).copyWith(primary: _purple),
      ),
      child: Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hola, líder del programa',
                  style: TextStyle(fontSize: 18)),
              Text(
                _titles[_selectedTab],
                style: const TextStyle(fontSize: 12, color: Color(0xFFDCD0F6)),
              ),
            ],
          ),
          actions: [
            const NotificationBellButton(accentColor: _purple),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: () {
                ref.invalidate(directorDashboardProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final content = AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_selectedTab),
                  child: screen,
                ),
              );
              if (!isWide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: content,
                  ),
                );
              }
              return Row(
                children: [
                  NavigationRail(
                    backgroundColor: _purple,
                    selectedIndex: _selectedTab,
                    onDestinationSelected: (index) =>
                        setState(() => _selectedTab = index),
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: -0.8,
                    indicatorColor: const Color(0xFF45258A),
                    selectedIconTheme: const IconThemeData(color: Colors.white),
                    unselectedIconTheme: IconThemeData(
                        color: Colors.white.withValues(alpha: .78)),
                    selectedLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Inicio'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.star_outline),
                        label: Text('Calidad'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.bar_chart),
                        label: Text('Pronóstico'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        label: Text('Perfil'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
            ? SlidingPillNavigationBar(
                selectedColor: _purple,
                indicatorColor: const Color(0xFFEAE2FA),
                selectedIndex: _selectedTab,
                onDestinationSelected: (index) =>
                    setState(() => _selectedTab = index),
                destinations: const [
                  SlidingPillDestination(
                      icon: Icons.home_outlined, label: 'Inicio'),
                  SlidingPillDestination(
                      icon: Icons.star_outline, label: 'Calidad'),
                  SlidingPillDestination(
                      icon: Icons.bar_chart, label: 'Pronóstico'),
                  SlidingPillDestination(
                      icon: Icons.person_outline, label: 'Perfil'),
                ],
              )
            : null,
      ),
    );
  }

  Widget _home(AsyncValue<DirectorDashboard> dashboard) => dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _errorState(error),
        data: (data) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(directorDashboardProvider.future).then<void>((_) {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Resumen institucional',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
              ),
              const SizedBox(height: 4),
              const Text(
                'Indicadores calculados a partir de las tutorías registradas.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Tutorías registradas',
                      value: '${data.totalTutorias}',
                      icon: Icons.menu_book_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: 'Asistencia',
                      value: data.tasaAsistencia == null
                          ? 'Sin datos'
                          : '${data.tasaAsistencia!.toStringAsFixed(1)}%',
                      icon: Icons.fact_check_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Realizadas',
                      value: '${data.tutoriasRealizadas}',
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: 'Programadas',
                      value: '${data.tutoriasProgramadas}',
                      icon: Icons.event_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Satisfacción',
                      value: 'Sin datos',
                      icon: Icons.star_outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _quality() => ref.watch(directorDashboardProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _errorState(error),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Calidad de las tutorías',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 5),
            const Text(
              'Seguimiento de asistencia por materia. Las calificaciones todavía no están disponibles.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Materias',
              subtitle: 'Asistencia y tutorías registradas',
              child: _SubjectSummaryList(data.tutoriasPorMateria),
            ),
            const SizedBox(height: 16),
            const _SectionCard(
              title: 'Calificaciones anónimas',
              subtitle: 'Satisfacción de estudiantes y docentes',
              child: _EvaluationEmptyState(),
            ),
            const SizedBox(height: 16),
            const _InfoNote(
              text:
                  'Las tutorías no almacenan calificaciones ni comentarios. Para preservar el anonimato, los resultados futuros solo se mostrarán al alcanzar el mínimo de respuestas definido.',
            ),
          ],
        ),
      );

  Widget _forecast() => ref.watch(directorDashboardProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _errorState(error),
        data: (data) => _ForecastPage(dashboard: data),
      );

  Widget _profile() {
    return _ProfilePage(
      onLogout: () async {
        await ref.read(authRepositoryProvider).logout();
        if (mounted) context.go('/login');
      },
    );
  }

  Widget _errorState(Object error) {
    final isForbidden =
        error is DioException && error.response?.statusCode == 403;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForbidden ? Icons.lock_outline : Icons.cloud_off_outlined,
              size: 44,
              color: _purple,
            ),
            const SizedBox(height: 12),
            Text(
              isForbidden
                  ? 'Acceso exclusivo para el líder del programa'
                  : 'No se pudo cargar el resumen',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              isForbidden
                  ? 'Esta cuenta no está autorizada como líder del programa. Solicita al administrador que registre tu cédula.'
                  : 'Verifica que el servidor esté activo e inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            if (!isForbidden)
              FilledButton.icon(
                onPressed: () => ref.invalidate(directorDashboardProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              )
            else
              TextButton(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).logout();
                  if (mounted) context.go('/login');
                },
                child: const Text('Cerrar sesión'),
              ),
          ],
        ),
      ),
    );
  }
}

const _titles = ['Panel institucional', 'Calidad', 'Pronóstico', 'Perfil'];

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _purple, size: 21),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  color: _purple,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      );
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart(this.weeks, {this.showDates = false});

  final List<WeeklyTutoringCount> weeks;
  final bool showDates;

  @override
  Widget build(BuildContext context) {
    final maximum = weeks.fold<int>(
      0,
      (current, week) => week.total > current ? week.total : current,
    );
    if (weeks.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Aún no hay semanas registradas.',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }
    return SizedBox(
      height: 176,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < weeks.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${weeks[index].total}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final factor = maximum == 0
                              ? 0.035
                              : (weeks[index].total / maximum)
                                  .clamp(0.035, 1.0)
                                  .toDouble();
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              height: constraints.maxHeight * factor,
                              decoration: BoxDecoration(
                                color: _purple,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                        showDates
                            ? '${weeks[index].semanaInicio.day}/${weeks[index].semanaInicio.month}'
                            : 'S${index + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectSummaryList extends StatelessWidget {
  const _SubjectSummaryList(this.subjects);

  final List<SubjectTutoringSummary> subjects;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return const Text(
        'Todavía no hay tutorías registradas por materia.',
        style: TextStyle(color: _muted),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < subjects.length; index++) ...[
          if (index > 0) const Divider(height: 20),
          _SubjectSummaryRow(subject: subjects[index]),
        ],
      ],
    );
  }
}

class _SubjectSummaryRow extends StatelessWidget {
  const _SubjectSummaryRow({required this.subject});

  final SubjectTutoringSummary subject;

  @override
  Widget build(BuildContext context) {
    final rate = subject.tasaAsistencia;
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFEDE6FA),
          child: Icon(Icons.menu_book_outlined, size: 18, color: _purple),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.materia,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 3),
              Text(
                '${subject.totalTutorias} tutorías · ${subject.tutoriasRealizadas} realizadas',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
              const SizedBox(height: 3),
              Text(
                '${subject.estudiantesInscritos} estudiantes · '
                '${subject.asistenciasConfirmadas} asistencias confirmadas '
                'de ${subject.asistenciasRegistradas} registradas',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
              if (rate != null) ...[
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (rate / 100).clamp(0.0, 1.0).toDouble(),
                    minHeight: 5,
                    backgroundColor: const Color(0xFFEDECF2),
                    color: _purple,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          rate == null ? 'Sin datos' : '${rate.toStringAsFixed(0)}%',
          style: const TextStyle(color: _purple, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _DemandForecastCard extends StatelessWidget {
  const _DemandForecastCard({required this.subject});

  final SubjectTutoringSummary subject;

  @override
  Widget build(BuildContext context) {
    final forecast = subject.pronostico;
    final estimate = forecast?.estimadoProximasCuatroSemanas;
    final minimum = forecast?.minimoProximasCuatroSemanas;
    final maximum = forecast?.maximoProximasCuatroSemanas;
    final trendLabel = switch (forecast?.tendencia) {
      'SUBE' => 'Demanda creciente',
      'BAJA' => 'Demanda decreciente',
      'ESTABLE' => 'Demanda estable',
      _ => 'Historial insuficiente',
    };
    final trendColor = switch (forecast?.tendencia) {
      'SUBE' => const Color(0xFFB3261E),
      'BAJA' => const Color(0xFF49628A),
      _ => _muted,
    };

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: const Color(0xFFF9F4FC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject.materia,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                if (forecast?.alertaCreciente ?? false)
                  const Icon(Icons.trending_up, color: Color(0xFFB3261E)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              trendLabel,
              style: TextStyle(
                color: trendColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            if (estimate != null && minimum != null && maximum != null) ...[
              Text(
                '~$estimate solicitudes en 4 semanas',
                style: const TextStyle(
                  color: _purple,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                forecast?.modelo == 'REPTREE'
                    ? 'Predicción REPTree: $minimum–$maximum'
                    : 'Predicción REPTree: $minimum–$maximum',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _WeeklyChart(
                forecast!.prediccionesSemanales,
                showDates: true,
              ),
            ] else
              const Text(
                'Se requieren solicitudes registradas en al menos 4 semanas completas dentro del historial disponible.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationEmptyState extends StatelessWidget {
  const _EvaluationEmptyState();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rate_review_outlined, color: _purple, size: 28),
          SizedBox(height: 10),
          Text(
            'Aún no hay evaluaciones registradas.',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          SizedBox(height: 4),
          Text(
            'No se muestran promedios ni comentarios hasta contar con respuestas reales.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      );
}

class _ForecastPage extends StatelessWidget {
  const _ForecastPage({required this.dashboard});

  final DirectorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final subjects = dashboard.tutoriasPorMateria
        .where(
            (subject) => subject.pronostico?.prediccionesSemanales.length == 4)
        .toList()
      ..sort((left, right) {
        final leftForecast = left.pronostico?.estimadoProximasCuatroSemanas;
        final rightForecast = right.pronostico?.estimadoProximasCuatroSemanas;
        return (rightForecast ?? -1).compareTo(leftForecast ?? -1);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pronóstico de tutorías',
          style:
              TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 5),
        const Text(
          'Pronósticos calculados por el modelo para las próximas cuatro semanas.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 16),
        if (subjects.isEmpty)
          const _InfoNote(
            text:
                'El modelo todavía no puede generar pronósticos. Necesita al menos cuatro semanas completas de solicitudes en una materia compatible.',
          )
        else ...[
          for (final subject in subjects) ...[
            _DemandForecastCard(
              subject: subject,
            ),
            const SizedBox(height: 12),
          ],
        ],
        const _InfoNote(
          text:
              'REPTree predice de forma iterativa usando las últimas 4 semanas completas; requiere al menos 4 semanas de historial. Si el modelo no está disponible o no puede procesar una materia, no se muestra un pronóstico. La tendencia se considera estable cuando el cambio es menor a 1 solicitud o al 10% del promedio de las últimas 4 semanas.',
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEDE6FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Text(text, style: const TextStyle(color: _purple, fontSize: 12)),
        ),
      );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFEDE6FA),
            child: Icon(Icons.person_outline, color: _purple, size: 34),
          ),
          const SizedBox(height: 14),
          const Text(
            'Cuenta del líder del programa',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 6),
          const Text(
            'El nombre y los datos institucionales no están disponibles en el perfil actual.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      );
}
