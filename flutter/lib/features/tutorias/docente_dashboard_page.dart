import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/tutoring_updates.dart';
import '../../core/widgets/brand_logo.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import 'docente_proyectos_aula_page.dart';
import 'docente_lider_proyectos_page.dart';
import 'livekit_room_page.dart';
import 'tutoria_chat_page.dart';

const _teacherGreen = Color(0xFF0C8A53);
const _teacherCanvas = Color(0xFFF3F8F4);
const _teacherNavy = Color(0xFF0A6843);

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

class _DocenteDashboardPageState extends ConsumerState<DocenteDashboardPage>
    with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.invalidate(_teacherSessionsProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(_teacherSessionsProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) ref.invalidate(_teacherSessionsProvider);
    });
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme:
            Theme.of(context).colorScheme.copyWith(primary: _teacherGreen),
        scaffoldBackgroundColor: _teacherCanvas,
      ),
      child: Scaffold(
        backgroundColor: _teacherCanvas,
        appBar: AppBar(
          backgroundColor: _teacherGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Panel docente',
              style: TextStyle(fontWeight: FontWeight.w800)),
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
                _startTutoring(),
                const DocenteProyectosAulaPage(),
                const DocenteLiderProyectosPage(),
                const NotificationsInbox(),
                _history(),
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
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Inicio'),
                  NavigationDestination(
                      icon: Icon(Icons.event_note_outlined),
                      selectedIcon: Icon(Icons.event_note),
                      label: 'Tutorías'),
                  NavigationDestination(
                      icon: Icon(Icons.play_circle_outline),
                      selectedIcon: Icon(Icons.play_circle),
                      label: 'Empezar'),
                  NavigationDestination(
                      icon: Icon(Icons.school_outlined),
                      selectedIcon: Icon(Icons.school),
                      label: 'Proyectos'),
                  NavigationDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(Icons.fact_check),
                      label: 'Líder PA'),
                  NavigationDestination(
                      icon: Icon(Icons.notifications_none_outlined),
                      selectedIcon: Icon(Icons.notifications),
                      label: 'Avisos'),
                  NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: 'Historial'),
                ],
              ),
      ),
    );
  }

  Widget _desktopMenu() => Material(
        color: _teacherNavy,
        child: SizedBox(
          width: 250,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
              child: SizedBox(
                height: 112,
                child: Transform.scale(
                  scale: 1.06,
                  child: const BrandLogo(
                    width: 190,
                    height: 112,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('DOCENTE',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700))),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Divider(height: 1, color: Color(0x44FFFFFF)),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < 3; i++)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: ListTile(
                  selected: _tab == i,
                  selectedColor: Colors.white,
                  selectedTileColor: const Color(0xFF064D33),
                  textColor: Colors.white,
                  iconColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Icon(_teacherIcons[i]),
                  title: Text(_teacherLabels[i]),
                  onTap: () => setState(() => _tab = i),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: ListTile(
                selected: _tab == 3,
                selectedColor: Colors.white,
                selectedTileColor: const Color(0xFF064D33),
                textColor: Colors.white,
                iconColor: Colors.white70,
                leading: const Icon(Icons.school_outlined),
                title: const Text('Proyectos de aula'),
                onTap: () => setState(() => _tab = 3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: ListTile(
                selected: _tab == 4,
                selectedColor: Colors.white,
                selectedTileColor: const Color(0xFF064D33),
                textColor: Colors.white,
                iconColor: Colors.white70,
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Líder PA'),
                onTap: () => setState(() => _tab = 4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: ListTile(
                selected: _tab == 5,
                selectedColor: Colors.white,
                selectedTileColor: const Color(0xFF064D33),
                textColor: Colors.white,
                iconColor: Colors.white70,
                leading: const Icon(Icons.notifications_none_outlined),
                title: const Text('Avisos'),
                onTap: () => setState(() => _tab = 5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: ListTile(
                selected: _tab == 6,
                selectedColor: Colors.white,
                selectedTileColor: const Color(0xFF064D33),
                textColor: Colors.white,
                iconColor: Colors.white70,
                leading: const Icon(Icons.history_outlined),
                title: const Text('Historial'),
                onTap: () => setState(() => _tab = 6),
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Color(0x44FFFFFF)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  foregroundColor: Colors.white,
                  child: const Text('D'),
                ),
                const SizedBox(width: 10),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Docente',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      Text('SearchTeach',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
              ]),
            ),
          ]),
        ),
      );

  Widget _home() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('¡Hola, docente!',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _teacherNavy)),
          const SizedBox(height: 6),
          const Text(
              'Consulta tus tutorías, solicita cambios de fecha y acompaña tus proyectos de aula.'),
          const SizedBox(height: 20),
          _TeacherHomeTile(
              icon: Icons.event_note_outlined,
              title: 'Mis tutorías',
              subtitle:
                  'Revisa sesiones y solicita a coordinación cambiar una fecha.',
              onTap: () => setState(() => _tab = 1)),
          _TeacherHomeTile(
              icon: Icons.play_circle_outline,
              title: 'Empezar tutorías',
              subtitle:
                  'Abre la sala, toma asistencia y consulta el chat de tus sesiones.',
              onTap: () => setState(() => _tab = 2)),
          _TeacherHomeTile(
              icon: Icons.school_outlined,
              title: 'Proyectos de aula',
              subtitle:
                  'Escribe reportes, programa sesiones y responde a los estudiantes.',
              onTap: () => setState(() => _tab = 3)),
          _TeacherHomeTile(
              icon: Icons.fact_check_outlined,
              title: 'Líder PA',
              subtitle:
                  'Revisa la documentación de los tutores y confirma el trabajo del proyecto.',
              onTap: () => setState(() => _tab = 4)),
          _TeacherHomeTile(
              icon: Icons.notifications_none_outlined,
              title: 'Avisos',
              subtitle: 'Consulta las notificaciones de tu cuenta.',
              onTap: () => setState(() => _tab = 5)),
          _TeacherHomeTile(
              icon: Icons.history_outlined,
              title: 'Historial',
              subtitle: 'Consulta las tutorías finalizadas y sus chats.',
              onTap: () => setState(() => _tab = 6)),
        ],
      );

  Widget _sessions() => _buildSessions(view: _SessionView.scheduled);

  Widget _startTutoring() => _buildSessions(view: _SessionView.start);

  Widget _history() => _buildSessions(view: _SessionView.history);

  Widget _buildSessions({required _SessionView view}) => ref
      .watch(_teacherSessionsProvider)
      .when(
        loading: () => view == _SessionView.history
            ? _historyPage(
                body: const Center(child: CircularProgressIndicator()))
            : const Center(child: CircularProgressIndicator()),
        error: (error, _) => view == _SessionView.history
            ? _historyPage(
                body: _historyMessage(
                  'No se pudo cargar el historial: $error',
                  onRetry: () => ref.invalidate(_teacherSessionsProvider),
                ),
              )
            : Center(
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
        data: (allSessions) {
          final sessions = allSessions
              .where((session) => switch (view) {
                    _SessionView.history => session.state == 'FINALIZADA',
                    _SessionView.scheduled ||
                    _SessionView.start =>
                      session.state != 'FINALIZADA',
                  })
              .toList()
            ..sort((a, b) => (a.start ?? DateTime(9999))
                .compareTo(b.start ?? DateTime(9999)));
          if (view == _SessionView.history) {
            return _historyPage(
              count: sessions.length,
              body: sessions.isEmpty
                  ? _historyMessage('Aún no tienes tutorías finalizadas.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _historySessionCard(sessions[index]),
                    ),
            );
          }
          return sessions.isEmpty
              ? const Center(
                  child: Text('No tienes tutorías grupales asignadas.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                        switch (view) {
                          _SessionView.scheduled => 'Mis tutorías',
                          _SessionView.start => 'Empezar tutorías',
                          _SessionView.history => 'Historial'
                        },
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _teacherNavy)),
                    const SizedBox(height: 10),
                    for (final session in sessions)
                      Card(
                        child: Column(children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE6F4EA),
                                child: Icon(Icons.event_available,
                                    color: _teacherGreen)),
                            title: Text(session.subject,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                '${session.start == null ? 'Fecha no disponible' : _dateTimeLabel(session.start!)} · ${_modalityLabel(session.modality)} · Semestre ${session.semester} · ${session.technologies.join(', ')}\n${session.students.isEmpty ? 'Publicada · sin inscritos' : 'Estudiantes inscritos: ${session.students.length}'}${session.state == 'FINALIZADA' ? '\nClase finalizada' : ''}'),
                            isThreeLine: true,
                            trailing: session.id.isNotEmpty &&
                                    session.start != null &&
                                    session.end != null &&
                                    session.state != 'FINALIZADA'
                                ? IconButton.filledTonal(
                                    tooltip: 'Solicitar cambio de fecha',
                                    onPressed: () =>
                                        _requestDateChange(session),
                                    icon: const Icon(
                                        Icons.edit_calendar_outlined),
                                  )
                                : null,
                          ),
                          if (session.id.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context)
                                        .push(MaterialPageRoute(
                                      builder: (_) => TutoriaChatPage(
                                          sessionId: session.id,
                                          subject: session.subject,
                                          readOnly:
                                              view == _SessionView.history),
                                    )),
                                    icon: const Icon(Icons.forum_outlined),
                                    label: const Text('Abrir chat'),
                                  ),
                                  if (view != _SessionView.scheduled)
                                    FilledButton.icon(
                                      onPressed: () async {
                                        await Navigator.of(context)
                                            .push(MaterialPageRoute(
                                          builder: (_) => LiveKitRoomPage(
                                              sessionId: session.id,
                                              subject: session.subject,
                                              modality: session.modality,
                                              teacherMode: true,
                                              students: session.students,
                                              ended:
                                                  view == _SessionView.history,
                                              endAt: session.end),
                                        ));
                                        if (mounted) {
                                          ref.invalidate(
                                              _teacherSessionsProvider);
                                        }
                                      },
                                      icon: Icon(view == _SessionView.history
                                          ? Icons.history
                                          : Icons.video_call_outlined),
                                      label: Text(view == _SessionView.history
                                          ? 'Ver historial'
                                          : 'Empezar tutoría'),
                                    ),
                                ],
                              ),
                            ),
                        ]),
                      ),
                  ],
                );
        },
      );

  Widget _historyPage({required Widget body, int? count}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.history, color: _teacherGreen),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historial de tutorías',
                        style: TextStyle(
                          color: _teacherNavy,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Consulta tus sesiones finalizadas, sus datos y chats.',
                        style: TextStyle(color: Color(0xFF687A70)),
                      ),
                    ],
                  ),
                ),
                if (count != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count ${count == 1 ? 'sesión' : 'sesiones'}',
                      style: const TextStyle(
                        color: _teacherNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );

  Widget _historyMessage(String message, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE3ECE5)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, color: _teacherGreen, size: 34),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF53665B)),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _historySessionCard(_TeacherTutoringSession session) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE3ECE5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE6F4EA),
                    child: Icon(Icons.event_available, color: _teacherGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      session.subject,
                      style: const TextStyle(
                        color: _teacherNavy,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Finalizada',
                      style: TextStyle(
                        color: _teacherNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HistoryDetail(
                    icon: Icons.calendar_month_outlined,
                    label: session.start == null
                        ? 'Fecha no disponible'
                        : _dateTimeLabel(session.start!),
                  ),
                  _HistoryDetail(
                    icon: Icons.school_outlined,
                    label: 'Semestre ${session.semester}',
                  ),
                  _HistoryDetail(
                    icon: Icons.meeting_room_outlined,
                    label: _modalityLabel(session.modality),
                  ),
                  _HistoryDetail(
                    icon: Icons.people_outline,
                    label: '${session.students.length} estudiantes',
                  ),
                ],
              ),
              if (session.technologies.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  session.technologies.join(' · '),
                  style: const TextStyle(color: Color(0xFF687A70)),
                ),
              ],
              if (session.id.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFEAF0EB)),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TutoriaChatPage(
                              sessionId: session.id,
                              subject: session.subject,
                              readOnly: true,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('Abrir chat'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveKitRoomPage(
                                sessionId: session.id,
                                subject: session.subject,
                                modality: session.modality,
                                teacherMode: true,
                                students: session.students,
                                ended: true,
                                endAt: session.end,
                              ),
                            ),
                          );
                          if (mounted) ref.invalidate(_teacherSessionsProvider);
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('Ver historial'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Future<void> _requestDateChange(_TeacherTutoringSession session) async {
    final originalStart = session.start;
    final originalEnd = session.end;
    if (session.id.isEmpty || originalStart == null || originalEnd == null) {
      return;
    }
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (mounted) context.go('/login');
  }
}

