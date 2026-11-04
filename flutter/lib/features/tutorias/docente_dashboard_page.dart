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
import 'docente_perfil_page.dart';

const _teacherGreen = Color(0xFF16834A);
const _teacherCanvas = Color(0xFFF3F8F4);
const _teacherNavy = Color(0xFF18352A);
const _teacherSidebar = Color(0xFF0E8A62);

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

final _teacherProjectCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final response = await ref.read(dioProvider).get<List<dynamic>>(
        '/api/docente/tutorias-colectivas',
      );
  return (response.data ?? const [])
      .whereType<Map<String, dynamic>>()
      .where((row) => row['proyecto'] is Map<String, dynamic>)
      .length;
});

final _teacherStudentNamesProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, sessionId) async {
  final response = await ref.read(dioProvider).get<List<dynamic>>(
        '/api/tutorias/grupales/${Uri.encodeComponent(sessionId)}/estudiantes',
      );
  return (response.data ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((student) => student['nombre'])
      .whereType<String>()
      .where((name) => name.trim().isNotEmpty)
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
  DateTime? _selectedDate;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

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
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 850;
    final showAside = width >= 1120 && _tab != 5 && _tab != 7;
    final profile = ref.watch(docenteProfileProvider);
    final teacherName = profile.value?['nombre'] is String
        ? profile.value!['nombre'] as String
        : 'Docente';
    final titles = <int, String>{
      0: 'Inicio',
      1: 'Sesiones',
      2: 'Empezar tutoría',
      3: 'Proyectos de aula',
      4: 'Líder PA',
      5: 'Avisos',
      6: 'Historial',
      7: 'Mi perfil',
    };

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme:
            Theme.of(context).colorScheme.copyWith(primary: _teacherGreen),
        scaffoldBackgroundColor: _teacherCanvas,
      ),
      child: Scaffold(
        backgroundColor: _teacherCanvas,
        body: Row(
          children: [
            if (wide)
              _TeacherSidebar(
                activeTab: _tab,
                teacherName: teacherName,
                onSelect: (tab) => setState(() => _tab = tab),
              ),
            Expanded(
              child: Column(
                children: [
                  _TeacherHeader(
                    title: titles[_tab] ?? 'SearchTeach',
                    teacherName: teacherName,
                    onProfile: () => setState(() => _tab = 7),
                    onLogout: _logout,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: IndexedStack(
                            index: _tab,
                            children: [
                              _home(teacherName),
                              _sessions(),
                              _startTutoring(),
                              DocenteProyectosAulaPage(
                                onOpenLeaderView: () =>
                                    setState(() => _tab = 4),
                              ),
                              const DocenteLiderProyectosPage(),
                              const NotificationsInbox(),
                              _history(),
                              const DocentePerfilPage(),
                            ],
                          ),
                        ),
                        if (showAside)
                          SizedBox(
                            width: 286,
                            child: _TeacherAside(
                              calendarMonth: _calendarMonth,
                              selectedDate: _selectedDate,
                              onMonthChanged: (month) =>
                                  setState(() => _calendarMonth = month),
                              onDateSelected: (date) => setState(() {
                                _selectedDate = date;
                                _calendarMonth =
                                    DateTime(date.year, date.month);
                              }),
                              onOpenSessions: () => setState(() => _tab = 1),
                              onOpenHistory: () => setState(() => _tab = 6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: switch (_tab) {
                  1 || 2 => 1,
                  3 || 4 => 2,
                  7 => 3,
                  _ => 0,
                },
                onDestinationSelected: (value) => setState(() {
                  _tab = switch (value) {
                    1 => 1,
                    2 => 3,
                    3 => 7,
                    _ => 0,
                  };
                }),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Inicio'),
                  NavigationDestination(
                      icon: Icon(Icons.event_note_outlined),
                      selectedIcon: Icon(Icons.event_note),
                      label: 'Sesiones'),
                  NavigationDestination(
                      icon: Icon(Icons.school_outlined),
                      selectedIcon: Icon(Icons.school),
                      label: 'Proyectos'),
                  NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Perfil'),
                ],
              ),
      ),
    );
  }

  Widget _home(String teacherName) => ref.watch(_teacherSessionsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TeacherLoadError(
          message: 'No se pudieron cargar tus tutorías: $error',
          onRetry: () => ref.invalidate(_teacherSessionsProvider),
        ),
        data: (sessions) {
          final scheduled = sessions
              .where((session) => session.state != 'FINALIZADA')
              .toList()
            ..sort((a, b) => (a.start ?? DateTime(9999))
                .compareTo(b.start ?? DateTime(9999)));
          final projects = ref.watch(_teacherProjectCountProvider);
          final activeCount = scheduled.length;
          final nextSession = scheduled.isEmpty ? null : scheduled.first;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Hola, ${teacherName.split(' ').first}',
                style: const TextStyle(
                  color: _teacherNavy,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Aquí tienes el resumen de tus tutorías y actividades.',
                style: TextStyle(color: Color(0xFF687A70)),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _TeacherMetricCard(
                    icon: Icons.event_available_outlined,
                    label: 'Tutorías activas',
                    value: '$activeCount',
                    color: _teacherGreen,
                  ),
                  _TeacherMetricCard(
                    icon: Icons.groups_outlined,
                    label: 'Estudiantes inscritos',
                    value:
                        '${scheduled.fold<int>(0, (total, item) => total + item.students.length)}',
                    color: const Color(0xFF2878B8),
                  ),
                  projects.when(
                    data: (count) => _TeacherMetricCard(
                      icon: Icons.school_outlined,
                      label: 'Proyectos de aula',
                      value: '$count',
                      color: const Color(0xFF9A6B18),
                    ),
                    error: (_, __) => const _TeacherMetricCard(
                      icon: Icons.school_outlined,
                      label: 'Proyectos de aula',
                      value: '—',
                      color: Color(0xFF9A6B18),
                    ),
                    loading: () => const _TeacherMetricCard(
                      icon: Icons.school_outlined,
                      label: 'Proyectos de aula',
                      value: '…',
                      color: Color(0xFF9A6B18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Próxima tutoría',
                      style: TextStyle(
                        color: _teacherNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _tab = 1),
                    child: const Text('Ver agenda'),
                  ),
                ],
              ),
              if (nextSession == null)
                const _TeacherEmptyCard(
                  icon: Icons.event_busy_outlined,
                  message: 'No tienes tutorías pendientes.',
                )
              else
                _TeacherSessionCard(
                  session: nextSession,
                  view: _SessionView.scheduled,
                  onRequestDateChange: () => _requestDateChange(nextSession),
                  onOpenChat: () => _openSessionChat(nextSession),
                  onStart: () => _openRoom(nextSession, ended: false),
                  onHistory: () => _openRoom(nextSession, ended: true),
                ),
              const SizedBox(height: 22),
              const Text(
                'Accesos rápidos',
                style: TextStyle(
                  color: _teacherNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _TeacherHomeTile(
                icon: Icons.video_call_outlined,
                title: 'Empezar tutoría',
                subtitle: 'Abre la sala y registra la asistencia.',
                onTap: () => setState(() => _tab = 2),
              ),
              _TeacherHomeTile(
                icon: Icons.school_outlined,
                title: 'Proyectos de aula',
                subtitle: 'Consulta los proyectos que tienes asignados.',
                onTap: () => setState(() => _tab = 3),
              ),
              _TeacherHomeTile(
                icon: Icons.history_outlined,
                title: 'Historial',
                subtitle: 'Consulta tutorías finalizadas y sus conversaciones.',
                onTap: () => setState(() => _tab = 6),
              ),
            ],
          );
        },
      );

  Widget _sessions() => _buildSessions(view: _SessionView.scheduled);

  Widget _startTutoring() => _buildSessions(view: _SessionView.start);

  Widget _history() => _buildSessions(view: _SessionView.history);

  Widget _buildSessions({required _SessionView view}) =>
      ref.watch(_teacherSessionsProvider).when(
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
            data: (allSessions) {
              final filteredSessions = allSessions
                  .where((session) => switch (view) {
                        _SessionView.history => session.state == 'FINALIZADA',
                        _SessionView.scheduled ||
                        _SessionView.start =>
                          session.state != 'FINALIZADA',
                      })
                  .toList()
                ..sort((a, b) => (a.start ?? DateTime(9999))
                    .compareTo(b.start ?? DateTime(9999)));
              final sessions =
                  view != _SessionView.scheduled || _selectedDate == null
                      ? filteredSessions
                      : filteredSessions.where((session) {
                          final start = session.start?.toLocal();
                          return start != null &&
                              start.year == _selectedDate!.year &&
                              start.month == _selectedDate!.month &&
                              start.day == _selectedDate!.day;
                        }).toList();
              if (view == _SessionView.scheduled) {
                return _sessionsCalendarPage(sessions, filteredSessions);
              }
              return sessions.isEmpty
                  ? _TeacherEmptyCard(
                      icon: view == _SessionView.history
                          ? Icons.history
                          : Icons.video_call_outlined,
                      message: view == _SessionView.history
                          ? 'Aún no tienes tutorías finalizadas.'
                          : 'No tienes tutorías disponibles para iniciar.',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  view == _SessionView.history
                                      ? 'Historial de tutorías'
                                      : 'Empezar tutoría',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _teacherNavy)),
                            ),
                            if (view == _SessionView.start)
                              TextButton.icon(
                                onPressed: () => setState(() => _tab = 6),
                                icon: const Icon(Icons.history),
                                label: const Text('Historial'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final session in sessions)
                          _TeacherSessionCard(
                            session: session,
                            view: view,
                            onRequestDateChange: () =>
                                _requestDateChange(session),
                            onOpenChat: () => _openSessionChat(
                              session,
                              readOnly: view == _SessionView.history,
                            ),
                            onStart: () => _openRoom(session, ended: false),
                            onHistory: () => _openRoom(session, ended: true),
                          ),
                      ],
                    );
            },
          );

  Widget _sessionsCalendarPage(
    List<_TeacherTutoringSession> sessions,
    List<_TeacherTutoringSession> allSessions,
  ) {
    final titleDate = _selectedDate;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Agenda de tutorías',
                style: TextStyle(
                  color: _teacherNavy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _tab = 2),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Empezar tutoría'),
            ),
            IconButton(
              tooltip: 'Ver historial',
              onPressed: () => setState(() => _tab = 6),
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TeacherCalendarCard(
          month: _calendarMonth,
          selectedDate: _selectedDate,
          sessions: allSessions,
          onMonthChanged: (month) => setState(() => _calendarMonth = month),
          onDateSelected: (date) => setState(() {
            _selectedDate = date;
            _calendarMonth = DateTime(date.year, date.month);
          }),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                titleDate == null
                    ? 'Todas las próximas sesiones'
                    : 'Sesiones del ${_dateLabel(titleDate)}',
                style: const TextStyle(
                  color: _teacherNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (titleDate != null)
              TextButton(
                onPressed: () => setState(() => _selectedDate = null),
                child: const Text('Ver todas'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (sessions.isEmpty)
          _TeacherEmptyCard(
            icon: Icons.event_busy_outlined,
            message: titleDate == null
                ? 'No tienes tutorías pendientes.'
                : 'No hay sesiones en la fecha seleccionada.',
          )
        else
          for (final session in sessions)
            _TeacherSessionCard(
              session: session,
              view: _SessionView.scheduled,
              onRequestDateChange: () => _requestDateChange(session),
              onOpenChat: () => _openSessionChat(session),
              onStart: () => _openRoom(session, ended: false),
              onHistory: () => _openRoom(session, ended: true),
            ),
      ],
    );
  }

  Future<void> _openSessionChat(
    _TeacherTutoringSession session, {
    bool readOnly = false,
  }) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TutoriaChatPage(
        sessionId: session.id,
        subject: session.subject,
        readOnly: readOnly,
      ),
    ));
  }

  Future<void> _openRoom(
    _TeacherTutoringSession session, {
    required bool ended,
  }) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LiveKitRoomPage(
        sessionId: session.id,
        subject: session.subject,
        modality: session.modality,
        teacherMode: true,
        students: session.students,
        ended: ended,
        endAt: session.end,
        onNavigateToDashboard: (tab) {
          Navigator.of(context).pop();
          if (mounted) setState(() => _tab = tab);
        },
      ),
    ));
    if (mounted) ref.invalidate(_teacherSessionsProvider);
  }

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

