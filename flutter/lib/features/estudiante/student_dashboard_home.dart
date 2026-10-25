part of 'student_dashboard_views.dart';

class StudentHomeView extends StatelessWidget {
  const StudentHomeView({
    required this.data,
    required this.onBrowse,
    required this.onHistory,
    super.key,
  });

  final StudentDashboardData data;
  final VoidCallback onBrowse;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final active = data.tutorings
        .where((t) => t.status == 'PROGRAMADA' || t.status == 'EN_CURSO')
        .toList()
      ..sort((a, b) => (a.start ?? DateTime(9999))
          .compareTo(b.start ?? DateTime(9999)));
    final pending = data.tutorings
        .where((t) =>
            t.status == 'SOLICITADA' || t.status == 'ALTERNATIVA_PROPUESTA')
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        _WelcomeCard(name: data.profile.name, onBrowse: onBrowse),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 780 ? 3 : 1;
          final cards = [
            _MetricCard(
              icon: Icons.event_available_outlined,
              label: 'Próximas tutorías',
              value: '${active.length}',
              color: const Color(0xFF2B8A65),
            ),
            _MetricCard(
              icon: Icons.pending_actions_outlined,
              label: 'Solicitudes pendientes',
              value: '$pending',
              color: const Color(0xFFD08419),
            ),
            _MetricCard(
              icon: Icons.history,
              label: 'Tutorías completadas',
              value: '${data.tutorings.where((t) => t.status == 'REALIZADA').length}',
              color: _blue,
            ),
          ];
          if (columns == 1) {
            return Column(children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ]);
          }
          return Row(children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 14),
            ],
          ]);
        }),
        const SizedBox(height: 28),
        _SectionHeading(
          title: 'Tutorías disponibles',
          action: 'Explorar',
          onAction: onBrowse,
        ),
        const SizedBox(height: 12),
        if (data.tutors.isEmpty)
          const _EmptyCard(
            icon: Icons.event_busy_outlined,
            title: 'Aún no hay horarios publicados',
            message: 'Cuando haya tutores disponibles, aparecerán aquí.',
          )
        else
          ...data.tutors.take(3).map(
                (tutor) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TutorSummaryCard(tutor: tutor),
                ),
              ),
        const SizedBox(height: 18),
        _SectionHeading(
          title: 'Actividad reciente',
          action: 'Ver historial',
          onAction: onHistory,
        ),
        const SizedBox(height: 12),
        if (data.tutorings.isEmpty)
          const _EmptyCard(
            icon: Icons.menu_book_outlined,
            title: 'Tu actividad aparecerá aquí',
            message: 'Inscríbete en una tutoría para comenzar.',
          )
        else
          ...data.tutorings.take(3).map(
                (tutoring) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TutoringSummaryCard(tutoring: tutoring),
                ),
              ),
      ],
    );
  }
}

class StudentProfileView extends ConsumerWidget {
  const StudentProfileView({
    required this.profile,
    this.onTeacherMode,
    super.key,
  });

  final StudentProfile profile;
  final VoidCallback? onTeacherMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _PageHeading(
            title: 'Mi perfil',
            subtitle: 'Tu información registrada en SearchTeach.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFFE7F1FC),
                    child: Text(
                      _initials(profile.name),
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(profile.name,
                      style: const TextStyle(
                          color: _navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(_roleLabel(profile.role),
                      style: const TextStyle(color: _muted)),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  _ProfileRow(label: 'Documento', value: profile.id),
                  _ProfileRow(label: 'Correo', value: profile.email),
                  _ProfileRow(label: 'Teléfono', value: profile.phone),
                  _ProfileRow(label: 'Rol académico', value: _roleLabel(profile.role)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showProfileChangeDialog(context, ref,
                          onUpdated: () => ref.invalidate(studentDashboardProvider)),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Cambiar correo, teléfono o contraseña'),
                    ),
                  ),
                  if (onTeacherMode != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onTeacherMode,
                        icon: const Icon(Icons.co_present_outlined),
                        label: const Text('Cambiar a vista docente'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
}
