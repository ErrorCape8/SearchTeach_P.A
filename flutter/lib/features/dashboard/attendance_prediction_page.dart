import 'package:flutter/material.dart';

import '../pa/pa_widgets.dart';
import 'director_dashboard_provider.dart';
import 'director_widgets.dart';

/// Registros de entrenamiento del modelo (`models/asistencia.arff`).
/// Actualizar este valor cada vez que se reentrene el modelo.
const _modelTrainingRecords = 7796;

/// Actividad registrada en la app y estimación de asistencia por materia.
class AttendancePredictionPage extends StatelessWidget {
  const AttendancePredictionPage({required this.dashboard, super.key});

  final DirectorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final training = dashboard.datosModeloAsistencia;
    final available = dashboard.modeloAsistenciaDisponible;

    return PaScaffold(
      title: 'Asistencia y estimación',
      subtitle: 'Actividad de la app y estimación de asistencia por materia',
      children: [
        const PaSection('Actividad registrada en la app'),
        PaKpiRow([
          ('${training.asistencias}', 'Asistencias'),
          ('${training.inasistencias}', 'Inasistencias'),
          ('${training.registrosEtiquetados}', 'Total con resultado'),
        ]),
        const PaSection('Detalle de registros de la app'),
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
        const PaInfo(
          'El modelo fue entrenado con $_modelTrainingRecords registros '
          'históricos. Los datos de arriba son la actividad registrada en la '
          'app y no se usan para reentrenarlo.',
          tone: PaTone.neutral,
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: 10),
        PaInfo(
          available
              ? 'Estimación generada con el modelo entrenado con registros históricos.'
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
