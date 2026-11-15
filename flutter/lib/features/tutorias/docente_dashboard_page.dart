// ignore_for_file: unused_element, unused_element_parameter
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
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import 'docente_proyectos_aula_page.dart';
import 'docente_lider_proyectos_page.dart';
import 'docente_perfil_page.dart';
import 'docente_solicitudes_page.dart';
import '../pa/pa_docente_pages.dart';
import '../pa/pa_widgets.dart';
import 'livekit_room_page.dart';
import 'presencial_tutoria_page.dart';
import 'tutoria_chat_page.dart';
import 'tutoria_historial_page.dart';

const _teacherGreen = Color(0xFF16834A);

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
  bool _sessionsCalendar = false;

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

  static const _teacherTabNames = {
    0: 'Inicio',
    1: 'Tutoría',
    2: 'Empezar tutoría',
    3: 'Mis sesiones',
    4: 'Líder de proyecto de aula',
    5: 'Avisos',
    6: 'Historial',
    7: 'Mi perfil',
    8: 'Solicitudes',
  };

  String get _headerTitle =>
      _tab == 0 ? 'Panel docente' : _teacherTabNames[_tab] ?? 'Panel docente';

  static const _navigationTabs = [0, 2, 3, 1, 4];

  static String _initials(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return 'D';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Widget _profileButton(String teacherName) => Semantics(
        button: true,
        label: 'Abrir perfil',
        child: GestureDetector(
          onTap: () => setState(() => _tab = 7),
          child: SizedBox(
            width: 46,
            height: 46,
            child: NeuSurface(
              radius: 46,
              shadows: Neu.raiseS,
              child: Center(
                child: Text(_initials(teacherName),
                    style: neuPoppins(
                        size: 15,
                        weight: FontWeight.w700,
                        color: _teacherGreen)),
              ),
            ),
          ),
        ),
      );

  Widget _header(bool wide, String teacherName, String teacherCareer) {
    final home = _tab == 0;
    final unread = ref.watch(notificationUnreadCountProvider).valueOrNull ?? 0;
    return NeuHeader(
      title: home
          ? 'Hola, ${teacherName.split(RegExp(r'\s+')).first}'
          : _headerTitle,
      subtitle: home
          ? teacherCareer
          : (_tab == 7 ? 'Docente' : 'Docente · $teacherCareer'),
      leading: home
          ? _profileButton(teacherName)
          : NeuCircleButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Volver al inicio',
              onTap: () => setState(() => _tab = 0),
            ),
      actions: [
        if (wide)
          NeuButton(
            'Actualizar',
            onPressed: () {
              ref.invalidate(_teacherSessionsProvider);
              ref.invalidate(docenteProfileProvider);
              ref.invalidate(notificationUnreadCountProvider);
            },
            kind: NeuButtonKind.alt,
            small: true,
            icon: Icons.refresh_rounded,
            expand: false,
          )
        else
          NeuCircleButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualizar',
            onTap: () {
              ref.invalidate(_teacherSessionsProvider);
              ref.invalidate(docenteProfileProvider);
              ref.invalidate(notificationUnreadCountProvider);
            },
          ),
        NeuCircleButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Avisos',
          badge: unread > 0 ? unread : null,
          onTap: () => setState(() => _tab = 5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) ref.invalidate(_teacherSessionsProvider);
    });
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final profile = ref.watch(docenteProfileProvider).asData?.value;
    final teacherName = profile?['nombre'] is String
        ? profile!['nombre'] as String
        : 'Docente';
    final teacherCareer = profile?['carrera'] is String
        ? profile!['carrera'] as String
        : 'SearchTeach';

    final content = Column(
      children: [
        _header(wide, teacherName, teacherCareer),
        Expanded(
          child: _content(teacherName),
        ),
      ],
    );

    return Theme(
      data: withRoleAccent(
        Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _teacherGreen,
            brightness: Theme.of(context).brightness,
          ).copyWith(primary: _teacherGreen),
          scaffoldBackgroundColor: Neu.bg,
        ),
        _teacherGreen,
      ),
      child: Scaffold(
        backgroundColor: Neu.bg,
        body: wide
            ? Row(
                children: [
                  _TeacherSidebar(
                    index: _tab,
                    name: teacherName,
                    career: teacherCareer,
                    onSelect: (tab) => setState(() => _tab = tab),
                    onLogout: _logout,
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
        bottomNavigationBar: wide
            ? null
            : NeuBottomBar(
                items: const [
                  NeuNavItem(Icons.home_outlined, 'Inicio'),
                  NeuNavItem(Icons.videocam_outlined, 'Empezar'),
                  NeuNavItem(Icons.calendar_month_outlined, 'Mis sesiones'),
                  NeuNavItem(Icons.menu_book_outlined, 'Tutoría'),
                  NeuNavItem(Icons.star_outline_rounded, 'Líder PA'),
                ],
                index: _navigationTabs.indexOf(_tab),
                onSelect: (position) => setState(
                  () => _tab = _navigationTabs[position],
                ),
              ),
      ),
    );
  }

  Widget _content(String teacherName) => switch (_tab) {
        0 => _home(teacherName),
        1 => _sessions(),
        2 => _startTutoring(),
        3 => const DocenteProyectosAulaPage(),
        4 => const DocenteLiderProyectosPage(),
        5 => const NotificationsInbox(
            accentColor: _teacherGreen,
            htmlStyle: true,
          ),
        6 => _history(),
        7 => const DocentePerfilPage(),
        8 => const DocenteSolicitudesPage(),
        _ => _home(teacherName),
      };

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
        loading: () => const Center(
          child: CircularProgressIndicator(color: _teacherGreen),
        ),
        error: (error, _) => view == _SessionView.history
            ? _historyPage(
                body: _historyMessage(
                  'No se pudo cargar el historial: $error',
                  onRetry: () => ref.invalidate(_teacherSessionsProvider),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: PaCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const NeuIconBox(Icons.cloud_off_outlined,
                              color: Neu.error),
                          const SizedBox(height: 12),
                          Text(
                            'No se pudieron cargar tus tutorías.',
                            style: neuPoppins(
                                size: 15,
                                weight: FontWeight.w700,
                                color: Neu.heading),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$error',
                            textAlign: TextAlign.center,
                            style: neuBody(size: 13, color: Neu.muted),
                          ),
                          const SizedBox(height: 16),
                          NeuButton(
                            'Reintentar',
                            onPressed: () =>
                                ref.invalidate(_teacherSessionsProvider),
                            kind: NeuButtonKind.alt,
                            small: true,
                            icon: Icons.refresh,
                            expand: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        data: (allSessions) {
          final sessions = allSessions
              .where((session) => switch (view) {
                    _SessionView.history => session.state == 'FINALIZADA',
                    _SessionView.scheduled ||
                    _SessionView.start =>
                      session.state != 'FINALIZADA' &&
                          session.start != null &&
                          _isSameDay(session.start!, DateTime.now()),
                  })
              .toList()
            ..sort((a, b) => (a.start ?? DateTime(9999))
                .compareTo(b.start ?? DateTime(9999)));

          if (view == _SessionView.history) {
            return _historyPage(
              count: sessions.length,
              body: sessions.isEmpty
                  ? _historyMessage('Aún no tienes tutorías finalizadas.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) =>
                          _historySessionCard(sessions[index]),
                    ),
            );
          }

          return sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: const _TeacherEmptyCard(
                        icon: Icons.event_available_outlined,
                        message: 'No tienes tutorías programadas para hoy.',
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            switch (view) {
                              _SessionView.scheduled => 'Mis sesiones',
                              _SessionView.start => 'Tutorías de hoy',
                              _SessionView.history => 'Historial'
                            },
                            style: neuPoppins(
                              size: 20,
                              weight: FontWeight.w700,
                              color: Neu.heading,
                            ),
                          ),
                        ),
                        if (view == _SessionView.scheduled)
                          NeuSegmented(
                            labels: const ['Lista', 'Calendario'],
                            icons: const [
                              Icons.view_list_rounded,
                              Icons.calendar_month_rounded,
                            ],
                            selected: _sessionsCalendar ? 1 : 0,
                            onSelect: (value) => setState(
                              () => _sessionsCalendar = value == 1,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (view == _SessionView.scheduled && _sessionsCalendar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TeacherCalendarPanel(
                          sessions: sessions,
                          onOpenSessions: () =>
                              setState(() => _sessionsCalendar = false),
                        ),
                      ),
                    if (view != _SessionView.scheduled || !_sessionsCalendar)
                      for (final session in sessions)
                        _buildSessionCard(context, session, view),
                  ],
                );
        },
      );

  Widget _buildSessionCard(BuildContext context,
      _TeacherTutoringSession session, _SessionView view) {
    return PaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NeuIconBox(Icons.event_available, color: _teacherGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subject,
                      style: neuPoppins(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Neu.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.start == null ? 'Fecha no disponible' : _dateTimeLabel(session.start!)} · ${_modalityLabel(session.modality)} · Semestre ${session.semester} · ${session.technologies.join(', ')}${session.modality.toUpperCase() == 'VIRTUAL' || session.location.trim().isEmpty ? '' : '\nLugar: ${session.location}'}\n${session.students.isEmpty ? 'Publicada · sin inscritos' : 'Estudiantes inscritos: ${session.students.length}'}${session.state == 'FINALIZADA' ? '\nClase finalizada' : ''}',
                      style:
                          neuBody(size: 13, color: Neu.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (session.id.isNotEmpty &&
                  session.start != null &&
                  session.end != null &&
                  session.state != 'FINALIZADA')
                NeuCircleButton(
                  size: 38,
                  icon: Icons.edit_calendar_outlined,
                  tooltip: 'Solicitar cambio de fecha',
                  onTap: () => _requestDateChange(session),
                ),
            ],
          ),
          if (session.id.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (view != _SessionView.start ||
                    session.modality.toUpperCase() != 'PRESENCIAL')
                  NeuButton(
                    'Abrir chat',
                    kind: NeuButtonKind.alt,
                    small: true,
                    expand: false,
                    icon: Icons.forum_outlined,
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TutoriaChatPage(
                        sessionId: session.id,
                        subject: session.subject,
                        readOnly: view == _SessionView.history,
                      ),
                    )),
                  ),
                if (view != _SessionView.scheduled ||
                    (session.start != null &&
                        _isSameDay(session.start!, DateTime.now())))
                  NeuButton(
                    view == _SessionView.history
                        ? 'Ver historial'
                        : view == _SessionView.scheduled
                            ? 'Iniciar tutoría'
                            : session.modality.toUpperCase() == 'PRESENCIAL'
                                ? session.state == 'EN_CURSO'
                                    ? 'Tomar asistencia'
                                    : 'Habilitar clase presencial'
                                : 'Empezar tutoría',
                    icon: view == _SessionView.history
                        ? Icons.history
                        : session.modality.toUpperCase() == 'PRESENCIAL'
                            ? Icons.fact_check_outlined
                            : Icons.video_call_outlined,
                    small: true,
                    expand: false,
                    onPressed: () async {
                      if (session.modality.toUpperCase() == 'PRESENCIAL' &&
                          view != _SessionView.history) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PresencialTutoriaPage(
                              sessionId: session.id,
                              subject: session.subject,
                            ),
                          ),
                        );
                      } else {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LiveKitRoomPage(
                            sessionId: session.id,
                            subject: session.subject,
                            modality: session.modality,
                            teacherMode: true,
                            students: session.students,
                            ended: view == _SessionView.history,
                            endAt: session.end,
                          ),
                        ));
                      }
                      if (mounted) {
                        ref.invalidate(_teacherSessionsProvider);
                      }
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyPage({required Widget body, int? count}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                const NeuIconBox(Icons.history,
                    color: _teacherGreen, size: 44, iconSize: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historial de tutorías',
                        style: neuPoppins(
                          color: Neu.heading,
                          size: 19,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Consulta tus sesiones finalizadas, sus datos y chats.',
                        style: neuBody(color: Neu.muted, size: 12.5),
                      ),
                    ],
                  ),
                ),
                if (count != null)
                  PaTag(
                    '$count ${count == 1 ? 'sesión' : 'sesiones'}',
                    tone: PaTone.neutral,
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: PaCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NeuIconBox(Icons.history,
                      color: _teacherGreen, size: 48, iconSize: 26),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: neuBody(size: 14, color: Neu.muted),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    NeuButton(
                      'Reintentar',
                      icon: Icons.refresh,
                      kind: NeuButtonKind.alt,
                      small: true,
                      expand: false,
                      onPressed: onRetry,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget _historySessionCard(_TeacherTutoringSession session) => PaCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const NeuIconBox(Icons.event_available, color: _teacherGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    session.subject,
                    style: neuPoppins(
                      color: Neu.heading,
                      weight: FontWeight.w700,
                      size: 15,
                    ),
                  ),
                ),
                const PaTag('Finalizada', tone: PaTone.ok),
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
                style: neuBody(color: Neu.muted, size: 12),
              ),
            ],
            if (session.id.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: Neu.line),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: NeuButton(
                  'Ver historial',
                  icon: Icons.history,
                  kind: NeuButtonKind.alt,
                  small: true,
                  expand: false,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TutoriaHistorialPage(
                        sessionId: session.id,
                        subject: session.subject,
                        isIndividual: false,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
      builder: (_) =>
          _DateChangeDialog(start: originalStart, end: originalEnd),
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

class _TeacherSidebar extends StatelessWidget {
  const _TeacherSidebar({
    required this.index,
    required this.name,
    required this.career,
    required this.onSelect,
    required this.onLogout,
  });

  final int index;
  final String name;
  final String career;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  static const _items = [
    (Icons.home_outlined, 'Inicio', 0),
    (Icons.videocam_outlined, 'Empezar', 2),
    (Icons.calendar_month_outlined, 'Mis sesiones', 3),
    (Icons.menu_book_outlined, 'Tutoría', 1),
    (Icons.star_outline_rounded, 'Líder PA', 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Neu.bg,
        boxShadow: [
          BoxShadow(
              color: Neu.shadowDark, offset: Offset(4, 0), blurRadius: 12),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(children: [
            const SizedBox(
              height: 64,
              width: 170,
              child: BrandLogo(
                  width: 170, height: 64, accentColor: _teacherGreen),
            ),
            const SizedBox(height: 6),
            Text('DOCENTE',
                style: neuBody(
                    size: 11,
                    weight: FontWeight.w700,
                    color: _teacherGreen,
                    letterSpacing: 1.2)),
            const SizedBox(height: 20),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: NeuSurface(
                  radius: 16,
                  shadows: const [],
                  sunken: index == item.$3,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  onTap: () => onSelect(item.$3),
                  child: Row(children: [
                    Icon(item.$1,
                        size: 22,
                        color: index == item.$3 ? _teacherGreen : Neu.navIdle),
                    const SizedBox(width: 12),
                    Text(item.$2,
                        style: neuBody(
                            size: 15,
                            weight: FontWeight.w700,
                            color:
                                index == item.$3 ? _teacherGreen : Neu.muted)),
                  ]),
                ),
              ),
            const Spacer(),
            NeuSurface(
              radius: 16,
              shadows: const [],
              sunken: index == 7,
              padding: const EdgeInsets.all(10),
              onTap: () => onSelect(7),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: NeuSurface(
                    radius: 40,
                    shadows: Neu.raiseS,
                    child: Center(
                      child: Text(_DocenteDashboardPageState._initials(name),
                          style: neuPoppins(
                              size: 13,
                              weight: FontWeight.w700,
                              color: _teacherGreen)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: neuBody(size: 14, weight: FontWeight.w700)),
                        Text(career,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: neuBody(size: 12, color: Neu.muted)),
                      ]),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, color: Neu.muted),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HistoryDetail extends StatelessWidget {
  const _HistoryDetail({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => NeuSunken(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _teacherGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: neuBody(
                color: Neu.text,
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _TeacherHomeDashboard extends ConsumerWidget {
  const _TeacherHomeDashboard({required this.onOpen, required this.name, super.key});
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
    final finishedCount =
        sessions.where((s) => s.state == 'FINALIZADA').length;
    final withStudentsCount =
        sessions.where((s) => s.students.isNotEmpty).length;

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
                  style: neuBody(color: Neu.muted, size: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hola, $name',
                  style: neuPoppins(
                    color: Neu.heading,
                    size: 24,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextSession == null
                      ? 'Aquí tienes un resumen de tus tutorías y actividades.'
                      : 'Tu próxima tutoría es ${nextSession.subject} · ${_dateTimeLabel(nextSession.start!)}',
                  style: neuBody(color: Neu.muted, size: 13),
                ),
                const SizedBox(height: 18),
                PaKpiRow([
                  ('${scheduled.length}', 'Programadas'),
                  ('$finishedCount', 'Finalizadas'),
                  ('$withStudentsCount', 'Con inscritos'),
                ]),
                const SizedBox(height: 6),
                _TeacherQuickLinks(onOpen: onOpen),
                const SizedBox(height: 18),
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
                else ...[
                  schedule,
                  const SizedBox(height: 18),
                  _TeacherCalendarPanel(
                    sessions: scheduled,
                    onOpenSessions: () => onOpen(1),
                  ),
                ],
              ],
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(
                  showCalendar ? 28 : 18, 20, showCalendar ? 28 : 18, 32),
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
    super.key,
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
              Expanded(
                child: Text(
                  'Tutorías programadas',
                  style: neuPoppins(
                    color: Neu.heading,
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onOpenSessions,
                child: Text(
                  'Ver todas',
                  style: neuBody(
                    color: _teacherGreen,
                    size: 13,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                  child: CircularProgressIndicator(color: _teacherGreen)),
            )
          else if (error)
            _TeacherEmptyCard(
              icon: Icons.cloud_off_outlined,
              message: 'No se pudieron cargar las tutorías.',
              action: NeuButton(
                'Reintentar',
                icon: Icons.refresh,
                kind: NeuButtonKind.alt,
                small: true,
                expand: false,
                onPressed: onRetry,
              ),
            )
          else if (sessions.isEmpty)
            const _TeacherEmptyCard(
              icon: Icons.event_available_outlined,
              message: 'No tienes tutorías programadas por ahora.',
            )
          else
            for (final session in sessions.take(6))
              _TeacherScheduleCard(
                session: session,
                onOpen: onOpenSessions,
                onStart: onStart,
              ),
        ],
      );
}

class _TeacherScheduleCard extends StatelessWidget {
  const _TeacherScheduleCard({
    required this.session,
    required this.onOpen,
    required this.onStart,
    super.key,
  });

  final _TeacherTutoringSession session;
  final VoidCallback onOpen;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final start = session.start;
    final isToday = start != null && _isSameDay(start, DateTime.now());
    final isActive = session.state == 'EN_CURSO';
    return PaCard(
      onTap: onOpen,
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
                  : Neu.muted.withValues(alpha: .4),
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
                  style: neuPoppins(
                    color: Neu.heading,
                    size: 15,
                    weight: FontWeight.w700,
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
                    PaTag(
                      isActive
                          ? 'En curso'
                          : isToday
                              ? 'Hoy'
                              : 'Programada',
                      tone: isActive
                          ? PaTone.ok
                          : isToday
                              ? PaTone.neutral
                              : PaTone.quiet,
                    ),
                    if (isToday || isActive)
                      NeuButton(
                        'Iniciar tutoría',
                        icon: Icons.play_arrow_rounded,
                        small: true,
                        expand: false,
                        onPressed: onStart,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherCalendarPanel extends StatelessWidget {
  const _TeacherCalendarPanel({
    required this.sessions,
    required this.onOpenSessions,
    super.key,
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
    return NeuSurface(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Calendario',
                    style: neuPoppins(
                        color: Neu.heading,
                        size: 16,
                        weight: FontWeight.w700)),
              ),
              Text('${monthNames[now.month - 1]} ${now.year}',
                  style: neuBody(color: Neu.muted, size: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final label in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(label,
                        style: neuBody(
                            color: Neu.muted,
                            size: 11,
                            weight: FontWeight.w700)),
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
          const Divider(height: 1, color: Neu.line),
          const SizedBox(height: 14),
          Text('Próximas tutorías',
              style: neuPoppins(
                  color: Neu.heading, size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (nextSessions.isEmpty)
            Text('No tienes próximas tutorías.',
                style: neuBody(color: Neu.muted, size: 12))
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
                        style: neuBody(
                            color: Neu.text,
                            size: 12,
                            weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onOpenSessions,
              child: Text(
                'Ver agenda',
                style: neuBody(
                  color: _teacherGreen,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
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
    super.key,
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
                      style: neuBody(
                        color: isToday ? Colors.white : Neu.text,
                        size: 11,
                        weight: isToday ? FontWeight.w800 : FontWeight.w500,
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
  const _TeacherQuickLinks({required this.onOpen, super.key});
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
              label: 'Rúbricas y reporte',
              icon: Icons.fact_check_outlined,
              onTap: () => paPush(context, const PaColectivasDocentePage())),
          _TeacherQuickLink(
              label: 'Líder PA',
              icon: Icons.star_outline_rounded,
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
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NeuButton(
        label,
        icon: icon,
        kind: NeuButtonKind.alt,
        small: true,
        expand: false,
        onPressed: onTap,
      );
}

class _TeacherInlineDetail extends StatelessWidget {
  const _TeacherInlineDetail({required this.icon, required this.text, super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _teacherGreen),
          const SizedBox(width: 5),
          Text(text,
              style: neuBody(
                  color: Neu.muted, size: 11.5)),
        ],
      );
}

class _TeacherEmptyCard extends StatelessWidget {
  const _TeacherEmptyCard({
    required this.icon,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PaCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            NeuIconBox(icon, color: _teacherGreen, size: 44, iconSize: 24),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: neuBody(color: Neu.muted, size: 13.5)),
            if (action != null) ...[
              const SizedBox(height: 10),
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
  const _DateChangeDialog({required this.start, required this.end, super.key});
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
        backgroundColor: Neu.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Solicitar cambio de fecha',
          style: neuPoppins(
              size: 18, weight: FontWeight.w700, color: Neu.heading),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La solicitud se enviará a coordinación para su aprobación.',
                style: neuBody(size: 13, color: Neu.muted),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: NeuButton(
                    _dateLabel(_date),
                    icon: Icons.calendar_month_outlined,
                    kind: NeuButtonKind.alt,
                    small: true,
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _date.isBefore(DateTime.now())
                            ? DateTime.now()
                            : _date,
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeuButton(
                    _time.format(context),
                    icon: Icons.schedule,
                    kind: NeuButtonKind.alt,
                    small: true,
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null) setState(() => _time = picked);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Text(
                'MOTIVO',
                style: neuBody(
                    size: 11, weight: FontWeight.w700, color: Neu.muted),
              ),
              const SizedBox(height: 6),
              NeuField(
                controller: _reason,
                hint: 'Explica el motivo del cambio...',
                minLines: 3,
                maxLines: 4,
                maxLength: 1000,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: neuBody(size: 12, color: Neu.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: neuBody(size: 14, color: Neu.muted)),
          ),
          NeuButton(
            'Enviar solicitud',
            small: true,
            expand: false,
            onPressed: () {
              final start = DateTime(_date.year, _date.month, _date.day,
                  _time.hour, _time.minute);
              if (!start.isAfter(DateTime.now())) {
                setState(
                    () => _error = 'Selecciona una fecha y hora futura.');
                return;
              }
              if (_reason.text.trim().isEmpty) {
                setState(
                    () => _error = 'Escribe el motivo de la solicitud.');
                return;
              }
              final duration = widget.end.difference(widget.start);
              Navigator.pop(
                context,
                _DateChangeDraft(
                  start,
                  start.add(duration),
                  _reason.text.trim(),
                ),
              );
            },
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
