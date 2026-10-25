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
    this.career = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String career;

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        id: _string(json['id']),
        name: _string(json['nombre'], fallback: 'Estudiante'),
        email: _string(json['correo']),
        phone: _string(json['telefono']),
        role: _string(json['rol']),
        career: _string(json['carrera']),
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
    this.careers = const [],
    this.subjects = const [],
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
  final List<String> careers;
  final List<AvailableSubject> subjects;

  factory AvailableTutor.fromJson(Map<String, dynamic> json) => AvailableTutor(
        teacherId: _string(json['docenteId']),
        name: _string(json['nombre'], fallback: 'Tutor'),
        career: _string(json['carrera']),
        semester:
            json['semestre'] is num ? (json['semestre'] as num).toInt() : 0,
        day: _string(json['dia']),
        startTime: _string(json['horaInicio']),
        endTime: _string(json['horaFin']),
        modality: _string(json['modalidad'], fallback: 'PRESENCIAL'),
        location: _string(json['ubicacion']),
        careers: json['carreras'] is List
            ? (json['carreras'] as List).whereType<String>().toList()
            : [_string(json['carrera'])],
        subjects: json['materias'] is List
            ? (json['materias'] as List)
                .whereType<Map<String, dynamic>>()
                .map(AvailableSubject.fromJson)
                .toList()
            : const [],
      );
}

class AvailableSubject {
  const AvailableSubject({required this.name, required this.careers});
  final String name;
  final List<String> careers;

  factory AvailableSubject.fromJson(Map<String, dynamic> json) =>
      AvailableSubject(
        name: _string(json['nombre']),
        careers: json['carreras'] is List
            ? (json['carreras'] as List).whereType<String>().toList()
            : const [],
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
    this.projectSpaces = const [],
    this.groupSessions = const [],
    this.availableGroupSessions = const [],
  });

  final StudentProfile profile;
  final List<AvailableTutor> tutors;
  final List<StudentTutoring> tutorings;
  final List<ClassroomProjectSpace> projectSpaces;
  final List<StudentGroupSession> groupSessions;
  final List<StudentGroupSession> availableGroupSessions;

  StudentDashboardData withGroupSessions(StudentGroupSessionsData value) =>
      StudentDashboardData(
        profile: profile,
        tutors: tutors,
        tutorings: tutorings,
        projectSpaces: projectSpaces,
        groupSessions: value.enrolled,
        availableGroupSessions: value.available,
      );
}

class StudentGroupSessionsData {
  const StudentGroupSessionsData({required this.enrolled, required this.available});

  final List<StudentGroupSession> enrolled;
  final List<StudentGroupSession> available;
}

class StudentGroupSession {
  const StudentGroupSession({
    required this.id,
    required this.teacherId,
    required this.subject,
    required this.technology,
    required this.technologies,
    required this.semester,
    required this.start,
    required this.end,
    required this.studentCount,
    this.modality = '',
    this.location = '',
  });

  final String id;
  final String teacherId;
  final String subject;
  final String technology;
  final List<String> technologies;
  final int semester;
  final DateTime? start;
  final DateTime? end;
  final int studentCount;
  final String modality;
  final String location;

  factory StudentGroupSession.fromJson(Map<String, dynamic> json) =>
      StudentGroupSession(
        id: _string(json['id']),
        teacherId: _string(json['docenteId']),
        subject: _string(json['materia'], fallback: 'Tutoría'),
        technology: _string(json['tecnologia']),
        technologies: json['tecnologias'] is List
            ? (json['tecnologias'] as List).whereType<String>().toList()
            : const [],
        semester:
            json['semestre'] is num ? (json['semestre'] as num).toInt() : 0,
        start: _date(json['fechaInicio']),
        end: _date(json['fechaFin']),
        studentCount: json['estudianteIds'] is List
            ? (json['estudianteIds'] as List).length
            : 1,
        modality: _string(json['modalidad']),
        location: _string(json['ubicacion']),
      );
}

class ClassroomProjectSpace {
  const ClassroomProjectSpace({
    required this.tutoringId,
    required this.projectId,
    required this.name,
    required this.teacherId,
    required this.career,
    required this.semester,
    required this.enrolledCount,
    required this.enrolled,
    this.createOrJoin = false,
  });

  final String tutoringId;
  final String projectId;
  final String name;
  final String teacherId;
  final String career;
  final int semester;
  final int enrolledCount;
  final bool enrolled;
  final bool createOrJoin;

  factory ClassroomProjectSpace.fromJson(Map<String, dynamic> json) =>
      ClassroomProjectSpace(
        tutoringId: _string(json['tutoriaColectivaId']),
        projectId: _string(json['proyectoId']),
        name: _string(json['nombre'], fallback: 'Proyecto de aula'),
        teacherId: _string(json['docenteResponsableId']),
        career: _string(json['tecnologia']),
        semester:
            json['semestre'] is num ? (json['semestre'] as num).toInt() : 0,
        enrolledCount: json['estudiantesInscritos'] is num
            ? (json['estudiantesInscritos'] as num).toInt()
            : 0,
        enrolled: json['inscrito'] == true,
        createOrJoin: false,
      );

  factory ClassroomProjectSpace.createOrJoin({
    required String tutoringId,
    required String career,
    required int semester,
  }) =>
      ClassroomProjectSpace(
        tutoringId: tutoringId,
        projectId: '',
        name: 'Crear o unirse a un proyecto',
        teacherId: '',
        career: career,
        semester: semester,
        enrolledCount: 0,
        enrolled: false,
        createOrJoin: true,
      );
}