class _TeacherSidebar extends StatelessWidget {
  const _TeacherSidebar({
    required this.activeTab,
    required this.teacherName,
    required this.onSelect,
  });

  final int activeTab;
  final String teacherName;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        width: 224,
        color: _teacherSidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const BrandLogo(width: 38, height: 34),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'SearchTeach',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'MENÚ PRINCIPAL',
                style: TextStyle(
                  color: Color(0xFFD4EEE2),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _item(0, 'Inicio', Icons.home_outlined),
            _item(1, 'Sesiones', Icons.calendar_month_outlined),
            _item(3, 'Proyectos de aula', Icons.school_outlined),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: Colors.white,
                    child: Text(
                      _initials(teacherName),
                      style: const TextStyle(
                        color: _teacherSidebar,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Docente',
                          style: TextStyle(
                            color: Color(0xFFD4EEE2),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _item(int tab, String label, IconData icon) {
    final selected = activeTab == tab ||
        (tab == 1 && activeTab == 2) ||
        (tab == 3 && activeTab == 4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        selected: selected,
        selectedTileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: selected ? _teacherSidebar : Colors.white,
          size: 21,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? _teacherSidebar : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: () => onSelect(tab),
      ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({
    required this.title,
    required this.teacherName,
    required this.onProfile,
    required this.onLogout,
  });

  final String title;
  final String teacherName;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          color: _teacherSidebar,
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const NotificationBellButton(),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Mi perfil',
              child: InkWell(
                onTap: onProfile,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white,
                        child: Text(
                          _initials(teacherName),
                          style: const TextStyle(
                            color: _teacherSidebar,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 850) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
          ],
        ),
      );
}

class _TeacherAside extends ConsumerWidget {
  const _TeacherAside({
    required this.calendarMonth,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onOpenSessions,
    required this.onOpenHistory,
  });

  final DateTime calendarMonth;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFE7EEE9))),
        ),
        child: ref.watch(_teacherSessionsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'No se pudo cargar la agenda: $error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (allSessions) {
                final sessions = allSessions
                    .where((session) => session.state != 'FINALIZADA')
                    .toList()
                  ..sort((a, b) => (a.start ?? DateTime(9999))
                      .compareTo(b.start ?? DateTime(9999)));
                final daily = selectedDate == null
                    ? sessions.take(4).toList()
                    : sessions.where((session) {
                        final start = session.start?.toLocal();
                        return start != null &&
                            start.year == selectedDate!.year &&
                            start.month == selectedDate!.month &&
                            start.day == selectedDate!.day;
                      }).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  children: [
                    _TeacherCalendarCard(
                      compact: true,
                      month: calendarMonth,
                      selectedDate: selectedDate,
                      sessions: sessions,
                      onMonthChanged: onMonthChanged,
                      onDateSelected: onDateSelected,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Próximas sesiones',
                            style: TextStyle(
                              color: _teacherNavy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Abrir agenda',
                          onPressed: onOpenSessions,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                        ),
                      ],
                    ),
                    if (daily.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'No hay sesiones en esta fecha.',
                          style: TextStyle(
                            color: Color(0xFF687A70),
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      for (final session in daily.take(4))
                        _TeacherUpcomingSession(
                          session: session,
                          onTap: session.start == null
                              ? onOpenSessions
                              : () {
                                  onDateSelected(session.start!.toLocal());
                                  onOpenSessions();
                                },
                        ),
                    const Divider(height: 24),
                    TextButton.icon(
                      onPressed: onOpenHistory,
                      icon: const Icon(Icons.history, size: 18),
                      label: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Consultar historial'),
                      ),
                    ),
                  ],
                );
              },
            ),
      );
}

