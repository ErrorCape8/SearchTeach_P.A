import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/role_theme.dart';
import '../../core/tutoring_updates.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/role_toast.dart';
import '../../core/widgets/sliding_pill_navigation_bar.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import 'docente_proyectos_aula_page.dart';
import 'docente_lider_proyectos_page.dart';
import 'docente_perfil_page.dart';
import 'docente_solicitudes_page.dart';
import 'livekit_room_page.dart';
import 'presencial_tutoria_page.dart';
import 'tutoria_chat_page.dart';
import 'tutoria_historial_page.dart';

const _teacherGreen = Color(0xFF16834A);
const _teacherCanvas = Color(0xFFF5F7FB);
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
    final profile = ref.watch(docenteProfileProvider).asData?.value;
    final teacherName = profile?['nombre'] is String
        ? profile!['nombre'] as String
        : 'Docente';
    final teacherCareer = profile?['carrera'] is String
        ? profile!['carrera'] as String
        : 'SearchTeach';
    return Theme(
      data: withRoleAccent(
        Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: _teacherGreen),
          scaffoldBackgroundColor: _teacherCanvas,
        ),
        _teacherGreen,
      ),
      child: Scaffold(
        backgroundColor: _teacherCanvas,
        body: Row(
          children: [
            if (wide) _desktopMenu(teacherName, teacherCareer),
            Expanded(
              child: Column(
                children: [
                  _TeacherHeader(
                    title: _headerTitle,
                    subtitle: _tab == 0
                        ? teacherCareer
                        : 'Docente · $teacherCareer',
                    name: teacherName,
                    onRefresh: () {
                      ref.invalidate(_teacherSessionsProvider);
                      ref.invalidate(docenteProfileProvider);
                      ref.invalidate(notificationUnreadCountProvider);
                    },
                    onNotifications: () => setState(() => _tab = 5),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          _home(teacherName),
                          _sessions(),
                          _startTutoring(),
                          const DocenteProyectosAulaPage(),
                          const DocenteLiderProyectosPage(),
                          const NotificationsInbox(
                            accentColor: _teacherGreen,
                            htmlStyle: true,
                          ),
                          _history(),
                          const DocentePerfilPage(),
                          const DocenteSolicitudesPage(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : SlidingPillNavigationBar(
                selectedColor: _teacherGreen,
                indicatorColor: const Color(0xFFE6F4EA),
                selectedIndex: _navigationTabs.indexOf(_tab).clamp(
                      0,
                      _navigationTabs.length - 1,
                    ),
                onDestinationSelected: (position) => setState(
                  () => _tab = _navigationTabs[position],
                ),
                destinations: [
                  const SlidingPillDestination(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'Inicio',
                  ),
                  const SlidingPillDestination(
                    icon: Icons.inbox_outlined,
                    selectedIcon: Icons.inbox_rounded,
                    label: 'Solicitudes',
                  ),
                  const SlidingPillDestination(
                    icon: Icons.event_note_outlined,
                    selectedIcon: Icons.event_note_rounded,
                    label: 'Tutorías',
                  ),
                  const SlidingPillDestination(
                    icon: Icons.groups_outlined,
                    selectedIcon: Icons.groups_rounded,
                    label: 'Colectivas',
                  ),
                  const SlidingPillDestination(
                    icon: Icons.star_outline_rounded,
                    selectedIcon: Icons.star_rounded,
                    label: 'Líder PA',
                  ),
                  const SlidingPillDestination(
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    label: 'Perfil',
                  ),
                  const SlidingPillDestination(
                    icon: Icons.notifications_none_rounded,
                    selectedIcon: Icons.notifications_rounded,
                    label: 'Avisos',
                  ),
                ],
              ),
      ),
    );
  }

  static const _teacherTabNames = {
    0: 'Inicio',
    1: 'Tutorías',
    2: 'Iniciar tutoría',
    3: 'Colectivas',
    4: 'Líder de proyecto de aula',
    5: 'Avisos',
    6: 'Historial',
    7: 'Mi perfil',
    8: 'Solicitudes',
  };

  String get _headerTitle =>
      _tab == 0 ? 'Panel docente' : _teacherTabNames[_tab] ?? 'Panel docente';

  List<int> get _navigationTabs => [0, 8, 1, 3, 4, 7, 5];

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return 'D';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Widget _desktopMenu(String teacherName, String teacherCareer) => Material(
        color: Colors.white,
        child: SizedBox(
          width: 198,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 16),
              child: SizedBox(
                height: 76,
                child: BrandLogo(
                  width: 158,
                  height: 76,
                  accentColor: _teacherGreen,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('DOCENTE',
                      style: TextStyle(
                          color: Color(0xFF687A70),
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700))),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Divider(height: 1, color: Color(0xFFE3ECE5)),
            ),
            const SizedBox(height: 10),
            for (final item in const [
            (0, Icons.home_outlined, 'Inicio'),
            (8, Icons.inbox_outlined, 'Solicitudes'),
            (1, Icons.event_note_outlined, 'Tutorías'),
            (3, Icons.groups_outlined, 'Colectivas'),
            (4, Icons.fact_check_outlined, 'Líder PA'),
            (7, Icons.person_outline_rounded, 'Perfil'),
            (5, Icons.notifications_none_outlined, 'Avisos'),
            ])
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: ListTile(
                dense: true,
                selected: _tab == item.$1,
                selectedColor: _teacherNavy,
                selectedTileColor: const Color(0xFFEAF5EE),
                textColor: _teacherNavy,
                iconColor: _teacherGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Icon(item.$2, size: 20),
                title: Text(item.$3,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () => setState(() => _tab = item.$1),
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Color(0xFFE3ECE5)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEAF5EE),
                  foregroundColor: _teacherNavy,
                  child: Text(_initials(teacherName)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teacherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _teacherNavy,
                              fontWeight: FontWeight.w700)),
                      Text(teacherCareer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Color(0xFF687A70), fontSize: 11)),
                    ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 17),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teacherNavy,
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _home(String name) => _TeacherHomeDashboard(
        name: name,
        onOpen: (tab) => setState(() => _tab = tab),
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
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE5ECE7)),
                        ),
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
                                '${session.start == null ? 'Fecha no disponible' : _dateTimeLabel(session.start!)} · ${_modalityLabel(session.modality)} · Semestre ${session.semester} · ${session.technologies.join(', ')}${session.modality.toUpperCase() == 'VIRTUAL' || session.location.trim().isEmpty ? '' : '\nLugar: ${session.location}'}\n${session.students.isEmpty ? 'Publicada · sin inscritos' : 'Estudiantes inscritos: ${session.students.length}'}${session.state == 'FINALIZADA' ? '\nClase finalizada' : ''}'),
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
                                  if (view != _SessionView.start ||
                                      session.modality.toUpperCase() !=
                                          'PRESENCIAL')
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
                                  if (view != _SessionView.scheduled ||
                                      (session.start != null &&
                                          _isSameDay(
                                              session.start!, DateTime.now())))
                                    FilledButton.icon(
                                      onPressed: () async {
                                        if (session.modality.toUpperCase() ==
                                                'PRESENCIAL' &&
                                            view != _SessionView.history) {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PresencialTutoriaPage(
                                                sessionId: session.id,
                                                subject: session.subject,
                                              ),
                                            ),
                                          );
                                        } else {
                                          await Navigator.of(context)
                                              .push(MaterialPageRoute(
                                            builder: (_) => LiveKitRoomPage(
                                                sessionId: session.id,
                                                subject: session.subject,
                                                modality: session.modality,
                                                teacherMode: true,
                                                students: session.students,
                                                ended: view ==
                                                    _SessionView.history,
                                                endAt: session.end),
                                          ));
                                        }
                                        if (mounted) {
                                          ref.invalidate(
                                              _teacherSessionsProvider);
                                        }
                                      },
                                      icon: Icon(view == _SessionView.history
                                          ? Icons.history
                                          : session.modality.toUpperCase() ==
                                                  'PRESENCIAL'
                                              ? Icons.fact_check_outlined
                                              : Icons.video_call_outlined),
                                      label: Text(view == _SessionView.history
                                          ? 'Ver historial'
                                          : view == _SessionView.scheduled
                                              ? 'Iniciar tutoría'
                                              : session.modality.toUpperCase() ==
                                                      'PRESENCIAL'
                                              ? session.state == 'EN_CURSO'
                                                  ? 'Tomar asistencia'
                                                  : 'Habilitar clase presencial'
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
                  if (session.modality.toUpperCase() != 'VIRTUAL' &&
                      session.location.trim().isNotEmpty)
                    _HistoryDetail(
                      icon: Icons.place_outlined,
                      label: session.location,
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
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TutoriaHistorialPage(
                              sessionId: session.id,
                              subject: session.subject,
                              isIndividual: false,
                            ),
                          ),
                        ),
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
      RoleToast.show(context,
          message: 'Solicitud enviada a coordinación.',
          roleColor: _teacherGreen);
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo enviar la solicitud. Inténtalo de nuevo.';
      RoleToast.show(context, message: message, roleColor: _teacherGreen);
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

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({
    required this.title,
    required this.subtitle,
    required this.name,
    required this.onRefresh,
    required this.onNotifications,
  });

  final String title;
  final String subtitle;
  final String name;
  final VoidCallback onRefresh;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF16834A), Color(0xFF18352A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 78,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: Colors.white.withValues(alpha: .16),
                    foregroundColor: Colors.white,
                    child: Text(
                      _DocenteDashboardPageState._initials(name),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: onRefresh,
                    color: Colors.white,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Avisos',
                    onPressed: onNotifications,
                    color: Colors.white,
                    icon: const NotificationUnreadIcon(
                      icon: Icons.notifications_none_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TeacherHomeDashboard extends ConsumerWidget {
  const _TeacherHomeDashboard({required this.onOpen, required this.name});
  final ValueChanged<int> onOpen;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(_teacherSessionsProvider).when(
            loading: () => _content(context, ref, const [], loading: true),
            error: (error, _) => _content(context, ref, const [], error: true),
            data: (sessions) => _content(context, ref, sessions),
          );

  Widget _content(BuildContext context, WidgetRef ref,
      List<_TeacherTutoringSession> sessions,
      {bool loading = false, bool error = false}) {
    final now = DateTime.now();
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo'
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    final scheduled = sessions
        .where((session) =>
            session.state != 'FINALIZADA' && session.start != null)
        .toList()
      ..sort((a, b) => a.start!.compareTo(b.start!));
    final upcoming = scheduled
        .where((session) => session.start!.isAfter(now))
        .toList();
    final nextSession = upcoming.isEmpty ? null : upcoming.first;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showCalendar = constraints.maxWidth >= 900;
            final schedule = _TeacherScheduleList(
              sessions: scheduled,
              loading: loading,
              error: error,
              onRetry: () => ref.invalidate(_teacherSessionsProvider),
              onOpenSessions: () => onOpen(1),
              onStart: () => onOpen(2),
            );
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weekdays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]} de ${now.year}',
                  style: const TextStyle(
                      color: Color(0xFF748078), fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  'Hola, $name',
                  style: const TextStyle(
                    color: _teacherNavy,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  nextSession == null
                      ? 'Aquí tienes un resumen de tus tutorías y actividades.'
                      : 'Tu próxima tutoría es ${nextSession.subject} · ${_dateTimeLabel(nextSession.start!)}',
                  style: const TextStyle(
                      color: Color(0xFF748078), fontSize: 13),
                ),
                const SizedBox(height: 22),
                if (showCalendar)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: schedule),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 4,
                        child: _TeacherCalendarPanel(
                          sessions: scheduled,
                          onOpenSessions: () => onOpen(1),
                        ),
                      ),
                    ],
                  )
                else
                  schedule,
              ],
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(
                  showCalendar ? 28 : 18, 24, showCalendar ? 28 : 18, 32),
              children: [content],
            );
          },
        ),
      ),
    );
  }
}

