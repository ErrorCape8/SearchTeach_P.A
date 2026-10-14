part of 'student_dashboard_views.dart';

class StudentTutoringView extends StatefulWidget {
  const StudentTutoringView({
    required this.data,
    required this.focusSection,
    required this.focusRequest,
    required this.onEnroll,
    required this.onAction,
    required this.onShowMessage,
    super.key,
  });

  final StudentDashboardData data;
  final String? focusSection;
  final int focusRequest;
  final Future<void> Function(AvailableTutor tutor) onEnroll;
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
            title: 'Sesiones disponibles',
            subtitle:
                'Busca tutores por nombre, identificación o disponibilidad.',
            onTap: () => setState(() => _section = 'disponibles'),
          ),
          _MenuTile(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Solicitar tutoría',
            subtitle: 'Elige un tutor y envía tu solicitud de inscripción.',
            onTap: () => setState(() => _section = 'solicitar'),
          ),
          _MenuTile(
            icon: Icons.pending_actions_outlined,
            title: 'Mis solicitudes',
            subtitle: 'Consulta solicitudes pendientes o propuestas.',
            onTap: () => setState(() => _section = 'solicitudes'),
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
      'disponibles' => (
          'Sesiones disponibles',
          'Explora la disponibilidad publicada por los tutores.'
        ),
      'solicitar' => (
          'Inscribirse en una tutoría',
          'Selecciona un horario y envía tu solicitud al tutor.'
        ),
      'solicitudes' => (
          'Mis solicitudes',
          'Haz seguimiento a tus solicitudes de tutoría.'
        ),
      'sesiones' => ('Mis sesiones', 'Tutorías confirmadas y en curso.'),
      _ => ('Historial', 'Tutorías realizadas o canceladas.'),
    };
    return _PageHeading(title: content.$1, subtitle: content.$2);
  }

  Widget _sectionContent() {
    switch (_section) {
      case 'disponibles':
      case 'solicitar':
        return _availableTutors();
      case 'solicitudes':
        return _tutoringList(
          widget.data.tutorings.where((t) =>
              t.status == 'SOLICITADA' || t.status == 'ALTERNATIVA_PROPUESTA'),
          emptyTitle: 'No tienes solicitudes pendientes',
          emptyMessage: 'Al inscribirte, tus solicitudes aparecerán aquí.',
        );
      case 'sesiones':
        return _tutoringList(
          widget.data.tutorings
              .where((t) => t.status == 'PROGRAMADA' || t.status == 'EN_CURSO'),
          emptyTitle: 'No tienes sesiones programadas',
          emptyMessage: 'Las tutorías confirmadas aparecerán en esta sección.',
        );
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
      ...widget.data.tutors
          .map((tutor) => tutor.career)
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
          (_career == 'Todas' || tutor.career == _career) &&
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