class _TeacherCalendarCard extends StatelessWidget {
  const _TeacherCalendarCard({
    required this.month,
    required this.selectedDate,
    required this.sessions,
    required this.onMonthChanged,
    required this.onDateSelected,
    this.compact = false,
  });

  final DateTime month;
  final DateTime? selectedDate;
  final List<_TeacherTutoringSession> sessions;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final mondayOffset = DateTime(month.year, month.month, 1).weekday - 1;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(mondayOffset, null),
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final sessionDays = sessions
        .map((session) => session.start?.toLocal())
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day).toString())
        .toSet();
    final weekdays = compact
        ? const ['L', 'M', 'X', 'J', 'V', 'S', 'D']
        : const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE7EEE9)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_monthName(month.month)} ${month.year}',
                    style: TextStyle(
                      color: _teacherNavy,
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Mes anterior',
                  onPressed: () => onMonthChanged(
                    DateTime(month.year, month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Mes siguiente',
                  onPressed: () => onMonthChanged(
                    DateTime(month.year, month.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final weekday in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekday,
                        style: TextStyle(
                          color: const Color(0xFF79887F),
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: compact ? 1 : 1.22,
              ),
              itemBuilder: (context, index) {
                final date = cells[index];
                if (date == null) return const SizedBox.shrink();
                final selected = selectedDate != null &&
                    selectedDate!.year == date.year &&
                    selectedDate!.month == date.month &&
                    selectedDate!.day == date.day;
                final hasSessions = sessionDays.contains(
                  DateTime(date.year, date.month, date.day).toString(),
                );
                final today = DateUtils.isSameDay(date, DateTime.now());
                return InkWell(
                  onTap: () => onDateSelected(date),
                  borderRadius: BorderRadius.circular(9),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: compact ? 27 : 32,
                        height: compact ? 27 : 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? _teacherSidebar : null,
                          shape: BoxShape.circle,
                          border: today && !selected
                              ? Border.all(color: _teacherSidebar)
                              : null,
                        ),
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: selected ? Colors.white : _teacherNavy,
                            fontSize: compact ? 11 : 12,
                            fontWeight: selected || today
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              hasSessions ? _teacherGreen : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.circle, size: 8, color: _teacherGreen),
                  SizedBox(width: 6),
                  Text(
                    'Día con tutorías',
                    style: TextStyle(
                      color: Color(0xFF687A70),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeacherUpcomingSession extends StatelessWidget {
  const _TeacherUpcomingSession({
    required this.session,
    required this.onTap,
  });

  final _TeacherTutoringSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: _teacherGreen,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _teacherNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.start == null
                          ? 'Fecha pendiente'
                          : _dateTimeLabel(session.start!.toLocal()),
                      style: const TextStyle(
                        color: Color(0xFF687A70),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${session.students.length} estudiantes inscritos',
                      style: const TextStyle(
                        color: Color(0xFF687A70),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _TeacherSessionCard extends ConsumerWidget {
  const _TeacherSessionCard({
    required this.session,
    required this.view,
    required this.onRequestDateChange,
    required this.onOpenChat,
    required this.onStart,
    required this.onHistory,
  });

  final _TeacherTutoringSession session;
  final _SessionView view;
  final VoidCallback onRequestDateChange;
  final VoidCallback onOpenChat;
  final VoidCallback onStart;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHistory = view == _SessionView.history;
    final isStart = view == _SessionView.start;
    final studentNames = session.id.isNotEmpty && session.students.isNotEmpty
        ? ref.watch(_teacherStudentNamesProvider(session.id))
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE7EEE9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F4EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: _teacherGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.subject,
                        style: const TextStyle(
                          color: _teacherNavy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.start == null ? 'Fecha no disponible' : _dateTimeLabel(session.start!.toLocal())} · ${_modalityLabel(session.modality)}',
                        style: const TextStyle(
                          color: Color(0xFF687A70),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isHistory &&
                    session.id.isNotEmpty &&
                    session.start != null &&
                    session.end != null)
                  IconButton(
                    tooltip: 'Solicitar cambio de fecha',
                    onPressed: onRequestDateChange,
                    icon: const Icon(Icons.edit_calendar_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _TeacherTag(label: 'Semestre ${session.semester}'),
                _TeacherTag(label: '${session.students.length} estudiantes'),
                _TeacherTag(label: session.state),
                for (final tech in session.technologies.take(3))
                  _TeacherTag(label: tech),
              ],
            ),
            if (session.students.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (studentNames == null)
                Text(
                  '${session.students.length} estudiantes inscritos',
                  style: const TextStyle(
                    color: Color(0xFF687A70),
                    fontSize: 11,
                  ),
                )
              else
                studentNames.when(
                  loading: () => const Text(
                    'Cargando estudiantes…',
                    style: TextStyle(
                      color: Color(0xFF687A70),
                      fontSize: 11,
                    ),
                  ),
                  error: (error, _) => Text(
                    'No se pudieron cargar los estudiantes: $error',
                    style: const TextStyle(
                      color: Color(0xFF9B2C2C),
                      fontSize: 11,
                    ),
                  ),
                  data: (names) => Text(
                    names.isEmpty
                        ? '${session.students.length} estudiantes inscritos'
                        : 'Estudiantes: ${names.take(4).join(', ')}${names.length > 4 ? ' y ${names.length - 4} más' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF687A70),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: session.id.isEmpty ? null : onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: const Text('Chat'),
                ),
                if (isStart)
                  FilledButton.icon(
                    onPressed: session.id.isEmpty ? null : onStart,
                    icon: const Icon(Icons.video_call_outlined, size: 18),
                    label: const Text('Entrar a sala'),
                  ),
                if (isHistory)
                  FilledButton.tonalIcon(
                    onPressed: session.id.isEmpty ? null : onHistory,
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Ver historial'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherTag extends StatelessWidget {
  const _TeacherTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F5F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF53665B),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _TeacherMetricCard extends StatelessWidget {
  const _TeacherMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE7EEE9)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: color,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF687A70),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TeacherEmptyCard extends StatelessWidget {
  const _TeacherEmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE7EEE9)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, color: _teacherGreen, size: 30),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687A70)),
              ),
            ],
          ),
        ),
      );
}

class _TeacherLoadError extends StatelessWidget {
  const _TeacherLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}

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

String _monthName(int month) => const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ][month - 1];

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  if (parts.isEmpty) return 'D';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _modalityLabel(String modality) => switch (modality.toUpperCase()) {
      'VIRTUAL' => 'Virtual',
      'HIBRIDA' => 'Híbrida',
      'PRESENCIAL' => 'Presencial',
      _ => modality.isEmpty ? 'Modalidad por confirmar' : modality,
    };
