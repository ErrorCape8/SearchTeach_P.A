import 'package:dio/dio.dart';

class Teacher {
  const Teacher({required this.id, required this.nombre});

  final String id;
  final String nombre;

  factory Teacher.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String || json['nombre'] is! String) {
      throw const FormatException(
          'El docente no tiene nombre o identificación válida.');
    }
    return Teacher(id: json['id'] as String, nombre: json['nombre'] as String);
  }
}

class TutorSchedule {
  const TutorSchedule({
    required this.docenteId,
    required this.carrera,
    required this.semestre,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.modalidad,
    required this.ubicacion,
    this.materias = const [],
  });

  final String docenteId;
  final String carrera;
  final int semestre;
  final String dia;
  final String horaInicio;
  final String horaFin;
  final String modalidad;
  final String ubicacion;
  final List<ScheduleSubject> materias;

  factory TutorSchedule.fromJson(Map<String, dynamic> json) {
    if (json['docenteId'] is! String ||
        json['carrera'] is! String ||
        json['semestre'] is! num ||
        json['dia'] is! String ||
        json['horaInicio'] is! String ||
        json['horaFin'] is! String ||
        json['modalidad'] is! String) {
      throw const FormatException(
          'El horario devuelto por el servidor está incompleto.');
    }
    return TutorSchedule(
      docenteId: json['docenteId'] as String,
      carrera: json['carrera'] as String,
      semestre: (json['semestre'] as num).toInt(),
      dia: json['dia'] as String,
      horaInicio: json['horaInicio'] as String,
      horaFin: json['horaFin'] as String,
      modalidad: json['modalidad'] as String,
      ubicacion: json['ubicacion'] is String ? json['ubicacion'] as String : '',
      materias: json['materias'] is List
          ? (json['materias'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ScheduleSubject.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

class ScheduleSubject {
  const ScheduleSubject({required this.nombre, required this.carreras});

  final String nombre;
  final List<String> carreras;

  factory ScheduleSubject.fromJson(Map<String, dynamic> json) =>
      ScheduleSubject(
        nombre: json['nombre'] is String ? json['nombre'] as String : '',
        carreras: json['carreras'] is List
            ? (json['carreras'] as List).whereType<String>().toList()
            : const [],
      );

  Map<String, Object> toJson() => {'nombre': nombre, 'carreras': carreras};
}

String normalizeSearch(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');

String apiError(DioException error, String fallback) {
  final response = error.response?.data;
  if (response is Map && response['message'] is String) {
    return response['message'] as String;
  }
  return '$fallback Comprueba tu conexión e inténtalo de nuevo.';
}
