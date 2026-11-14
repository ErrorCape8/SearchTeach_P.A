import 'package:flutter/material.dart';

import '../pa/pa_widgets.dart';
import 'director_dashboard_provider.dart';
import 'director_widgets.dart';

String _pct(double? value) => value == null ? '—' : '${value.round()}%';

// ═════════════════════════════════════════════════════════════════════════════
//  INICIO
// ═════════════════════════════════════════════════════════════════════════════

class DirHomeView extends StatelessWidget {
  const DirHomeView({
    required this.data,
    required this.onOpenForecast,
    required this.onOpenProjects,
    super.key,
  });

  final DirectorDashboard data;
  final VoidCallback onOpenForecast;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final next = data.proximaSemanaTotal;
    final weeks = data.ultimasSemanas;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PaKpiRow([
        ('${data.tutoriasRealizadas}', 'Tutorías dadas'),
        (_pct(data.tasaAsistencia), 'Asistencia'),
        ('—', 'Satisfacción'),
      ]),
      // Tarjeta "Próxima semana"
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          child: NeuSurface(
            radius: 20,
            padding: const EdgeInsets.all(14),
            onTap: onOpenForecast,
            child: Row(children: [
              NeuSurface(
                radius: 16,
                shadows: Neu.raiseS,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.bar_chart_rounded, size: 26, color: p.c),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next == null
                            ? 'Próxima semana: sin pronóstico'
                            : 'Próxima semana: ~$next tutorías',
                        style: neuPoppins(size: 16, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next == null
                            ? 'Se necesitan al menos cuatro semanas de datos · ver pronóstico'
                            : 'Según los datos de la semana pasada · ver pronóstico',
                        style: neuBody(size: 13, color: Neu.muted, height: 1.3),
                      ),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 26, color: Neu.chevron),
            ]),
          ),
        ),
      ),
      const PaSection('¿Cómo van las tutorías?'),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: PaKpi('${data.countStatus(DirStatus.bien)}', 'Bien',
                  color: Neu.okFg)),
          const SizedBox(width: 10),
          Expanded(
              child: PaKpi(
                  '${data.countStatus(DirStatus.atencion)}', 'Atención',
                  color: Neu.warnFg)),
          const SizedBox(width: 10),
          Expanded(
              child: PaKpi('${data.countStatus(DirStatus.critico)}', 'Crítico',
                  color: Neu.errFg)),
        ]),
      ),
      const PaSection('Tutorías por semana'),
      DirBarChart(
        height: 130,
        bars: [
          for (var i = 0; i < weeks.length; i++)
            DirBar('S${i + 1}', weeks[i].total.toDouble()),
        ],
      ),
      const PaSection('Más información'),
      PaRowList([
        DirRow(
          icon: Icons.groups_outlined,
          title: 'Proyectos de aula',
          subtitle: 'Estado de los proyectos inscritos',
          onTap: onOpenProjects,
        ),
      ]),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TUTORÍAS
// ═════════════════════════════════════════════════════════════════════════════

class DirTutoriasView extends StatelessWidget {
  const DirTutoriasView({required this.data, super.key});

  final DirectorDashboard data;

