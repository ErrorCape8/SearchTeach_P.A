import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repository.dart';
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
    final dashboard = ref.watch(directorDashboardProvider);
    final screen = switch (_selectedTab) {
      0 => _home(dashboard),
      1 => _quality(),
      2 => _forecast(),
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
            const Text('Hola, Dirección', style: TextStyle(fontSize: 18)),
            Text(
              _titles[_selectedTab],
              style: const TextStyle(fontSize: 12, color: Color(0xFFDCD0F6)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(directorDashboardProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_selectedTab),
                child: screen,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.star_outline), label: 'Calidad'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Pronóstico'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _home(AsyncValue<DirectorDashboard> dashboard) => dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _errorState(error),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref
              .refresh(directorDashboardProvider.future)
              .then<void>((_) {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Resumen institucional',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
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
                history: data.historialSemanal,
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
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

  Widget _profile() => _ProfilePage(
        onLogout: () async {
          await ref.read(authRepositoryProvider).logout();
          if (context.mounted) context.go('/login');
        },
      );

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
              isForbidden ? 'Acceso exclusivo para dirección' : 'No se pudo cargar el resumen',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              isForbidden
                  ? 'Esta cuenta no está registrada como coordinadora. Solicita al administrador que autorice su cédula en MongoDB.'
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
                  if (context.mounted) context.go('/login');
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      );
}

class _ForecastPreview extends StatelessWidget {
  const _ForecastPreview({required this.history, required this.onTap});

  final List<WeeklyTutoringCount> history;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reference = WeeklyTutoringReference.fromHistory(history);
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
          reference == null
              ? 'Se requieren 4 semanas completas con actividad'
              : 'Referencia: ~${reference.average.round()} tutorías · promedio reciente',
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
                    Text('S${index + 1}', style: const TextStyle(fontSize: 9, color: _muted)),
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
                style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 3),
              Text(
                '${subject.totalTutorias} tutorías · ${subject.tutoriasRealizadas} realizadas',
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

class _ForecastPage extends StatefulWidget {
  const _ForecastPage({required this.dashboard});

  final DirectorDashboard dashboard;

  @override
  State<_ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<_ForecastPage> {
  int _horizonWeeks = 1;

  @override
  Widget build(BuildContext context) {
    final reference =
        WeeklyTutoringReference.fromHistory(widget.dashboard.historialSemanal);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pronóstico de tutorías',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 5),
        const Text(
          'Referencia basada en actividad observada, no en un modelo predictivo.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Próxima semana')),
            ButtonSegment(value: 4, label: Text('Próximas 4 semanas')),
          ],
          selected: {_horizonWeeks},
          onSelectionChanged: (selection) {
            setState(() => _horizonWeeks = selection.first);
          },
        ),
        const SizedBox(height: 16),
        if (reference != null) ...[
          _SectionCard(
            title: 'Estimación orientativa',
            subtitle: 'Promedio de las últimas 4 semanas completas',
            child: Column(
              children: [
                Text(
                  '~${(reference.average * _horizonWeeks).round()}',
                  style: const TextStyle(
                    color: _purple,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _horizonWeeks == 1
                      ? 'tutorías para la próxima semana'
                      : 'tutorías en las próximas 4 semanas',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rango observado: ${reference.minimum * _horizonWeeks}–${reference.maximum * _horizonWeeks}',
                  style: const TextStyle(color: _ink, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else
          const _InfoNote(
            text:
                'Aún no hay actividad suficiente en las últimas 4 semanas completas para calcular una referencia.',
          ),
        _SectionCard(
          title: 'Histórico de tutorías',
          subtitle: 'Cada barra representa una semana registrada',
          child: _WeeklyChart(widget.dashboard.historialSemanal),
        ),
        const SizedBox(height: 16),
        const _InfoNote(
          text:
              'La cifra usa el promedio de las últimas 4 semanas completas. El rango muestra los valores mínimo y máximo observados en esas semanas; no es un intervalo de confianza ni una garantía.',
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
          child: Text(text, style: const TextStyle(color: _purple, fontSize: 12)),
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
            'Cuenta de dirección',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
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
