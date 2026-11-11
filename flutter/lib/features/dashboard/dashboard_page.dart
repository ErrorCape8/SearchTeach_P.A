import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repository.dart';
import '../../core/widgets/sliding_pill_navigation_bar.dart';
import '../../core/tutoring_updates.dart';
import '../../core/role_theme.dart';
import '../../core/widgets/role_dashboard_header.dart';
import 'director_dashboard_provider.dart';
import 'demand_forecast_page.dart';
import 'proyectos_aula_page.dart';

const _purple = Color(0xFF6337BF);
const _ink = Color(0xFF28243A);
const _muted = Color(0xFF777487);
const _canvas = Color(0xFFF5F7FB);

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
        ref.invalidate(proyectosAulaProvider);
      }
    });
    final dashboard = ref.watch(directorDashboardProvider);
    final screen = switch (_selectedTab) {
      0 => _home(dashboard),
      1 => _tutoringOverview(),
      2 => _quality(),
      3 => _forecast(),
      4 => const ProyectosAulaPage(),
      5 => _attendance(),
      _ => _profile(),
    };

    return Theme(
      data: withRoleAccent(
        Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _purple,
            brightness: Theme.of(context).brightness,
          ).copyWith(primary: _purple),
        ),
        _purple,
      ),
      child: Scaffold(
        backgroundColor: _canvas,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final content = AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_selectedTab),
                child: screen,
              ),
            );
            final page = Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 1440 : 720,
                ),
                child: Padding(
                  padding: EdgeInsets.all(isWide ? 20 : 0),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: content,
                  ),
                ),
              ),
            );
            final roleHeader = RoleDashboardHeader(
              title: _selectedTab == 0
                  ? 'Hola, líder del programa'
                  : _titles[_selectedTab],
              subtitle: _selectedTab == 0
                  ? 'Dirección de programa'
                  : 'Dirección de programa · SearchTeach',
              accentColor: _purple,
              darkColor: const Color(0xFF4B2A96),
              initials: 'DP',
              onRefresh: () {
                ref.invalidate(directorDashboardProvider);
                ref.invalidate(proyectosAulaProvider);
              },
              onNotifications: () =>
                  context.push('/notificaciones', extra: _purple),
              onProfile: () => setState(
                () => _selectedTab = _selectedTab == 6 ? 0 : 6,
              ),
            );
            if (!isWide) {
              return Column(
                children: [
                  roleHeader,
                  Expanded(child: page),
                ],
              );
            }
            return Row(
              children: [
                NavigationRail(
                  backgroundColor: Colors.white,
                  selectedIndex: _selectedTab < 5 ? _selectedTab : null,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedTab = index),
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.8,
                  indicatorColor: const Color(0xFFEAE2FA),
                  selectedIconTheme: const IconThemeData(color: _purple),
                  unselectedIconTheme: const IconThemeData(color: _muted),
                  selectedLabelTextStyle: const TextStyle(
                    color: _purple,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelTextStyle: const TextStyle(color: _muted),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Inicio'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.event_note_outlined),
                      selectedIcon: Icon(Icons.event_note),
                      label: Text('Tutor\u{00ED}as'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.star_outline),
                      label: Text('Calidad'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.query_stats_outlined),
                      label: Text('Pron\u{00F3}stico'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.groups_outlined),
                      label: Text('Proyectos'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Column(
                    children: [
                      roleHeader,
                      Expanded(child: page),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
            ? SlidingPillNavigationBar(
                selectedColor: _purple,
                indicatorColor: const Color(0xFFEAE2FA),
                selectedIndex: _selectedTab < 5 ? _selectedTab : 0,
                onDestinationSelected: (index) =>
                    setState(() => _selectedTab = index),
                destinations: const [
                  SlidingPillDestination(
                      icon: Icons.home_outlined, label: 'Inicio'),
                  SlidingPillDestination(
                      icon: Icons.event_note_outlined,
                      selectedIcon: Icons.event_note,
                      label: 'Tutor\u{00ED}as'),
                  SlidingPillDestination(
                      icon: Icons.star_outline, label: 'Calidad'),
                  SlidingPillDestination(
                      icon: Icons.query_stats_outlined,
                      label: 'Pron\u{00F3}stico'),
                  SlidingPillDestination(
                      icon: Icons.groups_outlined, label: 'Proyectos'),
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
                      title: 'Tutor\u{00ED}as realizadas',
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
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedTab = 5),
                icon: const Icon(Icons.query_stats_outlined),
                label: const Text('Ver predicci\u{00F3}n de asistencia'),
              ),
            ],
          ),
        ),
      );

  Widget _tutoringOverview() => ref.watch(directorDashboardProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _errorState(error),
        data: (data) {
          final maximum = data.historialSemanal.fold<int>(
            1,
            (largest, week) => week.total > largest ? week.total : largest,
          );
          return RefreshIndicator(
            onRefresh: () => ref
                .refresh(directorDashboardProvider.future)
                .then<void>((_) {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Actividad de tutor\u{00ED}as',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Resumen de sesiones y participaci\u{00F3}n por materia.',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Tutor\u{00ED}as realizadas',
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
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Por materia',
                  subtitle: 'Sesiones registradas y asistencia confirmada',
                  child: _SubjectSummaryList(data.tutoriasPorMateria),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Actividad semanal',
                  subtitle: 'Tutor\u{00ED}as registradas por semana',
                  child: data.historialSemanal.isEmpty
                      ? const Text(
                          'Todav\u{00ED}a no hay actividad registrada.')
                      : Column(
                          children: [
                            for (final week
                                in data.historialSemanal.reversed.take(8))
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 96,
                                      child: Text(
                                        '${week.semanaInicio.day}/${week.semanaInicio.month}',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: week.total / maximum,
                                        minHeight: 9,
                                        borderRadius: BorderRadius.circular(8),
                                        color: _purple,
                                        backgroundColor:
                                            const Color(0xFFEDE6FA),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${week.total}',
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
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

  Widget _attendance() => ref.watch(directorDashboardProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _errorState(error),
        data: (data) => _AttendancePredictionPage(dashboard: data),
      );

  Widget _forecast() => ref.watch(directorDashboardProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _errorState(error),
        data: (data) => DemandForecastPage(
          subjects: data.tutoriasPorMateria,
        ),
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

const _titles = [
  'Panel institucional',
  'Tutor\u{00ED}as',
  'Calidad',
  'Pron\u{00F3}stico',
  'Proyectos',
  'Asistencia',
  'Perfil',
];

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

class _AttendancePredictionPage extends StatelessWidget {
  const _AttendancePredictionPage({required this.dashboard});

  final DirectorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final trainingData = dashboard.datosModeloAsistencia;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Predicción de asistencia',
          style:
              TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 5),
        const Text(
          'Objetivo: estimar la probabilidad de asistencia de tutorías programadas.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Estado del modelo',
          subtitle: dashboard.modeloAsistenciaDisponible
              ? 'Weka Logistic cargado'
              : 'No se pudo cargar el modelo Weka',
          child: Row(
            children: [
              Icon(
                dashboard.modeloAsistenciaDisponible
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: dashboard.modeloAsistenciaDisponible
                    ? _purple
                    : const Color(0xFFB3261E),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dashboard.modeloAsistenciaDisponible
                      ? 'Las predicciones siguientes se generaron con el modelo adjunto.'
                      : 'No hay predicciones disponibles mientras el modelo no cargue.',
                  style: const TextStyle(color: _muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _InfoNote(
          text:
              'Este modelo se entrenó con datos sintéticos. Sus predicciones sirven para demostrar la integración, pero no son una estimación validada de la asistencia real.',
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Tutor\u{00ED}as realizadas',
          subtitle: 'Probabilidad promedio estimada por materia',
          child: !dashboard.modeloAsistenciaDisponible
              ? const Text(
                  'El modelo no está disponible.',
                  style: TextStyle(color: _muted),
                )
              : dashboard.prediccionesAsistencia.isEmpty
                  ? const Text(
                      'No hay tutorías futuras compatibles con las categorías del modelo.',
                      style: TextStyle(color: _muted),
                    )
                  : Column(
                      children: [
                        for (var index = 0;
                            index < dashboard.prediccionesAsistencia.length;
                            index++) ...[
                          if (index > 0) const Divider(height: 20),
                          _AttendancePredictionRow(
                            prediction: dashboard.prediccionesAsistencia[index],
                          ),
                        ],
                      ],
                    ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Datos históricos disponibles',
          subtitle: 'Tutorías realizadas con asistencia registrada',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReadinessMetric(
                label: 'Registros con resultado',
                value: trainingData.registrosEtiquetados,
              ),
              const Divider(height: 20),
              _ReadinessMetric(
                label: 'Asistencias',
                value: trainingData.asistencias,
              ),
              const SizedBox(height: 10),
              _ReadinessMetric(
                label: 'Inasistencias',
                value: trainingData.inasistencias,
              ),
              const SizedBox(height: 10),
              _ReadinessMetric(
                label: 'Realizadas sin asistencia registrada',
                value: trainingData.registrosSinEtiqueta,
              ),
              const SizedBox(height: 10),
              _ReadinessMetric(
                label: 'Programadas sin predicción',
                value: dashboard.tutoriasProgramadasNoEvaluables,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendancePredictionRow extends StatelessWidget {
  const _AttendancePredictionRow({required this.prediction});

  final SubjectAttendancePrediction prediction;

  @override
  Widget build(BuildContext context) {
    final probability =
        (prediction.probabilidadAsistenciaPromedio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                prediction.materia,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            Text(
              '$probability% asistencia estimada',
              style: const TextStyle(
                color: _purple,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${prediction.tutoriasEvaluadas} tutorías · '
          '${prediction.asistenciasPredichas} con asistencia probable · '
          '${prediction.inasistenciasPredichas} con inasistencia probable',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ReadinessMetric extends StatelessWidget {
  const _ReadinessMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: _muted)),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
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
