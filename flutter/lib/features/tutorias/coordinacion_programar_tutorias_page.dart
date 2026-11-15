import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/career_catalog.dart';
import '../../core/neu/neu.dart';
import '../../core/widgets/role_toast.dart';
import '../pa/pa_widgets.dart';
import 'coordinacion_horarios_models.dart';

class CoordinacionProgramarTutoriasPage extends ConsumerStatefulWidget {
  const CoordinacionProgramarTutoriasPage({super.key});

  @override
  ConsumerState<CoordinacionProgramarTutoriasPage> createState() =>
      _CoordinacionProgramarTutoriasPageState();
}

class _CoordinacionProgramarTutoriasPageState
    extends ConsumerState<CoordinacionProgramarTutoriasPage> {
  static const _wine = Color(0xFF800020);
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
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
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
    final sub = _subject?.trim().toLowerCase();
    return _teachers.where((t) {
      final matchesTec = t.tecnologia.isEmpty ||
          t.tecnologia.toLowerCase() == _technology.toLowerCase();
      if (!matchesTec) return false;
      if (sub == null || sub.isEmpty) return true;
      return t.materiasPrincipales.any((m) {
        final matName = m['materia']?.toString().toLowerCase() ?? '';
        return matName == sub ||
            (matName.isNotEmpty && sub.contains(matName)) ||
            (sub.isNotEmpty && matName.contains(sub));
      });
    }).toList();
  }

  void _addSlot() {
    if (_slots.length >= 3) {
      setState(() => _error = 'Puedes agregar hasta tres tutorías por envío.');
      return;
    }
    if (_date == null || _start == null || _end == null) {
      setState(() => _error = 'Selecciona la fecha y las horas de tutoría.');
      return;
    }
    final teacher = _teachers.firstWhere(
      (item) => item.id == _teacherId,
      orElse: () => const Teacher(
        id: '',
        nombre: 'Docente',
      ),
    );
    if (teacher.id.isEmpty) {
      setState(() => _error = 'Selecciona un docente para la tutoría.');
      return;
    }
    if (_subject == null || _subject!.trim().isEmpty) {
      setState(() => _error = 'Selecciona la materia a programar.');
      return;
    }
    final startDt = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _start!.hour,
      _start!.minute,
    );
    final endDt = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _end!.hour,
      _end!.minute,
    );
    if (!endDt.isAfter(startDt)) {
      setState(() =>
          _error = 'La hora de fin debe ser posterior a la de inicio.');
      return;
    }
    if (_modality != 'Virtual' && _locationController.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el lugar físico de la tutoría.');
      return;
    }

    setState(() {
      _slots.add(_PlannedSlot(
        teacher: teacher,
        subject: _subject!.trim(),
        start: startDt,
        end: endDt,
        modality: _modality,
        location:
            _modality == 'Virtual' ? '' : _locationController.text.trim(),
      ));
      _error = null;
      _date = null;
      _start = null;
      _end = null;
      _teacherId = null;
    });
  }

  Future<void> _save() async {
    if (_slots.isEmpty) {
      setState(() => _error = 'Agrega al menos una tutoría a la lista.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      String iso(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}T'
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}:00';

      final payload = {
        'tecnologia': _technology,
        'semestre': _semester,
        'bloques': _slots
            .map((slot) => {
                  'docenteId': slot.teacher.id,
                  'materia': slot.subject,
                  'modalidad': _apiModality(slot.modality),
                  'ubicacion': slot.location,
                  'fechaInicio': iso(slot.start),
                  'fechaFin': iso(slot.end),
                })
            .toList(),
      };
      await dio.post<void>('/api/coordinacion/sesiones-grupales',
          data: payload);
      if (!mounted) return;
      RoleToast.show(
        context,
        message: 'Tutorías programadas y publicadas exitosamente.',
        roleColor: _wine,
      );
      Navigator.of(context).pop();
    } on DioException catch (error) {
      if (mounted) {
        setState(() =>
            _error = apiError(error, 'No se pudieron programar las tutorías.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neu.bg,
      body: SafeArea(
        child: Column(
          children: [
            NeuHeader(
              title: 'Programar tutorías',
              subtitle: 'Publica tutorías retroalimentativas para estudiantes',
              leading: NeuCircleButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Volver',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              actions: const [],
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _wine))
                  : _error != null && _teachers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style: neuBody(color: Neu.muted)),
                                const SizedBox(height: 14),
                                NeuButton('Reintentar',
                                    kind: NeuButtonKind.alt,
                                    small: true,
                                    expand: false,
                                    icon: Icons.refresh_rounded,
                                    onPressed: _loadTeachers),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 780),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                              children: [
                                NeuSurface(
                                  radius: 22,
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Programa tutorías para docentes de una tecnología, elige la materia, fecha, horas y modalidad. Puedes publicar hasta tres tutorías por vez.',
                                        style: neuBody(
                                          color: Neu.muted,
                                          size: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const PaFieldLabel('Tecnología',
                                          first: true),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(color: Neu.line),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _technology,
                                            items: careerCatalog
                                                .map((value) =>
                                                    DropdownMenuItem(
                                                      value: value,
                                                      child: Text(value,
                                                          style: neuBody(
                                                              color:
                                                                  Neu.heading)),
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
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const PaFieldLabel('Semestre'),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(color: Neu.line),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            isExpanded: true,
                                            value: _semester,
                                            items: [
                                              for (var i = 1; i <= 6; i++)
                                                DropdownMenuItem(
                                                  value: i,
                                                  child: Text('Semestre $i',
                                                      style: neuBody(
                                                          color:
                                                              Neu.heading)),
                                                )
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
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const PaFieldLabel('Materia'),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(color: Neu.line),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _subject,
                                            hint: Text(
                                              _subjects.isEmpty
                                                  ? 'No hay materias para esta selección'
                                                  : 'Selecciona una materia',
                                              style: neuBody(
                                                  color: Neu.muted),
                                            ),
                                            items: _subjects
                                                .map((value) =>
                                                    DropdownMenuItem(
                                                      value: value,
                                                      child: Text(value,
                                                          style: neuBody(
                                                              color:
                                                                  Neu.heading)),
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
                                        ),
                                      ),
                                      if (_loadingSubjects) ...[
                                        const SizedBox(height: 6),
                                        const LinearProgressIndicator(
                                            color: _wine),
                                      ],
                                      const SizedBox(height: 14),
                                      const PaFieldLabel('Modalidad'),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(color: Neu.line),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _modality,
                                            items: const [
                                              'Presencial',
                                              'Virtual',
                                              'Híbrida'
                                            ]
                                                .map((value) =>
                                                    DropdownMenuItem(
                                                      value: value,
                                                      child: Text(value,
                                                          style: neuBody(
                                                              color:
                                                                  Neu.heading)),
                                                    ))
                                                .toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(
                                                    () => _modality = value);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      if (_modality != 'Virtual') ...[
                                        const SizedBox(height: 14),
                                        const PaFieldLabel('Lugar físico'),
                                        NeuField(
                                          controller: _locationController,
                                          hint: 'Ej. Bloque A, salón 204',
                                        ),
                                      ],
                                      const SizedBox(height: 22),
                                      Text(
                                        'AGREGAR HORARIO A LA LISTA',
                                        style: neuPoppins(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: _wine,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          NeuButton(
                                            _date == null
                                                ? 'Elegir fecha'
                                                : _dateLabel(_date!),
                                            kind: NeuButtonKind.alt,
                                            small: true,
                                            expand: false,
                                            icon: Icons
                                                .calendar_month_outlined,
                                            onPressed: () async {
                                              final today = DateUtils.dateOnly(
                                                  DateTime.now());
                                              final value =
                                                  await showDatePicker(
                                                context: context,
                                                firstDate: today,
                                                lastDate: today.add(
                                                    const Duration(days: 180)),
                                                initialDate: _date ??
                                                    today.add(const Duration(
                                                        days: 1)),
                                              );
                                              if (value != null) {
                                                setState(() {
                                                  _date = value;
                                                  _teacherId = null;
                                                });
                                              }
                                            },
                                          ),
                                          NeuButton(
                                            _start == null
                                                ? 'Hora de inicio'
                                                : 'Inicio: ${_start!.format(context)}',
                                            kind: NeuButtonKind.alt,
                                            small: true,
                                            expand: false,
                                            icon: Icons.schedule_rounded,
                                            onPressed: () async {
                                              final value =
                                                  await showTimePicker(
                                                context: context,
                                                initialTime: _start ??
                                                    const TimeOfDay(
                                                        hour: 8, minute: 0),
                                              );
                                              if (value != null) {
                                                setState(() {
                                                  _start = value;
                                                  _teacherId = null;
                                                });
                                              }
                                            },
                                          ),
                                          NeuButton(
                                            _end == null
                                                ? 'Hora de fin'
                                                : 'Fin: ${_end!.format(context)}',
                                            kind: NeuButtonKind.alt,
                                            small: true,
                                            expand: false,
                                            icon: Icons.schedule_outlined,
                                            onPressed: () async {
                                              final value =
                                                  await showTimePicker(
                                                context: context,
                                                initialTime: _end ??
                                                    const TimeOfDay(
                                                        hour: 9, minute: 0),
                                              );
                                              if (value != null) {
                                                setState(() {
                                                  _end = value;
                                                  _teacherId = null;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      const PaFieldLabel(
                                          'Docente habilitado'),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(color: Neu.line),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _teacherId,
                                            hint: Text(
                                              _compatibleTeachers.isEmpty
                                                  ? (_subject == null
                                                      ? 'Primero selecciona una materia'
                                                      : 'No hay docentes para esta materia')
                                                  : 'Selecciona un docente',
                                              style: neuBody(
                                                  color: Neu.muted),
                                            ),
                                            items: _compatibleTeachers
                                                .map((teacher) =>
                                                    DropdownMenuItem(
                                                      value: teacher.id,
                                                      child: Text(
                                                          '${teacher.nombre}',
                                                          style: neuBody(
                                                              color: Neu
                                                                  .heading)),
                                                    ))
                                                .toList(),
                                            onChanged: (value) => setState(
                                                () => _teacherId = value),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: NeuButton(
                                          _slots.length >= 3
                                              ? 'Máximo 3 tutorías'
                                              : 'Agregar a la lista (+)',
                                          kind: NeuButtonKind.alt,
                                          small: true,
                                          expand: false,
                                          icon: Icons.add_circle_outline,
                                          onPressed: _slots.length >= 3 ||
                                                  _teacherId == null ||
                                                  _date == null ||
                                                  _start == null ||
                                                  _end == null
                                              ? null
                                              : _addSlot,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'TUTORÍAS POR PUBLICAR (${_slots.length})',
                                  style: neuPoppins(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: Neu.heading,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_slots.isEmpty)
                                  NeuSurface(
                                    radius: 16,
                                    padding: const EdgeInsets.all(18),
                                    child: Center(
                                      child: Text(
                                        'Aún no has agregado tutorías para publicar.',
                                        style: neuBody(color: Neu.muted),
                                      ),
                                    ),
                                  ),
                                for (final slot in _slots)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: NeuSurface(
                                      radius: 18,
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _wine.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.event_available_rounded,
                                              color: _wine,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${slot.subject} · ${slot.teacher.nombre}',
                                                  style: neuPoppins(
                                                    size: 14,
                                                    weight: FontWeight.w700,
                                                    color: Neu.heading,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${_dateLabel(slot.start)} · ${_timeLabel(slot.start)}–${_timeLabel(slot.end)} · ${slot.modality}${slot.location.isEmpty ? '' : ' · ${slot.location}'}',
                                                  style: neuBody(
                                                    size: 12.5,
                                                    color: Neu.muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          NeuCircleButton(
                                            icon: Icons.close_rounded,
                                            tooltip: 'Quitar horario',
                                            onTap: () => setState(
                                                () => _slots.remove(slot)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_error != null) ...[
                                  const SizedBox(height: 10),
                                  PaInfo(_error!, tone: PaTone.error),
                                ],
                                const SizedBox(height: 20),
                                NeuButton(
                                  _saving
                                      ? 'Publicando…'
                                      : 'Publicar ${_slots.length} tutorías',
                                  icon: Icons.send_rounded,
                                  loading: _saving,
                                  onPressed: _saving || _slots.isEmpty
                                      ? null
                                      : _save,
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

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
