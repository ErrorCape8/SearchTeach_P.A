part of 'student_dashboard_views.dart';

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name, required this.onBrowse});
  final String name;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF164B83), Color(0xFF2183C6)],
          ),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 540;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hola, ${name.split(' ').first}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text(
                'Encuentra acompañamiento para avanzar en tus estudios.',
                style: TextStyle(color: Color(0xFFE4F1FC)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onBrowse,
                icon: const Icon(Icons.search),
                label: const Text('Buscar tutoría'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _blue,
                ),
              ),
            ],
          );
          return compact
              ? copy
              : Row(children: [
                  Expanded(child: copy),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22),
                    child: Icon(Icons.school_outlined,
                        color: Color(0x99FFFFFF), size: 76),
                  ),
                ]);
        }),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 22)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: _navy, fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        TextButton(onPressed: onAction, child: Text(action)),
      ]);
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _navy, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: _muted)),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(children: [
            Icon(icon, color: _blue, size: 34),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _navy, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted)),
          ]),
        ),
      );
}

class _TutorSummaryCard extends StatelessWidget {
  const _TutorSummaryCard({required this.tutor});
  final AvailableTutor tutor;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE7F1FC),
            child: Icon(Icons.person_outline, color: _blue),
          ),
          title: Text(tutor.name,
              style: const TextStyle(
                  color: _navy, fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${tutor.career} · ${tutor.day} ${tutor.startTime}–${tutor.endTime}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        ),
      );
}

class _TutoringSummaryCard extends StatelessWidget {
  const _TutoringSummaryCard({required this.tutoring});
  final StudentTutoring tutoring;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEAF5EF),
            child: Icon(Icons.menu_book_outlined, color: Color(0xFF2B8A65)),
          ),
          title: Text(tutoring.subject,
              style: const TextStyle(
                  color: _navy, fontWeight: FontWeight.w700)),
          subtitle: Text(_statusLabel(tutoring.status)),
          trailing: Text(
            tutoring.start == null
                ? 'Por confirmar'
                : _shortDate(tutoring.start!),
            style: const TextStyle(color: _muted),
          ),
        ),
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: _muted)),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'No registrado' : value,
                style: const TextStyle(
                    color: _navy, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

String _shortDate(DateTime date) =>
    '${date.day} ${const ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'][date.month - 1]}';

String _roleLabel(String role) {
  final normalized = role.toLowerCase();
  final student = normalized.contains('estudiante');
  final teacher = normalized.contains('docente');
  if (student && teacher) return 'Estudiante y docente';
  if (teacher) return 'Docente';
  if (student) return 'Estudiante';
  return role;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
