import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repository.dart';
import 'director_dashboard_provider.dart';
import 'proyectos_aula_page.dart';

const _purple = Color(0xFF6337BF);
const _brandOrange = Color(0xFFEA580C);
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
    final dashboard = ref.watch(directorDashboardProvider);
    final screen = switch (_selectedTab) {
      0 => _home(dashboard),
      1 => _quality(),
      2 => _forecast(),
      3 => const ProyectosAulaPage(),
      _ => _profile(),
    };

    return Scaffold(
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
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () {
              ref.invalidate(directorDashboardProvider);
              ref.invalidate(proyectosAulaProvider);
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
                  backgroundColor: Colors.white,
                  selectedIndex: _selectedTab,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedTab = index),
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.8,
                  indicatorColor: const Color(0xFFFFF1E6),
                  selectedIconTheme: const IconThemeData(color: _brandOrange),
                  unselectedIconTheme:
                      const IconThemeData(color: Color(0xFF8C95A6)),
                  selectedLabelTextStyle: const TextStyle(
                    color: _brandOrange,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelTextStyle:
                      const TextStyle(color: Color(0xFF64748B)),
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
                      icon: Icon(Icons.science_outlined),
                      label: Text('Proyectos'),
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
          ? NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (index) =>
                  setState(() => _selectedTab = index),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined), label: 'Inicio'),
                NavigationDestination(
                    icon: Icon(Icons.star_outline), label: 'Calidad'),
                NavigationDestination(
                    icon: Icon(Icons.bar_chart), label: 'Pronóstico'),
                NavigationDestination(
                    icon: Icon(Icons.science_outlined), label: 'Proyectos'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline), label: 'Perfil'),
              ],
            )
          : null,
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
              const SizedBox(height: 16),
              _ForecastPreview(
                subjects: data.tutoriasPorMateria,
                onTap: () => setState(() => _selectedTab = 2),
              ),
              const SizedBox(height: 22),
              _SectionCard(
                title: 'Tutorías por semana',
                subtitle: 'Últimas 10 semanas',
                child: _WeeklyChart(data.historialSemanal),
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Asistencia por materia',
                subtitle: 'Indicador basado en asistencias registradas',
                child: _SubjectSummaryList(data.tutoriasPorMateria),
              ),
              const SizedBox(height: 12),
              const _InfoNote(
                text:
                    'La asistencia se calcula solo con tutorías finalizadas que tienen el resultado de asistencia registrado.',
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

const _titles = [
  'Panel institucional',
  'Calidad',
  'Pronóstico',
  'Proyectos',
  'Perfil'
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

class _ForecastPreview extends StatelessWidget {
  const _ForecastPreview({required this.subjects, required this.onTap});

  final List<SubjectTutoringSummary> subjects;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final forecasts = subjects
        .map((subject) => subject.pronostico)
        .whereType<PronosticoDemanda>()
        .toList(growable: false);
    final estimated = forecasts.fold<int>(
      0,
      (total, forecast) => total + forecast.estimadoProximaSemana,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEDE6FA),
          child: Icon(Icons.insights_outlined, color: _purple),
        ),
        title: const Text(
          'Próxima semana',
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        subtitle: Text(
          forecasts.isEmpty
              ? 'Se requieren solicitudes en 4 semanas por asignatura'
              : 'Modelo lineal: ~$estimated solicitudes · ${forecasts.length} asignaturas con historial suficiente',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: _muted),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart(this.weeks);

  final List<WeeklyTutoringCount> weeks;

  @override
  Widget build(BuildContext context) {
    final maximum = weeks.fold<int>(
      0,
      (current, week) => week.total > current ? week.total : current,
    );
    return SizedBox(
      height: 144,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < weeks.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${weeks[index].total}',
                      style: const TextStyle(fontSize: 9, color: _muted),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: maximum == 0
                              ? 0.025
                              : (weeks[index].total / maximum)
                                  .clamp(0.025, 1.0)
                                  .toDouble(),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _purple.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('S${index + 1}',
                        style: const TextStyle(fontSize: 9, color: _muted)),
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
  const _DemandForecastCard({
    required this.subject,
    required this.horizonWeeks,
  });

  final SubjectTutoringSummary subject;
  final int horizonWeeks;

  @override
  Widget build(BuildContext context) {
    final forecast = subject.pronostico;
    final estimate = horizonWeeks == 1
        ? forecast?.estimadoProximaSemana
        : forecast?.estimadoProximasCuatroSemanas;
    final minimum = horizonWeeks == 1
        ? forecast?.minimoProximaSemana
        : forecast?.minimoProximasCuatroSemanas;
    final maximum = horizonWeeks == 1
        ? forecast?.maximoProximaSemana
        : forecast?.maximoProximasCuatroSemanas;
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
                '~$estimate solicitudes para '
                '${horizonWeeks == 1 ? 'la próxima semana' : 'las próximas 4 semanas'}',
                style: const TextStyle(
                  color: _purple,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                forecast?.modelo == 'REPTREE'
                    ? 'Rango de referencia lineal: $minimum–$maximum'
                    : 'Intervalo predictivo 95%: $minimum–$maximum',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _WeeklyChart(forecast!.historialSolicitudes),
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

class _ForecastPage extends StatefulWidget {
  const _ForecastPage({required this.dashboard});

  final DirectorDashboard dashboard;

  @override
  State<_ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<_ForecastPage> {
  int _selectedHorizon = 1;

  @override
  Widget build(BuildContext context) {
    final subjects = widget.dashboard.tutoriasPorMateria.toList()
      ..sort((left, right) {
        final leftForecast = _selectedHorizon == 1
            ? left.pronostico?.estimadoProximaSemana
            : left.pronostico?.estimadoProximasCuatroSemanas;
        final rightForecast = _selectedHorizon == 1
            ? right.pronostico?.estimadoProximaSemana
            : right.pronostico?.estimadoProximasCuatroSemanas;
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
          'Regresión lineal por asignatura a partir de solicitudes registradas en MongoDB.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Próxima semana')),
            ButtonSegment(value: 4, label: Text('Próximas 4 semanas')),
          ],
          selected: {_selectedHorizon},
          onSelectionChanged: (selection) {
            setState(() => _selectedHorizon = selection.first);
          },
        ),
        const SizedBox(height: 16),
        if (subjects.isEmpty)
          const _InfoNote(
            text:
                'Aún no hay solicitudes de tutoría registradas por asignatura.',
          )
        else ...[
          for (final subject in subjects) ...[
            _DemandForecastCard(
              subject: subject,
              horizonWeeks: _selectedHorizon,
            ),
            const SizedBox(height: 12),
          ],
        ],
        _SectionCard(
          title: 'Histórico de tutorías',
          subtitle: 'Solicitudes registradas durante las últimas 10 semanas',
          child: _WeeklyChart(widget.dashboard.historialSemanal),
        ),
        const SizedBox(height: 16),
        const _InfoNote(
          text:
              'REPTree predice de forma iterativa usando las últimas 4 semanas completas; requiere al menos 4 semanas de historial. El rango que se muestra para REPTree es una referencia calculada por regresión lineal, no un intervalo calibrado para el árbol. Si REPTree no está disponible o no puede procesar una materia, se usa la regresión lineal. La tendencia se considera estable cuando el cambio es menor a 1 solicitud o al 10% del promedio de las últimas 4 semanas.',
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
