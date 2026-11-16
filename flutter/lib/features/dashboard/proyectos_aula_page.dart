import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/career_catalog.dart';
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

/// Vista de proyectos de aula integrada en el tablero de dirección.
class DirProyectosAulaView extends ConsumerStatefulWidget {
  const DirProyectosAulaView({super.key});

  @override
  ConsumerState<DirProyectosAulaView> createState() =>
      _DirProyectosAulaViewState();
}

class _DirProyectosAulaViewState extends ConsumerState<DirProyectosAulaView> {
  String? _career;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(proyectosAulaProvider);

    final groups = async.asData?.value ?? const <_TutoriaColectivaVista>[];
    final allProjects = [for (final g in groups) ...g.proyectos];

    final careers = <String>{
      ...careerCatalog,
      for (final project in allProjects)
        if (project.tecnologia.trim().isNotEmpty) project.tecnologia.trim(),
    }.toList();

    final projects = _career == null
        ? allProjects
        : allProjects.where((x) => x.tecnologia.trim() == _career).toList();

    final List<Widget> projectWidgets = async.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.only(top: 30, bottom: 30),
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
      data: (_) {
        if (projects.isEmpty) {
          return [
            PaCard(
                child: PaEmpty(_career == null
                    ? 'Todavía no hay proyectos de aula inscritos en las tutorías colectivas.'
                    : 'No hay proyectos de aula para la carrera seleccionada.')),
          ];
        }
        return [
          PaRowList([
            for (final project in projects) _ProyectoRow(project: project),
          ]),
        ];
      },
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CareerFilter(
          careers: careers,
          selected: _career,
          onChanged: (v) => setState(() => _career = v),
        ),
        _HistoricoPronosticoBlock(career: _career),
        const PaSection('Proyectos inscritos'),
        ...projectWidgets,
      ]);
  }
}

final paGruposProvider =
    FutureProvider.autoDispose<_PaGruposVista>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/api/direccion/dashboard/pa-grupos');
  final data = response.data;
  if (data == null) {
    throw const FormatException('El servidor devolvió un pronóstico inválido.');
  }
  return _PaGruposVista.fromJson(data);
});

/// "ningún grupo nuevo", "1 grupo nuevo", "3 grupos nuevos".
String _gruposTexto(int n) => switch (n) {
      0 => 'ningún grupo nuevo',
      1 => '1 grupo nuevo',
      _ => '$n grupos nuevos',
    };

String _decimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

