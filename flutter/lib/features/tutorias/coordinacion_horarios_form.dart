import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/career_catalog.dart';
import 'coordinacion_horarios_models.dart';

class CoordinacionHorariosFormPage extends ConsumerStatefulWidget {
  const CoordinacionHorariosFormPage({
    required this.teacher,
    this.existing,
    super.key,
  });

  final Teacher teacher;
  final TutorSchedule? existing;

  @override
  ConsumerState<CoordinacionHorariosFormPage> createState() =>
      _CoordinacionHorariosFormPageState();
}

class _CoordinacionHorariosFormPageState
    extends ConsumerState<CoordinacionHorariosFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _career;
  late final TextEditingController _location;
  late final TextEditingController _subjectEntry;
  TextEditingController? _subjectFieldController;
  late List<ScheduleSubject> _subjects;
  List<ScheduleSubject> _catalogSubjects = const [];
  String? _chosenSubject;
  late int _semester;
  late String _day;
  late String _modality;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;
  bool _loadingSubjects = false;
  int _subjectRequest = 0;
  String? _error;
  String? _catalogError;

  @override
  void initState() {
    super.initState();
    final schedule = widget.existing;
    _career = TextEditingController(text: schedule?.carrera ?? '');
    _location = TextEditingController(text: schedule?.ubicacion ?? '');
    _subjectEntry = TextEditingController();
    _subjects = [...?schedule?.materias];
    _semester = (schedule?.semestre ?? 1).clamp(1, 6);
    _day = schedule?.dia ?? 'Lunes';
    _modality = schedule?.modalidad ?? 'Presencial';
    _start =
        _readTime(schedule?.horaInicio, const TimeOfDay(hour: 8, minute: 0));
    _end = _readTime(schedule?.horaFin, const TimeOfDay(hour: 10, minute: 0));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubjectCatalog());
  }

  @override
  void dispose() {
    _career.dispose();
    _location.dispose();
    _subjectEntry.dispose();
    super.dispose();
  }

  TimeOfDay _readTime(String? value, TimeOfDay fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _chooseTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (selected == null || !mounted) return;
    setState(() => start ? _start = selected : _end = selected);
  }

  Future<void> _loadSubjectCatalog() async {
    final request = ++_subjectRequest;
    final career = _career.text.trim();
    if (!careerCatalog.contains(career)) {
      if (mounted) {
        setState(() {
          _catalogSubjects = const [];
          _catalogError = null;
          _loadingSubjects = false;
        });
      }
      return;
    }
    setState(() {
      _loadingSubjects = true;
      _catalogError = null;
    });
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>(
        '/api/coordinacion/horarios/materias',
        queryParameters: {'carrera': career, 'semestre': _semester},
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('El servidor devolvió un catálogo vacío.');
      }
      final subjects = data.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('El catálogo de materias es inválido.');
        }
        return ScheduleSubject.fromJson(entry);
      }).toList(growable: false);
      if (!mounted || request != _subjectRequest) return;
      setState(() {
        _catalogSubjects = subjects;
        _loadingSubjects = false;
      });
    } on DioException catch (error) {
      if (!mounted || request != _subjectRequest) return;
      setState(() {
        _catalogError = apiError(error, 'No se pudieron cargar las materias.');
        _loadingSubjects = false;
      });
    } on FormatException catch (error) {
      if (!mounted || request != _subjectRequest) return;
      setState(() {
        _catalogError = error.message;
        _loadingSubjects = false;
      });
    }
  }

  Future<void> _save() async {
    if (!careerCatalog.contains(_career.text.trim())) {
      setState(() => _error = 'Indica la carrera o selecciona una tecnología.');
      return;
    }
    if (_loadingSubjects || _catalogError != null) {
      setState(() =>
          _error = 'Espera a que cargue el catálogo oficial de materias.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final validSubjects =
        _catalogSubjects.map((subject) => subject.nombre).toSet();
    if (_subjects.any((subject) => !validSubjects.contains(subject.nombre))) {
      setState(() => _error =
          'Quita las materias que no pertenecen al plan de estudios de esta carrera y semestre.');
      return;
    }
    if (_formatTime(_end).compareTo(_formatTime(_start)) <= 0) {
      setState(() => _error =
          'La hora de finalización debe ser posterior a la de inicio.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final path =
          '/api/coordinacion/horarios/${Uri.encodeComponent(widget.teacher.id)}';
      final dio = ref.read(dioProvider);
      final response = widget.existing == null
          ? await dio.post<Map<String, dynamic>>(path, data: _requestBody())
          : await dio.put<Map<String, dynamic>>(path, data: _requestBody());
      final data = response.data;
      if (data == null) {
        throw const FormatException(
            'El servidor no devolvió el horario guardado.');
      }
      final schedule = TutorSchedule.fromJson(data);
      if (mounted) Navigator.of(context).pop(schedule);
    } on DioException catch (error) {
      if (mounted) {
        setState(
            () => _error = apiError(error, 'No se pudo guardar el horario.'));
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addSubject() {
    final name = _chosenSubject;
    if (name == null) {
      setState(() => _error = 'Selecciona una materia del plan de estudios.');
      return;
    }
    if (_subjects.length >= 2) {
      setState(() =>
          _error = 'Cada docente puede asignar como máximo dos materias.');
      return;
    }
    if (_subjects
        .any((subject) => subject.nombre.toLowerCase() == name.toLowerCase())) {
      setState(() => _error = 'Esa materia ya está agregada.');
      return;
    }
    final matches = _catalogSubjects.where((subject) => subject.nombre == name);
    final catalogSubject = matches.isEmpty ? null : matches.first;
    if (catalogSubject == null) {
      setState(
          () => _error = 'La materia no pertenece al plan de estudios actual.');
      return;
    }
    setState(() {
      _subjects.add(catalogSubject);
      _subjectEntry.clear();
      _subjectFieldController?.clear();
      _chosenSubject = null;
      _error = null;
    });
  }

  Map<String, Object> _requestBody() => {
        'carrera': _career.text.trim(),
        'semestre': _semester,
        'dia': _day,
        'horaInicio': _formatTime(_start),
        'horaFin': _formatTime(_end),
        'modalidad': _modality,
        'ubicacion': _location.text.trim(),
        'materias': _subjects.map((subject) => subject.toJson()).toList(),
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF1F4F9),
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver a horarios',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing == null
                  ? 'Asignar horario'
                  : 'Editar horario'),
              Text(
                widget.teacher.nombre,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Autocomplete<String>(
                            initialValue: TextEditingValue(text: _career.text),
                            optionsBuilder: (value) {
                              final query = value.text.trim().toLowerCase();
                              if (query.isEmpty) return careerCatalog;
                              return careerCatalog.where((career) =>
                                  career.toLowerCase().contains(query));
                            },
                            onSelected: (career) {
                              setState(() {
                                _career.text = career;
                                _catalogSubjects = const [];
                                _chosenSubject = null;
                                _subjectEntry.clear();
                                _subjectFieldController?.clear();
                              });
                              _loadSubjectCatalog();
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, onSubmitted) =>
                                    TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (value) {
                                _career.text = value;
                                _chosenSubject = null;
                                _loadSubjectCatalog();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Tecnología / carrera',
                                hintText: 'Escribe para ver sugerencias',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Materias que dicta',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingSubjects) const LinearProgressIndicator(),
                          if (_catalogError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _catalogError!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error),
                              ),
                            ),
                          Autocomplete<String>(
                            optionsBuilder: (value) {
                              final query = value.text.trim().toLowerCase();
                              return _catalogSubjects
                                  .map((subject) => subject.nombre)
                                  .where((subject) =>
                                      subject.toLowerCase().contains(query) &&
                                      !_subjects.any((selected) =>
                                          selected.nombre == subject));
                            },
                            onSelected: (subject) => setState(() {
                              _subjectEntry.text = subject;
                              _chosenSubject = subject;
                            }),
                            fieldViewBuilder:
                                (context, controller, focusNode, onSubmitted) =>
                                    Builder(
                              builder: (context) {
                                _subjectFieldController = controller;
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onChanged: (value) {
                                    _subjectEntry.text = value;
                                    if (value != _chosenSubject) {
                                      _chosenSubject = null;
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Materia',
                                    hintText: _catalogSubjects.isEmpty
                                        ? 'Selecciona primero carrera y semestre'
                                        : 'Busca una materia del plan de estudios',
                                    border: const OutlineInputBorder(),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_catalogSubjects.isEmpty &&
                              !_loadingSubjects &&
                              _catalogError == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Elige una tecnología válida para consultar sus materias.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed:
                                  _subjects.length >= 2 ? null : _addSubject,
                              icon: const Icon(Icons.add),
                              label: Text(
                                _subjects.length >= 2
                                    ? 'Límite de 2 materias'
                                    : 'Agregar materia',
                              ),
                            ),
                          ),
                          if (_subjects.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final subject in _subjects)
                                  InputChip(
                                    label: Text(
                                      '${subject.nombre} · ${subject.carreras.length > 1 ? 'Compartida' : 'Exclusiva'}',
                                    ),
                                    tooltip: subject.carreras.length > 1
                                        ? 'Compartida con ${subject.carreras.where((career) => career != _career.text.trim()).join(', ')}'
                                        : 'Exclusiva de ${subject.carreras.first}',
                                    onDeleted: () => setState(() =>
                                        _subjects.removeWhere((item) =>
                                            item.nombre == subject.nombre)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            initialValue: _semester,
                            decoration: const InputDecoration(
                              labelText: 'Semestre',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (var item = 1; item <= 6; item++)
                                DropdownMenuItem(
                                    value: item, child: Text('$item')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _semester = value;
                                  _catalogSubjects = const [];
                                  _chosenSubject = null;
                                  _subjectEntry.clear();
                                  _subjectFieldController?.clear();
                                });
                                _loadSubjectCatalog();
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _day,
                            decoration: const InputDecoration(
                              labelText: 'Día',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              'Lunes',
                              'Martes',
                              'Miércoles',
                              'Jueves',
                              'Viernes',
                              'Sábado',
                              'Domingo',
                            ]
                                .map((day) => DropdownMenuItem(
                                    value: day, child: Text(day)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _day = value);
                            },
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final start = _TimeField(
                                label: 'Hora de inicio',
                                time: _start.format(context),
                                onPressed: () => _chooseTime(start: true),
                              );
                              final end = _TimeField(
                                label: 'Hora de finalización',
                                time: _end.format(context),
                                onPressed: () => _chooseTime(start: false),
                              );
                              return constraints.maxWidth < 540
                                  ? Column(
                                      children: [
                                        start,
                                        const SizedBox(height: 12),
                                        end,
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(child: start),
                                        const SizedBox(width: 12),
                                        Expanded(child: end),
                                      ],
                                    );
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _modality,
                            decoration: const InputDecoration(
                              labelText: 'Modalidad',
                              border: OutlineInputBorder(),
                            ),
                            items: const ['Presencial', 'Virtual', 'Híbrida']
                                .map((value) => DropdownMenuItem(
                                    value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _modality = value);
                              }
                            },
                          ),
                          if (_modality != 'Virtual') ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _location,
                              decoration: const InputDecoration(
                                labelText: 'Ubicación (parte presencial)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => _modality != 'Virtual' &&
                                      (value == null || value.trim().isEmpty)
                                  ? 'Indica la ubicación.'
                                  : null,
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(widget.existing == null
                                ? 'Guardar horario'
                                : 'Guardar cambios'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onPressed,
  });

  final String label;
  final String time;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.schedule),
            label: Text(time),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
          ),
        ],
      );
}
