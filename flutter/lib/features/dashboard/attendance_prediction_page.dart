import 'package:flutter/material.dart';

import '../pa/pa_widgets.dart';
import 'director_dashboard_provider.dart';
import 'director_widgets.dart';

/// Predicción de asistencia (modelo Weka) con el estilo neumórfico.
class AttendancePredictionPage extends StatelessWidget {
  const AttendancePredictionPage({required this.dashboard, super.key});

  final DirectorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final training = dashboard.datosModeloAsistencia;
    final available = dashboard.modeloAsistenciaDisponible;

    return PaScaffold(
      title: 'Predicción de asistencia',
      subtitle: 'Probabilidad estimada por materia',
      children: [
        PaInfo(
          available
              ? 'Modelo Weka Logistic cargado. Las predicciones se generaron con el modelo adjunto.'
              : 'No se pudo cargar el modelo Weka. No hay predicciones disponibles.',
          tone: available ? PaTone.ok : PaTone.error,
          icon: available
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
        ),
        const PaInfo(
          'Este modelo se entrenó con datos sintéticos. Sus predicciones sirven para demostrar la integración, pero no son una estimación validada de la asistencia real.',
          icon: Icons.info_outline_rounded,
        ),
        const PaSection('Asistencia estimada por materia'),
        if (!available)
          const PaCard(child: PaEmpty('El modelo no está disponible.'))
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
                ? 'No hay tutorías futuras compatibles con las categorías del modelo.'
                : 'Probabilidad promedio de asistencia en las tutorías programadas.',
          ),
        const PaSection('Datos históricos disponibles'),
        PaRowList([
          _metric('Registros con resultado', training.registrosEtiquetados),
          _metric('Asistencias', training.asistencias),
          _metric('Inasistencias', training.inasistencias),
          _metric('Realizadas sin asistencia registrada',
              training.registrosSinEtiqueta),
          _metric('Programadas sin predicción',
              dashboard.tutoriasProgramadasNoEvaluables),
        ]),
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
