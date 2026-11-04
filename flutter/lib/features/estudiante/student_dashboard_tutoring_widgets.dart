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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject.name),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: subject.careers.length > 1
                              ? [
                                  const _SubjectScopeLabel(
                                    text: 'Compartida con',
                                    color: Color(0xFFE8F1FF),
                                    foreground: Color(0xFF2459A6),
                                  ),
                                  for (final career in subject.careers)
                                    _SubjectScopeLabel(
                                      text: career,
                                      color: const Color(0xFFE8F1FF),
                                      foreground: const Color(0xFF2459A6),
                                    ),
                                ]
                              : [
                                  const _SubjectScopeLabel(
                                    text: 'Exclusiva para',
                                    color: Color(0xFFFFF1DF),
                                    foreground: Color(0xFF9A5A00),
                                  ),
                                  _SubjectScopeLabel(
                                    text: subject.careers.isEmpty
                                        ? tutor.career
                                        : subject.careers.first,
                                    color: const Color(0xFFFFF1DF),
                                    foreground: const Color(0xFF9A5A00),
                                  ),
                                ],
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

class _SubjectScopeLabel extends StatelessWidget {
  const _SubjectScopeLabel({
    required this.text,
    required this.color,
    required this.foreground,
  });

  final String text;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: foreground,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
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
              if (session.start != null && session.end != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _addToGoogleCalendar(context, session),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Agregar a Google Calendar'),
                  ),
                ),
              ],
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

  Future<void> _addToGoogleCalendar(
    BuildContext context,
    StudentGroupSession session,
  ) async {
    final start = session.start!.toUtc();
    final end = session.end!.toUtc();
    String calendarDate(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}T'
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}'
        '${value.second.toString().padLeft(2, '0')}Z';

    final details = [
      'Tutoría grupal de SearchTeach',
      'Tecnología: ${session.technology}',
      'Docente: ${session.teacherId}',
      if (session.modality.isNotEmpty) 'Modalidad: ${session.modality}',
    ].join('\n');
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Tutoría: ${session.subject}',
      'dates': '${calendarDate(start)}/${calendarDate(end)}',
      'details': details,
      if (session.location.isNotEmpty) 'location': session.location,
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Calendar.')),
      );
    }
  }
}

class _GroupHistoryCard extends ConsumerStatefulWidget {
  const _GroupHistoryCard({
    required this.session,
    required this.onRated,
    this.showRating = true,
  });
  final StudentGroupSession session;
  final VoidCallback onRated;
  final bool showRating;

  @override
  ConsumerState<_GroupHistoryCard> createState() => _GroupHistoryCardState();
}

class _GroupHistoryCardState extends ConsumerState<_GroupHistoryCard> {
  bool _sending = false;
  bool _rated = false;

  Future<void> _rate() async {
    var stars = 0;
    final selectedComments = <String>{};
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          final options = _ratingComments(stars);
          return AlertDialog(
            title: const Text('¿Cómo sentiste la atención del tutor?'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 1; index <= 5; index++)
                      IconButton(
                        tooltip: '$index estrellas',
                        onPressed: () => refresh(() {
                          stars = index;
                          selectedComments.clear();
                        }),
                        icon: Icon(
                          index <= stars ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                      ),
                  ],
                ),
                if (stars > 0) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecciona uno o varios comentarios sobre el tutor:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in options)
                        FilterChip(
                          label: Text(option),
                          selected: selectedComments.contains(option),
                          onSelected: (selected) => refresh(() {
                            if (selected) {
                              selectedComments.add(option);
                            } else {
                              selectedComments.remove(option);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'${selectedComments.join('. ')}'
                        '${selectedComments.isEmpty ? '' : '.'}'.length}/300 '
                    'caracteres',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: stars == 0
                    ? null
                    : () => Navigator.pop(dialogContext, (
                          stars,
                          '${selectedComments.join('. ')}'
                              '${selectedComments.isEmpty ? '' : '.'}'
                        )),
                child: const Text('Enviar valoración'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(dioProvider).post(
        '/api/tutorias/grupales/${Uri.encodeComponent(widget.session.id)}/valoracion',
        data: {'estrellas': result.$1, 'comentario': result.$2},
      );
      if (!mounted) return;
      setState(() => _rated = true);
      widget.onRated();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado a coordinación.')));
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.data is Map &&
              (error.response!.data as Map)['message'] is String
          ? (error.response!.data as Map)['message'] as String
          : 'No se pudo enviar el reporte.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<String> _ratingComments(int stars) => switch (stars) {
        1 => const [
            'El tutor no se presentó',
            'El tutor no ingresó',
            'El tutor no explicó bien',
          ],
        2 => const [
            'El tutor llegó tarde',
            'La explicación fue poco clara',
            'Necesité más apoyo del tutor',
          ],
        3 => const [
            'La clase estuvo bien',
            'El tutor explicó lo básico',
            'El tutor podría mejorar',
          ],
        4 => const [
            'El tutor explicó claramente',
            'Buena atención del tutor',
            'El tutor resolvió mis dudas',
          ],
        5 => const [
            'Excelente explicación del tutor',
            'El tutor fue atento y claro',
            'Recomiendo a este tutor',
          ],
        _ => const [],
      };

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const CircleAvatar(child: Icon(Icons.history)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.session.subject,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                        '${widget.session.start == null ? 'Fecha no disponible' : _longDate(widget.session.start!)} · Tutoría grupal finalizada'),
                  ]),
            ),
            if (widget.showRating)
              IconButton(
                tooltip: _rated ? 'Reporte enviado' : 'Calificar clase',
                onPressed: _sending || _rated ? null : _rate,
                icon: Icon(_rated ? Icons.check_circle : Icons.star_border,
                    color: _rated ? Colors.green : Colors.amber),
              ),
          ]),
        ),
      );
}

// ignore: unused_element
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
