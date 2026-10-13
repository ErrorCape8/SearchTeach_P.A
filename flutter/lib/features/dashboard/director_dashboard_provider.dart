import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class DirectorDashboard {
  const DirectorDashboard({
    required this.totalTutorias,
    required this.tutoriasRealizadas,
    required this.tutoriasProgramadas,
    required this.tasaAsistencia,
    required this.historialSemanal,
  });

  final int totalTutorias;
  final int tutoriasRealizadas;
  final int tutoriasProgramadas;
  final double? tasaAsistencia;
  final List<WeeklyTutoringCount> historialSemanal;

  factory DirectorDashboard.fromJson(Map<String, dynamic> json) {
    final weekly = json['historialSemanal'];
    if (weekly is! List) {
      throw const FormatException('El historial semanal no tiene un formato válido.');
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
