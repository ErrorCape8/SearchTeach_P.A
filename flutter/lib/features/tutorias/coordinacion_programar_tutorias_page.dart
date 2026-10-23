import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/career_catalog.dart';
import 'coordinacion_horarios_models.dart';

class CoordinacionProgramarTutoriasPage extends ConsumerStatefulWidget {
  const CoordinacionProgramarTutoriasPage({super.key});

  @override
  ConsumerState<CoordinacionProgramarTutoriasPage> createState() =>
      _CoordinacionProgramarTutoriasPageState();
}

class _CoordinacionProgramarTutoriasPageState
    extends ConsumerState<CoordinacionProgramarTutoriasPage> {
  static const _brand = Color(0xFFA9154F);
  String _technology = careerCatalog.first;
  int _semester = 1;
  String? _subject;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  String? _teacherId;
  List<String> _subjects = const [];
  List<Teacher> _teachers = const [];
  List<TutorSchedule> _schedules = const [];
  final List<_PlannedSlot> _slots = [];
  bool _loading = true;
  bool _loadingSubjects = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    _loadSubjects();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get<List<dynamic>>('/api/coordinacion/docentes'),
        dio.get<List<dynamic>>('/api/coordinacion/horarios'),
      ]);
      if (!mounted) return;
      setState(() {
        _teachers = (results[0].data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Teacher.fromJson)
            .toList();
        _schedules = (results[1].data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TutorSchedule.fromJson)
            .toList();
        _loading = false;
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _error = apiError(error, 'No se pudieron cargar los docentes.');
          _loading = false;
        });
      }
    } on FormatException catch (error) {
      if (mounted) setState(() { _error = error.message; _loading = false; });
    }
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _loadingSubjects = true;
      _subject = null;
      _subjects = const [];
      _teacherId = null;
    });
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>(
        '/api/coordinacion/horarios/materias',
        queryParameters: {'carrera': _technology, 'semestre': _semester},
      );
      if (!mounted) return;
      setState(() {
        _subjects = (response.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) => item['nombre'])
            .whereType<String>()
            .toList();
        _loadingSubjects = false;
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _error = apiError(error, 'No se pudieron cargar las materias.');
          _loadingSubjects = false;
        });
      }
    }
  }

  TutorSchedule? _scheduleFor(String id) {
    for (final schedule in _schedules) {
      if (schedule.docenteId == id) return schedule;
    }
    return null;
  }

  List<Teacher> get _compatibleTeachers {
    if (_subject == null) return const [];
    return _teachers.where((teacher) {
      final schedule = _scheduleFor(teacher.id);
      if (schedule == null || schedule.semestre != _semester ||
          !_supportsTechnology(schedule) || !_supportsSubject(schedule)) {
        return false;
      }
      if (_date == null || _start == null || _end == null) return true;
      final start = DateTime(_date!.year, _date!.month, _date!.day,
          _start!.hour, _start!.minute);
      final end = DateTime(_date!.year, _date!.month, _date!.day,
          _end!.hour, _end!.minute);
      return !_slots.any((slot) => slot.teacher.id == teacher.id &&
          start.isBefore(slot.end) && slot.start.isBefore(end));
    }).toList();
  }

  bool _supportsTechnology(TutorSchedule schedule) =>
      schedule.carrera == _technology ||
      schedule.materias.any((item) => item.carreras.contains(_technology));

  bool _supportsSubject(TutorSchedule schedule) => schedule.materias.any(
      (item) => item.nombre.toLowerCase() == _subject?.toLowerCase() &&
          item.carreras.contains(_technology));

  void _addSlot() {
    final date = _date;
    final time = _start;
    final endTime = _end;
    Teacher? teacher;
    for (final item in _teachers) {
      if (item.id == _teacherId) teacher = item;
    }
    final subject = _subject;
    final selectedTeacher = teacher;
    if (date == null || time == null || endTime == null ||
        selectedTeacher == null || subject == null) return;
    final schedule = _scheduleFor(selectedTeacher.id);
    if (schedule == null) return;
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final end = DateTime(date.year, date.month, date.day,
        endTime.hour, endTime.minute);
    if (!end.isAfter(start) || !start.isAfter(DateTime.now())) {
      setState(() => _error = 'La hora final debe ser posterior a la inicial y la fecha debe ser futura.');
      return;
    }
    setState(() {
      _slots.add(_PlannedSlot(
        teacher: selectedTeacher,
        subject: subject,
        start: start,
        end: end,
        schedule: schedule,
      ));
      _teacherId = null;
    });
  }

  Future<void> _save() async {
    if (_slots.isEmpty) {
      setState(() => _error = 'Agrega al menos una tutoría antes de guardar.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(dioProvider).post<List<dynamic>>(
        '/api/coordinacion/sesiones-grupales',
        data: {
          'tecnologia': _technology,
          'semestre': _semester,
          'bloques': _slots.map((slot) => {
            'docenteId': slot.teacher.id,
            'materia': slot.subject,
            'modalidad': _apiModality(slot.schedule.modalidad),
            'fechaInicio': slot.start.toIso8601String(),
            'fechaFin': slot.end.toIso8601String(),
          }).toList(),
        },
      );
      if (!mounted) return;
      setState(() => _slots.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TutorÃ­as programadas y publicadas.')),
      );
    } on DioException catch (error) {
      if (mounted) setState(() => _error = apiError(error, 'No se pudieron programar las tutorÃ­as.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Programar tutorÃ­as'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => context.push('/coordinacion/tutorias-colectivas'),
                icon: const Icon(Icons.folder_outlined),
                label: const Text('Proyectos de aula'),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _teachers.isEmpty
                ? Center(child: Text(_error!))
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Text(
                            'Crea sesiones grupales y define cuánto dura cada una. Los docentes se filtran por tecnología, semestre y materia; la coordinadora define el día y las horas.',
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: _technology,
                            decoration: const InputDecoration(
                              labelText: 'TecnologÃ­a',
                              border: OutlineInputBorder(),
                            ),
                            items: careerCatalog.map((value) => DropdownMenuItem(
                              value: value, child: Text(value),
                            )).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() { _technology = value; _slots.clear(); });
                              _loadSubjects();
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _semester,
                            decoration: const InputDecoration(
                              labelText: 'Semestre',
                              border: OutlineInputBorder(),
                            ),
                            items: [for (var i = 1; i <= 6; i++)
                              DropdownMenuItem(value: i, child: Text('$i'))],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() { _semester = value; _slots.clear(); });
                              _loadSubjects();
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _subject,
                            decoration: const InputDecoration(
                              labelText: 'Materia',
                              border: OutlineInputBorder(),
                            ),
                            items: _subjects.map((value) => DropdownMenuItem(
                              value: value, child: Text(value),
                            )).toList(),
                            onChanged: _loadingSubjects ? null : (value) => setState(() {
                              _subject = value;
                              _slots.clear();
                              _teacherId = null;
                            }),
                          ),
                          if (_loadingSubjects) const LinearProgressIndicator(),
                          const SizedBox(height: 20),
                          const Text('Agregar tutoría', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final value = await showDatePicker(
                                    context: context,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 180)),
                                    initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
                                  );
                                  if (value != null) setState(() { _date = value; _teacherId = null; });
                                },
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: Text(_date == null ? 'Elegir fecha' : _dateLabel(_date!)),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final value = await showTimePicker(
                                    context: context,
                                    initialTime: _start ?? const TimeOfDay(hour: 8, minute: 0),
                                  );
                                  if (value != null) setState(() { _start = value; _teacherId = null; });
                                },
                                icon: const Icon(Icons.schedule),
                                label: Text(_start == null ? 'Hora de inicio' : 'Inicio: ${_start!.format(context)}'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final value = await showTimePicker(
                                    context: context,
                                    initialTime: _end ?? const TimeOfDay(hour: 9, minute: 0),
                                  );
                                  if (value != null) setState(() { _end = value; _teacherId = null; });
                                },
                                icon: const Icon(Icons.schedule_outlined),
                                label: Text(_end == null ? 'Hora de fin' : 'Fin: ${_end!.format(context)}'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _teacherId,
                            decoration: const InputDecoration(
                              labelText: 'Docente para esta materia y tecnología',
                              border: OutlineInputBorder(),
                            ),
                            items: _compatibleTeachers.map((teacher) => DropdownMenuItem(
                              value: teacher.id,
                              child: Text('${teacher.nombre} Â· ${teacher.id}'),
                            )).toList(),
                            onChanged: (value) => setState(() => _teacherId = value),
                          ),
                          if (_subject != null && _compatibleTeachers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('No hay docentes asignados a esta materia y tecnología.'),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              onPressed: _teacherId == null || _date == null || _start == null || _end == null
                                  ? null
                                  : _addSlot,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar a la lista'),
                            ),
                          ),
                          const Divider(height: 28),
                          Text('Tutorías por publicar (${_slots.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_slots.isEmpty)
                            const Text('AÃºn no has agregado tutorías.'),
                          for (final slot in _slots)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.event_available, color: _brand),
                                title: Text('${slot.subject} Â· ${slot.teacher.nombre}'),
                                subtitle: Text('${_dateLabel(slot.start)} Â· ${_timeLabel(slot.start)}â€“${_timeLabel(slot.end)} Â· ${slot.schedule.modalidad}'),
                                trailing: IconButton(
                                  tooltip: 'Quitar horario',
                                  onPressed: () => setState(() => _slots.remove(slot)),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.publish_outlined),
                            label: Text(_saving ? 'Publicandoâ€¦' : 'Publicar ${_slots.length} tutorÃ­as'),
                          ),
                        ],
                      ),
                    ),
                  ),
      );

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _apiModality(String value) {
    switch (value.toLowerCase()) {
      case 'presencial': return 'PRESENCIAL';
      case 'virtual': return 'VIRTUAL';
      default: return 'HIBRIDA';
    }
  }
}

class _PlannedSlot {
  const _PlannedSlot({
    required this.teacher,
    required this.subject,
    required this.start,
    required this.end,
    required this.schedule,
  });

  final Teacher teacher;
  final String subject;
  final DateTime start;
  final DateTime end;
  final TutorSchedule schedule;
}
