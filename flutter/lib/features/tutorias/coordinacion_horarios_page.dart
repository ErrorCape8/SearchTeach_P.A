import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'coordinacion_horarios_form.dart';
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
  String _career = 'Todas';
  int? _semester;
  int _section = 0;
  bool _loading = true;
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
      ]);
      final teacherData = results[0].data;
      final scheduleData = results[1].data;
      if (teacherData == null || scheduleData == null) {
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
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        _schedules = schedules;
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
        .toSet()
        .toList()
      ..sort();
    return ['Todas', ...careers];
  }

  Map<String, TutorSchedule> get _scheduleByTeacher => {
        for (final schedule in _schedules) schedule.docenteId: schedule,
      };

  List<Teacher> get _visibleTeachers {
    final query = normalizeSearch(_searchController.text.trim());
    final schedules = _scheduleByTeacher;
    final source = _section == 0
        ? _teachers
        : _teachers.where((teacher) => schedules.containsKey(teacher.id));
    return source.where((teacher) {
      final schedule = schedules[teacher.id];
      final matchesText = query.isEmpty ||
          normalizeSearch(teacher.nombre).contains(query) ||
          normalizeSearch(teacher.id).contains(query);
      final matchesCareer = _career == 'Todas' ||
          schedule?.carrera == _career ||
          (schedule?.materias
                  .any((subject) => subject.carreras.contains(_career)) ??
              false);
      final matchesSemester =
          _semester == null || schedule?.semestre == _semester;
      return matchesText && matchesCareer && matchesSemester;
    }).toList(growable: false);
  }

  Future<void> _editSchedule(Teacher teacher) async {
    final existing = _scheduleByTeacher[teacher.id];
    final result = await Navigator.of(context).push<TutorSchedule>(
      MaterialPageRoute(
        builder: (_) => CoordinacionHorariosFormPage(
          teacher: teacher,
          existing: existing,
          subjectSuggestions: _schedules
              .expand((schedule) =>
                  schedule.materias.map((subject) => subject.nombre))
              .toSet()
              .toList(growable: false),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _schedules = [
        result,
        ..._schedules.where((item) => item.docenteId != teacher.id),
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            existing == null ? 'Horario asignado.' : 'Horario actualizado.'),
      ),
    );
  }

  Future<void> _deleteSchedule(Teacher teacher) async {
    final schedule = _scheduleByTeacher[teacher.id];
    if (schedule == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar horario'),
        content: Text(
          '¿Eliminar el horario publicado de ${teacher.nombre}? '
          'Las tutorías ya creadas no se modificarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(dioProvider).delete<void>(
            '/api/coordinacion/horarios/${Uri.encodeComponent(teacher.id)}',
          );
      if (!mounted) return;
      setState(() => _schedules =
          _schedules.where((item) => item.docenteId != teacher.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horario eliminado.')),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(apiError(error, 'No se pudo eliminar el horario.'))),
      );
    }
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
          actions: [
            TextButton.icon(
              onPressed: () =>
                  context.push('/coordinacion/tutorias-colectivas'),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Tutorías colectivas'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/coordinacion/tutorias-colectivas'),
          backgroundColor: const Color(0xFFA9154F),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Crear tutoría colectiva'),
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
                              scheduleCount: _schedules.length,
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
                            ),
                            Expanded(
                              child: _visibleTeachers.isEmpty
                                  ? const ScheduleEmptyResults()
                                  : TeacherScheduleGrid(
                                      teachers: _visibleTeachers,
                                      schedules: _scheduleByTeacher,
                                      onSelect: _editSchedule,
                                      onDelete: _deleteSchedule,
                                    ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      );
}
