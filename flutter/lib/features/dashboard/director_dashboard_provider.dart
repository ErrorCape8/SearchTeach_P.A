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
    this.prediccionesAsistenciaSemanales = const [],
    this.resumenPa,
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
  final List<WeeklyAttendancePrediction> prediccionesAsistenciaSemanales;
  final PaDashboardSummary? resumenPa;

  factory DirectorDashboard.fromJson(Map<String, dynamic> json) {
    final weekly = json['historialSemanal'];
    final subjects = json['tutoriasPorMateria'];
    final attendanceData = json['datosModeloAsistencia'];
    final attendancePredictions = json['prediccionesAsistencia'];
    final weeklyAttendance = json['prediccionesAsistenciaSemanales'];
    final paSummaryRaw = json['resumenPa'];

    if (weekly is! List ||
        subjects is! List ||
        attendanceData is! Map<String, dynamic> ||
        attendancePredictions is! List ||
        json['modeloAsistenciaDisponible'] is! bool) {
      throw const FormatException('Formato inválido en el resumen del dashboard.');
    }

    return DirectorDashboard(
      totalTutorias: _readInt(json, 'totalTutorias'),
      tutoriasRealizadas: _readInt(json, 'tutoriasRealizadas'),
      tutoriasProgramadas: _readInt(json, 'tutoriasProgramadas'),
      tasaAsistencia: _readNullableDouble(json, 'tasaAsistencia'),
      historialSemanal: weekly.map((entry) {
        final map = entry as Map<String, dynamic>;
        return WeeklyTutoringCount(
          semanaInicio: DateTime.parse(map['semanaInicio'] as String),
          total: _readInt(map, 'total'),
        );
      }).toList(growable: false),
      tutoriasPorMateria: subjects.map((entry) {
        final map = entry as Map<String, dynamic>;
        return SubjectTutoringSummary(
          materia: (map['materia'] as String).trim(),
          carreras: _readStringList(
              map, const ['carreras', 'carrera', 'programa', 'tecnologia']),
          semestres: _readIntList(map, const ['semestres', 'semestre']),
          totalTutorias: _readInt(map, 'totalTutorias'),
          tutoriasRealizadas: _readInt(map, 'tutoriasRealizadas'),
          estudiantesInscritos: _readInt(map, 'estudiantesInscritos'),
          asistenciasConfirmadas: _readInt(map, 'asistenciasConfirmadas'),
          asistenciasRegistradas: _readInt(map, 'asistenciasRegistradas'),
          tasaAsistencia: _readNullableDouble(map, 'tasaAsistencia'),
          pronostico: map['pronostico'] is Map<String, dynamic>
              ? PronosticoDemanda.fromJson(
                  map['pronostico'] as Map<String, dynamic>)
              : null,
        );
      }).toList(growable: false),
      datosModeloAsistencia: AttendanceTrainingData.fromJson(attendanceData),
      modeloAsistenciaDisponible: json['modeloAsistenciaDisponible'] as bool,
      prediccionesAsistencia: attendancePredictions.map((entry) {
        final map = entry as Map<String, dynamic>;
        return SubjectAttendancePrediction(
          materia: (map['materia'] as String).trim(),
          carrera: (map['carrera'] as String?)?.trim(),
          semestre: (map['semestre'] as num?)?.toInt(),
          tutoriasEvaluadas: _readInt(map, 'tutoriasEvaluadas'),
          asistenciasPredichas: _readInt(map, 'asistenciasPredichas'),
          inasistenciasPredichas: _readInt(map, 'inasistenciasPredichas'),
          probabilidadAsistenciaPromedio:
              _readDouble(map, 'probabilidadAsistenciaPromedio'),
        );
      }).toList(growable: false),
      tutoriasProgramadasNoEvaluables:
          _readInt(json, 'tutoriasProgramadasNoEvaluables'),
      prediccionesAsistenciaSemanales: weeklyAttendance is List
          ? weeklyAttendance.map((entry) {
              final map = entry as Map<String, dynamic>;
              return WeeklyAttendancePrediction(
                semanaInicio: DateTime.parse(map['semanaInicio'] as String),
                tutoriasEvaluadas: _readInt(map, 'tutoriasEvaluadas'),
                asistenciasPredichas: _readInt(map, 'asistenciasPredichas'),
                inasistenciasPredichas:
                    _readInt(map, 'inasistenciasPredichas'),
                probabilidadAsistenciaPromedio:
                    _readDouble(map, 'probabilidadAsistenciaPromedio'),
              );
            }).toList(growable: false)
          : const [],
      resumenPa: paSummaryRaw is Map<String, dynamic>
          ? PaDashboardSummary.fromJson(paSummaryRaw)
          : null,
    );
  }

  static int _readInt(Map<String, dynamic> json, String key) =>
      (json[key] as num).toInt();

  static double? _readNullableDouble(Map<String, dynamic> json, String key) =>
      (json[key] as num?)?.toDouble();

  static double _readDouble(Map<String, dynamic> json, String key) =>
      (json[key] as num).toDouble();

  static List<String> _readStringList(
      Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is List) {
        return value
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
      if (value is String && value.trim().isNotEmpty) {
        return [value.trim()];
      }
    }
    return const [];
  }

  static List<int> _readIntList(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is List) {
        return value
            .map(_parseSemester)
            .whereType<int>()
            .toList(growable: false);
      }
      final single = _parseSemester(value);
      if (single != null) return [single];
    }
    return const [];
  }

  static int? _parseSemester(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final digits = RegExp(r'\d+').firstMatch(raw.trim());
      if (digits != null) return int.tryParse(digits.group(0)!);
    }
    return null;
  }
}

