import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import 'docente_informes_page.dart';

const _teacherGreen = Color(0xFF16834A);
const _teacherCanvas = Color(0xFFF3F8F4);
const _teacherNavy = Color(0xFF18352A);

final _teacherSessionsProvider =
    FutureProvider.autoDispose<List<_TeacherTutoringSession>>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/tutorias/grupales/docente');
  return (response.data ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(_TeacherTutoringSession.fromJson)
      .toList(growable: false);
});

class DocenteDashboardPage extends ConsumerStatefulWidget {
  const DocenteDashboardPage({super.key});

  @override
  ConsumerState<DocenteDashboardPage> createState() =>
      _DocenteDashboardPageState();
}

class _DocenteDashboardPageState extends ConsumerState<DocenteDashboardPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _teacherGreen),
        scaffoldBackgroundColor: _teacherCanvas,
      ),
      child: Scaffold(
        backgroundColor: _teacherCanvas,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _teacherNavy,
          title: const Text('Panel docente', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            const NotificationBellButton(),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Row(children: [
          if (wide) _desktopMenu(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _home(),
                _sessions(),
                const DocenteInformesPage(),
                const NotificationsInbox(),
              ],
            ),
          ),
        ]),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (value) => setState(() => _tab = value),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
                  NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Tutorías'),
                  NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Informes'),
                  NavigationDestination(icon: Icon(Icons.notifications_none_outlined), selectedIcon: Icon(Icons.notifications), label: 'Avisos'),
                ],
              ),
      ),
    );
  }

  Widget _desktopMenu() => Material(
        color: Colors.white,
        child: SizedBox(
          width: 230,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('Menú docente', style: TextStyle(color: _teacherNavy, fontWeight: FontWeight.w800)),
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: ListTile(
                  selected: _tab == i,
                  selectedColor: _teacherGreen,
                  selectedTileColor: const Color(0xFFE6F4EA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(_teacherIcons[i]),
                  title: Text(_teacherLabels[i]),
                  onTap: () => setState(() => _tab = i),
                ),
              ),
            const Spacer(),
          ]),
        ),
      );

  Widget _home() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('¡Hola, docente!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _teacherNavy)),
          const SizedBox(height: 6),
          const Text('Consulta tus tutorías, solicita cambios de fecha y reporta avances.'),
          const SizedBox(height: 20),
          _TeacherHomeTile(icon: Icons.event_note_outlined, title: 'Mis tutorías', subtitle: 'Revisa sesiones y solicita a coordinación cambiar una fecha.', onTap: () => setState(() => _tab = 1)),
          _TeacherHomeTile(icon: Icons.assignment_outlined, title: 'Informes de avance', subtitle: 'Envía el seguimiento de tus proyectos asignados.', onTap: () => setState(() => _tab = 2)),
          _TeacherHomeTile(icon: Icons.notifications_none_outlined, title: 'Avisos', subtitle: 'Consulta las notificaciones de tu cuenta.', onTap: () => setState(() => _tab = 3)),
        ],
      );

  Widget _sessions() => ref.watch(_teacherSessionsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('No se pudieron cargar tus tutorías: $error'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(_teacherSessionsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ]),
        ),
        data: (sessions) => sessions.isEmpty
            ? const Center(child: Text('No tienes tutorías grupales asignadas.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Mis tutorías', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _teacherNavy)),
                  const SizedBox(height: 10),
                  for (final session in sessions)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE6F4EA), child: Icon(Icons.event_available, color: _teacherGreen)),
                        title: Text(session.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${session.start == null ? 'Fecha no disponible' : _dateTimeLabel(session.start!)} · Semestre ${session.semester} · ${session.technologies.join(', ')}\n${session.students.isEmpty ? 'Publicada · sin inscritos' : 'Estudiantes: ${session.students.join(', ')}'}'),
                        isThreeLine: true,
                        trailing: session.start != null && session.start!.isAfter(DateTime.now())
                            ? IconButton.filledTonal(
                                tooltip: 'Solicitar cambio de fecha',
                                onPressed: () => _requestDateChange(session),
                                icon: const Icon(Icons.edit_calendar_outlined),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
      );

  Future<void> _requestDateChange(_TeacherTutoringSession session) async {
    final originalStart = session.start;
    final originalEnd = session.end;
    if (session.id.isEmpty || originalStart == null || originalEnd == null) return;
    final draft = await showDialog<_DateChangeDraft>(
      context: context,
      builder: (_) => _DateChangeDialog(start: originalStart, end: originalEnd),
    );
    if (draft == null || !mounted) return;
    try {
      await ref.read(dioProvider).post(
        '/api/tutorias/grupales/${Uri.encodeComponent(session.id)}/solicitud-cambio-fecha',
        data: {
          'fechaInicio': draft.start.toIso8601String(),
          'fechaFin': draft.end.toIso8601String(),
          'motivo': draft.reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada a coordinación.')),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo enviar la solicitud. Inténtalo de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (mounted) context.go('/login');
  }
}

const _teacherLabels = ['Inicio', 'Tutorías', 'Informes', 'Avisos'];
const _teacherIcons = [Icons.home_outlined, Icons.event_note_outlined, Icons.assignment_outlined, Icons.notifications_none_outlined];

class _TeacherHomeTile extends StatelessWidget {
  const _TeacherHomeTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: CircleAvatar(backgroundColor: const Color(0xFFE6F4EA), child: Icon(icon, color: _teacherGreen)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class _TeacherTutoringSession {
  const _TeacherTutoringSession({required this.id, required this.subject, required this.technologies, required this.students, required this.start, required this.end, required this.semester});
  final String id;
  final String subject;
  final List<String> technologies;
  final List<String> students;
  final DateTime? start;
  final DateTime? end;
  final int semester;

  factory _TeacherTutoringSession.fromJson(Map<String, dynamic> json) =>
      _TeacherTutoringSession(
        id: json['id'] is String ? json['id'] as String : '',
        subject: json['materia'] is String ? json['materia'] as String : 'Tutoría',
        technologies: json['tecnologias'] is List ? (json['tecnologias'] as List).whereType<String>().toList() : const [],
        students: json['estudianteIds'] is List ? (json['estudianteIds'] as List).whereType<String>().toList() : const [],
        start: DateTime.tryParse(json['fechaInicio']?.toString() ?? ''),
        end: DateTime.tryParse(json['fechaFin']?.toString() ?? ''),
        semester: json['semestre'] is num ? (json['semestre'] as num).toInt() : 0,
      );
}

class _DateChangeDraft {
  const _DateChangeDraft(this.start, this.end, this.reason);
  final DateTime start;
  final DateTime end;
  final String reason;
}

class _DateChangeDialog extends StatefulWidget {
  const _DateChangeDialog({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  @override
  State<_DateChangeDialog> createState() => _DateChangeDialogState();
}

class _DateChangeDialogState extends State<_DateChangeDialog> {
  late DateTime _date = widget.start.add(const Duration(days: 1));
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.start);
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Solicitar cambio de fecha'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('La solicitud se enviará a coordinación para su aprobación.'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: _date.isBefore(DateTime.now()) ? DateTime.now() : _date,
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_dateLabel(_date)),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
                icon: const Icon(Icons.schedule),
                label: Text(_time.format(context)),
              )),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Motivo', border: OutlineInputBorder()),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
              if (!start.isAfter(DateTime.now())) {
                setState(() => _error = 'Selecciona una fecha y hora futura.');
                return;
              }
              if (_reason.text.trim().isEmpty) {
                setState(() => _error = 'Escribe el motivo de la solicitud.');
                return;
              }
              final duration = widget.end.difference(widget.start);
              Navigator.pop(context, _DateChangeDraft(start, start.add(duration), _reason.text.trim()));
            },
            child: const Text('Enviar solicitud'),
          ),
        ],
      );
}

String _dateTimeLabel(DateTime value) =>
    '${_dateLabel(value.toLocal())} ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
