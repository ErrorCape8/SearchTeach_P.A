import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class CalidadGeneralSummary {
  const CalidadGeneralSummary({
    required this.promedioGeneral,
    required this.totalCalificaciones,
    required this.distribucionEstrellas,
    required this.calificacionPorMateria,
    required this.comentariosRecientes,
    this.comentariosFrecuentes = const [],
  });

  final double? promedioGeneral;
  final int totalCalificaciones;
  final Map<int, int> distribucionEstrellas;
  final List<MateriaCalidadItem> calificacionPorMateria;
  final List<CalificacionAnonimaItem> comentariosRecientes;

  /// Conteo de comentarios predeterminados enviado por el backend (opcional).
  /// Si viene vacío, [comentariosMasRepetidos] lo calcula con los recientes.
  final List<ComentarioFrecuenteItem> comentariosFrecuentes;

  /// Comentarios predeterminados más repetidos, de mayor a menor. Cada
  /// tutoría calificada cuenta una vez por cada mensaje elegido.
  List<ComentarioFrecuenteItem> get comentariosMasRepetidos {
    if (comentariosFrecuentes.isNotEmpty) {
      return [...comentariosFrecuentes]
        ..sort((a, b) => b.veces.compareTo(a.veces));
    }
    final counts = <String, int>{};
    for (final item in comentariosRecientes) {
      for (final raw in item.comentario.split('. ')) {
        final text = raw.trim().replaceAll(RegExp(r'\.$'), '');
        if (kComentarioEstrellas.containsKey(text)) {
          counts[text] = (counts[text] ?? 0) + 1;
        }
      }
    }
    return [
      for (final e in counts.entries) ComentarioFrecuenteItem(e.key, e.value),
    ]..sort((a, b) => b.veces.compareTo(a.veces));
  }

  factory CalidadGeneralSummary.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribucionEstrellas'];
    final dist = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    if (rawDist is Map) {
      rawDist.forEach((key, value) {
        final star = int.tryParse(key.toString());
        if (star != null && star >= 1 && star <= 5 && value is num) {
          dist[star] = value.toInt();
        }
      });
    }

    final rawMaterias = json['calificacionPorMateria'];
    final materias = rawMaterias is List
        ? rawMaterias
            .whereType<Map<String, dynamic>>()
            .map(MateriaCalidadItem.fromJson)
            .toList(growable: false)
        : const <MateriaCalidadItem>[];

    final rawComentarios = json['comentariosRecientes'];
    final comentarios = rawComentarios is List
        ? rawComentarios
            .whereType<Map<String, dynamic>>()
            .map(CalificacionAnonimaItem.fromJson)
            .toList(growable: false)
        : const <CalificacionAnonimaItem>[];

    final rawFrecuentes = json['comentariosFrecuentes'];
    final frecuentes = rawFrecuentes is List
        ? rawFrecuentes
            .whereType<Map<String, dynamic>>()
            .map(ComentarioFrecuenteItem.fromJson)
            .where((e) => e.comentario.isNotEmpty)
            .toList(growable: false)
        : const <ComentarioFrecuenteItem>[];

    final avg = json['promedioGeneral'];
    final total = json['totalCalificaciones'];

    return CalidadGeneralSummary(
      promedioGeneral: avg is num ? avg.toDouble() : null,
      totalCalificaciones: total is num ? total.toInt() : 0,
      distribucionEstrellas: dist,
      calificacionPorMateria: materias,
      comentariosRecientes: comentarios,
      comentariosFrecuentes: frecuentes,
    );
  }
}

class ComentarioFrecuenteItem {
  const ComentarioFrecuenteItem(this.comentario, this.veces);

  final String comentario;
  final int veces;

  factory ComentarioFrecuenteItem.fromJson(Map<String, dynamic> json) =>
      ComentarioFrecuenteItem(
        (json['comentario'] as String? ?? '').trim(),
        (json['veces'] as num? ?? 0).toInt(),
      );

