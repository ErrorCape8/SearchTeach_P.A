import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class CalidadGeneralSummary {
  const CalidadGeneralSummary({
    required this.promedioGeneral,
    required this.totalCalificaciones,
    required this.distribucionEstrellas,
    required this.calificacionPorMateria,
    required this.comentariosRecientes,
  });

  final double? promedioGeneral;
  final int totalCalificaciones;
  final Map<int, int> distribucionEstrellas;
  final List<MateriaCalidadItem> calificacionPorMateria;
  final List<CalificacionAnonimaItem> comentariosRecientes;

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

    final avg = json['promedioGeneral'];
    final total = json['totalCalificaciones'];

    return CalidadGeneralSummary(
      promedioGeneral: avg is num ? avg.toDouble() : null,
      totalCalificaciones: total is num ? total.toInt() : 0,
      distribucionEstrellas: dist,
      calificacionPorMateria: materias,
      comentariosRecientes: comentarios,
    );
  }
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

final calidadDirectorProvider =
    FutureProvider.autoDispose<CalidadGeneralSummary>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/api/direccion/calidad');
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
