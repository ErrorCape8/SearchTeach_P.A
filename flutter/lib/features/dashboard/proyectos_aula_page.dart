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
    throw const FormatException('El servidor devolvió una lista inválida.');
  }
  return data.whereType<Map<String, dynamic>>().map((entry) {
    final projects = (entry['proyectos'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_ProyectoAulaVista.fromJson)
        .toList(growable: false);
    return _TutoriaColectivaVista(
      tecnologia: entry['tecnologia']?.toString() ?? '',
      semestre: (entry['semestre'] as num?)?.toInt() ?? 0,
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
              'No se pudieron cargar los proyectos: $error',
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
                'Proyectos de aula',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('Estado actual de los proyectos inscritos.'),
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
    final closed = project.estado == 'FINALIZADO';
    final pending = project.estado == 'PENDIENTE_CONFIRMACION';
    final label = closed
        ? 'Finalizado'
        : pending
            ? 'Pendiente de confirmación'
            : 'En curso';
    final color = closed
        ? Colors.blueGrey
        : pending
            ? Colors.orange.shade700
            : Colors.green.shade700;
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
            Text('Tutor responsable: ${project.docenteResponsableId}'),
            Text('Estudiantes inscritos: ${project.estudiantes}'),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            if (project.descripcion.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(project.descripcion),
            ],
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
    required this.docenteResponsableId,
    required this.estudiantes,
    required this.tecnologia,
    required this.semestre,
    required this.estado,
    required this.descripcion,
  });

  factory _ProyectoAulaVista.fromJson(Map<String, dynamic> json) =>
      _ProyectoAulaVista(
        nombre: json['nombre']?.toString() ?? 'Proyecto sin nombre',
        docenteResponsableId:
            json['docenteResponsableId']?.toString() ?? 'Sin asignar',
        estudiantes: (json['estudianteIds'] as List<dynamic>?)?.length ?? 0,
        tecnologia: json['tecnologia']?.toString() ?? '',
        semestre: (json['semestre'] as num?)?.toInt() ?? 0,
        estado: json['estadoCierre']?.toString() ?? 'EN_CURSO',
        descripcion: json['descripcion']?.toString() ?? '',
      );

  final String nombre;
  final String docenteResponsableId;
  final int estudiantes;
  final String tecnologia;
  final int semestre;
  final String estado;
  final String descripcion;
}
