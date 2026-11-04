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

final _projectSessionsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _AssignedClassroomProject>(
        (ref, project) async {
  final response = await ref.read(dioProvider).get<List<dynamic>>(
        '/api/docente/tutorias-colectivas/${Uri.encodeComponent(project.tutoringId)}'
        '/proyectos/${Uri.encodeComponent(project.projectId)}/sesiones',
      );
  return (response.data ?? const []).whereType<Map<String, dynamic>>().toList();
});

class DocenteProyectosAulaPage extends ConsumerWidget {
  const DocenteProyectosAulaPage({
    super.key,
    this.onOpenLeaderView,
  });

  final VoidCallback? onOpenLeaderView;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(_assignedClassroomProjectsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudieron cargar tus proyectos: $error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(_assignedClassroomProjectsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
            data: (projects) => projects.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _pageHeading(context),
                      const SizedBox(height: 18),
                      const _ProjectEmptyState(),
                      if (onOpenLeaderView != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: onOpenLeaderView,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Abrir vista de líder PA'),
                          ),
                        ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _pageHeading(context),
                      const SizedBox(height: 18),
                      if (onOpenLeaderView != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: onOpenLeaderView,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Vista de líder PA'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      for (final project in projects)
                        _AssignedProjectCard(
                          project: project,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  _ClassroomProjectWorkspace(project: project),
                            ),
                          ),
                        ),
                    ],
                  ),
          );

  Widget _pageHeading(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proyectos de aula',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF18352A),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Da seguimiento a tus equipos, agenda conversaciones y consulta el historial de cada proyecto.',
            style: TextStyle(color: Color(0xFF687A70)),
          ),
        ],
      );
}

class _AssignedProjectCard extends StatelessWidget {
  const _AssignedProjectCard({required this.project, required this.onTap});
  final _AssignedClassroomProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE7EEE9)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F4EC),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: Color(0xFF16834A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: const TextStyle(
                          color: Color(0xFF18352A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${project.technology} · Semestre ${project.semester}',
                        style: const TextStyle(
                          color: Color(0xFF687A70),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        children: [
                          _ProjectPill(
                            label: '${project.studentIds.length} estudiantes',
                            icon: Icons.groups_outlined,
                          ),
                          const _ProjectPill(
                            label: 'Tutor asignado',
                            icon: Icons.check_circle_outline,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF16834A)),
              ],
            ),
          ),
        ),
      );
}

class _ProjectPill extends StatelessWidget {
  const _ProjectPill({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 14, color: const Color(0xFF16834A)),
        label: Text(label),
        labelStyle: const TextStyle(fontSize: 10),
        visualDensity: VisualDensity.compact,
        backgroundColor: const Color(0xFFF0F5F1),
        side: BorderSide.none,
        padding: EdgeInsets.zero,
      );
}

class _ProjectEmptyState extends StatelessWidget {
  const _ProjectEmptyState();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE7EEE9)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(Icons.school_outlined, color: Color(0xFF16834A), size: 34),
              SizedBox(height: 10),
              Text(
                'No tienes proyectos de aula asignados como tutor.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _ClassroomProjectWorkspace extends ConsumerStatefulWidget {
  const _ClassroomProjectWorkspace({required this.project});
  final _AssignedClassroomProject project;

  @override
  ConsumerState<_ClassroomProjectWorkspace> createState() =>
      _ClassroomProjectWorkspaceState();
}

