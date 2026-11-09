import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class DirectorDashboard {
  const DirectorDashboard({
    required this.totalTutorias,
    required this.tutoriasRealizadas,
    required this.tutoriasProgramadas,
    required this.tasaAsistencia,
    required this.historialSemanal,
    required this.tutoriasPorMateria,
    required this.datosModeloAsistencia,
    required this.modeloAsistenciaDisponible,
    required this.prediccionesAsistencia,
    required this.tutoriasProgramadasNoEvaluables,
  });

  final int totalTutorias;
  final int tutoriasRealizadas;
  final int tutoriasProgramadas;
  final double? tasaAsistencia;
  final List<WeeklyTutoringCount> historialSemanal;
  final List<SubjectTutoringSummary> tutoriasPorMateria;
  final AttendanceTrainingData datosModeloAsistencia;
  final bool modeloAsistenciaDisponible;
  final List<SubjectAttendancePrediction> prediccionesAsistencia;
  final int tutoriasProgramadasNoEvaluables;

  factory DirectorDashboard.fromJson(Map<String, dynamic> json) {
    final weekly = json['historialSemanal'];
    final subjects = json['tutoriasPorMateria'];
    final attendanceData = json['datosModeloAsistencia'];
    final attendancePredictions = json['prediccionesAsistencia'];
    if (weekly is! List) {
      throw const FormatException(
          'El historial semanal no tiene un formato válido.');
    }
    if (subjects is! List) {
      throw const FormatException(
          'El resumen por materia no tiene un formato válido.');
    }
    if (attendanceData is! Map<String, dynamic>) {
      throw const FormatException(
          'Los datos para el modelo de asistencia no tienen un formato válido.');
    }
    if (attendancePredictions is! List) {
      throw const FormatException(
          'Las predicciones de asistencia no tienen un formato válido.');
    }
    if (json['modeloAsistenciaDisponible'] is! bool) {
      throw const FormatException(
          'La disponibilidad del modelo de asistencia no es válida.');
    }

    return DirectorDashboard(
      totalTutorias: _readInt(json, 'totalTutorias'),
      tutoriasRealizadas: _readInt(json, 'tutoriasRealizadas'),
      tutoriasProgramadas: _readInt(json, 'tutoriasProgramadas'),
      tasaAsistencia: _readNullableDouble(json, 'tasaAsistencia'),
      historialSemanal: weekly.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
              'Una semana del historial no tiene un formato válido.');
        }
        final start = DateTime.tryParse(entry['semanaInicio'] as String? ?? '');
        if (start == null) {
          throw const FormatException('La fecha de una semana no es válida.');
        }
        return WeeklyTutoringCount(
          semanaInicio: start,
          total: _readInt(entry, 'total'),
        );
      }).toList(growable: false),
      tutoriasPorMateria: subjects.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
              'Una materia del resumen no tiene un formato válido.');
        }
        final materia = entry['materia'];
        if (materia is! String || materia.trim().isEmpty) {
          throw const FormatException('El nombre de una materia no es válido.');
        }
        return SubjectTutoringSummary(
          materia: materia,
          totalTutorias: _readInt(entry, 'totalTutorias'),
          tutoriasRealizadas: _readInt(entry, 'tutoriasRealizadas'),
          estudiantesInscritos: _readInt(entry, 'estudiantesInscritos'),
          asistenciasConfirmadas: _readInt(entry, 'asistenciasConfirmadas'),
          asistenciasRegistradas: _readInt(entry, 'asistenciasRegistradas'),
          tasaAsistencia: _readNullableDouble(entry, 'tasaAsistencia'),
        );
      }).toList(growable: false),
      datosModeloAsistencia: AttendanceTrainingData.fromJson(attendanceData),
      modeloAsistenciaDisponible: json['modeloAsistenciaDisponible'] as bool,
      prediccionesAsistencia: attendancePredictions.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
              'Una predicción de asistencia no tiene un formato válido.');
        }
        final materia = entry['materia'];
        if (materia is! String || materia.trim().isEmpty) {
          throw const FormatException(
              'El nombre de la materia de una predicción no es válido.');
        }
        return SubjectAttendancePrediction(
          materia: materia,
          tutoriasEvaluadas: _readInt(entry, 'tutoriasEvaluadas'),
          asistenciasPredichas: _readInt(entry, 'asistenciasPredichas'),
          inasistenciasPredichas: _readInt(entry, 'inasistenciasPredichas'),
          probabilidadAsistenciaPromedio:
              _readDouble(entry, 'probabilidadAsistenciaPromedio'),
        );
      }).toList(growable: false),
      tutoriasProgramadasNoEvaluables:
          _readInt(json, 'tutoriasProgramadasNoEvaluables'),
    );
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw FormatException('El campo "$key" no es un número.');
  }

  static double? _readNullableDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw FormatException('El campo "$key" no es un número.');
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    throw FormatException('El campo "$key" no es un número.');
  }
}

class WeeklyTutoringCount {
  const WeeklyTutoringCount({
    required this.semanaInicio,
    required this.total,
  });

  final DateTime semanaInicio;
  final int total;
}

class SubjectTutoringSummary {
  const SubjectTutoringSummary({
    required this.materia,
    required this.totalTutorias,
    required this.tutoriasRealizadas,
    required this.estudiantesInscritos,
    required this.asistenciasConfirmadas,
    required this.asistenciasRegistradas,
    required this.tasaAsistencia,
  });

  final String materia;
  final int totalTutorias;
  final int tutoriasRealizadas;
  final int estudiantesInscritos;
  final int asistenciasConfirmadas;
  final int asistenciasRegistradas;
  final double? tasaAsistencia;
}

class AttendanceTrainingData {
  const AttendanceTrainingData({
    required this.registrosEtiquetados,
    required this.asistencias,
    required this.inasistencias,
    required this.registrosSinEtiqueta,
  });

  final int registrosEtiquetados;
  final int asistencias;
  final int inasistencias;
  final int registrosSinEtiqueta;

  factory AttendanceTrainingData.fromJson(Map<String, dynamic> json) =>
      AttendanceTrainingData(
        registrosEtiquetados: _readInt(json, 'registrosEtiquetados'),
        asistencias: _readInt(json, 'asistencias'),
        inasistencias: _readInt(json, 'inasistencias'),
        registrosSinEtiqueta: _readInt(json, 'registrosSinEtiqueta'),
      );

  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw FormatException('El campo "$key" no es un número.');
  }
}

class SubjectAttendancePrediction {
  const SubjectAttendancePrediction({
    required this.materia,
    required this.tutoriasEvaluadas,
    required this.asistenciasPredichas,
    required this.inasistenciasPredichas,
    required this.probabilidadAsistenciaPromedio,
  });

  final String materia;
  final int tutoriasEvaluadas;
  final int asistenciasPredichas;
  final int inasistenciasPredichas;
  final double probabilidadAsistenciaPromedio;
}

final directorDashboardProvider =
    FutureProvider.autoDispose<DirectorDashboard>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/api/direccion/dashboard');
  final data = response.data;
  if (data == null) {
    throw const FormatException('El servidor devolvió un resumen vacío.');
  }
  return DirectorDashboard.fromJson(data);
});
