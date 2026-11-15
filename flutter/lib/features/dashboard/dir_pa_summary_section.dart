import 'package:flutter/material.dart';

import '../pa/pa_widgets.dart';
import 'director_dashboard_provider.dart';

enum PaTutoriaSalud {
  alDia,
  atencion,
  critico,
}

class PaProjectHealthItem {
  const PaProjectHealthItem({
    required this.estudiantesCount,
    required this.tieneTutor,
    required this.estadoProyecto,
    this.tasaAsistenciaTutoriasPa,
    this.tutoriasPaRealizadas = 0,
  });

  final int estudiantesCount;
  final bool tieneTutor;
  final String estadoProyecto;
  final double? tasaAsistenciaTutoriasPa;
  final int tutoriasPaRealizadas;

  PaTutoriaSalud get salud {
    final estado = estadoProyecto.trim().toUpperCase();
    final esCriticoPorEstado = estado.contains('RIESGO') ||
        estado.contains('CRITIC') ||
        estado.contains('CANCEL') ||
        estado.contains('SUSPEND') ||
        estado.contains('VENCID');

    if (!tieneTutor ||
        esCriticoPorEstado ||
        (tasaAsistenciaTutoriasPa != null && tasaAsistenciaTutoriasPa! < 50)) {
      return PaTutoriaSalud.critico;
    }

    final esFinalizado =
        estado.contains('FINALIZ') || estado.contains('COMPLET');
    if (estudiantesCount <= 0 ||
        (!esFinalizado &&
            tutoriasPaRealizadas == 0 &&
            tasaAsistenciaTutoriasPa == null) ||
        (tasaAsistenciaTutoriasPa != null && tasaAsistenciaTutoriasPa! < 75)) {
      return PaTutoriaSalud.atencion;
    }

    return PaTutoriaSalud.alDia;
  }
}

/// Bloque superior de la vista "Proyectos de aula":
/// 1) KPIs de salud de tutorías PA (Al día / Atención / Crítico) filtrables.
/// 2) Tarjeta de pronóstico del modelo predictivo para tutorías de PA.
class DirPaTutoriasSummarySection extends StatelessWidget {
  const DirPaTutoriasSummarySection({
    required this.items,
    this.dashboard,
    this.selectedFilter,
    this.onFilterChanged,
    super.key,
  });

  final List<PaProjectHealthItem> items;
  final DirectorDashboard? dashboard;
  final PaTutoriaSalud? selectedFilter;
  final ValueChanged<PaTutoriaSalud?>? onFilterChanged;

  void _toggleFilter(PaTutoriaSalud target) {
    if (onFilterChanged == null) return;
    onFilterChanged!(selectedFilter == target ? null : target);
  }

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final alDia = items.where((e) => e.salud == PaTutoriaSalud.alDia).length;
    final atencion =
        items.where((e) => e.salud == PaTutoriaSalud.atencion).length;
    final critico =
        items.where((e) => e.salud == PaTutoriaSalud.critico).length;

    final paSummary = dashboard?.resumenPa;
    final paSubjectPred = dashboard?.prediccionesAsistencia
        .where((pred) =>
            pred.materia.toLowerCase().contains('proyecto de aula') ||
            pred.materia.toLowerCase().contains('tutoria pa') ||
            pred.materia.toLowerCase().contains('tutoría pa'))
        .toList();

    final evaluadas = paSummary?.tutoriasPaEvaluadas ??
        paSubjectPred?.fold<int>(0, (acc, e) => acc + e.tutoriasEvaluadas) ??
        0;
    final predichas = paSummary?.asistenciasPaPredichas ??
        paSubjectPred?.fold<int>(
            0, (acc, e) => acc + e.asistenciasPredichas) ??
        0;
    final probPromedio = paSummary?.probabilidadAsistenciaPaPromedio ??
        ((paSubjectPred != null && paSubjectPred.isNotEmpty)
            ? paSubjectPred
                    .map((e) => e.probabilidadAsistenciaPromedio)
                    .reduce((a, b) => a + b) /
                paSubjectPred.length
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PaSection('¿Cómo van las tutorías de PA?'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SelectablePaKpi(
                  value: '$alDia',
                  label: 'Al día',
                  color: Neu.okFg,
                  selected: selectedFilter == PaTutoriaSalud.alDia,
                  onTap: onFilterChanged == null
                      ? null
                      : () => _toggleFilter(PaTutoriaSalud.alDia),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SelectablePaKpi(
                  value: '$atencion',
                  label: 'Atención',
                  color: Neu.warnFg,
                  selected: selectedFilter == PaTutoriaSalud.atencion,
                  onTap: onFilterChanged == null
                      ? null
                      : () => _toggleFilter(PaTutoriaSalud.atencion),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SelectablePaKpi(
                  value: '$critico',
                  label: 'Crítico',
                  color: Neu.errFg,
                  selected: selectedFilter == PaTutoriaSalud.critico,
                  onTap: onFilterChanged == null
                      ? null
                      : () => _toggleFilter(PaTutoriaSalud.critico),
                ),
              ),
            ],
          ),
        ),
        if (dashboard != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: NeuSurface(
              radius: 20,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  NeuSurface(
                    radius: 16,
                    shadows: Neu.raiseS,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child:
                          Icon(Icons.auto_graph_rounded, size: 24, color: p.c),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          evaluadas > 0
                              ? 'Pronóstico PA: ~$predichas asistencias'
                              : 'Pronóstico PA: sin sesiones próximas',
                          style: neuPoppins(size: 15, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          evaluadas > 0
                              ? '$evaluadas cupos programados · probabilidad ${(probPromedio! * 100).round()}%'
                              : 'Las tutorías colectivas de PA se evalúan aquí al programarse',
                          style:
                              neuBody(size: 12.5, color: Neu.muted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectablePaKpi extends StatelessWidget {
  const _SelectablePaKpi({
    required this.value,
    required this.label,
    required this.color,
    required this.selected,
    this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border:
                  Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
            )
          : null,
      child: GestureDetector(
        onTap: onTap,
        child: PaKpi(value, label, color: color),
      ),
    );
  }
}
