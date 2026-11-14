import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../pa/pa_widgets.dart';
import 'director_widgets.dart';

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

/// Proyectos de aula (solo lectura) con el estilo neumórfico.
class ProyectosAulaPage extends ConsumerWidget {
  const ProyectosAulaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(proyectosAulaProvider);
    final List<Widget> children = async.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => [
        PaInfo('No se pudieron cargar los proyectos: $error',
            tone: PaTone.error, icon: Icons.error_outline_rounded),
        NeuButton('Reintentar',
            expand: false,
            small: true,
            onPressed: () => ref.invalidate(proyectosAulaProvider)),
      ],
      data: (groups) {
        final projects = [for (final g in groups) ...g.proyectos];
        if (projects.isEmpty) {
          return const [
            PaCard(
                child: PaEmpty(
                    'Todavía no hay proyectos de aula inscritos en las tutorías colectivas.')),
          ];
        }
        return [
          PaRowList([
            for (final project in projects) _ProyectoRow(project: project),
          ]),
        ];
      },
    );

    return PaScaffold(
      title: 'Proyectos de aula',
      subtitle: 'Estado de los proyectos inscritos',
      children: children,
    );
  }
}

class _ProyectoRow extends StatelessWidget {
  const _ProyectoRow({required this.project});

  final _ProyectoAulaVista project;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (project.estado) {
      'FINALIZADO' => ('Finalizado', PaTone.quiet),
      'PENDIENTE_CONFIRMACION' => ('Pendiente', PaTone.warn),
      _ => ('En curso', PaTone.ok),
    };
    return DirRow(
      icon: Icons.groups_outlined,
      title: project.nombre,
      subtitle:
          '${project.tecnologia} · semestre ${project.semestre} · ${project.estudiantes} estudiantes\n'
          'Tutor: ${project.docenteResponsableId}',
      trailing: PaTag(label, tone: tone),
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
