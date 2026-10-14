part of 'student_dashboard_views.dart';

class _TutorCard extends StatelessWidget {
  const _TutorCard({required this.tutor, required this.onEnroll});
  final AvailableTutor tutor;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE7F1FC),
                  child: Icon(Icons.person_outline, color: _blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tutor.name,
                          style: const TextStyle(
                              color: _navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      Text('ID ${tutor.teacherId}',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
                _StatusPill(text: tutor.modality),
              ]),
              const SizedBox(height: 15),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _detail(Icons.school_outlined, tutor.career),
                  _detail(Icons.layers_outlined, 'Semestre ${tutor.semester}'),
                  _detail(Icons.calendar_today_outlined, tutor.day),
                  _detail(
                      Icons.schedule, '${tutor.startTime}–${tutor.endTime}'),
                  if (tutor.location.isNotEmpty)
                    _detail(Icons.place_outlined, tutor.location),
                ],
              ),
              if (tutor.subjects.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'MATERIAS QUE DICTA',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 5),
                for (final subject in tutor.subjects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(subject.name)),
                        if (subject.careers.length > 1)
                          Flexible(
                            child: Text(
                              'Compartida con ${subject.careers.where((career) => career != tutor.career).join(', ')}',
                              textAlign: TextAlign.end,
                              style:
                                  const TextStyle(color: _muted, fontSize: 11),
                            ),
                          )
                        else
                          const Text(
                            'Exclusiva',
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onEnroll,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Inscribirse'),
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _detail(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      );
}

class _TutoringCard extends StatelessWidget {
  const _TutoringCard({
    required this.tutoring,
    this.onConfirm,
    this.onCancel,
  });
  final StudentTutoring tutoring;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(tutoring.subject,
                      style: const TextStyle(
                          color: _navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
                _StatusPill(text: _statusLabel(tutoring.status)),
              ]),
              const SizedBox(height: 10),
              Text(
                tutoring.start == null
                    ? 'Horario por confirmar'
                    : _longDate(tutoring.start!),
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 5),
              Text('Modalidad: ${_modalityLabel(tutoring.modality)}',
                  style: const TextStyle(color: _muted)),
              if (tutoring.status == 'EN_CURSO') ...[
                const SizedBox(height: 12),
                const Text(
                  'El enlace de la clase no está configurado para esta tutoría.',
                  style: TextStyle(color: _muted),
                ),
              ],
              if (onConfirm != null || onCancel != null) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  if (onConfirm != null)
                    FilledButton(
                      onPressed: onConfirm,
                      child: const Text('Aceptar propuesta'),
                    ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancelar'),
                    ),
                ]),
              ],
            ],
          ),
        ),
      );
}

class _GroupSessionCard extends StatelessWidget {
  const _GroupSessionCard({required this.session, required this.onLeave});

  final StudentGroupSession session;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.subject,
                  style: const TextStyle(
                      color: _navy, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                  'Docente ${session.teacherId} · Semestre ${session.semester}'),
              if (session.start != null)
                Text(_longDate(session.start!),
                    style: const TextStyle(color: _muted)),
              Text('Tecnologías: ${session.technologies.join(', ')}',
                  style: const TextStyle(color: _muted)),
              Text('${session.studentCount}/5 estudiantes inscritos',
                  style: const TextStyle(color: _muted)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onLeave,
                  icon: const Icon(Icons.logout),
                  label: const Text('Desistir'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 170, maxWidth: 270),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _line),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: values
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (selected) {
                if (selected != null) onChanged(selected);
              },
            ),
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = switch (text) {
      'PROGRAMADA' || 'En curso' || 'Realizada' => const Color(0xFF2B8A65),
      'ALTERNATIVA_PROPUESTA' ||
      'Propuesta de horario' =>
        const Color(0xFFD08419),
      'CANCELADA' || 'Cancelada' => const Color(0xFF9B4C4C),
      _ => _blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _statusLabel(text),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _statusLabel(String value) => switch (value) {
      'SOLICITADA' => 'Pendiente',
      'ALTERNATIVA_PROPUESTA' => 'Propuesta de horario',
      'PROGRAMADA' => 'Programada',
      'EN_CURSO' => 'En curso',
      'REALIZADA' => 'Realizada',
      'CANCELADA' => 'Cancelada',
      _ => value,
    };

String _modalityLabel(String value) => switch (value.toUpperCase()) {
      'PRESENCIAL' => 'Presencial',
      'HIBRIDA' => 'Híbrida',
      'VIRTUAL' => 'Virtual',
      _ => value,
    };

String _longDate(DateTime date) {
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
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}, $time';
}
