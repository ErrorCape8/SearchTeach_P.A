part of 'student_dashboard_views.dart';

class StudentTutoringView extends StatefulWidget {
  const StudentTutoringView({
    required this.data,
    required this.focusSection,
    required this.focusRequest,
    required this.onEnroll,
    required this.onProjectEnrollment,
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
  final Future<void> Function(StudentGroupSession session) onLeaveGroupSession;
  final Future<void> Function(StudentGroupSession session) onJoinPublishedSession;
  final Future<void> Function(StudentTutoring tutoring, String action) onAction;
  final void Function(String message) onShowMessage;

  @override
  State<StudentTutoringView> createState() => _StudentTutoringViewState();
}

class _StudentTutoringViewState extends State<StudentTutoringView> {
  String? _section;
  String _query = '';
  String _career = 'Todas';
  String _semester = 'Todos';

  @override
  void initState() {
    super.initState();
    final studentCareer = widget.data.profile.career.trim();
    if (studentCareer.isNotEmpty) _career = studentCareer;
  }

  @override
  void didUpdateWidget(covariant StudentTutoringView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
            icon: Icons.pending_actions_outlined,
            title: 'Mis solicitudes',
            subtitle: 'Consulta solicitudes pendientes o propuestas.',
            onTap: () => setState(() => _section = 'solicitudes'),
          ),
          _MenuTile(
            icon: Icons.event_available_outlined,
            title: 'Tutorías grupales disponibles',
            subtitle: 'Inscríbete en una sesión publicada por coordinación.',
            onTap: () => setState(() => _section = 'grupales-disponibles'),
          ),
          _MenuTile(
            icon: Icons.event_note_outlined,
            title: 'Mis sesiones',
            subtitle: 'Consulta las tutorías programadas y en curso.',
            onTap: () => setState(() => _section = 'sesiones'),
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
      'solicitudes' => (
          'Mis solicitudes',
          'Haz seguimiento a tus solicitudes de tutoría.'
        ),
      'sesiones' => ('Mis sesiones', 'Tutorías confirmadas y en curso.'),
      'grupales-disponibles' => (
          'Tutorías grupales disponibles',
          'Elige una sesión de tu tecnología y semestre.'
        ),
      _ => ('Historial', 'Tutorías realizadas o canceladas.'),
    };
    return _PageHeading(title: content.$1, subtitle: content.$2);
  }

  Widget _sectionContent() {
    switch (_section) {
      case 'disponibles':
      case 'solicitar':
        return _availableTutors();
      case 'proyectos':
        return _projectSpaces();
      case 'solicitudes':
        return _tutoringList(
          widget.data.tutorings.where((t) =>
              t.status == 'SOLICITADA' || t.status == 'ALTERNATIVA_PROPUESTA'),
          emptyTitle: 'No tienes solicitudes pendientes',
          emptyMessage: 'Al inscribirte, tus solicitudes aparecerán aquí.',
        );
      case 'sesiones':
        return _sessionsList();
      case 'grupales-disponibles':
        return _publishedGroupSessions();
      default:
        return _tutoringList(
          widget.data.tutorings
              .where((t) => t.status == 'REALIZADA' || t.status == 'CANCELADA'),
          emptyTitle: 'Tu historial está vacío',
          emptyMessage: 'Las tutorías finalizadas aparecerán aquí.',
        );
    }
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
          const _EmptyCard(
            icon: Icons.search_off,
            title: 'No encontramos tutores con esos filtros',
            message: 'Prueba con otro nombre, carrera o semestre.',
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
      return const Center(
        child: _EmptyCard(
          icon: Icons.groups_outlined,
          title: 'No hay proyectos de aula disponibles',
          message:
              'Cuando coordinación cree un espacio para tu tecnología aparecerá aquí.',
        ),
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
                    onPressed: !space.createOrJoin && !space.enrolled && full
                        ? null
                        : () => widget.onProjectEnrollment(space),
                    child: Text(space.createOrJoin
                        ? 'Crear o unirse'
                        : space.enrolled
                            ? 'Desistir de esta tutoría'
                            : full
                                ? 'Cupo completo'
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

  Widget _sessionsList() {
    final legacy = widget.data.tutorings
        .where((t) => t.status == 'PROGRAMADA' || t.status == 'EN_CURSO');
    if (widget.data.groupSessions.isEmpty && legacy.isEmpty) {
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
        if (widget.data.groupSessions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Tutorías grupales',
                style: TextStyle(fontWeight: FontWeight.w700, color: _navy)),
          ),
          ...widget.data.groupSessions.map((session) => _GroupSessionCard(
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
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => widget.onJoinPublishedSession(session),
                    child: const Text('Inscribirme'),
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
