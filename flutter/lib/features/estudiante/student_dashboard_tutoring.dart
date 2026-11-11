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
    required this.onAction,
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
  final Future<void> Function(StudentTutoring tutoring, String action) onAction;
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
  String _sessionFilter = 'disponibles';
  final ScrollController _sessionsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _section = widget.focusSection;
  }

  @override
  void didUpdateWidget(covariant StudentTutoringView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusRequest != oldWidget.focusRequest) {
      _section = widget.focusSection;
    }
  }

  @override
  void dispose() {
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
    widget.onSectionChanged(section);
  }

  Widget _menu() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _PageHeading(
            title: 'Tutorías',
            subtitle: 'Encuentra apoyo académico y revisa tus sesiones.',
          ),
          const SizedBox(height: 20),
          _MenuTile(
            icon: Icons.event_available_outlined,
            title: 'Tutores con horario disponible',
            subtitle: 'Consulta los horarios disponibles para tu carrera.',
            onTap: () => _goToSection('tutores'),
          ),
          _MenuTile(
            icon: Icons.groups_outlined,
            title: 'Asignación de proyecto de aula',
            subtitle: 'Inscríbete en un espacio disponible para tu tecnología.',
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
            title: 'Proyectos de aula',
            subtitle: 'Consulta tus proyectos activos y finalizados.',
            onTap: () => _goToSection('proyectos-historial'),
          ),
          _MenuTile(
            icon: Icons.video_call_outlined,
            title: 'Unirse a videoconferencias',
            subtitle:
                'Entra al chat y a la sala de las tutorias en las que estas inscrita.',
            onTap: () => _goToSection('chats-videoconferencias'),
          ),
          _MenuTile(
            icon: Icons.event_note_outlined,
            title: 'Mis sesiones',
            subtitle: 'Consulta las tutorías programadas y en curso.',
            onTap: () => _goToSection('sesiones'),
          ),
          _MenuTile(
            icon: Icons.history,
            title: 'Historial',
            subtitle: 'Revisa tutorías realizadas o canceladas.',
            onTap: () => _goToSection('historial'),
          ),
          _MenuTile(
            icon: Icons.star_outline,
            title: 'Calificar tutorías',
            subtitle: 'Valora una tutoría solamente después de finalizarla.',
            onTap: () => _goToSection('calificar'),
          ),
        ],
      );

  Widget _sectionContent() {
    switch (_section) {
      case 'menu':
        return _menu();
      case 'publicadas':
        return _publishedGroupSessions();
      case 'tutores':
        return _availableTutors();
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
        return _tutoringList(
          widget.data.tutorings
              .where((t) => t.status == 'REALIZADA' || t.status == 'CANCELADA'),
          emptyTitle: 'Tu historial está vacío',
          emptyMessage: 'Las tutorías finalizadas aparecerán aquí.',
        );
    }
  }

  Widget _projectFollowup() => ref.watch(studentProjectFollowupProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Text('No se pudo cargar el seguimiento de tu proyecto: $error'),
        )),
        data: (projects) {
          final activeProjects = projects
              .where((item) => item.tutoringState != 'DISUELTA')
              .toList();
          return activeProjects.isEmpty
              ? const _EmptyCard(
                  icon: Icons.assignment_outlined,
                  title: 'Aún no tienes un proyecto inscrito',
                  message:
                      'Cuando te inscribas, aquí verás el horario y los reportes de tu tutor.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                  children: [
                    for (final item in activeProjects)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.project.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _navy)),
                                Text(
                                    '${item.project.career} · Semestre ${item.project.semester} · Tutor ${item.project.teacherId}'),
                                if (item.project.description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      item.project.description,
                                      style: const TextStyle(color: _muted),
                                    ),
                                  ),
                                if (item.invitationCode.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SelectableText(
                                      'Código para integrantes: ${item.invitationCode}',
                                      style: const TextStyle(
                                        color: _blue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                Text(item.status == 'FINALIZADO'
                                    ? 'Proyecto finalizado por el docente líder.'
                                    : item.status == 'PENDIENTE_CONFIRMACION'
                                        ? 'El cierre del proyecto está pendiente de revisión del docente líder.'
                                        : 'Proyecto en curso.'),
                                if (item.meetingAt != null)
                                  Text(
                                    'Reunión de PA: ${_longDate(item.meetingAt!.toLocal())} · ${TimeOfDay.fromDateTime(item.meetingAt!.toLocal()).format(context)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                const SizedBox(height: 12),
                                const Text('Horario e historial de sesiones',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                if (item.nextSession != null)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.event_available,
                                        color: _blue),
                                    title: const Text('Próxima sesión',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                        '${_longDate(item.nextSession!.start!.toLocal())} · ${TimeOfDay.fromDateTime(item.nextSession!.start!.toLocal()).format(context)} – ${TimeOfDay.fromDateTime(item.nextSession!.end!.toLocal()).format(context)}'),
                                  ),
                                if (item.sessions.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                        'El tutor aún no ha registrado un horario.'),
                                  ),
                                for (final session in item.sessions)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading:
                                        const Icon(Icons.event_note_outlined),
                                    title: Text(session.start == null
                                        ? 'Fecha pendiente'
                                        : _longDate(session.start!.toLocal())),
                                    subtitle: Text(
                                        '${session.start == null ? '' : TimeOfDay.fromDateTime(session.start!.toLocal()).format(context)} – ${session.end == null ? '' : TimeOfDay.fromDateTime(session.end!.toLocal()).format(context)}\n${session.notes}',
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis),
                                    isThreeLine: true,
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
                                if (item.status == 'EN_CURSO' &&
                                    item.tutoringState == 'ACTIVA')
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _leaveClassroomProject(item),
                                      icon: const Icon(Icons.exit_to_app),
                                      label:
                                          const Text('Desistir del proyecto'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                              ]),
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
              .where((item) => item.tutoringState != 'DISUELTA')
              .toList();
          if (visibleProjects.isEmpty) {
            return const _EmptyCard(
              icon: Icons.folder_off_outlined,
              title: 'No tienes proyectos de aula',
              message: 'Cuando te inscribas en un proyecto aparecerá aquí.',
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
    final individualHistory = widget.data.tutorings
        .where((t) => t.status == 'REALIZADA' || t.status == 'CANCELADA')
        .toList();
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
            individualHistory,
            const [],
          ),
          data: (projects) => _historyContent(
            completedGroups,
            individualHistory,
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
    List<StudentTutoring> individualHistory,
    List<StudentProjectFollowup> completedProjects,
  ) {
    if (completedGroups.isEmpty &&
        individualHistory.isEmpty &&
        completedProjects.isEmpty) {
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
                value:
                    '${completedGroups.length + individualHistory.where((item) => item.status == 'REALIZADA').length}',
                label: 'Realizadas',
              ),
            ),
            SizedBox(
              width: 150,
              child: _HistoryMetricCard(
                value:
                    '${individualHistory.where((item) => item.status == 'CANCELADA').length}',
                label: 'Canceladas',
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
        if (individualHistory.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Tutorías individuales',
            style: TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...individualHistory.map(
          (tutoring) => _TutoringCard(
            tutoring: tutoring,
            onOpenHistory: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TutoriaHistorialPage(
                  sessionId: tutoring.id,
                  subject: tutoring.subject,
                  isIndividual: true,
                ),
              ),
            ),
          ),
        ),
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
      return const _EmptyCard(
        icon: Icons.star_border,
        title: 'No hay tutorías para calificar',
        message: 'La opción aparecerá cuando una tutoría haya terminado.',
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
    final pending = widget.data.tutorings.where((tutoring) =>
        tutoring.status == 'SOLICITADA' ||
        tutoring.status == 'ALTERNATIVA_PROPUESTA');
    final activeIndividual = widget.data.tutorings.where((tutoring) =>
        tutoring.status == 'PROGRAMADA' || tutoring.status == 'EN_CURSO');
    final cancelled = widget.data.tutorings
        .where((tutoring) => tutoring.status == 'CANCELADA');
    final options = [
      (
        'disponibles',
        'Disponibles para unirme',
        widget.data.availableGroupSessions.length
      ),
      ('pendientes', 'Pendientes', pending.length),
      (
        'encurso',
        'Próximas y en curso',
        activeGroupSessions.length + activeIndividual.length
      ),
      ('canceladas', 'Canceladas', cancelled.length),
    ];

    Widget content;
    switch (_sessionFilter) {
      case 'pendientes':
        content = _tutoringList(
          pending,
          scrollController: _sessionsScrollController,
          emptyTitle: 'No tienes solicitudes pendientes',
          emptyMessage: 'Tus solicitudes aparecerán aquí.',
        );
        break;
      case 'encurso':
        content = activeGroupSessions.isEmpty && activeIndividual.isEmpty
            ? ListView(
                controller: _sessionsScrollController,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                children: const [
                  _EmptyCard(
                    icon: Icons.event_note_outlined,
                    title: 'No tienes sesiones próximas',
                    message:
                        'Tus tutorías confirmadas aparecerán aquí. Podrás entrar cuando el docente inicie la clase.',
                  ),
                ],
              )
            : ListView(
                controller: _sessionsScrollController,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                children: [
                  ...activeGroupSessions.map((session) => _GroupSessionCard(
                        session: session,
                        studentName: widget.data.profile.name,
                        onLeave: () => widget.onLeaveGroupSession(session),
                      )),
                  ...activeIndividual.map((tutoring) => _TutoringCard(
                        tutoring: tutoring,
                        onJoinRoom: tutoring.status == 'EN_CURSO' &&
                                tutoring.modality.toUpperCase() != 'PRESENCIAL'
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LiveKitRoomPage(
                                      sessionId: tutoring.id,
                                      subject: tutoring.subject,
                                      modality: tutoring.modality,
                                      teacherMode: false,
                                      students: [tutoring.studentId],
                                      endAt: tutoring.end?.toLocal(),
                                      studentMode: true,
                                      studentName: widget.data.profile.name,
                                      isIndividualTutoring: true,
                                    ),
                                  ),
                                )
                            : null,
                        onCancel: tutoring.status == 'PROGRAMADA'
                            ? () => widget.onAction(tutoring, 'cancelar')
                            : null,
                      )),
                ],
              );
        break;
      case 'canceladas':
        content = _tutoringList(
          cancelled,
          scrollController: _sessionsScrollController,
          emptyTitle: 'No tienes tutorías canceladas',
          emptyMessage: 'Las tutorías canceladas aparecerán aquí.',
        );
        break;
      default:
        content = _publishedGroupSessions(
          scrollController: _sessionsScrollController,
        );
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
          child: Row(
            children: [
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: ChoiceChip(
                    label: Text('${option.$2} (${option.$3})'),
                    selected: _sessionFilter == option.$1,
                    onSelected: (_) =>
                        setState(() => _sessionFilter = option.$1),
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: _sessionFilter == option.$1
                          ? Colors.white
                          : const Color(0xFF334155),
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF0D4FC4),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
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

  Widget _groupChatsAndCalls() {
    final sessions = widget.data.groupSessions
        .where((session) => session.state != 'FINALIZADA')
        .toList()
      ..sort((a, b) =>
          (a.start ?? DateTime(9999)).compareTo(b.start ?? DateTime(9999)));
    if (sessions.isEmpty) {
      return const _EmptyCard(
        icon: Icons.forum_outlined,
        title: 'Aún no tienes tutorías grupales',
        message:
            'Cuando te inscribas en una tutoría, su chat y su videollamada aparecerán aquí.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [
        for (final session in sessions)
          _GroupChatAndCallCard(
            session: session,
            studentName: widget.data.profile.name,
          ),
      ],
    );
  }

  Widget _publishedGroupSessions({ScrollController? scrollController}) {
    final sessions = widget.data.availableGroupSessions;
    if (sessions.isEmpty) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        children: const [
          _EmptyCard(
            icon: Icons.event_busy_outlined,
            title: 'No hay sesiones disponibles',
            message:
                'Cuando coordinación publique tutorías para tu tecnología, aparecerán aquí.',
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
        final enrolledIndividual = widget.data.tutorings.where((item) =>
            (item.status == 'SOLICITADA' ||
                item.status == 'ALTERNATIVA_PROPUESTA' ||
                item.status == 'PROGRAMADA' ||
                item.status == 'EN_CURSO') &&
            (item.end?.isAfter(now) ?? false));
        final maximumReached =
            enrolledGroups.length + enrolledIndividual.length >= 3;
        final overlapsGroup = start != null &&
            end != null &&
            enrolledGroups.any((item) =>
                item.start != null &&
                item.end != null &&
                start.isBefore(item.end!) &&
                item.start!.isBefore(end));
        final overlapsIndividual = start != null &&
            end != null &&
            enrolledIndividual.any((item) =>
                item.start != null &&
                item.end != null &&
                start.isBefore(item.end!) &&
                item.start!.isBefore(end));
        final hasScheduleConflict = overlapsGroup || overlapsIndividual;
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
                            : 'Inscribirme'),
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

  Widget _tutoringList(
    Iterable<StudentTutoring> values, {
    ScrollController? scrollController,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    final items = values.toList()
      ..sort((a, b) =>
          (a.start ?? DateTime(9999)).compareTo(b.start ?? DateTime(9999)));
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [
        if (items.isEmpty)
          _EmptyCard(
            icon: Icons.event_note_outlined,
            title: emptyTitle,
            message: emptyMessage,
          )
        else
          ...items.map((tutoring) => _TutoringCard(
                tutoring: tutoring,
                onConfirm: tutoring.status == 'ALTERNATIVA_PROPUESTA'
                    ? () => widget.onAction(tutoring, 'confirmar-alternativa')
                    : null,
                onCancel: tutoring.status == 'SOLICITADA' ||
                        tutoring.status == 'ALTERNATIVA_PROPUESTA' ||
                        tutoring.status == 'PROGRAMADA'
                    ? () => widget.onAction(tutoring, 'cancelar')
                    : null,
              )),
      ],
    );
  }
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
  });

  final StudentGroupSession session;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = session.start?.toLocal();
    final end = session.end?.toLocal();

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
            if (session.state == 'EN_CURSO' &&
                session.modality.toUpperCase() != 'PRESENCIAL')
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
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
                )),
                icon: const Icon(Icons.video_call_outlined),
                label: const Text('Entrar a la sala'),
              ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TutoriaChatPage(
                  sessionId: session.id,
                  subject: session.subject,
                  readOnly: session.state == 'FINALIZADA' ||
                      (end != null && !end.isAfter(now)),
                ),
              )),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Abrir chat'),
            ),
          ]),
        ]),
      ),
    );
  }
}

String _groupSessionModalityLabel(String value) =>
    switch (value.toUpperCase()) {
      'PRESENCIAL' => 'Presencial',
      'HIBRIDA' => 'Híbrida',
      'VIRTUAL' => 'Virtual',
      _ => value.isEmpty ? 'Por confirmar' : value,
    };

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE7F1FC),
            child: Icon(icon, color: _blue),
          ),
          title: Text(title,
              style:
                  const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}
