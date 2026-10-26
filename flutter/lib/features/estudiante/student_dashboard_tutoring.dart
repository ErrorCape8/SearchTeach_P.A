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
    super.key,
  });

  final StudentDashboardData data;
  final String? focusSection;
  final int focusRequest;
  final Future<void> Function(AvailableTutor tutor) onEnroll;
  final Future<void> Function(ClassroomProjectSpace space) onProjectEnrollment;
  final Future<void> Function() onJoinProjectCode;
  final Future<void> Function(StudentGroupSession session) onLeaveGroupSession;
  final Future<void> Function(StudentGroupSession session) onJoinPublishedSession;
  final Future<void> Function(StudentTutoring tutoring, String action) onAction;
  final void Function(String message) onShowMessage;

  @override
  ConsumerState<StudentTutoringView> createState() => _StudentTutoringViewState();
}

class _StudentTutoringViewState extends ConsumerState<StudentTutoringView> {
  String? _section;
  String _query = '';
  String _career = 'Todas';
  String _semester = 'Todos';

  @override
  void initState() {
    super.initState();
    final studentCareer = widget.data.profile.career.trim();
    if (studentCareer.isNotEmpty) _career = studentCareer;
    if (widget.data.profile.semester > 0) {
      _semester = '${widget.data.profile.semester}';
    }
  }

