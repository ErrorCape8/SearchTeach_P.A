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
      throw const FormatException('El historial semanal no tiene un formato válido.');
    }
    if (subjects is! List) {
      throw const FormatException('El resumen por materia no tiene un formato válido.');
    }

    return DirectorDashboard(
      totalTutorias: _readInt(json, 'totalTutorias'),
      tutoriasRealizadas: _readInt(json, 'tutoriasRealizadas'),
      tutoriasProgramadas: _readInt(json, 'tutoriasProgramadas'),
      tasaAsistencia: _readNullableDouble(json, 'tasaAsistencia'),
      historialSemanal: weekly.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Una semana del historial no tiene un formato válido.');
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
          throw const FormatException('Una materia del resumen no tiene un formato válido.');
        }
        final materia = entry['materia'];
        if (materia is! String || materia.trim().isEmpty) {
          throw const FormatException('El nombre de una materia no es válido.');
        }
        return SubjectTutoringSummary(
          materia: materia,
          totalTutorias: _readInt(entry, 'totalTutorias'),
          tutoriasRealizadas: _readInt(entry, 'tutoriasRealizadas'),
          tasaAsistencia: _readNullableDouble(entry, 'tasaAsistencia'),
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

class WeeklyTutoringReference {
  const WeeklyTutoringReference({
    required this.average,
    required this.minimum,
    required this.maximum,
  });

  final double average;
  final int minimum;
  final int maximum;

  static WeeklyTutoringReference? fromHistory(
    List<WeeklyTutoringCount> history, {
    DateTime? today,
  }) {
    final date = today ?? DateTime.now();
    final startOfCurrentWeek = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - DateTime.monday));
    final completedWeeks = history
        .where((week) => week.semanaInicio.isBefore(startOfCurrentWeek))
        .toList(growable: false);
    if (completedWeeks.length < 4) return null;

    final sample = completedWeeks.sublist(completedWeeks.length - 4);
    if (!sample.any((week) => week.total > 0)) return null;
    final total = sample.fold<int>(0, (sum, week) => sum + week.total);
    return WeeklyTutoringReference(
      average: total / sample.length,
      minimum: sample.map((week) => week.total).reduce((a, b) => a < b ? a : b),
      maximum: sample.map((week) => week.total).reduce((a, b) => a > b ? a : b),
    );
  }
}

class SubjectTutoringSummary {
  const SubjectTutoringSummary({
    required this.materia,
    required this.totalTutorias,
    required this.tutoriasRealizadas,
    required this.tasaAsistencia,
  });

  final String materia;
  final int totalTutorias;
  final int tutoriasRealizadas;
  final double? tasaAsistencia;
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