  /// Estrellas del mensaje predeterminado (null si no es uno de la lista).
  int? get estrellas => kComentarioEstrellas[comentario];
}

/// Mensajes predeterminados que el estudiante puede elegir al calificar
/// (mismos textos que `_ratingComments` en la pantalla del estudiante).
const Map<String, int> kComentarioEstrellas = {
  'El tutor no se presentó': 1,
  'El tutor no ingresó': 1,
  'El tutor no explicó bien': 1,
  'El tutor llegó tarde': 2,
  'La explicación fue poco clara': 2,
  'Necesité más apoyo del tutor': 2,
  'La clase estuvo bien': 3,
  'El tutor explicó lo básico': 3,
  'El tutor podría mejorar': 3,
  'El tutor explicó claramente': 4,
  'Buena atención del tutor': 4,
  'El tutor resolvió mis dudas': 4,
  'Excelente explicación del tutor': 5,
  'El tutor fue atento y claro': 5,
  'Recomiendo a este tutor': 5,
};

/// Filtro de la vista de calidad: `tipo` = 'PA' limita a proyecto de aula y
/// `carrera` a una tecnología concreta. Sin valores = calidad general.
class CalidadFiltro {
  const CalidadFiltro({this.tipo, this.carrera});

  final String? tipo;
  final String? carrera;

  @override
  bool operator ==(Object other) =>
      other is CalidadFiltro && other.tipo == tipo && other.carrera == carrera;

  @override
  int get hashCode => Object.hash(tipo, carrera);
}

class MateriaCalidadItem {
  const MateriaCalidadItem({
    required this.materia,
    required this.promedioEstrellas,
    required this.totalCalificaciones,
  });

  final String materia;
  final double promedioEstrellas;
  final int totalCalificaciones;

  factory MateriaCalidadItem.fromJson(Map<String, dynamic> json) =>
      MateriaCalidadItem(
        materia: (json['materia'] as String? ?? '').trim(),
        promedioEstrellas: (json['promedioEstrellas'] as num? ?? 0).toDouble(),
        totalCalificaciones: (json['totalCalificaciones'] as num? ?? 0).toInt(),
      );
}

class CalificacionAnonimaItem {
  const CalificacionAnonimaItem({
    required this.estrellas,
    required this.materia,
    required this.comentario,
    this.fecha,
  });

  final int estrellas;
  final String materia;
  final String comentario;
  final DateTime? fecha;

  factory CalificacionAnonimaItem.fromJson(Map<String, dynamic> json) =>
      CalificacionAnonimaItem(
        estrellas: (json['estrellas'] as num? ?? 5).toInt(),
        materia: (json['materia'] as String? ?? 'Tutoría académica').trim(),
        comentario: (json['comentario'] as String? ?? '').trim(),
        fecha: DateTime.tryParse(json['fecha'] as String? ?? ''),
      );
}

final calidadFiltradaProvider = FutureProvider.autoDispose
    .family<CalidadGeneralSummary, CalidadFiltro>((ref, filtro) async {
  final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
    '/api/direccion/calidad',
    queryParameters: {
      if (filtro.tipo != null) 'tipo': filtro.tipo,
      if (filtro.carrera != null) 'carrera': filtro.carrera,
    },
  );
  final data = response.data;
  if (data == null) {
    return const CalidadGeneralSummary(
      promedioGeneral: null,
      totalCalificaciones: 0,
      distribucionEstrellas: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      calificacionPorMateria: [],
      comentariosRecientes: [],
    );
  }
  return CalidadGeneralSummary.fromJson(data);
});

/// Calidad general (sin filtros).
final calidadDirectorProvider =
    FutureProvider.autoDispose<CalidadGeneralSummary>(
        (ref) => ref.watch(calidadFiltradaProvider(const CalidadFiltro()).future));
