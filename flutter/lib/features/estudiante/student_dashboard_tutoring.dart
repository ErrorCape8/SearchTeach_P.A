part of 'student_dashboard_views.dart';

class StudentTutoringView extends ConsumerStatefulWidget {
  const StudentTutoringView({
    required this.data,
    required this.focusSection,
    required this.focusRequest,
    required this.onEnroll,
    required this.onProjectEnrollment,
    required this.onJoinProjectCode,
    required this.onLeaveGroupSession,
    required this.onJoinPublishedSession,
    required this.onShowMessage,
    required this.onSectionChanged,
    super.key,
  });

  final StudentDashboardData data;
  final String? focusSection;
  final int focusRequest;
  final Future<void> Function(AvailableTutor tutor) onEnroll;
  final Future<void> Function(ClassroomProjectSpace space) onProjectEnrollment;
  final Future<void> Function() onJoinProjectCode;
  final Future<void> Function(StudentGroupSession session) onLeaveGroupSession;
  final Future<void> Function(StudentGroupSession session)
      onJoinPublishedSession;
  final void Function(String message) onShowMessage;
  final ValueChanged<String> onSectionChanged;

  @override
  ConsumerState<StudentTutoringView> createState() =>
      _StudentTutoringViewState();
}

class _StudentTutoringViewState extends ConsumerState<StudentTutoringView> {
  String? _section;
  String _query = '';
  int _semesterFilter = 0;
  final ScrollController _sessionsScrollController = ScrollController();
  Timer? _groupSessionRefreshTimer;

  @override
  void initState() {
    super.initState();
    _section = widget.focusSection;
    _syncGroupSessionRefresh();
  }