String _etiquetaSemana(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

class _PrediccionGrupos {
  const _PrediccionGrupos({
    required this.carrera,
    required this.semanaInicio,
    required this.nuevosSemanaAnterior,
    required this.promedio3,
    required this.sinGrupo,
    required this.clase,
    required this.probabilidadClase,
    required this.esperados,
    required this.probabilidades,
  });

  factory _PrediccionGrupos.fromJson(Map<String, dynamic> json) {
    final raw = json['probabilidades'];
    return _PrediccionGrupos(
      carrera: json['carrera']?.toString().trim() ?? '',
      semanaInicio: DateTime.parse(json['semanaInicio'] as String),
      nuevosSemanaAnterior: (json['nuevosSemanaAnterior'] as num?)?.toInt() ?? 0,
      promedio3: (json['promedioUltimas3Semanas'] as num?)?.toDouble() ?? 0,
      sinGrupo: (json['estudiantesSinGrupos'] as num?)?.toInt() ?? 0,
      clase: json['clasePredicha']?.toString() ?? '0',
      probabilidadClase: (json['probabilidadClase'] as num?)?.toDouble() ?? 0,
      esperados: (json['gruposEsperados'] as num?)?.toDouble() ?? 0,
      probabilidades: raw is Map<String, dynamic>
          ? {
              for (final e in raw.entries)
                e.key: (e.value as num?)?.toDouble() ?? 0,
            }
          : const {},
    );
  }

  final String carrera;
  final DateTime semanaInicio;
  final int nuevosSemanaAnterior;
  final double promedio3;
  final int sinGrupo;
  final String clase;
  final double probabilidadClase;
  final double esperados;
  final Map<String, double> probabilidades;

  /// Varianza de la cantidad de grupos nuevos (3_o_mas cuenta como 3).
  double get varianza {
    var v = 0.0;
    probabilidades.forEach((clase, prob) {
      final valor = clase == '3_o_mas' ? 3 : (int.tryParse(clase) ?? 0);
      v += prob * (valor - esperados) * (valor - esperados);
    });
    return v;
  }
}

class _SemanaGrupos {
  const _SemanaGrupos(this.semana, this.carrera, this.nuevos);
  final DateTime semana;
  final String carrera;
  final int nuevos;
}

class _PaGruposVista {
  const _PaGruposVista({
    required this.disponible,
    required this.predicciones,
    required this.historial,
  });

  factory _PaGruposVista.fromJson(Map<String, dynamic> json) => _PaGruposVista(
        disponible: json['modeloDisponible'] == true,
        predicciones: (json['predicciones'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_PrediccionGrupos.fromJson)
            .toList(growable: false),
        historial: (json['historial'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((m) => _SemanaGrupos(
                  DateTime.parse(m['semanaInicio'] as String),
                  m['carrera']?.toString().trim() ?? '',
                  (m['nuevos'] as num?)?.toInt() ?? 0,
                ))
            .toList(growable: false),
      );

  final bool disponible;
  final List<_PrediccionGrupos> predicciones;
  final List<_SemanaGrupos> historial;
}

/// Compara los grupos formados por semana con el pronóstico de la siguiente.
class _HistoricoPronosticoBlock extends ConsumerWidget {
  const _HistoricoPronosticoBlock({required this.career});

  final String? career;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paGruposProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => PaInfo(
          'No se pudo calcular el pronóstico de grupos nuevos: $error',
          tone: PaTone.error,
          icon: Icons.error_outline_rounded),
      data: (vista) => _contenido(context, vista),
    );
  }

  Widget _contenido(BuildContext context, _PaGruposVista vista) {
    final preds = [
      for (final x in vista.predicciones)
        if (career == null || x.carrera == career) x,
    ];
    if (!vista.disponible || preds.isEmpty) {
      return const PaInfo(
          'No hay datos para estimar los grupos nuevos con este filtro.',
          icon: Icons.info_outline_rounded);
    }

    final semanaPronostico = preds.first.semanaInicio;
    final esperados = preds.fold<double>(0, (a, e) => a + e.esperados);
    final promedio = preds.fold<double>(0, (a, e) => a + e.promedio3);
    final total = esperados.round();

    // Solo se muestran las semanas en las que sí se formaron grupos.
    final porSemana = <DateTime, int>{};
    for (final h in vista.historial) {
      if (h.semana.isBefore(semanaPronostico) &&
          (career == null || h.carrera == career)) {
        porSemana[h.semana] = (porSemana[h.semana] ?? 0) + h.nuevos;
      }
    }
    final semanas = [
      for (final e in porSemana.entries)
        if (e.value > 0) e.key,
    ]..sort();
    final semanasGrafico = semanas.length > 5
        ? semanas.sublist(semanas.length - 5)
        : semanas;

    final diff = esperados - promedio;
    final tendencia = diff > 0.5
        ? 'Es más de lo normal (en las últimas semanas: ${_decimal(promedio)} por semana).'
        : diff < -0.5
            ? 'Es menos de lo normal (en las últimas semanas: ${_decimal(promedio)} por semana).'
            : 'Es parecido a lo normal (en las últimas semanas: ${_decimal(promedio)} por semana).';

    final prediccion = switch (total) {
      0 => 'No se espera ningún grupo nuevo.',
      1 => 'Se espera 1 grupo nuevo.',
      _ => 'Se esperan $total grupos nuevos.',
    };

    final porCarrera = [
      for (final x in preds)
        if (x.esperados.round() >= 1) x,
    ]..sort((a, b) => b.esperados.compareTo(a.esperados));

    final detalles = [
      'Cada barra muestra los grupos nuevos formados en la semana indicada. La barra clara es el pronóstico.',
      prediccion,
      tendencia,
      if (preds.length > 1 && porCarrera.isNotEmpty)
        'Por carrera: ${porCarrera.map((item) => '${item.carrera}: ${_gruposTexto(item.esperados.round())}').join(' · ')}',
    ].join('\n');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PaSection('Histórico y pronóstico'),
      DirBarChart(
        height: 160,
        showValues: true,
        labelLines: 2,
        bars: [
          for (final semana in semanasGrafico)
            DirBar(
              _etiquetaSemana(semana),
              (porSemana[semana] ?? 0).toDouble(),
            ),
          DirBar(
            'Próx.\n${_etiquetaSemana(semanaPronostico)}',
            esperados,
            light: true,
          ),
        ],
        caption: detalles,
      ),
    ]);
  }
}

class _CareerFilter extends StatelessWidget {
  const _CareerFilter({
    required this.careers,
    required this.selected,
    required this.onChanged,
  });

  final List<String> careers;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuSurface(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: selected,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: p.c),
            hint: Text('Todas las carreras',
                overflow: TextOverflow.ellipsis,
                style: neuBody(size: 13, color: Neu.muted)),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las carreras',
                    overflow: TextOverflow.ellipsis,
                    style: neuBody(size: 13)),
              ),
              for (final c in careers)
                DropdownMenuItem<String?>(
                  value: c,
                  child: Text(c,
                      overflow: TextOverflow.ellipsis,
                      style: neuBody(size: 13)),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
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
