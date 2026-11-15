import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/widgets/role_toast.dart';
import '../pa/pa_widgets.dart';
import 'coordinacion_horarios_models.dart';
import 'coordinacion_horarios_form.dart';
import 'coordinacion_horarios_widgets.dart';
import '../../core/tutoring_updates.dart';

const _wine = Color(0xFFA9154F);

class CoordinacionHorariosPage extends ConsumerStatefulWidget {
  const CoordinacionHorariosPage({this.leading, super.key});

  final Widget? leading;

  @override
  ConsumerState<CoordinacionHorariosPage> createState() =>
      _CoordinacionHorariosPageState();
}

class _CoordinacionHorariosPageState
    extends ConsumerState<CoordinacionHorariosPage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  List<Teacher> _teachers = const [];
  List<TutorSchedule> _schedules = const [];
  List<PublishedTutoringSession> _publishedSessions = const [];
  String _career = 'Todas';
  int? _semester;
  int _section = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      final results = await Future.wait<Response<List<dynamic>>>([
        dio.get<List<dynamic>>('/api/coordinacion/docentes'),
        dio.get<List<dynamic>>('/api/coordinacion/horarios'),
        dio.get<List<dynamic>>('/api/coordinacion/sesiones-grupales'),
      ]);
      final teacherData = results[0].data;
      final scheduleData = results[1].data;
      final publishedData = results[2].data;
      if (teacherData == null ||
          scheduleData == null ||
          publishedData == null) {
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

  Future<void> _editTeacherSchedule(
    Teacher teacher,
    TutorSchedule? existing,
  ) async {
    final saved = await Navigator.of(context).push<TutorSchedule>(
      MaterialPageRoute(
        builder: (_) => CoordinacionHorariosFormPage(
          teacher: teacher,
          existing: existing,
        ),
      ),
    );
    if (saved != null && mounted) await _load();
  }

  Future<void> _chooseTutoringType() async {
    final selected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Neu.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Programar tutoría',
          style: neuPoppins(
              size: 18, weight: FontWeight.w700, color: Neu.heading),
        ),
        content: Text(
          'Selecciona el tipo de tutoría que deseas crear.',
          style: neuBody(color: Neu.muted),
        ),
        actions: [
          NeuButton(
            'Cerrar',
            kind: NeuButtonKind.alt,
            small: true,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, null),
          ),
          NeuButton(
            'Tutorías de proyecto de aula',
            kind: NeuButtonKind.alt,
            icon: Icons.groups_outlined,
            small: true,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
          NeuButton(
            'Tutorías retroalimentativas',
            icon: Icons.rate_review_outlined,
            small: true,
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    if (selected) {
      await context.push('/coordinacion/tutorias-colectivas');
      return;
    }
    await context.push('/coordinacion/programar-tutorias');
    if (mounted) _load();
  }

  Future<void> _deleteSession(PublishedTutoringSession session) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Neu.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Eliminar tutoría',
            style: neuPoppins(
                size: 18, weight: FontWeight.w700, color: Neu.heading),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para confirmar, escribe eliminar.',
                style: neuBody(color: Neu.muted),
              ),
              const SizedBox(height: 12),
              NeuField(
                controller: controller,
                hint: 'Escribe eliminar',
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            NeuButton(
              'Cancelar',
              kind: NeuButtonKind.alt,
              small: true,
              expand: false,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            NeuButton(
              'Eliminar',
              kind: NeuButtonKind.danger,
              small: true,
              expand: false,
              onPressed: controller.text.trim().toLowerCase() == 'eliminar'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(dioProvider)
          .delete<void>('/api/coordinacion/sesiones-grupales/${session.id}');
      if (!mounted) return;
      RoleToast.show(context,
          message: 'Tutoría eliminada.', roleColor: _wine);
      await _load();
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.show(context,
            message: apiError(error, 'No se pudo eliminar la tutoría.'),
            roleColor: _wine);
      }
    }
  }

  Future<void> _editSession(PublishedTutoringSession session) async {
    final subjectController = TextEditingController(text: session.subject);
    final locationController = TextEditingController(text: session.location);
    DateTime start =
        session.start?.toLocal() ?? DateTime.now().add(const Duration(days: 1));
    final duration = session.end != null && session.start != null
        ? session.end!.difference(session.start!)
        : const Duration(hours: 1);
    String modality = session.modality.toUpperCase();
    if (!const ['PRESENCIAL', 'VIRTUAL', 'HIBRIDA'].contains(modality)) {
      modality = 'PRESENCIAL';
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Neu.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Editar tutoría',
            style: neuPoppins(
                size: 18, weight: FontWeight.w700, color: Neu.heading),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PaFieldLabel('Materia', first: true),
                NeuField(
                  controller: subjectController,
                  hint: 'Materia',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: NeuButton(
                        '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}',
                        icon: Icons.calendar_month,
                        kind: NeuButtonKind.alt,
                        small: true,
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: start,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => start = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                start.hour,
                                start.minute));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: NeuButton(
                        TimeOfDay.fromDateTime(start).format(context),
                        icon: Icons.schedule,
                        kind: NeuButtonKind.alt,
                        small: true,
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(start),
                          );
                          if (picked != null) {
                            setDialogState(() => start = DateTime(
                                start.year,
                                start.month,
                                start.day,
                                picked.hour,
                                picked.minute));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const PaFieldLabel('Modalidad'),
                NeuDropdown<String>(
                  items: const ['PRESENCIAL', 'VIRTUAL', 'HIBRIDA'],
                  value: modality,
                  labelOf: (v) => switch (v) {
                    'PRESENCIAL' => 'Presencial',
                    'VIRTUAL' => 'Virtual',
                    'HIBRIDA' => 'Híbrida',
                    _ => v,
                  },
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => modality = value);
                    }
                  },
                ),
                if (modality != 'VIRTUAL') ...[
                  const PaFieldLabel('Lugar'),
                  NeuField(
                    controller: locationController,
                    hint: 'Lugar',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            NeuButton(
              'Cancelar',
              kind: NeuButtonKind.alt,
              small: true,
              expand: false,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            NeuButton(
              'Guardar',
              small: true,
              expand: false,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      subjectController.dispose();
      locationController.dispose();
      return;
    }
    final end = start.add(duration);
    try {
      await ref.read(dioProvider).put<void>(
          '/api/coordinacion/sesiones-grupales/${session.id}',
          data: {
            'tecnologia': session.technology,
            'semestre': session.semester,
            'bloques': [
              {
                'docenteId': session.teacherId,
                'materia': subjectController.text.trim(),
                'modalidad': modality,
                'ubicacion': modality == 'VIRTUAL'
                    ? null
                    : locationController.text.trim(),
                'fechaInicio': start.toIso8601String(),
                'fechaFin': end.toIso8601String(),
              }
            ],
          });
      if (mounted) {
        RoleToast.show(context,
            message: 'Tutoría actualizada.',
            roleColor: _wine);
        await _load();
      }
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.show(context,
            message: apiError(error, 'No se pudo editar la tutoría.'),
            roleColor: _wine);
      }
    } finally {
      subjectController.dispose();
      locationController.dispose();
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
      final sessions =
          sessionsByTeacher[teacher.id] ?? const <PublishedTutoringSession>[];
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
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) _load();
    });

    final wide = MediaQuery.sizeOf(context).width >= 650;
    final withCount = _teachers
        .where((teacher) => _hasAvailability(teacher.id))
        .length;
    final withoutCount = _teachers
        .where((teacher) => !_hasAvailability(teacher.id))
        .length;

    return ColoredBox(
      color: Neu.bg,
      child: Column(
        children: [
          NeuHeader(
            title: 'Horarios de tutores',
            subtitle: 'Asigna y administra su disponibilidad',
            leading: widget.leading,
            actions: [
              if (wide)
                NeuButton(
                  'Programar tutoría',
                  onPressed: _chooseTutoringType,
                  icon: Icons.add,
                  small: true,
                  expand: false,
                )
              else
                NeuCircleButton(
                  icon: Icons.add,
                  tooltip: 'Programar tutoría',
                  onTap: _chooseTutoringType,
                ),
              const NeuHeaderLogo(),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _wine,
                        ),
                      )
                    : _error != null
                        ? ScheduleLoadError(message: _error!, onRetry: _load)
                        : Column(
                            children: [
                              ScheduleSectionSelector(
                                selected: _section,
                                withScheduleCount: withCount,
                                withoutScheduleCount: withoutCount,
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
                                        onEditSession: _editSession,
                                        onDeleteSession: _deleteSession,
                                        onEditSchedule: _editTeacherSchedule,
                                      ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