class _ClassroomProjectWorkspaceState
    extends ConsumerState<_ClassroomProjectWorkspace> {
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
    final value = await showTimePicker(
        context: context, initialTime: start ? _start : _end);
    if (value != null) {
      setState(() {
        if (start) {
          _start = value;
        } else {
          _end = value;
        }
      });
    }
  }

  Future<void> _save() async {
    final content = _notes.text.trim();
    final start = DateTime(
        _date.year, _date.month, _date.day, _start.hour, _start.minute);
    final end =
        DateTime(_date.year, _date.month, _date.day, _end.hour, _end.minute);
    if (!end.isAfter(start)) {
      setState(() => _error =
          'La hora de finalización debe ser posterior a la hora de inicio.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref.read(dioProvider).post<Map<String, dynamic>>(
        '/api/docente/tutorias-colectivas/${Uri.encodeComponent(widget.project.tutoringId)}'
        '/proyectos/${Uri.encodeComponent(widget.project.projectId)}/sesiones',
        data: {
          'fechaInicio': start.toIso8601String(),
          'fechaFin': end.toIso8601String(),
          'contenido':
              content.isEmpty ? 'Conversación de seguimiento' : content,
        },
      );
      ref.invalidate(_projectSessionsProvider(widget.project));
      _notes.clear();
      final sessionId = created.data?['id']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        setState(() =>
            _error = 'Se creó la sesión, pero no llegó su identificador.');
        return;
      }
      if (content.isNotEmpty) {
        try {
          await ref.read(dioProvider).post(
                '/api/tutorias-colectivas/${Uri.encodeComponent(widget.project.tutoringId)}'
                '/proyectos/${Uri.encodeComponent(widget.project.projectId)}'
                '/sesiones/${Uri.encodeComponent(sessionId)}/mensajes',
                data: FormData.fromMap({'texto': content}),
              );
        } on DioException {
          // La sesión ya existe y el docente puede enviar el primer mensaje desde el chat.
        }
      }
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProyectoAulaChatPage(
            tutoringId: widget.project.tutoringId,
            projectId: widget.project.projectId,
            sessionId: sessionId,
            title: widget.project.name,
            teacherMode: true,
          ),
        ));
        ref.invalidate(_projectSessionsProvider(widget.project));
      }
    } on DioException catch (error) {
      final data = error.response?.data;
      setState(() => _error = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo guardar la sesión.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.project.name)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
              '${widget.project.technology} · Semestre ${widget.project.semester} · ${widget.project.studentIds.length} estudiantes'),
          const SizedBox(height: 16),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Programar conversación',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: _chooseDate,
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                  '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}')),
                          OutlinedButton.icon(
                              onPressed: () => _chooseTime(start: true),
                              icon: const Icon(Icons.schedule),
                              label: Text('Inicio ${_start.format(context)}')),
                          OutlinedButton.icon(
                              onPressed: () => _chooseTime(start: false),
                              icon: const Icon(Icons.schedule),
                              label: Text('Fin ${_end.format(context)}')),
                        ]),
                        const SizedBox(height: 12),
                        const Text('Mensaje inicial (opcional)',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                            controller: _notes,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 4000,
                            decoration: const InputDecoration(
                                hintText:
                                    'Escribe el primer mensaje para iniciar la conversación…',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true)),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red))),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.chat_bubble_outline),
                            label: const Text('Iniciar conversación')),
                      ]))),
          const SizedBox(height: 20),
          const Text('Historial de sesiones y próximos horarios',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ref.watch(_projectSessionsProvider(widget.project)).when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) =>
                    Text('No se pudo cargar el historial: $error'),
                data: (sessions) => sessions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Aún no hay sesiones registradas.'))
                    : Column(children: [
                        for (final session in sessions)
                          Card(
                              child: ListTile(
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(_dateLabel(session['fechaInicio'])),
                            subtitle: Text(
                                '${_timeLabel(session['fechaInicio'])} – ${_timeLabel(session['fechaFin'])} · Abrir conversación'),
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProyectoAulaChatPage(
                                tutoringId: widget.project.tutoringId,
                                projectId: widget.project.projectId,
                                sessionId: session['id']?.toString() ?? '',
                                title: widget.project.name,
                                teacherMode: true,
                              ),
                            )),
                          ))
                      ]),
              ),
        ]),
      );

  String _dateLabel(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')
          ?.toLocal()
          .toString()
          .split(' ')
          .first ??
      'Fecha no disponible';
  String _timeLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null
        ? '--:--'
        : TimeOfDay.fromDateTime(date).format(context);
  }
}

class _AssignedClassroomProject {
  const _AssignedClassroomProject(
      {required this.tutoringId,
      required this.projectId,
      required this.name,
      required this.technology,
      required this.semester,
      required this.studentIds});
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
      semester:
          project['semestre'] is num ? (project['semestre'] as num).toInt() : 0,
      studentIds: project['estudianteIds'] is List
          ? (project['estudianteIds'] as List).whereType<String>().toList()
          : const [],
    );
  }
  @override
  bool operator ==(Object other) =>
      other is _AssignedClassroomProject &&
      tutoringId == other.tutoringId &&
      projectId == other.projectId;
  @override
  int get hashCode => Object.hash(tutoringId, projectId);
}
