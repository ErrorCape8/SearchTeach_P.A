import 'package:flutter/material.dart';
import 'director_dashboard_provider.dart';

const _forecastPurple = Color(0xFF6337BF);
const _forecastInk = Color(0xFF28243A);
const _forecastMuted = Color(0xFF777487);

class DemandForecastPage extends StatelessWidget {
  const DemandForecastPage({required this.subjects, super.key});

  final List<SubjectTutoringSummary> subjects;

  @override
  Widget build(BuildContext context) {
    final forecastSubjects = subjects
        .where((subject) => subject.pronostico?.prediccionesSemanales.length == 4)
        .toList()
      ..sort((left, right) => (right.pronostico?.estimadoProximasCuatroSemanas ?? 0)
          .compareTo(left.pronostico?.estimadoProximasCuatroSemanas ?? 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pronóstico semanal de tutorías',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: _forecastInk),
        ),
        const SizedBox(height: 5),
        const Text(
          'Estimaciones por materia para cada una de las próximas cuatro semanas, calculadas con las solicitudes guardadas.',
          style: TextStyle(color: _forecastMuted),
        ),
        const SizedBox(height: 16),
        if (forecastSubjects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Todavía no hay pronósticos. El modelo necesita al menos cuatro semanas de datos históricos y una materia compatible.',
                style: TextStyle(color: _forecastMuted),
              ),
            ),
          )
        else
          for (final subject in forecastSubjects) ...[
            _SubjectForecastCard(subject: subject),
            const SizedBox(height: 12),
          ],
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'El modelo REPTree usa las últimas cuatro semanas completas de cada materia. Cada resultado semanal alimenta la siguiente predicción.',
              style: TextStyle(color: _forecastMuted, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectForecastCard extends StatelessWidget {
  const _SubjectForecastCard({required this.subject});

  final SubjectTutoringSummary subject;

  @override
  Widget build(BuildContext context) {
    final forecast = subject.pronostico!;
    final maximum = forecast.prediccionesSemanales
        .map((week) => week.total)
        .fold<int>(0, (largest, value) => value > largest ? value : largest);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject.materia,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _forecastInk)),
            const SizedBox(height: 4),
            Text(
              'Estimado para cuatro semanas: ${forecast.estimadoProximasCuatroSemanas} tutorías · Modelo ${forecast.modelo}',
              style: const TextStyle(color: _forecastMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            for (final week in forecast.prediccionesSemanales) ...[
              Row(
                children: [
                  SizedBox(
                    width: 102,
                    child: Text(
                      'Semana ${_formatDate(week.semanaInicio)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _forecastInk),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: maximum == 0 ? 0 : week.total / maximum,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(8),
                      color: _forecastPurple,
                      backgroundColor: const Color(0xFFEAE2FA),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 28,
                    child: Text('${week.total}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _forecastPurple)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
