import 'package:flutter/material.dart';

import '../pa/pa_widgets.dart';
import 'director_dashboard_provider.dart';
import 'director_widgets.dart';

/// Datos históricos disponibles y estimación de asistencia por materia.
class AttendancePredictionPage extends StatelessWidget {
  const AttendancePredictionPage({required this.dashboard, super.key});

  final DirectorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final training = dashboard.datosModeloAsistencia;
    final available = dashboard.modeloAsistenciaDisponible;

    return PaScaffold(
      title: 'Datos históricos disponibles',
      subtitle: 'Historial y estimación de asistencia por materia',
      children: [
        const PaSection('Resumen histórico'),
        PaKpiRow([
          ('${training.asistencias}', 'Asistencias'),
          ('${training.inasistencias}', 'Inasistencias'),
          ('${training.registrosEtiquetados}', 'Total evaluados'),
        ]),
        const PaSection('Detalle de registros históricos'),
        PaRowList([
          _metric('Registros con resultado', training.registrosEtiquetados),
          _metric('Asistencias confirmadas', training.asistencias),
          _metric('Inasistencias registradas', training.inasistencias),
          _metric('Realizadas sin asistencia registrada',
              training.registrosSinEtiqueta),
          _metric('Programadas sin evaluación',
              dashboard.tutoriasProgramadasNoEvaluables),
        ]),
        const SizedBox(height: 12),
        const PaSection('Estimación de asistencia por materia'),
        PaInfo(
          available
              ? 'Estimación generada a partir de los datos históricos del programa.'
              : 'No hay datos suficientes o el modelo no está disponible.',
          tone: available ? PaTone.ok : PaTone.error,
          icon: available
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
        ),
        if (!available)
          const PaCard(child: PaEmpty('El modelo histórico no está disponible.'))
        else
          DirHBars(
            items: [
              for (final prediction in dashboard.prediccionesAsistencia)
                DirHBar(
                  prediction.materia,
                  prediction.probabilidadAsistenciaPromedio
                      .clamp(0.0, 1.0)
                      .toDouble(),
                  '${(prediction.probabilidadAsistenciaPromedio * 100).round()}%',
                ),
            ],
            footer: dashboard.prediccionesAsistencia.isEmpty
                ? 'No hay tutorías futuras compatibles con los registros históricos.'
                : 'Probabilidad promedio calculada para las tutorías programadas.',
          ),
      ],
    );
  }

  Widget _metric(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(child: Text(label, style: neuBody(size: 14))),
          Text('$value', style: neuPoppins(size: 15, color: Neu.heading)),
        ]),
      );
}