enum _SessionView { scheduled, start, history }

class _HistoryDetail extends StatelessWidget {
  const _HistoryDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _teacherGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF53665B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

const _teacherLabels = ['Inicio', 'Tutorías', 'Empezar tutorías'];
const _teacherIcons = [
  Icons.home_outlined,
  Icons.event_note_outlined,
  Icons.play_circle_outline
];

class _TeacherHomeTile extends StatelessWidget {
  const _TeacherHomeTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: CircleAvatar(
              backgroundColor: const Color(0xFFE6F4EA),
              child: Icon(icon, color: _teacherGreen)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class _TeacherTutoringSession {
  const _TeacherTutoringSession(
      {required this.id,
      required this.subject,
      required this.technologies,
      required this.students,
      required this.start,
      required this.end,
      required this.semester,
      required this.modality,
      required this.state});
  final String id;
  final String subject;
  final List<String> technologies;
  final List<String> students;
  final DateTime? start;
  final DateTime? end;
  final int semester;
  final String modality;
  final String state;

  factory _TeacherTutoringSession.fromJson(Map<String, dynamic> json) =>
      _TeacherTutoringSession(
        id: json['id'] is String ? json['id'] as String : '',
        subject:
            json['materia'] is String ? json['materia'] as String : 'Tutoría',
        technologies: json['tecnologias'] is List
            ? (json['tecnologias'] as List).whereType<String>().toList()
            : const [],
        students: json['estudianteIds'] is List
            ? (json['estudianteIds'] as List).whereType<String>().toList()
            : const [],
        start: DateTime.tryParse(json['fechaInicio']?.toString() ?? ''),
        end: DateTime.tryParse(json['fechaFin']?.toString() ?? ''),
        semester:
            json['semestre'] is num ? (json['semestre'] as num).toInt() : 0,
        modality: json['modalidad'] is String &&
                (json['modalidad'] as String).isNotEmpty
            ? json['modalidad'] as String
            : 'PRESENCIAL',
        state: json['estadoClase'] is String
            ? json['estadoClase'] as String
            : 'PROGRAMADA',
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
            const Text(
                'La solicitud se enviará a coordinación para su aprobación.'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate:
                        _date.isBefore(DateTime.now()) ? DateTime.now() : _date,
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_dateLabel(_date)),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: _time);
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
              decoration: const InputDecoration(
                  labelText: 'Motivo', border: OutlineInputBorder()),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final start = DateTime(
                  _date.year, _date.month, _date.day, _time.hour, _time.minute);
              if (!start.isAfter(DateTime.now())) {
                setState(() => _error = 'Selecciona una fecha y hora futura.');
                return;
              }
              if (_reason.text.trim().isEmpty) {
                setState(() => _error = 'Escribe el motivo de la solicitud.');
                return;
              }
              final duration = widget.end.difference(widget.start);
              Navigator.pop(
                  context,
                  _DateChangeDraft(
                      start, start.add(duration), _reason.text.trim()));
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

String _modalityLabel(String modality) => switch (modality.toUpperCase()) {
      'VIRTUAL' => 'Virtual',
      'HIBRIDA' => 'Híbrida',
      'PRESENCIAL' => 'Presencial',
      _ => modality.isEmpty ? 'Modalidad por confirmar' : modality,
    };