class _TeacherScheduleList extends StatelessWidget {
  const _TeacherScheduleList({
    required this.sessions,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onOpenSessions,
    required this.onStart,
  });

  final List<_TeacherTutoringSession> sessions;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  final VoidCallback onOpenSessions;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tutorías programadas',
                  style: TextStyle(
                    color: _teacherNavy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenSessions,
                child: const Text('Ver todas'),
              ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error)
            _TeacherEmptyCard(
              icon: Icons.cloud_off_outlined,
              message: 'No se pudieron cargar las tutorías.',
              action: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            )
          else if (sessions.isEmpty)
            const _TeacherEmptyCard(
              icon: Icons.event_available_outlined,
              message: 'No tienes tutorías programadas por ahora.',
            )
          else
            for (final session in sessions.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TeacherScheduleCard(
                  session: session,
                  onOpen: onOpenSessions,
                  onStart: onStart,
                ),
              ),
        ],
      );
}

class _TeacherScheduleCard extends StatelessWidget {
  const _TeacherScheduleCard({
    required this.session,
    required this.onOpen,
    required this.onStart,
  });

  final _TeacherTutoringSession session;
  final VoidCallback onOpen;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final start = session.start;
    final isToday = start != null && _isSameDay(start, DateTime.now());
    final isActive = session.state == 'EN_CURSO';
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5ECE7)),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 74,
                decoration: BoxDecoration(
                  color: isToday || isActive
                      ? _teacherGreen
                      : const Color(0xFFB7C7BC),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subject,
                      style: const TextStyle(
                        color: _teacherNavy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 14,
                      runSpacing: 7,
                      children: [
                        _TeacherInlineDetail(
                          icon: Icons.calendar_today_outlined,
                          text: start == null
                              ? 'Fecha pendiente'
                              : _dateTimeLabel(start),
                        ),
                        _TeacherInlineDetail(
                          icon: Icons.people_outline,
                          text: '${session.students.length} inscritos',
                        ),
                        _TeacherInlineDetail(
                          icon: Icons.meeting_room_outlined,
                          text: _modalityLabel(session.modality),
                        ),
                      ],
                    ),
                    if (session.location.trim().isNotEmpty &&
                        session.modality.toUpperCase() != 'VIRTUAL') ...[
                      const SizedBox(height: 7),
                      _TeacherInlineDetail(
                        icon: Icons.place_outlined,
                        text: session.location,
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _TeacherStatusBadge(
                          label: isActive
                              ? 'En curso'
                              : isToday
                                  ? 'Hoy'
                                  : 'Programada',
                        ),
                        if (isToday || isActive)
                          FilledButton.tonalIcon(
                            onPressed: onStart,
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Iniciar tutoría'),
                          ),
                      ],
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
}

class _TeacherCalendarPanel extends StatelessWidget {
  const _TeacherCalendarPanel({
    required this.sessions,
    required this.onOpenSessions,
  });

  final List<_TeacherTutoringSession> sessions;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final offset = first.weekday - 1;
    final dayCount = DateTime(now.year, now.month + 1, 0).day;
    const monthNames = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final cells = <int?>[
      ...List<int?>.filled(offset, null),
      ...List<int?>.generate(dayCount, (index) => index + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final nextSessions = sessions
        .where((session) =>
            session.start != null &&
            !session.start!.isBefore(DateTime(now.year, now.month, now.day)))
        .take(3)
        .toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Calendario',
                    style: TextStyle(
                        color: _teacherNavy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
              Text('${monthNames[now.month - 1]} ${now.year}',
                  style: const TextStyle(
                      color: Color(0xFF687A70), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final label in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(label,
                        style: const TextStyle(
                            color: Color(0xFF849087),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var week = 0; week < cells.length ~/ 7; week++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  for (var dayIndex = 0; dayIndex < 7; dayIndex++)
                    Expanded(
                      child: _TeacherCalendarDay(
                        day: cells[week * 7 + dayIndex],
                        isToday: cells[week * 7 + dayIndex] == now.day,
                        hasSession: sessions.any((session) =>
                            session.start?.year == now.year &&
                            session.start?.month == now.month &&
                            session.start?.day ==
                                cells[week * 7 + dayIndex]),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEAF0EB)),
          const SizedBox(height: 14),
          const Text('Próximas tutorías',
              style: TextStyle(
                  color: _teacherNavy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (nextSessions.isEmpty)
            const Text('No tienes próximas tutorías.',
                style: TextStyle(color: Color(0xFF687A70), fontSize: 12))
          else
            for (final session in nextSessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: _teacherGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${session.subject} · ${_dateTimeLabel(session.start!)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _teacherNavy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onOpenSessions,
              child: const Text('Ver agenda'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherCalendarDay extends StatelessWidget {
  const _TeacherCalendarDay({
    required this.day,
    required this.isToday,
    required this.hasSession,
  });

  final int? day;
  final bool isToday;
  final bool hasSession;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: day == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? _teacherGreen : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isToday ? Colors.white : _teacherNavy,
                        fontSize: 11,
                        fontWeight:
                            isToday ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (hasSession)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                          color: _teacherGreen, shape: BoxShape.circle),
                    ),
                ],
              ),
      );
}

class _TeacherQuickLinks extends StatelessWidget {
  const _TeacherQuickLinks({required this.onOpen});
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _TeacherQuickLink(
              label: 'Solicitudes',
              icon: Icons.inbox_outlined,
              onTap: () => onOpen(8)),
          _TeacherQuickLink(
              label: 'Proyectos colectivos',
              icon: Icons.groups_outlined,
              onTap: () => onOpen(3)),
          _TeacherQuickLink(
              label: 'Líder PA',
              icon: Icons.fact_check_outlined,
              onTap: () => onOpen(4)),
          _TeacherQuickLink(
              label: 'Historial',
              icon: Icons.history_outlined,
              onTap: () => onOpen(6)),
        ],
      );
}

class _TeacherQuickLink extends StatelessWidget {
  const _TeacherQuickLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _teacherNavy,
          side: const BorderSide(color: Color(0xFFDCE7DF)),
          backgroundColor: Colors.white,
        ),
      );
}

class _TeacherInlineDetail extends StatelessWidget {
  const _TeacherInlineDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7C8B81)),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFF687A70), fontSize: 11)),
        ],
      );
}

class _TeacherStatusBadge extends StatelessWidget {
  const _TeacherStatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5EE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: _teacherGreen,
              fontSize: 11,
              fontWeight: FontWeight.w700),
        ),
      );
}

class _TeacherEmptyCard extends StatelessWidget {
  const _TeacherEmptyCard({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5ECE7)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _teacherGreen, size: 30),
            const SizedBox(height: 9),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687A70))),
            if (action != null) ...[
              const SizedBox(height: 7),
              action!,
            ],
          ],
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
      required this.location,
      required this.state});
  final String id;
  final String subject;
  final List<String> technologies;
  final List<String> students;
  final DateTime? start;
  final DateTime? end;
  final int semester;
  final String modality;
  final String location;
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
        location:
            json['ubicacion'] is String ? json['ubicacion'] as String : '',
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

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
