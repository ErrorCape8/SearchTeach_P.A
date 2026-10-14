import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        id: _string(json['id']),
        name: _string(json['nombre'], fallback: 'Estudiante'),
        email: _string(json['correo']),
        phone: _string(json['telefono']),
        role: _string(json['rol']),
      );
}

class AvailableTutor {
  const AvailableTutor({
    required this.teacherId,
    required this.name,
    required this.career,
    required this.semester,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.modality,
    required this.location,
  });

  final String teacherId;
  final String name;
  final String career;
  final int semester;
  final String day;
  final String startTime;
  final String endTime;
  final String modality;
  final String location;

  factory AvailableTutor.fromJson(Map<String, dynamic> json) => AvailableTutor(
        teacherId: _string(json['docenteId']),
        name: _string(json['nombre'], fallback: 'Tutor'),
        career: _string(json['carrera']),
        semester:
            json['semestre'] is num ? (json['semestre'] as num).toInt() : 0,
        day: _string(json['dia']),
        startTime: _string(json['horaInicio']),
        endTime: _string(json['horaFin']),
        modality: _string(json['modalidad']),
        location: _string(json['ubicacion']),
      );
}

class StudentTutoring {
  const StudentTutoring({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.subject,
    required this.modality,
    required this.start,
    required this.end,
    required this.alternativeStart,
    required this.status,
  });

  final String id;
  final String teacherId;
  final String studentId;
  final String subject;
  final String modality;
  final DateTime? start;
  final DateTime? end;
  final DateTime? alternativeStart;
  final String status;

  factory StudentTutoring.fromJson(Map<String, dynamic> json) =>
      StudentTutoring(
        id: _string(json['id']),
        teacherId: _string(json['docenteId']),
        studentId: _string(json['estudianteId']),
        subject: _string(json['materia'], fallback: 'Tutoría'),
        modality: _string(json['modalidad']),
        start: _date(json['fechaInicio']),
        end: _date(json['fechaFin']),
        alternativeStart: _date(json['fechaAlternativaInicio']),
        status: _string(json['estado']),
      );
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.profile,
    required this.tutors,
    required this.tutorings,
  });

  final StudentProfile profile;
  final List<AvailableTutor> tutors;
  final List<StudentTutoring> tutorings;
}

final studentDashboardProvider =
    FutureProvider.autoDispose<StudentDashboardData>((ref) async {
  final dio = ref.read(dioProvider);
  final profileRequest = dio.get<Map<String, dynamic>>('/api/usuarios/perfil');
  final tutorsRequest = dio.get<List<dynamic>>('/api/tutorias/disponibles');
  final tutoringsRequest = dio.get<List<dynamic>>('/api/tutorias');
  await Future.wait<Object>([profileRequest, tutorsRequest, tutoringsRequest]);
  final profileJson = (await profileRequest).data;
  if (profileJson == null) {
    throw const FormatException('El servidor devolvió un perfil vacío.');
  }
  final tutorsJson = (await tutorsRequest).data ?? const [];
  final tutoringsJson = (await tutoringsRequest).data ?? const [];
  final profile = StudentProfile.fromJson(profileJson);
  final tutors = tutorsJson
      .whereType<Map<String, dynamic>>()
      .map(AvailableTutor.fromJson)
      .where((tutor) => tutor.teacherId != profile.id)
      .toList();
  final tutorings = tutoringsJson
      .whereType<Map<String, dynamic>>()
      .map(StudentTutoring.fromJson)
      .where((tutoring) => tutoring.studentId == profile.id)
      .toList();
  return StudentDashboardData(
    profile: profile,
    tutors: tutors,
    tutorings: tutorings,
  );
});

Future<void> enrollInTutoring({
  required Dio dio,
  required StudentProfile student,
  required AvailableTutor tutor,
  required String subject,
  required DateTime start,
}) async {
  final parts = tutor.startTime.split(':');
  if (parts.length < 2) {
    throw const FormatException('El horario del tutor no es válido.');
  }
  final startAt = DateTime(
    start.year,
    start.month,
    start.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
  final endParts = tutor.endTime.split(':');
  if (endParts.length < 2) {
    throw const FormatException('El horario del tutor no es válido.');
  }
  final availableUntil = DateTime(
    start.year,
    start.month,
    start.day,
    int.parse(endParts[0]),
    int.parse(endParts[1]),
  );
  if (!availableUntil.isAfter(startAt)) {
    throw const FormatException('El horario del tutor no es válido.');
  }
  final endAt = startAt.add(const Duration(hours: 1));
  if (endAt.isAfter(availableUntil)) {
    throw const FormatException(
        'El horario seleccionado no alcanza para una tutoría de una hora.');
  }
  await dio.post<void>(
    '/api/tutorias',
    data: {
      'estudianteId': student.id,
      'docenteId': tutor.teacherId,
      'materia': subject.trim(),
      'modalidad': _apiModality(tutor.modality),
      'fechaInicio': startAt.toIso8601String(),
      'fechaFin': endAt.toIso8601String(),
    },
  );
}

Future<void> updateTutoring({
  required Dio dio,
  required StudentTutoring tutoring,
  required String action,
}) =>
    dio.patch<void>('/api/tutorias/${tutoring.id}/$action');

String _apiModality(String value) {
  switch (value.toLowerCase()) {
    case 'presencial':
      return 'PRESENCIAL';
    case 'híbrida':
    case 'hibrida':
      return 'HIBRIDA';
    case 'virtual':
      return 'VIRTUAL';
    default:
      throw FormatException('Modalidad desconocida: $value');
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