class PaDashboardSummary {
  const PaDashboardSummary({
    required this.totalTutoriasPa,
    required this.tutoriasPaRealizadas,
    required this.tutoriasPaProgramadas,
    required this.tasaAsistenciaPa,
    required this.tutoriasPaEvaluadas,
    required this.asistenciasPaPredichas,
    required this.probabilidadAsistenciaPaPromedio,
  });

  final int totalTutoriasPa;
  final int tutoriasPaRealizadas;
  final int tutoriasPaProgramadas;
  final double? tasaAsistenciaPa;
  final int tutoriasPaEvaluadas;
  final int asistenciasPaPredichas;
  final double? probabilidadAsistenciaPaPromedio;

  factory PaDashboardSummary.fromJson(Map<String, dynamic> json) {
    int readIntOrZero(String k) => (json[k] as num?)?.toInt() ?? 0;
    double? readNullableDouble(String k) => (json[k] as num?)?.toDouble();

    return PaDashboardSummary(
      totalTutoriasPa: readIntOrZero('totalTutoriasPa'),
      tutoriasPaRealizadas: readIntOrZero('tutoriasPaRealizadas'),
      tutoriasPaProgramadas: readIntOrZero('tutoriasPaProgramadas'),
      tasaAsistenciaPa: readNullableDouble('tasaAsistenciaPa'),
      tutoriasPaEvaluadas: readIntOrZero('tutoriasPaEvaluadas'),
      asistenciasPaPredichas: readIntOrZero('asistenciasPaPredichas'),
      probabilidadAsistenciaPaPromedio:
          readNullableDouble('probabilidadAsistenciaPaPromedio'),
    );
  }
}

class WeeklyTutoringCount {
  const WeeklyTutoringCount({required this.semanaInicio, required this.total});
  final DateTime semanaInicio;
  final int total;

  factory WeeklyTutoringCount.fromJson(Map<String, dynamic> json) =>
      WeeklyTutoringCount(
        semanaInicio: DateTime.parse(json['semanaInicio'] as String),
        total: (json['total'] as num).toInt(),
      );
}

class PronosticoDemanda {
  const PronosticoDemanda({
    required this.prediccionesSemanales,
    required this.estimadoProximasCuatroSemanas,
    required this.modelo,
  });

  final List<WeeklyTutoringCount> prediccionesSemanales;
  final int estimadoProximasCuatroSemanas;
  final String modelo;

  factory PronosticoDemanda.fromJson(Map<String, dynamic> json) =>
      PronosticoDemanda(
        prediccionesSemanales: (json['prediccionesSemanales'] as List)
            .whereType<Map<String, dynamic>>()
            .map(WeeklyTutoringCount.fromJson)
            .toList(growable: false),
        estimadoProximasCuatroSemanas:
            (json['estimadoProximasCuatroSemanas'] as num).toInt(),
        modelo: json['modelo'] as String? ?? 'REPTREE',
      );
}

class SubjectTutoringSummary {
  const SubjectTutoringSummary({
    required this.materia,
    this.carreras = const [],
    this.semestres = const [],
    required this.totalTutorias,
    required this.tutoriasRealizadas,
    required this.estudiantesInscritos,
    required this.asistenciasConfirmadas,
    required this.asistenciasRegistradas,
    required this.tasaAsistencia,
    required this.pronostico,
  });

  final String materia;
  final List<String> carreras;
  final List<int> semestres;
  final int totalTutorias;
  final int tutoriasRealizadas;
  final int estudiantesInscritos;
  final int asistenciasConfirmadas;
  final int asistenciasRegistradas;
  final double? tasaAsistencia;
  final PronosticoDemanda? pronostico;
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
        registrosEtiquetados: (json['registrosEtiquetados'] as num).toInt(),
        asistencias: (json['asistencias'] as num).toInt(),
        inasistencias: (json['inasistencias'] as num).toInt(),
        registrosSinEtiqueta: (json['registrosSinEtiqueta'] as num).toInt(),
      );
}

class SubjectAttendancePrediction {
  const SubjectAttendancePrediction({
    required this.materia,
    required this.carrera,
    required this.semestre,
    required this.tutoriasEvaluadas,
    required this.asistenciasPredichas,
    required this.inasistenciasPredichas,
    required this.probabilidadAsistenciaPromedio,
  });

  final String materia;
  final String? carrera;
  final int? semestre;
  final int tutoriasEvaluadas;
  final int asistenciasPredichas;
  final int inasistenciasPredichas;
  final double probabilidadAsistenciaPromedio;
}

class WeeklyAttendancePrediction {
  const WeeklyAttendancePrediction({
    required this.semanaInicio,
    required this.tutoriasEvaluadas,
    required this.asistenciasPredichas,
    required this.inasistenciasPredichas,
    required this.probabilidadAsistenciaPromedio,
  });

  final DateTime semanaInicio;
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