final studentDashboardProvider =
    FutureProvider.autoDispose<StudentDashboardData>((ref) async {
  final dio = ref.read(dioProvider);
  final profileRequest = dio.get<Map<String, dynamic>>('/api/usuarios/perfil');
  final tutorsRequest = dio.get<List<dynamic>>('/api/tutorias/disponibles');
  final tutoringsRequest = dio.get<List<dynamic>>('/api/tutorias');
  final projectsRequest =
      dio.get<List<dynamic>>('/api/estudiante/tutorias-colectivas/espacios');
  await Future.wait<Object>([
    profileRequest,
    tutorsRequest,
    tutoringsRequest,
    projectsRequest,
  ]);
  final profileJson = (await profileRequest).data;
  if (profileJson == null) {
    throw const FormatException('El servidor devolvió un perfil vacío.');
  }
  final tutorsJson = (await tutorsRequest).data ?? const [];
  final tutoringsJson = (await tutoringsRequest).data ?? const [];
  final projectsJson = (await projectsRequest).data ?? const [];
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
  final projectSpaces = <ClassroomProjectSpace>[];
  for (final entry in projectsJson.whereType<Map<String, dynamic>>()) {
    if (entry['proyectos'] is! List) {
      projectSpaces.add(ClassroomProjectSpace.fromJson(entry));
      continue;
    }
    final career = _string(entry['tecnologia']);
    final semester =
        entry['semestre'] is num ? (entry['semestre'] as num).toInt() : 0;
    final tutoringId = _string(entry['tutoriaColectivaId']);
    projectSpaces.addAll(
      (entry['proyectos'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ClassroomProjectSpace.fromJson),
    );
    if (entry['permiteCrearProyecto'] == true) {
      projectSpaces.add(ClassroomProjectSpace.createOrJoin(
        tutoringId: tutoringId,
        career: career,
        semester: semester,
      ));
    }
  }
  return StudentDashboardData(
    profile: profile,
    tutors: tutors,
    tutorings: tutorings,
    projectSpaces: projectSpaces,
  );
});

final studentGroupSessionsProvider =
    FutureProvider.autoDispose<StudentGroupSessionsData>((ref) async {
  final dio = ref.read(dioProvider);
  final enrolledRequest = dio.get<List<dynamic>>('/api/tutorias/grupales');
  final availableRequest =
      dio.get<List<dynamic>>('/api/tutorias/grupales/disponibles');
  final results = await Future.wait([
    enrolledRequest,
    availableRequest,
  ]);
  final enrolled = results[0].data ?? const <dynamic>[];
  final available = results[1].data ?? const <dynamic>[];
  return StudentGroupSessionsData(
    enrolled: enrolled
        .whereType<Map<String, dynamic>>()
        .map(StudentGroupSession.fromJson)
        .toList(),
    available: available
        .whereType<Map<String, dynamic>>()
        .map(StudentGroupSession.fromJson)
        .toList(),
  );
});

Future<Map<String, dynamic>> createOrJoinClassroomProject({
  required Dio dio,
  required String tutoringId,
  required String name,
}) async {
  final response = await dio.post<Map<String, dynamic>>(
    '/api/estudiante/tutorias-colectivas/$tutoringId/proyectos',
    data: {'nombre': name},
  );
  return response.data ?? const {};
}

Future<Map<String, dynamic>> previewClassroomProjectCode({
  required Dio dio,
  required String code,
}) async {
  final response = await dio.get<Map<String, dynamic>>(
    '/api/estudiante/tutorias-colectivas/proyectos/codigo/$code',
  );
  return response.data ?? const {};
}

Future<void> enrollInClassroomProjectCode({
  required Dio dio,
  required String code,
}) async {
  await dio.post<void>(
    '/api/estudiante/tutorias-colectivas/proyectos/inscripcion-codigo',
    data: {'codigo': code},
  );
}

Future<void> leaveClassroomProject({
  required Dio dio,
  required ClassroomProjectSpace space,
}) async {
  await dio.delete<void>(
    '/api/estudiante/tutorias-colectivas/${space.tutoringId}/proyectos/${space.projectId}/inscripcion',
  );
}

Future<void> enrollInTutoring({
  required Dio dio,
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
    '/api/tutorias/grupales/inscripcion',
    data: {
      'docenteId': tutor.teacherId,
      'materia': subject.trim(),
      'modalidad': _apiModality(tutor.modality),
      'fechaInicio': startAt.toIso8601String(),
      'fechaFin': endAt.toIso8601String(),
      'semestre': tutor.semester,
    },
  );
}

Future<void> leaveGroupTutoring(
        {required Dio dio, required String sessionId}) =>
    dio.delete<void>('/api/tutorias/grupales/$sessionId/inscripcion');

Future<void> enrollInPublishedGroupTutoring({
  required Dio dio,
  required StudentGroupSession session,
  required String modality,
}) async {
  final start = session.start;
  final end = session.end;
  if (start == null || end == null) {
    throw const FormatException('El horario publicado no es válido.');
  }
  await dio.post<void>(
    '/api/tutorias/grupales/inscripcion',
    data: {
      'docenteId': session.teacherId,
      'materia': session.subject,
      'modalidad': _apiModality(modality),
      'fechaInicio': start.toIso8601String(),
      'fechaFin': end.toIso8601String(),
      'semestre': session.semester,
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
