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
  });

  final int totalTutorias;
  final int tutoriasRealizadas;
  final int tutoriasProgramadas;
  final double? tasaAsistencia;
  final List<WeeklyTutoringCount> historialSemanal;
  final List<SubjectTutoringSummary> tutoriasPorMateria;

  factory DirectorDashboard.fromJson(Map<String, dynamic> json) {
    final weekly = json['historialSemanal'];
    final subjects = json['tutoriasPorMateria'];
    if (weekly is! List) {
      throw const FormatException(
          'El historial semanal no tiene un formato válido.');
    }
    if (subjects is! List) {
      throw const FormatException(
          'El resumen por materia no tiene un formato válido.');
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
          pronostico: entry['pronostico'] == null
              ? null
              : PronosticoDemanda.fromJson(
                  entry['pronostico'] as Map<String, dynamic>,
                ),
        );
      }).toList(growable: false),
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
    required this.pronostico,
  });

  final String materia;
  final int totalTutorias;
  final int tutoriasRealizadas;
  final int estudiantesInscritos;
  final int asistenciasConfirmadas;
  final int asistenciasRegistradas;
  final double? tasaAsistencia;
  final PronosticoDemanda? pronostico;
}

class PronosticoDemanda {
  const PronosticoDemanda({
    required this.historialSolicitudes,
    required this.estimadoProximaSemana,
    required this.minimoProximaSemana,
    required this.maximoProximaSemana,
    required this.estimadoProximasCuatroSemanas,
    required this.minimoProximasCuatroSemanas,
    required this.maximoProximasCuatroSemanas,
    required this.tendencia,
    required this.alertaCreciente,
    this.modelo,
  });

  final List<WeeklyTutoringCount> historialSolicitudes;
  final int estimadoProximaSemana;
  final int minimoProximaSemana;
  final int maximoProximaSemana;
  final int estimadoProximasCuatroSemanas;
  final int minimoProximasCuatroSemanas;
  final int maximoProximasCuatroSemanas;
  final String tendencia;
  final bool alertaCreciente;
  final String? modelo;

  factory PronosticoDemanda.fromJson(Map<String, dynamic> json) {
    final weekly = json['historialSolicitudes'];
    if (weekly is! List) {
      throw const FormatException(
        'El historial de solicitudes no tiene un formato válido.',
      );
    }
    final trend = json['tendencia'];
    if (trend is! String ||
        !const {'SUBE', 'ESTABLE', 'BAJA'}.contains(trend)) {
      throw const FormatException('La tendencia no tiene un formato válido.');
    }
    final alert = json['alertaCreciente'];
    if (alert is! bool) {
      throw const FormatException(
        'La alerta de demanda no tiene un formato válido.',
      );
    }

    return PronosticoDemanda(
      historialSolicitudes: weekly.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
            'Una semana de solicitudes no tiene un formato válido.',
          );
        }
        final weekStart =
            DateTime.tryParse(entry['semanaInicio'] as String? ?? '');
        if (weekStart == null) {
          throw const FormatException(
            'La fecha de una semana de solicitudes no es válida.',
          );
        }
        return WeeklyTutoringCount(
          semanaInicio: weekStart,
          total: _readInt(entry, 'total'),
        );
      }).toList(growable: false),
      estimadoProximaSemana: _readInt(json, 'estimadoProximaSemana'),
      minimoProximaSemana: _readInt(json, 'minimoProximaSemana'),
      maximoProximaSemana: _readInt(json, 'maximoProximaSemana'),
      estimadoProximasCuatroSemanas:
          _readInt(json, 'estimadoProximasCuatroSemanas'),
      minimoProximasCuatroSemanas:
          _readInt(json, 'minimoProximasCuatroSemanas'),
      maximoProximasCuatroSemanas:
          _readInt(json, 'maximoProximasCuatroSemanas'),
      tendencia: trend,
      alertaCreciente: alert,
      modelo: json['modelo'] as String?,
    );
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw FormatException('El campo "$key" no es un número.');
  }
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