  @override
  Widget build(BuildContext context) {
    final subjects = data.tutoriasPorMateria;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PaRowList(
        [
          for (final s in subjects)
            DirRow(
              title: s.materia,
              subtitle:
                  '${s.tutoriasRealizadas} dadas · ${s.programadas} programadas · asistencia ${s.asistenciaTexto}',
              trailing: PaTag(dirStatusOf(s.tasaAsistencia).label,
                  tone: dirStatusOf(s.tasaAsistencia).tone),
            ),
        ],
        empty: 'Todavía no hay tutorías registradas por materia.',
      ),
      const PaSection('Asistencia por materia'),
      DirHBars(
        items: [
          for (final s in subjects)
            if (s.tasaAsistencia != null)
              DirHBar(
                  s.materia,
                  (s.tasaAsistencia! / 100).clamp(0.0, 1.0).toDouble(),
                  '${s.tasaAsistencia!.round()}%'),
        ],
        footer: 'Las materias con menos asistencia necesitan más apoyo.',
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CALIDAD
// ═════════════════════════════════════════════════════════════════════════════

class DirCalidadView extends StatelessWidget {
  const DirCalidadView({required this.data, super.key});

  final DirectorDashboard data;

  String _detail(SubjectTutoringSummary s) {
    final rate = s.tasaAsistencia;
    if (rate == null) return 'Aún no hay asistencia registrada.';
    final text = '${rate.round()}%';
    return switch (dirStatusOf(rate)) {
      DirStatus.critico => 'Asistencia baja ($text): conviene reforzar el apoyo.',
      DirStatus.atencion => 'Revisar: asistencia $text.',
      _ => 'Buena asistencia ($text).',
    };
  }

  @override
  Widget build(BuildContext context) {
    final subjects = data.tutoriasPorMateria;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PaInfo('Nunca se muestra quién califica.',
          icon: Icons.lock_outline_rounded),
      const SizedBox(height: 2),
      PaCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Servicio de tutorías', style: neuPoppins(size: 16)),
          const PaEmpty(
              'Aún no hay calificaciones registradas. Cuando existan, se mostrarán aquí sin identificar a quien califica.'),
        ]),
      ),
      const PaSection('Estado de cada materia'),
      PaRowList(
        [
          for (final s in subjects)
            DirRow(
              title: s.materia,
              subtitle: _detail(s),
              trailing: PaTag(dirStatusOf(s.tasaAsistencia).label,
                  tone: dirStatusOf(s.tasaAsistencia).tone),
            ),
        ],
        empty: 'Todavía no hay materias con tutorías registradas.',
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PRONÓSTICO
// ═════════════════════════════════════════════════════════════════════════════

class DirForecastView extends StatelessWidget {
  const DirForecastView({
    required this.data,
    required this.onOpenAttendance,
    super.key,
  });

  final DirectorDashboard data;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final next = data.proximaSemanaTotal;
    final trend = data.tendencia;
    final weeks = data.ultimasSemanas;
    final perSubject = data.pronosticoPorMateria;

    if (next == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PaInfo(
            'Todavía no hay pronósticos. El modelo necesita al menos cuatro semanas de datos históricos y una materia compatible.',
            icon: Icons.info_outline_rounded),
        _attendanceEntry(),
      ]);
    }

    final (trendText, trendTone) = switch (trend) {
      'sube' => ('Tendencia: sube', PaTone.ok),
      'baja' => ('Tendencia: baja', PaTone.warn),
      _ => ('Tendencia: estable', PaTone.neutral),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PaInfo(
          'Se tomaron los datos de la semana pasada para predecir. La próxima semana se verá así:'),
      PaCard(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(children: [
          Text('Tutorías estimadas para la próxima semana',
              textAlign: TextAlign.center,
              style: neuBody(size: 14, color: Neu.muted)),
          const SizedBox(height: 6),
          Text('~$next',
              style: neuPoppins(
                  size: 46, weight: FontWeight.w700, color: p.c, height: 1.15)),
          const SizedBox(height: 10),
          PaTag(trendText, tone: trendTone),
        ]),
      ),
      PaCard(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Histórico y pronóstico', style: neuPoppins(size: 16)),
                const SizedBox(height: 12),
                // La gráfica ya incluye su propia tarjeta; aquí solo se usa
                // la caja exterior para el título.
                _InnerChart(
                  bars: [
                    for (var i = 0; i < weeks.length; i++)
                      DirBar('S${i + 1}', weeks[i].total.toDouble()),
                    DirBar('P1', next.toDouble(), light: true),
                  ],
                ),
              ]),
        ),
      ),
      const PaSection('Por materia · próxima semana'),
      DirBarChart(
        height: 150,
        showValues: true,
        labelLines: 2,
        bars: [
          for (final item in perSubject)
            DirBar(item.materia, item.total.toDouble()),
        ],
        caption:
            'Tutorías previstas para la próxima semana en cada materia.',
      ),
      _attendanceEntry(),
    ]);
  }

  Widget _attendanceEntry() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PaSection('Asistencia'),
          PaRowList([
            DirRow(
              icon: Icons.query_stats_rounded,
              title: 'Predicción de asistencia',
              subtitle: 'Probabilidad estimada por materia',
              onTap: onOpenAttendance,
            ),
          ]),
        ],
      );
}

/// Gráfica sin tarjeta propia, para anidarla dentro de otra tarjeta con título.
class _InnerChart extends StatelessWidget {
  const _InnerChart({required this.bars});

  final List<DirBar> bars;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final light = Color.lerp(Colors.white, p.c, .55)!;
    final maximum = bars.fold<double>(
        1, (largest, bar) => bar.value > largest ? bar.value : largest);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 120,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final bar in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.5),
                child: LayoutBuilder(builder: (context, box) {
                  final h = (box.maxHeight * (bar.value / maximum))
                      .clamp(6.0, box.maxHeight)
                      .toDouble();
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: bar.light ? light : p.c,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        for (final bar in bars)
          Expanded(
            child: Text(bar.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: neuBody(size: 10, color: Neu.muted)),
          ),
      ]),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text('S = semanas pasadas · P = pronóstico (barra clara).',
            style: neuBody(size: 12, color: Neu.muted)),
      ),
    ]);
  }
}
