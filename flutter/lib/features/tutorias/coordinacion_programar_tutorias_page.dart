import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String _modality = 'Presencial';
  String? _teacherId;
  List<String> _subjects = const [];
  List<Teacher> _teachers = const [];
  final List<_PlannedSlot> _slots = [];
  final _locationController = TextEditingController();
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
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get<List<dynamic>>('/api/coordinacion/docentes');
      if (!mounted) return;
      setState(() {
        _teachers = (response.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Teacher.fromJson)
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
      if (mounted)
        setState(() {
          _error = error.message;
          _loading = false;
        });
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

  List<Teacher> get _compatibleTeachers {
    if (_subject == null) return const [];
    return _teachers.where((teacher) {
      if (normalizeSearch(teacher.tecnologia) != normalizeSearch(_technology)) {
        return false;
      }
      if (_slots.where((slot) => slot.teacher.id == teacher.id).length >= 3) {
        return false;
      }
      if (_date == null || _start == null || _end == null) return true;
      final start = DateTime(
          _date!.year, _date!.month, _date!.day, _start!.hour, _start!.minute);
      final end = DateTime(
          _date!.year, _date!.month, _date!.day, _end!.hour, _end!.minute);
      return !_slots.any((slot) =>
          slot.teacher.id == teacher.id &&
          start.isBefore(slot.end) &&
          slot.start.isBefore(end));
    }).toList();
  }

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
    if (date == null ||
        time == null ||
        endTime == null ||
        selectedTeacher == null ||
        subject == null) return;
    final location = _locationController.text.trim();
    if (_modality != 'Virtual' && location.isEmpty) {
      setState(() => _error =
          'Indica el lugar físico para las tutorías presenciales o híbridas.');
      return;
    }
    final start =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final end =
        DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
    if (!end.isAfter(start) || !start.isAfter(DateTime.now())) {
      setState(() => _error =
          'Puedes programar para hoy; la hora de inicio debe ser futura y la hora final posterior.');
      return;
    }
    if (_slots.length >= 3) {
      setState(() =>
          _error = 'Puedes agregar como máximo tres tutorías por publicación.');
      return;
    }
    if (_slots.where((slot) => slot.teacher.id == selectedTeacher.id).length >=
        3) {
      setState(() =>
          _error = 'Este docente ya tiene tres tutorías en esta publicación.');
      return;
    }
    if (_slots.any((slot) =>
        slot.teacher.id == selectedTeacher.id &&
        start.isBefore(slot.end) &&
        slot.start.isBefore(end))) {
      setState(
          () => _error = 'El docente ya tiene una tutoría en ese horario.');
      return;
    }
    setState(() {
      _slots.add(_PlannedSlot(
        teacher: selectedTeacher,
        subject: subject,
        start: start,
        end: end,
        modality: _modality,
        location: location,
      ));
      _teacherId = null;
    });
  }

  Future<void> _save() async {
    if (_slots.isEmpty) {
      setState(() => _error = 'Agrega al menos una tutoría antes de guardar.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post<List<dynamic>>(
        '/api/coordinacion/sesiones-grupales',
        data: {
          'tecnologia': _technology,
          'semestre': _semester,
          'bloques': _slots
              .map((slot) => {
                    'docenteId': slot.teacher.id,
                    'materia': slot.subject,
                    'modalidad': _apiModality(slot.modality),
                    'ubicacion': slot.location.isEmpty ? null : slot.location,
                    'fechaInicio': slot.start.toIso8601String(),
                    'fechaFin': slot.end.toIso8601String(),
                  })
              .toList(),
        },
      );
      if (!mounted) return;
      setState(() => _slots.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutorías programadas y publicadas.')),
      );
    } on DioException catch (error) {
      if (mounted)
        setState(() =>
            _error = apiError(error, 'No se pudieron programar las tutorías.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Programar tutorías'),
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
                            'Programa tutorías para docentes de una tecnología, elige la materia, fecha, horas y modalidad. Puedes publicar hasta tres tutorías por vez.',
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: _technology,
                            decoration: const InputDecoration(
                              labelText: 'Tecnología',
                              border: OutlineInputBorder(),
                            ),
                            items: careerCatalog
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _technology = value;
                                _slots.clear();
                              });
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
                            items: [
                              for (var i = 1; i <= 6; i++)
                                DropdownMenuItem(value: i, child: Text('$i'))
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _semester = value;
                                _slots.clear();
                              });
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
                            items: _subjects
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: _loadingSubjects
                                ? null
                                : (value) => setState(() {
                                      _subject = value;
                                      _slots.clear();
                                      _teacherId = null;
                                    }),
                          ),
                          if (_loadingSubjects) const LinearProgressIndicator(),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: _modality,
                            decoration: const InputDecoration(
                              labelText: 'Modalidad',
                              border: OutlineInputBorder(),
                            ),
                            items: const ['Presencial', 'Virtual', 'Híbrida']
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _modality = value);
                              }
                            },
                          ),
                          if (_modality != 'Virtual') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Lugar físico',
                                hintText: 'Ej. Bloque A, salón 204',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Text('Agregar tutoría',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final today = DateUtils.dateOnly(DateTime.now());
                                  final value = await showDatePicker(
                                    context: context,
                                    firstDate: today,
                                    lastDate: today.add(const Duration(days: 180)),
                                    initialDate: _date ?? today.add(const Duration(days: 1)),
                                  );
                                  if (value != null)
                                    setState(() {
                                      _date = value;
                                      _teacherId = null;
                                    });
                                },
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: Text(_date == null
                                    ? 'Elegir fecha'
                                    : _dateLabel(_date!)),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final value = await showTimePicker(
                                    context: context,
                                    initialTime: _start ??
                                        const TimeOfDay(hour: 8, minute: 0),
                                  );
                                  if (value != null)
                                    setState(() {
                                      _start = value;
                                      _teacherId = null;
                                    });
                                },
                                icon: const Icon(Icons.schedule),
                                label: Text(_start == null
                                    ? 'Hora de inicio'
                                    : 'Inicio: ${_start!.format(context)}'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final value = await showTimePicker(
                                    context: context,
                                    initialTime: _end ??
                                        const TimeOfDay(hour: 9, minute: 0),
                                  );
                                  if (value != null)
                                    setState(() {
                                      _end = value;
                                      _teacherId = null;
                                    });
                                },
                                icon: const Icon(Icons.schedule_outlined),
                                label: Text(_end == null
                                    ? 'Hora de fin'
                                    : 'Fin: ${_end!.format(context)}'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _teacherId,
                            decoration: const InputDecoration(
                              labelText:
                                  'Docente de la tecnología seleccionada',
                              border: OutlineInputBorder(),
                            ),
                            items: _compatibleTeachers
                                .map((teacher) => DropdownMenuItem(
                                      value: teacher.id,
                                      child: Text(
                                          '${teacher.nombre} · ${teacher.id}'),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _teacherId = value),
                          ),
                          if (_subject != null && _compatibleTeachers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                  'No hay docentes asignados a esta tecnología.'),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              onPressed: _slots.length >= 3 ||
                                      _teacherId == null ||
                                      _date == null ||
                                      _start == null ||
                                      _end == null
                                  ? null
                                  : _addSlot,
                              icon: const Icon(Icons.add),
                              label: Text(_slots.length >= 3
                                  ? 'Máximo 3 tutorías'
                                  : 'Agregar a la lista'),
                            ),
                          ),
                          const Divider(height: 28),
                          Text('Tutorías por publicar (${_slots.length})',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_slots.isEmpty)
                            const Text('Aún no has agregado tutorías.'),
                          for (final slot in _slots)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.event_available,
                                    color: _brand),
                                title: Text(
                                    '${slot.subject} · ${slot.teacher.nombre}'),
                                subtitle: Text(
                                    '${_dateLabel(slot.start)} · ${_timeLabel(slot.start)}–${_timeLabel(slot.end)} · ${slot.modality}${slot.location.isEmpty ? '' : ' · ${slot.location}'}'),
                                trailing: IconButton(
                                  tooltip: 'Quitar horario',
                                  onPressed: () =>
                                      setState(() => _slots.remove(slot)),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.publish_outlined),
                            label: Text(_saving
                                ? 'Publicando…'
                                : 'Publicar ${_slots.length} tutorías'),
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
      case 'presencial':
        return 'PRESENCIAL';
      case 'virtual':
        return 'VIRTUAL';
      default:
        return 'HIBRIDA';
    }
  }
}

class _PlannedSlot {
  const _PlannedSlot({
    required this.teacher,
    required this.subject,
    required this.start,
    required this.end,
    required this.modality,
    required this.location,
  });

  final Teacher teacher;
  final String subject;
  final DateTime start;
  final DateTime end;
  final String modality;
  final String location;
}
