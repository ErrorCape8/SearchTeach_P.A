import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'coordinacion_horarios_models.dart';
import 'coordinacion_horarios_widgets.dart';

class CoordinacionHorariosPage extends ConsumerStatefulWidget {
  const CoordinacionHorariosPage({super.key});

  @override
  ConsumerState<CoordinacionHorariosPage> createState() =>
      _CoordinacionHorariosPageState();
}

class _CoordinacionHorariosPageState
    extends ConsumerState<CoordinacionHorariosPage> {
  final _searchController = TextEditingController();
  List<Teacher> _teachers = const [];
  List<TutorSchedule> _schedules = const [];
  List<PublishedTutoringSession> _publishedSessions = const [];
  String _career = 'Todas';
  int? _semester;
  int _section = 0;
  bool _loading = true;
  bool _speedDialOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get<List<dynamic>>('/api/coordinacion/docentes'),
        dio.get<List<dynamic>>('/api/coordinacion/horarios'),
        dio.get<List<dynamic>>('/api/coordinacion/sesiones-grupales'),
      ]);
      final teacherData = results[0].data;
      final scheduleData = results[1].data;
      final publishedData = results[2].data;
      if (teacherData == null || scheduleData == null || publishedData == null) {
        throw const FormatException(
            'El servidor devolvió una lista incompleta.');
      }
      final teachers = teacherData.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
              'El servidor devolvió un docente inválido.');
        }
        return Teacher.fromJson(entry);
      }).toList(growable: false);
      final schedules = scheduleData.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
              'El servidor devolvió un horario inválido.');
        }
        return TutorSchedule.fromJson(entry);
      }).toList(growable: false);
      final publishedSessions = publishedData
          .whereType<Map<String, dynamic>>()
          .map(PublishedTutoringSession.fromJson)
          .where((session) => session.teacherId.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        _schedules = schedules;
        _publishedSessions = publishedSessions;
        if (!_careers.contains(_career)) _career = 'Todas';
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiError(error, 'No se pudieron cargar los horarios.');
        _loading = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  List<String> get _careers {
    final careers = _schedules
        .expand((item) => [
              item.carrera,
              ...item.materias.expand((subject) => subject.carreras),
        ])
        .followedBy(_publishedSessions
            .map((session) => session.technology)
            .where((value) => value.isNotEmpty))
        .toSet()
        .toList()
      ..sort();
    return ['Todas', ...careers];
  }

  Map<String, TutorSchedule> get _scheduleByTeacher => {
        for (final schedule in _schedules) schedule.docenteId: schedule,
      };

  Map<String, List<PublishedTutoringSession>> get _sessionsByTeacher {
    final grouped = <String, List<PublishedTutoringSession>>{};
    for (final session in _publishedSessions) {
      grouped.putIfAbsent(session.teacherId, () => []).add(session);
    }
    return grouped;
  }

  bool _hasAvailability(String teacherId) =>
      _scheduleByTeacher.containsKey(teacherId) ||
      _sessionsByTeacher.containsKey(teacherId);

  List<Teacher> get _visibleTeachers {
    final query = normalizeSearch(_searchController.text.trim());
    final schedules = _scheduleByTeacher;
    final sessionsByTeacher = _sessionsByTeacher;
    final source = _section == 0
        ? _teachers.where((teacher) => _hasAvailability(teacher.id))
        : _teachers.where((teacher) => !_hasAvailability(teacher.id));
    return source.where((teacher) {
      final schedule = schedules[teacher.id];
      final matchesText = query.isEmpty ||
          normalizeSearch(teacher.nombre).contains(query) ||
          normalizeSearch(teacher.id).contains(query);
      final sessions = sessionsByTeacher[teacher.id] ??
          const <PublishedTutoringSession>[];
      final matchesCareer = (schedule == null && sessions.isEmpty) ||
          _career == 'Todas' ||
          (schedule != null &&
              (schedule.carrera == _career ||
                  schedule.materias
                      .any((subject) => subject.carreras.contains(_career)))) ||
          sessions.any((session) => session.technology == _career);
      final matchesSemester = (schedule == null && sessions.isEmpty) ||
          _semester == null ||
          (schedule != null && schedule.semestre == _semester) ||
          sessions.any((session) => session.semester == _semester);
      return matchesText && matchesCareer && matchesSemester;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF3F5FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFA9154F),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Horarios de tutores'),
              Text(
                'Asigna y administra su disponibilidad',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_speedDialOpen) ...[
              FloatingActionButton.extended(
                heroTag: 'tutorias_proyecto_aula',
                onPressed: () =>
                    context.push('/coordinacion/tutorias-colectivas'),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFA9154F),
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Tutorías de proyecto de aula'),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'tutorias_retroalimentativas',
                onPressed: () async {
                  await context.push('/coordinacion/programar-tutorias');
                  if (mounted) _load();
                },
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFA9154F),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Tutorías retroalimentativas'),
              ),
              const SizedBox(height: 12),
            ],
            FloatingActionButton.extended(
              heroTag: 'programar_tutorias_speed_dial',
              onPressed: () => setState(() => _speedDialOpen = !_speedDialOpen),
              backgroundColor: const Color(0xFFA9154F),
              foregroundColor: Colors.white,
              icon: Icon(_speedDialOpen ? Icons.close : Icons.add),
              label: Text(_speedDialOpen ? 'Cerrar' : 'Programar tutorías'),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ScheduleLoadError(message: _error!, onRetry: _load)
                      : Column(
                          children: [
                            ScheduleSectionSelector(
                              selected: _section,
                              withScheduleCount: _teachers
                                  .where((teacher) => _hasAvailability(teacher.id))
                                  .length,
                              withoutScheduleCount: _teachers
                                  .where((teacher) => !_hasAvailability(teacher.id))
                                  .length,
                              onChanged: (value) =>
                                  setState(() => _section = value),
                            ),
                            ScheduleFilters(
                              searchController: _searchController,
                              careers: _careers,
                              career: _career,
                              semester: _semester,
                              onSearchChanged: (_) => setState(() {}),
                              onCareerChanged: (value) =>
                                  setState(() => _career = value),
                              onSemesterChanged: (value) =>
                                  setState(() => _semester = value),
                              onRefresh: _load,
                              refreshing: _loading,
                            ),
                            Expanded(
                              child: _visibleTeachers.isEmpty
                                  ? const ScheduleEmptyResults()
                                  : TeacherScheduleGrid(
                                      teachers: _visibleTeachers,
                                      schedules: _scheduleByTeacher,
                                      sessions: _sessionsByTeacher,
                                    ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      );
}
