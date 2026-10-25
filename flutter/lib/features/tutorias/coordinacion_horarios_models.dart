import 'package:dio/dio.dart';

class Teacher {
  const Teacher({required this.id, required this.nombre, this.tecnologia = ''});

  final String id;
  final String nombre;
  final String tecnologia;

  factory Teacher.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String || json['nombre'] is! String) {
      throw const FormatException(
          'El docente no tiene nombre o identificaciÃ³n vÃ¡lida.');
    }
    return Teacher(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      tecnologia:
          json['tecnologia'] is String ? json['tecnologia'] as String : '',
    );
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
          'El horario devuelto por el servidor estÃ¡ incompleto.');
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

class PublishedTutoringSession {
  const PublishedTutoringSession({
    required this.id,
    required this.teacherId,
    required this.subject,
    required this.technology,
    required this.semester,
    required this.start,
    required this.end,
    required this.modality,
    required this.location,
  });

  final String id;
  final String teacherId;
  final String subject;
  final String technology;
  final int semester;
  final DateTime? start;
  final DateTime? end;
  final String modality;
  final String location;

  factory PublishedTutoringSession.fromJson(Map<String, dynamic> json) =>
      PublishedTutoringSession(
        id: json['id'] is String ? json['id'] as String : '',
        teacherId: json['docenteId'] is String ? json['docenteId'] as String : '',
        subject: json['materia'] is String ? json['materia'] as String : 'Tutoría',
        technology: json['tecnologia'] is String ? json['tecnologia'] as String : '',
        semester: json['semestre'] is num ? (json['semestre'] as num).toInt() : 0,
        start: DateTime.tryParse(json['fechaInicio']?.toString() ?? ''),
        end: DateTime.tryParse(json['fechaFin']?.toString() ?? ''),
        modality: json['modalidad']?.toString() ?? '',
        location: json['ubicacion'] is String ? json['ubicacion'] as String : '',
      );
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
    .replaceAll('Ã¡', 'a')
    .replaceAll('Ã©', 'e')
    .replaceAll('Ã­', 'i')
    .replaceAll('Ã³', 'o')
    .replaceAll('Ãº', 'u')
    .replaceAll('Ã¼', 'u')
    .replaceAll('Ã±', 'n');

String apiError(DioException error, String fallback) {
  final response = error.response?.data;
  if (response is Map) {
    for (final key in const ['message', 'detail']) {
      final value = response[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
  }
  if (response is String && response.trim().isNotEmpty) return response.trim();

  final status = error.response?.statusCode;
  if (status != null) {
    return '$fallback El servidor respondió con el código $status, pero no envió detalles.';
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return '$fallback No fue posible comunicarse con el servidor. Verifica que esté iniciado y que la dirección de la API sea correcta.';
    default:
      return '$fallback ${error.message ?? 'Ocurrió un error inesperado.'}';
  }
}
