import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

final proyectosAulaProvider =
    FutureProvider.autoDispose<List<_TutoriaColectivaVista>>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/direccion/tutorias-colectivas');
  final data = response.data;
  if (data == null) {
    throw const FormatException(
        'El servidor devolvió una lista de proyectos inválida.');
  }
  return data.map((entry) {
    if (entry is! Map<String, dynamic> ||
        entry['tutoriaColectiva'] is! Map<String, dynamic> ||
        entry['proyectos'] is! List) {
      throw const FormatException(
          'Un grupo de tutorías tiene datos inválidos.');
    }
    final projects = (entry['proyectos'] as List).map((item) {
      if (item is! Map<String, dynamic> ||
          item['proyecto'] is! Map<String, dynamic> ||
          item['informes'] is! List ||
          item['pronosticoMejora'] is! Map<String, dynamic>) {
        throw const FormatException(
            'Un resumen de proyecto tiene datos inválidos.');
      }
      final project = item['proyecto'] as Map<String, dynamic>;
      final forecast = item['pronosticoMejora'] as Map<String, dynamic>;
      if (project['nombre'] is! String ||
          project['tecnologia'] is! String ||
          project['semestre'] is! num ||
          forecast['tendencia'] is! String ||
          forecast['informesEvaluados'] is! num) {
        throw const FormatException(
            'Los datos de avance del proyecto están incompletos.');
      }
      return _ProyectoAulaVista(
        nombre: project['nombre'] as String,
        tecnologia: project['tecnologia'] as String,
        semestre: (project['semestre'] as num).toInt(),
        informes: (item['informes'] as List).length,
        tendencia: forecast['tendencia'] as String,
        puntajeActual: (forecast['puntajeActual'] as num?)?.toDouble(),
        puntajePronosticado:
            (forecast['puntajePronosticadoEnCuatroSemanas'] as num?)
                ?.toDouble(),
        cambio: (forecast['cambioPronosticado'] as num?)?.toDouble(),
      );
    }).toList(growable: false);
    final tutoria = entry['tutoriaColectiva'] as Map<String, dynamic>;
    return _TutoriaColectivaVista(
      tecnologia: tutoria['tecnologia'] is String
          ? tutoria['tecnologia'] as String
          : '',
      semestre:
          tutoria['semestre'] is num ? (tutoria['semestre'] as num).toInt() : 0,
      proyectos: projects,
    );
  }).toList(growable: false);
});

class ProyectosAulaPage extends ConsumerWidget {
  const ProyectosAulaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(proyectosAulaProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar los informes de proyectos: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (groups) => RefreshIndicator(
          onRefresh: () => ref.refresh(proyectosAulaProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Avance de proyectos de aula',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tendencia calculada a partir de los informes de los docentes de apoyo.',
              ),
              const SizedBox(height: 16),
              if (groups.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        Text('Todavía no se han creado tutorías colectivas.'),
                  ),
                )
              else
                for (final group in groups) ...[
                  if (group.proyectos.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${group.tecnologia} · semestre ${group.semestre}: '
                          'sin proyectos inscritos todavía.',
                        ),
                      ),
                    )
                  else
                    for (final project in group.proyectos)
                      _ProyectoCard(project: project),
                ],
            ],
          ),
        ),
      );
}

class _ProyectoCard extends StatelessWidget {
  const _ProyectoCard({required this.project});

  final _ProyectoAulaVista project;

  @override
  Widget build(BuildContext context) {
    final label = switch (project.tendencia) {
      'MEJORA_PRONOSTICADA' => 'Mejora pronosticada',
      'RETROCESO_PRONOSTICADO' => 'Retroceso pronosticado',
      'ESTABLE' => 'Avance estable',
      _ => 'Datos insuficientes para evaluar',
    };
    final color = switch (project.tendencia) {
      'MEJORA_PRONOSTICADA' => Colors.green.shade700,
      'RETROCESO_PRONOSTICADO' => Colors.red.shade700,
      _ => Colors.blueGrey,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${project.tecnologia} · semestre ${project.semestre}'),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            Text('Informes recibidos: ${project.informes}'),
            if (project.puntajeActual != null)
              Text(
                'Puntaje actual: ${project.puntajeActual!.toStringAsFixed(1)}/100',
              ),
            if (project.puntajePronosticado != null)
              Text(
                'Pronóstico en 4 semanas: '
                '${project.puntajePronosticado!.toStringAsFixed(1)}/100'
                '${project.cambio == null ? '' : ' (${project.cambio! >= 0 ? '+' : ''}${project.cambio!.toStringAsFixed(1)} puntos)'}',
              ),
          ],
        ),
      ),
    );
  }
}

class _TutoriaColectivaVista {
  const _TutoriaColectivaVista({
    required this.tecnologia,
    required this.semestre,
    required this.proyectos,
  });

  final String tecnologia;
  final int semestre;
  final List<_ProyectoAulaVista> proyectos;
}

class _ProyectoAulaVista {
  const _ProyectoAulaVista({
    required this.nombre,
    required this.tecnologia,
    required this.semestre,
    required this.informes,
    required this.tendencia,
    required this.puntajeActual,
    required this.puntajePronosticado,
    required this.cambio,
  });

  final String nombre;
  final String tecnologia;
  final int semestre;
  final int informes;
  final String tendencia;
  final double? puntajeActual;
  final double? puntajePronosticado;
  final double? cambio;
}
