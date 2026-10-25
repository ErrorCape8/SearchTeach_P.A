import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'proyecto_aula_chat_page.dart';

final _assignedClassroomProjectsProvider =
    FutureProvider.autoDispose<List<_AssignedClassroomProject>>((ref) async {
  final response = await ref.read(dioProvider).get<List<dynamic>>(
    '/api/docente/tutorias-colectivas',
  );
  return (response.data ?? const [])
      .whereType<Map<String, dynamic>>()
      .where((row) => row['proyecto'] is Map<String, dynamic>)
      .map((row) => _AssignedClassroomProject.fromJson(row))
      .toList();
});

final _projectSessionsProvider = FutureProvider.autoDispose.family<
    List<Map<String, dynamic>>, _AssignedClassroomProject>((ref, project) async {
  final response = await ref.read(dioProvider).get<List<dynamic>>(
    '/api/docente/tutorias-colectivas/${Uri.encodeComponent(project.tutoringId)}'
    '/proyectos/${Uri.encodeComponent(project.projectId)}/sesiones',
  );
  return (response.data ?? const []).whereType<Map<String, dynamic>>().toList();
});

class DocenteProyectosAulaPage extends ConsumerWidget {
  const DocenteProyectosAulaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_assignedClassroomProjectsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('No se pudieron cargar tus proyectos: $error')),
        data: (projects) => projects.isEmpty
            ? const Center(child: Text('No tienes proyectos de aula asignados como tutor.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Tutorías de proyecto de aula', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Abre cada proyecto para consultar el historial, preparar la siguiente sesión y registrar tus notas.'),
                  const SizedBox(height: 16),
                  for (final project in projects) Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
                      title: Text(project.name),
                      subtitle: Text('${project.technology} · Semestre ${project.semester} · ${project.studentIds.length} estudiantes'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _ClassroomProjectWorkspace(project: project),
                      )),
                    ),
                  ),
                ],
              ),
      );
}

class _ClassroomProjectWorkspace extends ConsumerStatefulWidget {
  const _ClassroomProjectWorkspace({required this.project});
  final _AssignedClassroomProject project;

  @override
  ConsumerState<_ClassroomProjectWorkspace> createState() => _ClassroomProjectWorkspaceState();
}

class _ClassroomProjectWorkspaceState extends ConsumerState<_ClassroomProjectWorkspace> {
  final _notes = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _chooseTime({required bool start}) async {
    final value = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (value != null) setState(() { if (start) { _start = value; } else { _end = value; } });
  }

  void _insert(String left, [String right = '']) {
    final selection = _notes.selection;
    final text = _notes.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selected = text.substring(start, end);
    final replacement = '$left$selected$right';
    _notes.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  Future<void> _save() async {
    final content = _notes.text.trim();
    if (content.isEmpty) {
      setState(() => _error = 'Escribe las notas de la sesión antes de guardar.');
      return;
    }
    final start = DateTime(_date.year, _date.month, _date.day, _start.hour, _start.minute);
    final end = DateTime(_date.year, _date.month, _date.day, _end.hour, _end.minute);
    if (!end.isAfter(start)) {
      setState(() => _error = 'La hora de finalización debe ser posterior a la hora de inicio.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(dioProvider).post(
        '/api/docente/tutorias-colectivas/${Uri.encodeComponent(widget.project.tutoringId)}'
        '/proyectos/${Uri.encodeComponent(widget.project.projectId)}/sesiones',
        data: {
          'fechaInicio': start.toIso8601String(),
          'fechaFin': end.toIso8601String(),
          'contenido': content,
        },
      );
      ref.invalidate(_projectSessionsProvider(widget.project));
      _notes.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión guardada en el historial del proyecto.')));
    } on DioException catch (error) {
      final data = error.response?.data;
      setState(() => _error = data is Map && data['message'] is String ? data['message'] as String : 'No se pudo guardar la sesión.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.project.name)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('${widget.project.technology} · Semestre ${widget.project.semester} · ${widget.project.studentIds.length} estudiantes'),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Programar y documentar sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(onPressed: _chooseDate, icon: const Icon(Icons.calendar_month), label: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}')),
              OutlinedButton.icon(onPressed: () => _chooseTime(start: true), icon: const Icon(Icons.schedule), label: Text('Inicio ${_start.format(context)}')),
              OutlinedButton.icon(onPressed: () => _chooseTime(start: false), icon: const Icon(Icons.schedule), label: Text('Fin ${_end.format(context)}')),
            ]),
            const SizedBox(height: 12),
            const Text('Notas de trabajo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 4, children: [
              IconButton(tooltip: 'Negrita', onPressed: () => _insert('**', '**'), icon: const Icon(Icons.format_bold)),
              IconButton(tooltip: 'Cursiva', onPressed: () => _insert('_', '_'), icon: const Icon(Icons.format_italic)),
              IconButton(tooltip: 'Lista', onPressed: () => _insert('\n• '), icon: const Icon(Icons.format_list_bulleted)),
            ]),
            TextField(controller: _notes, minLines: 12, maxLines: null, maxLength: 12000, decoration: const InputDecoration(hintText: 'Escribe objetivos, acuerdos, avances y tareas…', border: OutlineInputBorder(), alignLabelWithHint: true)),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('Guardar en historial')),
          ]))),
          const SizedBox(height: 20),
          const Text('Historial de sesiones y próximos horarios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ref.watch(_projectSessionsProvider(widget.project)).when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('No se pudo cargar el historial: $error'),
            data: (sessions) => sessions.isEmpty
                ? const Padding(padding: EdgeInsets.all(12), child: Text('Aún no hay sesiones registradas.'))
                : Column(children: [for (final session in sessions) Card(child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(_dateLabel(session['fechaInicio'])),
                    subtitle: Text('${_timeLabel(session['fechaInicio'])} – ${_timeLabel(session['fechaFin'])}\n${session['contenido'] ?? ''}', maxLines: 5, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProyectoAulaChatPage(
                        tutoringId: widget.project.tutoringId,
                        projectId: widget.project.projectId,
                        sessionId: session['id']?.toString() ?? '',
                        title: widget.project.name,
                        teacherMode: true,
                      ),
                    )),
                  ))]),
          ),
        ]),
      );

  String _dateLabel(dynamic value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal().toString().split(' ').first ?? 'Fecha no disponible';
  String _timeLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null ? '--:--' : TimeOfDay.fromDateTime(date).format(context);
  }
}

class _AssignedClassroomProject {
  const _AssignedClassroomProject({required this.tutoringId, required this.projectId, required this.name, required this.technology, required this.semester, required this.studentIds});
  final String tutoringId;
  final String projectId;
  final String name;
  final String technology;
  final int semester;
  final List<String> studentIds;
  factory _AssignedClassroomProject.fromJson(Map<String, dynamic> json) {
    final project = json['proyecto'] as Map<String, dynamic>;
    return _AssignedClassroomProject(
      tutoringId: json['tutoriaColectivaId']?.toString() ?? '',
      projectId: project['proyectoId']?.toString() ?? '',
      name: project['nombre']?.toString() ?? 'Proyecto de aula',
      technology: project['tecnologia']?.toString() ?? '',
      semester: project['semestre'] is num ? (project['semestre'] as num).toInt() : 0,
      studentIds: project['estudianteIds'] is List ? (project['estudianteIds'] as List).whereType<String>().toList() : const [],
    );
  }
  @override
  bool operator ==(Object other) => other is _AssignedClassroomProject && tutoringId == other.tutoringId && projectId == other.projectId;
  @override
  int get hashCode => Object.hash(tutoringId, projectId);
}