  @override
  void didUpdateWidget(covariant StudentTutoringView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.profile.semester != oldWidget.data.profile.semester &&
        widget.data.profile.semester > 0) {
      _semester = '${widget.data.profile.semester}';
    }
    if (widget.focusRequest != oldWidget.focusRequest) {
      _section = widget.focusSection;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_section == null) return _menu();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver a tutorías',
                onPressed: () => setState(() => _section = null),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Expanded(child: _sectionHeader()),
            ],
          ),
        ),
        Expanded(child: _sectionContent()),
      ],
    );
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
            icon: Icons.search,
            title: 'Tutorías retroalimentativas',
            subtitle:
                'Encuentra un tutor y solicita acompañamiento para una materia.',
            onTap: () => setState(() => _section = 'disponibles'),
          ),
          _MenuTile(
            icon: Icons.groups_outlined,
            title: 'Tutorías de proyectos de aula',
            subtitle: 'Inscríbete o desiste de un espacio de tu tecnología.',
            onTap: () => setState(() => _section = 'proyectos'),
          ),
          _MenuTile(
            icon: Icons.assignment_outlined,
            title: 'Seguimiento de mi proyecto',
            subtitle: 'Consulta los reportes del tutor, el horario y las respuestas.',
            onTap: () => setState(() => _section = 'seguimiento-proyecto'),
          ),
          _MenuTile(
            icon: Icons.event_note_outlined,
            title: 'Mis sesiones',
            subtitle: 'Consulta las tutorías programadas y en curso.',
            onTap: () => setState(() => _section = 'sesiones'),
          ),
          _MenuTile(
            icon: Icons.video_call_outlined,
            title: 'Chats y videoconferencias',
            subtitle: 'Abre el chat de tus tutorías o únete a una sesión virtual programada.',
            onTap: () => setState(() => _section = 'chats-videoconferencias'),
          ),
          _MenuTile(
            icon: Icons.history,
            title: 'Historial',
            subtitle: 'Revisa tutorías realizadas o canceladas.',
            onTap: () => setState(() => _section = 'historial'),
          ),
        ],
      );

  Widget _sectionHeader() {
    final content = switch (_section) {
      'disponibles' || 'solicitar' => (
          'Tutorías retroalimentativas',
          'Explora la disponibilidad publicada por los tutores.'
        ),
      'proyectos' => (
          'Tutorías de proyectos de aula',
          'Inscríbete en el espacio de tu tecnología y semestre.'
        ),
      'sesiones' => ('Mis sesiones', 'Tutorías confirmadas y en curso.'),
      'chats-videoconferencias' => (
          'Chats y videoconferencias',
          'Accede a la conversación o entra a la sala de tus sesiones.'
        ),
      _ => ('Historial', 'Tutorías realizadas o canceladas.'),
    };
    if (_section == 'seguimiento-proyecto') {
      return const _PageHeading(
        title: 'Seguimiento de mi proyecto',
        subtitle: 'Reportes del tutor, horario y conversación de cada sesión.',
      );
    }
    return _PageHeading(title: content.$1, subtitle: content.$2);
  }

  Widget _sectionContent() {
    switch (_section) {
      case 'disponibles':
      case 'solicitar':
        return _availableTutors();
      case 'proyectos':
        return _projectSpaces();
      case 'seguimiento-proyecto':
        return _projectFollowup();
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
        error: (error, _) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudo cargar el seguimiento de tu proyecto: $error'),
        )),
        data: (projects) => projects.isEmpty
            ? const _EmptyCard(
                icon: Icons.assignment_outlined,
                title: 'Aún no tienes un proyecto inscrito',
                message: 'Cuando te inscribas, aquí verás el horario y los reportes de tu tutor.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                children: [
                  for (final item in projects) Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.project.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                        Text('${item.project.career} · Semestre ${item.project.semester} · Tutor ${item.project.teacherId}'),
                        Text(item.status == 'FINALIZADO'
                            ? 'Proyecto finalizado por el docente líder.'
                            : item.status == 'PENDIENTE_CONFIRMACION'
                                ? 'El cierre del proyecto está pendiente de revisión del docente líder.'
                                : 'Proyecto en curso.'),
                        if (item.meetingAt != null) Text(
                          'Reunión de PA: ${_longDate(item.meetingAt!.toLocal())} · ${TimeOfDay.fromDateTime(item.meetingAt!.toLocal()).format(context)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        const Text('Horario e historial de sesiones', style: TextStyle(fontWeight: FontWeight.w700)),
                        if (item.nextSession != null) ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_available, color: _blue),
                          title: const Text('Próxima sesión', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${_longDate(item.nextSession!.start!.toLocal())} · ${TimeOfDay.fromDateTime(item.nextSession!.start!.toLocal()).format(context)} – ${TimeOfDay.fromDateTime(item.nextSession!.end!.toLocal()).format(context)}'),
                        ),
                        if (item.sessions.isEmpty) const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('El tutor aún no ha registrado un horario.'),
                        ),
                        for (final session in item.sessions) ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_note_outlined),
                          title: Text(session.start == null ? 'Fecha pendiente' : _longDate(session.start!.toLocal())),
                          subtitle: Text('${session.start == null ? '' : TimeOfDay.fromDateTime(session.start!.toLocal()).format(context)} – ${session.end == null ? '' : TimeOfDay.fromDateTime(session.end!.toLocal()).format(context)}\n${session.notes}', maxLines: 5, overflow: TextOverflow.ellipsis),
                          isThreeLine: true,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProyectoAulaChatPage(
                                tutoringId: item.tutoringId,
                                projectId: item.project.projectId,
                                sessionId: session.id,
                                title: item.project.name,
                                teacherMode: false,
                              ),
                            ));
                            if (mounted) ref.invalidate(studentProjectFollowupProvider);
                          },
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
      );

  Widget _history() {
    final completedGroups = widget.data.groupSessions
        .where((session) => session.state == 'FINALIZADA')
        .toList()
      ..sort((a, b) => (b.start ?? DateTime(0)).compareTo(a.start ?? DateTime(0)));
    final individualHistory = widget.data.tutorings
        .where((t) => t.status == 'REALIZADA' || t.status == 'CANCELADA')
        .toList();
    if (completedGroups.isEmpty && individualHistory.isEmpty) {
      return const _EmptyCard(
        icon: Icons.history,
        title: 'Tu historial está vacío',
        message: 'Las tutorías finalizadas aparecerán aquí.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [
        ...completedGroups.map((session) => _GroupHistoryCard(session: session)),
        ...individualHistory.map((tutoring) => _TutoringCard(tutoring: tutoring)),
      ],
    );
  }

  Widget _availableTutors() {
    final careers = {
      'Todas',
      if (_career != 'Todas') _career,
      ...widget.data.tutors
          .expand(
              (tutor) => tutor.careers.isEmpty ? [tutor.career] : tutor.careers)
          .where((v) => v.isNotEmpty)
    }.toList()
      ..sort();
    final semesters = {
      'Todos',
      if (widget.data.profile.semester > 0)
        '${widget.data.profile.semester}',
      ...widget.data.tutors
          .map((tutor) => '${tutor.semester}')
          .where((v) => v != '0')
    }.toList()
      ..sort((a, b) => a == 'Todos'
          ? -1
          : b == 'Todos'
              ? 1
              : a.compareTo(b));
    final filtered = widget.data.tutors.where((tutor) {
      final matchesQuery = '${tutor.name} ${tutor.teacherId}'
          .toLowerCase()
          .contains(_query.trim().toLowerCase());
      return matchesQuery &&
          (_career == 'Todas' ||
              tutor.careers.contains(_career) ||
              tutor.career == _career) &&
          (_semester == 'Todos' || '${tutor.semester}' == _semester);
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Buscar tutor por nombre o identificación',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _FilterDropdown(
              label: 'Carrera',
              value: _career,
              values: careers,
              onChanged: (value) => setState(() => _career = value),
            ),
            _FilterDropdown(
              label: 'Semestre',
              value: _semester,
              values: semesters,
              onChanged: (value) => setState(() => _semester = value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _EmptyCard(
            icon: Icons.search_off,
            title: widget.data.profile.semester <= 0
                ? 'Registra tu semestre para ver tutorías'
                : 'No encontramos tutorías de tu semestre',
            message: widget.data.profile.semester <= 0
                ? 'Ve a Mi perfil y registra tu semestre. Después aparecerán las materias y horarios correspondientes.'
                : 'Aún no hay docentes con horarios publicados para las materias de ${widget.data.profile.career}, semestre ${widget.data.profile.semester}.',
          )
        else
          ...filtered.map(
            (tutor) => _TutorCard(
              tutor: tutor,
              onEnroll: () => widget.onEnroll(tutor),
            ),
          ),
      ],
    );
  }

  Widget _projectSpaces() {
    final career = widget.data.profile.career.trim();
    final spaces = widget.data.projectSpaces
        .where((space) => career.isEmpty || space.career == career)
        .where((space) => space.createOrJoin || space.enrolled)
        .where((space) =>
            !space.createOrJoin ||
            !widget.data.projectSpaces.any(
              (project) =>
                  !project.createOrJoin &&
                  project.tutoringId == space.tutoringId &&
                  project.enrolled,
            ))
        .toList()
      ..sort((a, b) => a.semester.compareTo(b.semester));
    if (spaces.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        children: [
          const _EmptyCard(
            icon: Icons.groups_outlined,
            title: 'No hay proyectos de aula disponibles',
            message: 'Cuando coordinación cree un espacio para tu tecnología aparecerá aquí.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      itemCount: spaces.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final space = spaces[index];
        final full = space.enrolledCount >= 4;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Semestre ${space.semester}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(space.name),
                Text(space.career, style: const TextStyle(color: _muted)),
                const SizedBox(height: 8),
                if (!space.createOrJoin) ...[
                  Text(
                      'Docente: ${space.teacherId} · ${space.enrolledCount}/4 inscritos'),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: space.createOrJoin
                        ? () => widget.onProjectEnrollment(space)
                        : space.enrolled
                            ? () => widget.onProjectEnrollment(space)
                            : full
                                ? null
                                : widget.onJoinProjectCode,
                    child: Text(space.createOrJoin
                        ? 'Asignarme a un grupo'
                        : space.enrolled
                            ? 'Desistir de esta tutoría'
                            : full
                                ? 'Cupo completo'
                                : 'Asignación automática'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sessionsList() {
    final activeGroupSessions = widget.data.groupSessions
        .where((session) => session.state != 'FINALIZADA')
        .toList();
    final legacy = widget.data.tutorings
        .where((t) => t.status == 'PROGRAMADA' || t.status == 'EN_CURSO');
    if (activeGroupSessions.isEmpty && legacy.isEmpty) {
      return const _EmptyCard(
        icon: Icons.event_note_outlined,
        title: 'No tienes sesiones programadas',
        message:
            'Las tutorías grupales en las que te inscribas aparecerán aquí.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [
        if (activeGroupSessions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Tutorías grupales',
                style: TextStyle(fontWeight: FontWeight.w700, color: _navy)),
          ),
          ...activeGroupSessions.map((session) => _GroupSessionCard(
                session: session,
                onLeave: () => widget.onLeaveGroupSession(session),
              )),
        ],
        ...legacy.map((tutoring) => _TutoringCard(
              tutoring: tutoring,
              onCancel: () => widget.onAction(tutoring, 'cancelar'),
            )),
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
        message: 'Cuando te inscribas en una tutoría, su chat y su videollamada aparecerán aquí.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [
        for (final session in sessions)
          _GroupChatAndCallCard(session: session),
      ],
    );
  }

  Widget _publishedGroupSessions() {
    final sessions = widget.data.availableGroupSessions;
    if (sessions.isEmpty) {
      return const _EmptyCard(
        icon: Icons.event_busy_outlined,
        title: 'No hay sesiones disponibles',
        message: 'Cuando coordinación publique tutorías para tu tecnología, aparecerán aquí.',
      );
    }
    return ListView.separated(
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
        final overlapsGroup = start != null && end != null && enrolledGroups.any(
            (item) => item.start != null && item.end != null &&
                start.isBefore(item.end!) && item.start!.isBefore(end));
        final overlapsIndividual = start != null && end != null &&
            enrolledIndividual.any((item) => item.start != null && item.end != null &&
                start.isBefore(item.end!) && item.start!.isBefore(end));
        final hasScheduleConflict = overlapsGroup || overlapsIndividual;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.subject,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text('${teacher?.name ?? 'Docente'} · ${session.technology} · Semestre ${session.semester}'),
                if (session.modality.isNotEmpty)
                  Text(
                    '${_groupSessionModality(session.modality)}${session.location.isEmpty ? '' : ' · ${session.location}'}',
                  ),
                if (start != null && end != null)
                  Text('${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} · '
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
                    onPressed: maximumReached || hasScheduleConflict || start == null || end == null
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
    required String emptyTitle,
    required String emptyMessage,
  }) {
    final items = values.toList()
      ..sort((a, b) =>
          (a.start ?? DateTime(9999)).compareTo(b.start ?? DateTime(9999)));
    return ListView(
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

class _GroupChatAndCallCard extends StatelessWidget {
  const _GroupChatAndCallCard({required this.session});

  final StudentGroupSession session;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = session.start?.toLocal();
    final end = session.end?.toLocal();
    final virtual = session.modality.toUpperCase() == 'VIRTUAL' ||
        session.modality.toUpperCase() == 'HIBRIDA';
    final canJoin = virtual &&
        session.state != 'FINALIZADA' &&
        start != null &&
        end != null &&
        !now.isBefore(start.subtract(const Duration(minutes: 15))) &&
        !now.isAfter(end.add(const Duration(hours: 1)));
    final joinLabel = session.state == 'FINALIZADA'
        ? 'Videollamada finalizada'
        : !virtual
            ? 'Sesión presencial'
            : start != null && now.isBefore(start.subtract(const Duration(minutes: 15)))
                ? 'Disponible 15 min antes'
                : canJoin
                    ? 'Unirme a videoconferencia'
                    : 'Videollamada cerrada';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.subject,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 5),
          Text('Docente ${session.teacherId} · Semestre ${session.semester}'),
          if (start != null) Text(_longDate(start)),
          Text('Modalidad: ${session.modality}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
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
            if (virtual)
              FilledButton.icon(
                onPressed: canJoin
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LiveKitRoomPage(
                            sessionId: session.id,
                            subject: session.subject,
                            modality: session.modality,
                          ),
                        ))
                    : null,
                icon: const Icon(Icons.video_call_outlined),
                label: Text(joinLabel),
              ),
          ]),
        ]),
      ),
    );
  }
}

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