  @override
  void didUpdateWidget(covariant StudentTutoringView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusRequest != oldWidget.focusRequest) {
      _section = widget.focusSection;
      _syncGroupSessionRefresh();
    }
  }

  void _syncGroupSessionRefresh() {
    _groupSessionRefreshTimer?.cancel();
    if (_section != 'chats-videoconferencias') return;
    _groupSessionRefreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (mounted && _section == 'chats-videoconferencias') {
          ref.invalidate(studentGroupSessionsProvider);
        }
      },
    );
  }

  @override
  void dispose() {
    _groupSessionRefreshTimer?.cancel();
    _sessionsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_section == null) return _menu();
    return _sectionContent();
  }

  void _goToSection(String section) {
    setState(() => _section = section);
    _syncGroupSessionRefresh();
    widget.onSectionChanged(section);
  }

  void _openEnrolledSessions() {
    setState(() => _section = 'sesiones');
    _syncGroupSessionRefresh();
    widget.onSectionChanged('sesiones');
  }

  Future<void> _showRatingAfterCall(StudentGroupSession session) =>
      showStudentTutoringRatingIfNeeded(
        context,
        ref,
        sessionId: session.id,
        studentId: widget.data.profile.id,
        subject: session.subject,
      );

  Widget _menu() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _MenuTile(
            icon: Icons.calendar_month_outlined,
            title: 'Mis sesiones',
            subtitle: 'Las sesiones en las que estás inscrito.',
            onTap: _openEnrolledSessions,
          ),
          _MenuTile(
            icon: Icons.event_available_outlined,
            title: 'Inscribirse a tutorías retroalimentativas',
            subtitle: 'Consulta y reserva sesiones grupales publicadas.',
            onTap: () => _goToSection('publicadas'),
          ),
          _MenuTile(
            icon: Icons.groups_outlined,
            title: 'Proyecto de aula',
            subtitle: 'Crea tu proyecto o únete con un código.',
            onTap: () => _goToSection('proyectos'),
          ),
          _MenuTile(
            icon: Icons.assignment_outlined,
            title: 'Seguimiento de mi proyecto',
            subtitle:
                'Consulta los reportes del tutor, el horario y las respuestas.',
            onTap: () => _goToSection('seguimiento-proyecto'),
          ),
          _MenuTile(
            icon: Icons.folder_shared_outlined,
            title: 'Historial de proyectos de aula',
            subtitle: 'Consulta tus proyectos finalizados.',
            onTap: () => _goToSection('proyectos-historial'),
          ),
        ],
      );

  Widget _sectionContent() {
    switch (_section) {
      case 'menu':
        return _menu();
      case 'publicadas':
        return _publishedGroupSessions();
      case 'proyectos':
        return _projectSpaces();
      case 'seguimiento-proyecto':
        return _projectFollowup();
      case 'proyectos-historial':
        return _projectHistory();
      case 'calificar':
        return _ratingList();
      case 'sesiones':
        return _sessionsList();
      case 'chats-videoconferencias':
        return _groupChatsAndCalls();
      case 'historial':
        return _history();
      default:
        return _menu();
    }
  }

  Widget _projectFollowup() => ref.watch(studentProjectFollowupProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 36, color: Neu.error),
                const SizedBox(height: 10),
                Text(
                  'No se pudo cargar el seguimiento de tu proyecto',
                  style: neuPoppins(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: neuBody(size: 13, color: Neu.muted),
                ),
                const SizedBox(height: 14),
                NeuButton(
                  'Reintentar',
                  small: true,
                  expand: false,
                  onPressed: () =>
                      ref.invalidate(studentProjectFollowupProvider),
                ),
              ],
            ),
          ),
        ),
        data: (projects) {
          final activeProjects = projects
              .where((item) =>
                  item.tutoringState != 'DISUELTA' &&
                  item.status != 'FINALIZADO')
              .toList();
          return activeProjects.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                  children: const [
                    _EmptyCard(
                      icon: Icons.assignment_outlined,
                      title: 'Aún no tienes un proyecto inscrito',
                      message:
                          'Cuando te inscribas, aquí verás el horario y los reportes de tu tutor.',
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                  children: [
                    for (final item in activeProjects)
                      PaCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.project.name,
                                        style: neuPoppins(
                                          size: 17,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.project.career} · Semestre ${item.project.semester}',
                                        style: neuBody(
                                            size: 12.5, color: Neu.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                NeuSunken(
                                  radius: 12,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'ESTADO',
                                        style: neuBody(
                                          size: 9,
                                          weight: FontWeight.w700,
                                          color: Neu.muted,
                                        ),
                                      ),
                                      Text(
                                        item.status == 'PENDIENTE_CONFIRMACION'
                                            ? 'Pendiente cierre'
                                            : 'En curso',
                                        style: neuBody(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: _blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            PaInfo(
                              'Docente asignado: ${item.assignedTeacher.isNotEmpty ? item.assignedTeacher : item.project.teacherId}',
                              icon: Icons.person_outline_rounded,
                            ),
                            if (item.project.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.project.description,
                                style: neuBody(size: 13, color: Neu.muted),
                              ),
                            ],
                            if (item.project.studentIds.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.group_outlined,
                                      size: 16, color: Neu.muted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Integrantes (${item.project.studentIds.length}/4): ${item.project.studentIds.join(', ')}',
                                      style:
                                          neuBody(size: 12, color: Neu.muted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (item.invitationCode.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SelectableText(
                                'Código de invitación: ${item.invitationCode}',
                                style: neuBody(
                                  size: 12.5,
                                  weight: FontWeight.w700,
                                  color: _blue,
                                ),
                              ),
                            ],
                            if (item.meetingAt != null) ...[
                              const SizedBox(height: 14),
                              NeuSunken(
                                radius: 14,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.videocam_rounded,
                                            size: 18, color: _blue),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Reunión programada con el tutor',
                                          style: neuBody(
                                            size: 13.5,
                                            weight: FontWeight.w700,
                                            color: _blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_longDate(item.meetingAt!.toLocal())} · ${TimeOfDay.fromDateTime(item.meetingAt!.toLocal()).format(context)}',
                                      style: neuBody(size: 12.5),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            NeuButton(
                              'Abrir chat del proyecto',
                              icon: Icons.chat_bubble_outline_rounded,
                              small: true,
                              expand: false,
                              onPressed: () {
                                final sessionId =
                                    item.meetingSessionId.isNotEmpty
                                        ? item.meetingSessionId
                                        : item.sessions.isNotEmpty
                                            ? item.sessions.first.id
                                            : null;
                                if (sessionId == null) {
                                  widget.onShowMessage(
                                    'El chat estará disponible cuando el tutor registre una sesión.',
                                  );
                                  return;
                                }
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ProyectoAulaChatPage(
                                    tutoringId: item.tutoringId,
                                    projectId: item.project.projectId,
                                    sessionId: sessionId,
                                    title: item.project.name,
                                    teacherMode: false,
                                  ),
                                ));
                              },
                            ),
                            if (item.closureReport.isNotEmpty ||
                                item.closureReason.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              NeuSunken(
                                radius: 14,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reporte de evaluación del tutor',
                                      style: neuBody(
                                          size: 13, weight: FontWeight.w700),
                                    ),
                                    if (item.closureReason.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Estado: ${item.closureReason}',
                                        style:
                                            neuBody(size: 12, color: Neu.muted),
                                      ),
                                    ],
                                    if (item.closureReport.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        item.closureReport,
                                        style: neuBody(size: 12.5),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            const PaSection('Horario e historial de sesiones'),
                            if (item.nextSession != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: PaInfo(
                                  'Próxima sesión: ${_longDate(item.nextSession!.start!.toLocal())} · '
                                  '${TimeOfDay.fromDateTime(item.nextSession!.start!.toLocal()).format(context)} – '
                                  '${TimeOfDay.fromDateTime(item.nextSession!.end!.toLocal()).format(context)}',
                                  icon: Icons.event_available_rounded,
                                  tone: PaTone.ok,
                                ),
                              ),
                            if (item.sessions.isEmpty)
                              const PaEmpty(
                                  'El tutor aún no ha registrado sesiones ni horarios.')
                            else
                              PaRowList([
                                for (final session in item.sessions)
                                  PaRow(
                                    icon: Icons.event_note_rounded,
                                    title: session.start == null
                                        ? 'Fecha pendiente'
                                        : _longDate(session.start!.toLocal()),
                                    subtitle:
                                        '${session.start == null ? '' : TimeOfDay.fromDateTime(session.start!.toLocal()).format(context)} – '
                                        '${session.end == null ? '' : TimeOfDay.fromDateTime(session.end!.toLocal()).format(context)}\n'
                                        '${session.notes.isEmpty ? 'Sin notas del tutor' : session.notes}',
                                    trailing: const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 20,
                                        color: _blue),
                                    onTap: () async {
                                      await Navigator.of(context)
                                          .push(MaterialPageRoute(
                                        builder: (_) => ProyectoAulaChatPage(
                                          tutoringId: item.tutoringId,
                                          projectId: item.project.projectId,
                                          sessionId: session.id,
                                          title: item.project.name,
                                          teacherMode: false,
                                        ),
                                      ));
                                      if (mounted) {
                                        ref.invalidate(
                                            studentProjectFollowupProvider);
                                      }
                                    },
                                  ),
                              ]),
                            if (item.status == 'EN_CURSO' &&
                                item.tutoringState == 'ACTIVA') ...[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _leaveClassroomProject(item),
                                  icon: const Icon(Icons.exit_to_app,
                                      color: Neu.error),
                                  label: Text(
                                    'Desistir del proyecto',
                                    style: neuBody(size: 13, color: Neu.error),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
        },
      );

  Future<void> _leaveClassroomProject(StudentProjectFollowup project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desistir del proyecto'),
        content: Text(
            '¿Quieres salir de “${project.project.name}”? Perderás acceso a su seguimiento y chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await leaveClassroomProject(
        dio: ref.read(dioProvider),
        tutoringId: project.tutoringId,
        projectId: project.project.projectId,
      );
      ref.invalidate(studentProjectFollowupProvider);
      ref.invalidate(studentDashboardProvider);
      widget.onShowMessage('Saliste del proyecto de aula.');
    } on DioException catch (error) {
      final response = error.response?.data;
      final message = response is Map && response['message'] is String
          ? response['message'] as String
          : 'No se pudo desistir del proyecto.';
      widget.onShowMessage(message);
    }
  }

  Widget _projectHistory() => ref.watch(studentProjectFollowupProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudieron cargar tus proyectos de aula: $error'),
          ),
        ),
        data: (projects) {
          final visibleProjects = projects
              .where((item) =>
                  item.tutoringState != 'DISUELTA' &&
                  item.status == 'FINALIZADO')
              .toList();
          if (visibleProjects.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
              children: const [
                _EmptyCard(
                  icon: Icons.folder_off_outlined,
                  title: 'No tienes proyectos finalizados',
                  message: 'Tus proyectos cerrados aparecerán aquí.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            children: [
              for (final item in visibleProjects)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      item.status == 'FINALIZADO'
                          ? Icons.check_circle_outline
                          : Icons.folder_outlined,
                      color:
                          item.status == 'FINALIZADO' ? Colors.blueGrey : _blue,
                    ),
                    title: Text(item.project.name),
                    subtitle: Text(
                      '${item.project.career} · Semestre ${item.project.semester}\n'
                      '${item.status == 'FINALIZADO' ? 'Finalizado' : 'En curso'}',
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          );
        },
      );

  Widget _history() {
    final completedGroups = widget.data.groupSessions
        .where((session) => session.state == 'FINALIZADA')
        .toList()
      ..sort(
          (a, b) => (b.start ?? DateTime(0)).compareTo(a.start ?? DateTime(0)));
    return ref.watch(studentProjectFollowupProvider).when(
          loading: () => ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              _PageHeading(
                title: 'Historial de tutorías',
                subtitle: 'Consulta tus sesiones y proyectos finalizados.',
              ),
              SizedBox(height: 32),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => _historyContent(
            completedGroups,
            const [],
          ),
          data: (projects) => _historyContent(
            completedGroups,
            projects
                .where((item) =>
                    item.tutoringState != 'DISUELTA' &&
                    item.status == 'FINALIZADO')
                .toList(),
          ),
        );
  }

  Widget _historyContent(
    List<StudentGroupSession> completedGroups,
    List<StudentProjectFollowup> completedProjects,
  ) {
    if (completedGroups.isEmpty && completedProjects.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _PageHeading(
            title: 'Historial de tutorías',
            subtitle: 'Consulta tus sesiones y proyectos finalizados.',
          ),
          SizedBox(height: 18),
          _EmptyCard(
            icon: Icons.history,
            title: 'Tu historial está vacío',
            message: 'Las tutorías y proyectos finalizados aparecerán aquí.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      children: [
        const _PageHeading(
          title: 'Historial de tutorías',
          subtitle: 'Consulta tus sesiones y proyectos finalizados.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 150,
              child: _HistoryMetricCard(
                value: '${completedGroups.length}',
                label: 'Realizadas',
              ),
            ),
            SizedBox(
              width: 150,
              child: _HistoryMetricCard(
                value: '${completedProjects.length}',
                label: 'Proyectos',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (completedGroups.isNotEmpty) ...[
          const Text(
            'Tutorías grupales realizadas',
            style: TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...completedGroups.map((session) => _GroupHistoryCard(
                session: session,
                onRated: () => ref.invalidate(studentGroupSessionsProvider),
                showRating: false,
              )),
        ],
        if (completedProjects.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Proyectos finalizados',
            style: TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...completedProjects.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: _line),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE7F1FC),
                  child: Icon(Icons.check_circle_outline, color: _blue),
                ),
                title: Text(
                  item.project.name,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${item.project.career} · Semestre ${item.project.semester}\nProyecto de aula finalizado',
                ),
                isThreeLine: true,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _ratingList() {
    final completed = widget.data.groupSessions
        .where((session) => session.state == 'FINALIZADA')
        .toList();
    if (completed.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: const [
          _EmptyCard(
            icon: Icons.star_border,
            title: 'No hay tutorías para calificar',
            message: 'La opción aparecerá cuando una tutoría haya terminado.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [
        ...completed.map((session) => _GroupHistoryCard(
              session: session,
              onRated: () => ref.invalidate(studentGroupSessionsProvider),
            )),
      ],
    );
  }

  Widget _availableTutors() {
    final career = widget.data.profile.career.trim().toLowerCase();
    final semester = widget.data.profile.semester;
    final filtered = widget.data.tutors.where((tutor) {
      final matchesQuery =
          '${tutor.name} ${tutor.teacherId} ${tutor.subjects.map((subject) => subject.name).join(' ')}'
              .toLowerCase()
              .contains(_query.trim().toLowerCase());
      final matchesCareer = career.isEmpty ||
          tutor.career.trim().toLowerCase() == career ||
          tutor.careers.any((item) => item.trim().toLowerCase() == career);
      final matchesSemester =
          _semesterFilter == 0 || tutor.semester == _semesterFilter;
      return matchesQuery && matchesCareer && matchesSemester;
    }).toList();
    final semesters = widget.data.tutors
        .map((item) => item.semester)
        .toSet()
        .toList()
      ..sort();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Buscar tutor por nombre',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFEDF1F6),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
              );
              final semesterPicker = DropdownButtonFormField<int>(
                initialValue: _semesterFilter,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFEDF1F6),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: _navy, fontSize: 10),
                items: [
                  const DropdownMenuItem(
                      value: 0, child: Text('Semestre: todos')),
                  for (final item in semesters)
                    if (item > 0)
                      DropdownMenuItem(
                        value: item,
                        child: Text('Semestre: $item'),
                      ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _semesterFilter = value);
                },
              );
              return constraints.maxWidth < 430
                  ? Column(
                      children: [
                        search,
                        const SizedBox(height: 8),
                        semesterPicker,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 3, child: search),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: semesterPicker),
                      ],
                    );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              if (filtered.isEmpty)
                _EmptyCard(
                  icon: Icons.search_off,
                  title: semester <= 0 && _semesterFilter == 0
                      ? 'Registra tu semestre para ver tutores'
                      : 'No encontramos tutores disponibles',
                  message: semester <= 0 && _semesterFilter == 0
                      ? 'Ve a tu perfil para registrar el semestre actual.'
                      : 'No hay tutores con horarios para los filtros seleccionados.',
                )
              else
                ...filtered.map((tutor) => _TutorCard(
                      tutor: tutor,
                      onEnroll: () => widget.onEnroll(tutor),
                    )),
              if (filtered.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Dato: Cada sesión grupal dura 1 hora y tiene un cupo máximo de 5 estudiantes.',
                    style: TextStyle(color: _blue, fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _projectSpaces() {
    final career = widget.data.profile.career.trim();
    final enrolledProjects = widget.data.projectSpaces
        .where((space) => !space.createProjectSlot && space.enrolled);
    final spaces = widget.data.projectSpaces
        .where((space) =>
            space.createProjectSlot &&
            (career.isEmpty || space.career == career))
        .where((_) => enrolledProjects.isEmpty)
        .toList()
      ..sort((a, b) => a.semester.compareTo(b.semester));

    if (spaces.isEmpty) {
      final alreadyEnrolled = enrolledProjects.isNotEmpty;
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        children: [
          if (!alreadyEnrolled) ...[
            _projectCodeButton(),
            const SizedBox(height: 12),
          ],
          _EmptyCard(
            icon: Icons.groups_outlined,
            title: alreadyEnrolled
                ? 'Ya tienes un proyecto inscrito'
                : 'No hay espacios disponibles para inscripción',
            message: alreadyEnrolled
                ? 'Consulta el estado de tu equipo en Seguimiento de proyecto.'
                : 'Cuando coordinación habilite un espacio para tu tecnología, aparecerá aquí.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      itemCount: spaces.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) return _projectCodeButton();
        final space = spaces[index - 1];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Semestre ${space.semester}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Espacio disponible para proyecto de aula'),
                Text(space.career, style: const TextStyle(color: _muted)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () => widget.onProjectEnrollment(space),
                    child: const Text('Inscribir PA'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _projectCodeButton() => OutlinedButton.icon(
        onPressed: widget.onJoinProjectCode,
        icon: const Icon(Icons.vpn_key_outlined),
        label: const Text('Unirme a un proyecto con código'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: _blue,
          side: const BorderSide(color: _blue),
        ),
      );

  Widget _sessionsList() {
    final activeGroupSessions = widget.data.groupSessions
        .where((session) =>
            session.state == 'PROGRAMADA' || session.state == 'EN_CURSO')
        .toList();
    final agenda = <({DateTime? start, Widget card})>[
      for (final session in activeGroupSessions)
        (
          start: session.start?.toLocal(),
          card: _GroupSessionCard(
            session: session,
            studentName: widget.data.profile.name,
            teacherName: widget.data.tutors
                    .where((tutor) => tutor.teacherId == session.teacherId)
                    .map((tutor) => tutor.name)
                    .firstOrNull ??
                session.teacherId,
            onCallEnded: () => _showRatingAfterCall(session),
            onLeave: () => widget.onLeaveGroupSession(session),
          ),
        ),
    ]..sort((a, b) =>
        (a.start ?? DateTime(9999)).compareTo(b.start ?? DateTime(9999)));
    final content = agenda.isEmpty
        ? ListView(
            controller: _sessionsScrollController,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            children: const [
              _EmptyCard(
                icon: Icons.event_note_outlined,
                title: 'No tienes sesiones próximas',
                message:
                    'Tus tutorías grupales confirmadas aparecerán aquí. Podrás entrar cuando el docente inicie la clase.',
              ),
            ],
          )
        : ListView(
            controller: _sessionsScrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              const Text(
                'Aquí ves cuándo y dónde te toca cada sesión.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              ..._agendaSections(agenda),
            ],
          );
    return Column(
      children: [
        Expanded(child: content),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Text(
            'Dato: Cada sesión grupal dura 1 hora y tiene un cupo máximo de 5 estudiantes.',
            style: TextStyle(color: _blue, fontSize: 9),
          ),
        ),
      ],
    );
  }

  List<Widget> _agendaSections(
    List<({DateTime? start, Widget card})> agenda,
  ) {
    final children = <Widget>[];
    final today = DateTime.now();
    final currentWeek = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    var index = 0;
    while (index < agenda.length && agenda[index].start != null) {
      final start = agenda[index].start!;
      final weekStart = DateTime(start.year, start.month, start.day)
          .subtract(Duration(days: start.weekday - 1));
      var weekEnd = index + 1;
      while (weekEnd < agenda.length && agenda[weekEnd].start != null) {
        final next = agenda[weekEnd].start!;
        final nextWeek = DateTime(next.year, next.month, next.day)
            .subtract(Duration(days: next.weekday - 1));
        if (nextWeek != weekStart) break;
        weekEnd++;
      }

      final weekLabel = weekStart == currentWeek
          ? 'Esta semana'
          : weekStart == currentWeek.add(const Duration(days: 7))
              ? 'Próxima semana'
              : 'Semana del ${weekStart.day.toString().padLeft(2, '0')}/${weekStart.month.toString().padLeft(2, '0')}';
      children.add(_AgendaWeekHeading(
        label: weekLabel,
        count: weekEnd - index,
      ));

      while (index < weekEnd) {
        final day = agenda[index].start!;
        final dayStart = DateTime(day.year, day.month, day.day);
        children.add(_AgendaDayHeading(date: dayStart));
        while (index < weekEnd) {
          final itemStart = agenda[index].start!;
          if (itemStart.year != dayStart.year ||
              itemStart.month != dayStart.month ||
              itemStart.day != dayStart.day) {
            break;
          }
          children
            ..add(agenda[index].card)
            ..add(const SizedBox(height: 8));
          index++;
        }
      }
    }

    if (index < agenda.length) {
      children.add(_AgendaWeekHeading(
        label: 'Horario por confirmar',
        count: agenda.length - index,
      ));
      for (; index < agenda.length; index++) {
        children
          ..add(agenda[index].card)
          ..add(const SizedBox(height: 8));
      }
    }
    return children;
  }

  Widget _groupChatsAndCalls() {
    final now = DateTime.now();
    final groupSessions = widget.data.groupSessions
        .where((session) =>
            session.state != 'FINALIZADA' && _isToday(session.start, now))
        .toList()
      ..sort((a, b) =>
          (a.start ?? DateTime(9999)).compareTo(b.start ?? DateTime(9999)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        ...[
          if (groupSessions.isEmpty)
            PaCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const NeuIconBox(Icons.videocam_outlined,
                      color: _blue, size: 48, iconSize: 26),
                  const SizedBox(height: 12),
                  Text(
                    'No tienes clases activas hoy',
                    style: neuPoppins(
                        size: 16, weight: FontWeight.w700, color: Neu.heading),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Las tutorías grupales programadas para hoy aparecerán aquí.',
                    textAlign: TextAlign.center,
                    style: neuBody(size: 13, color: Neu.muted),
                  ),
                ],
              ),
            )
          else ...[
            for (final session in groupSessions)
              _GroupChatAndCallCard(
                session: session,
                studentName: widget.data.profile.name,
                onCallEnded: () => _showRatingAfterCall(session),
              ),
          ],
        ],
      ],
    );
  }

  Widget _publishedSessionCard(StudentGroupSession session) {
    AvailableTutor? teacher;
    for (final item in widget.data.tutors) {
      if (item.teacherId == session.teacherId) teacher = item;
    }
    final start = session.start?.toLocal();
    final end = session.end?.toLocal();
    final now = DateTime.now();
    final enrolledGroups = widget.data.groupSessions
        .where((item) => item.end?.isAfter(now) ?? false)
        .toList();
    final maximumReached = enrolledGroups.length >= 3;
    final overlapsGroup = start != null &&
        end != null &&
        enrolledGroups.any((item) =>
            item.start != null &&
            item.end != null &&
            start.isBefore(item.end!) &&
            item.start!.isBefore(end));
    final hasScheduleConflict = overlapsGroup;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.subject,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
                '${teacher?.name ?? 'Docente'} · ${session.technology} · Semestre ${session.semester}'),
            if (session.modality.isNotEmpty)
              Text(
                '${_groupSessionModality(session.modality)}${session.modality.toUpperCase() == 'VIRTUAL' || session.location.trim().isEmpty ? '' : ' · ${session.location}'}',
              ),
            if (start != null && end != null)
              Text(
                  '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} · '
                  '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}–'
                  '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'),
            const SizedBox(height: 8),
            Text('${5 - session.studentCount} cupos disponibles',
                style: const TextStyle(color: _muted)),
            if (maximumReached || hasScheduleConflict)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  maximumReached
                      ? 'Ya tienes tres tutorías inscritas.'
                      : 'Esta sesión se cruza con otra tutoría tuya.',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: maximumReached ||
                        hasScheduleConflict ||
                        start == null ||
                        end == null
                    ? null
                    : () => widget.onJoinPublishedSession(session),
                child: Text(maximumReached
                    ? 'Límite alcanzado'
                    : hasScheduleConflict
                        ? 'Cruce de horario'
                        : 'Reservar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _publishedGroupSessions({ScrollController? scrollController}) {
    final now = DateTime.now();
    final sessions = widget.data.availableGroupSessions.where((session) {
      return _isToday(session.start, now);
    }).toList()
      ..sort((first, second) =>
          (first.start ?? DateTime(0)).compareTo(second.start ?? DateTime(0)));
    if (sessions.isEmpty) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        children: const [
          _EmptyCard(
            icon: Icons.event_busy_outlined,
            title: 'No hay clases disponibles para hoy',
            message:
                'Aquí aparecerán las tutorías programadas para el día de hoy.',
          ),
        ],
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = sessions[index];
        AvailableTutor? teacher;
        for (final item in widget.data.tutors) {
          if (item.teacherId == session.teacherId) teacher = item;
        }
        final start = session.start?.toLocal();
        final end = session.end?.toLocal();
        final now = DateTime.now();
        final enrolledGroups = widget.data.groupSessions
            .where((item) => item.end?.isAfter(now) ?? false)
            .toList();
        final maximumReached = enrolledGroups.length >= 3;
        final overlapsGroup = start != null &&
            end != null &&
            enrolledGroups.any((item) =>
                item.start != null &&
                item.end != null &&
                start.isBefore(item.end!) &&
                item.start!.isBefore(end));
        final hasScheduleConflict = overlapsGroup;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.subject,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                    '${teacher?.name ?? 'Docente'} · ${session.technology} · Semestre ${session.semester}'),
                if (session.modality.isNotEmpty)
                  Text(
                    '${_groupSessionModality(session.modality)}${session.modality.toUpperCase() == 'VIRTUAL' || session.location.trim().isEmpty ? '' : ' · ${session.location}'}',
                  ),
                if (start != null && end != null)
                  Text(
                      '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} · '
                      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}–'
                      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'),
                const SizedBox(height: 8),
                Text('${5 - session.studentCount} cupos disponibles',
                    style: const TextStyle(color: _muted)),
                if (maximumReached || hasScheduleConflict)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      maximumReached
                          ? 'Ya tienes tres tutorías inscritas.'
                          : 'Esta sesión se cruza con otra tutoría tuya.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: maximumReached ||
                            hasScheduleConflict ||
                            start == null ||
                            end == null
                        ? null
                        : () => widget.onJoinPublishedSession(session),
                    child: Text(maximumReached
                        ? 'Límite alcanzado'
                        : hasScheduleConflict
                            ? 'Cruce de horario'
                            : 'Reservar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _groupSessionModality(String value) => switch (value.toUpperCase()) {
        'PRESENCIAL' => 'Presencial',
        'HIBRIDA' => 'Híbrida',
        'VIRTUAL' => 'Virtual',
        _ => value,
      };
}

class _HistoryMetricCard extends StatelessWidget {
  const _HistoryMetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0D4FC4),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _GroupChatAndCallCard extends StatelessWidget {
  const _GroupChatAndCallCard({
    required this.session,
    required this.studentName,
    required this.onCallEnded,
  });

  final StudentGroupSession session;
  final String studentName;
  final Future<void> Function() onCallEnded;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = session.start?.toLocal();
    final end = session.end?.toLocal();
    final isToday = start != null &&
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final canEnterRoomOrWaiting = isToday &&
        session.state != 'FINALIZADA' &&
        (end == null || end.isAfter(now));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.subject,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 5),
          Text('Docente ${session.teacherId} · Semestre ${session.semester}'),
          if (start != null) Text(_longDate(start)),
          Text('Modalidad: ${_groupSessionModalityLabel(session.modality)}'),
          if (session.modality.toUpperCase() != 'VIRTUAL' &&
              session.location.trim().isNotEmpty)
            Text('Lugar: ${session.location}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (session.modality.toUpperCase() != 'PRESENCIAL')
              FilledButton.icon(
                onPressed: canEnterRoomOrWaiting
                    ? () async {
                        final result = await Navigator.of(context)
                            .push<String>(MaterialPageRoute(
                          builder: (_) => LiveKitRoomPage(
                            sessionId: session.id,
                            subject: session.subject,
                            modality: session.modality,
                            teacherMode: false,
                            students: session.studentIds,
                            endAt: session.end?.toLocal(),
                            studentMode: true,
                            studentName: studentName,
                          ),
                        ));
                        if (result == 'ended') await onCallEnded();
                      }
                    : null,
                icon: const Icon(Icons.video_call_outlined),
                label: Text(
                  session.state == 'EN_CURSO' && canEnterRoomOrWaiting
                      ? 'Entrar a la sala'
                      : !isToday
                          ? start != null && start.isBefore(now)
                              ? 'Sesión no disponible hoy'
                              : 'Disponible el ${_longDate(start!)}'
                          : session.state == 'FINALIZADA' ||
                                  (end != null && !end.isAfter(now))
                              ? 'Sesión finalizada'
                              : 'Entrar a sala de espera',
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

String _formatHour(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _groupSessionModalityLabel(String value) =>
    switch (value.toUpperCase()) {
      'PRESENCIAL' => 'Presencial',
      'HIBRIDA' => 'Híbrida',
      'VIRTUAL' => 'Virtual',
      _ => value.isEmpty ? 'Por confirmar' : value,
    };

bool _isToday(DateTime? date, DateTime now) {
  final local = date?.toLocal();
  return local != null &&
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: primary ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A17324F),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: primary
                          ? Colors.white.withValues(alpha: .18)
                          : const Color(0xFFE7F1FC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      icon,
                      color: primary ? Colors.white : _blue,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: primary ? Colors.white : _navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: primary
                                ? Colors.white.withValues(alpha: .88)
                                : const Color(0xFF647895),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: primary ? Colors.white : const Color(0xFFB3BAC7),
                    size: 27,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
