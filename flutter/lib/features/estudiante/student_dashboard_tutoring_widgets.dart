part of 'student_dashboard_views.dart';

class _TutorCard extends StatelessWidget {
  const _TutorCard({required this.tutor, required this.onEnroll});
  final AvailableTutor tutor;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0x14000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const CircleAvatar(
                  radius: 11,
                  backgroundColor: Color(0xFFE7F1FC),
                  child: Icon(Icons.person_outline, color: _blue, size: 12),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tutor.name,
                          style: const TextStyle(
                              color: _navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      Text(
                        '${tutor.career} · Semestre ${tutor.semester}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 7),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  text: _modalityLabel(tutor.modality),
                ),
              ]),
              const Divider(height: 12),
              const Text(
                'DÍA Y HORARIO',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  letterSpacing: .4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${tutor.day} · ${tutor.startTime}–${tutor.endTime}',
                style: const TextStyle(
                  color: Color(0xFF202B3A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(height: 12),
              Text(
                'MODALIDAD Y UBICACIÓN',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  letterSpacing: .4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_modalityLabel(tutor.modality)}${tutor.location.isEmpty ? '' : ' · ${tutor.location}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF202B3A),
                  fontSize: 11,
                ),
              ),
              if (tutor.subjects.isNotEmpty) ...[
                const Divider(height: 12),
                const Text(
                  'MATERIAS DE TU CARRERA',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  ),
                ),
                for (final subject in tutor.subjects)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF202B3A),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _SubjectScopeLabel(
                          text: subject.careers.length > 1
                              ? 'Compartida'
                              : 'Exclusiva',
                          color: subject.careers.length > 1
                              ? const Color(0xFFE8F1FF)
                              : const Color(0xFFFFF1DF),
                          foreground: subject.careers.length > 1
                              ? const Color(0xFF2459A6)
                              : const Color(0xFF9A5A00),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onEnroll,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    minimumSize: const Size(0, 25),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  child:
                      const Text('Inscribirme', style: TextStyle(fontSize: 8)),
                ),
              ),
            ],
          ),
        ),
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
    this.onJoinRoom,
    this.onOpenHistory,
  });
  final StudentTutoring tutoring;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onJoinRoom;
  final VoidCallback? onOpenHistory;

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
              if (onJoinRoom != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onJoinRoom,
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Entrar a la clase'),
                ),
              ],
              if (onOpenHistory != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onOpenHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Ver historial'),
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
  const _GroupSessionCard({
    required this.session,
    required this.studentName,
    required this.onLeave,
  });

  final StudentGroupSession session;
  final String studentName;
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
              if (session.state == 'EN_CURSO' &&
                  session.modality.toUpperCase() != 'PRESENCIAL') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
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
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D4FC4),
                      minimumSize: const Size(0, 30),
                    ),
                    child: const Text(
                      'Entrar a la sala',
                      style: TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ],
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
      RoleToast.show(context,
          message: 'No se pudo abrir Google Calendar.', roleColor: _blue);
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
      RoleToast.show(context,
          message: 'Reporte enviado a coordinación.', roleColor: _blue);
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.data is Map &&
              (error.response!.data as Map)['message'] is String
          ? (error.response!.data as Map)['message'] as String
          : 'No se pudo enviar el reporte.';
      RoleToast.show(context, message: message, roleColor: _blue);
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

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builde°r: (_) => TutoriaHistorialPage(
          sessionId: widget.session.id,
          subject: widget.session.subject,
          isIndividual: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFE6EEFF),
                    child: Icon(Icons.groups_outlined, color: _blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.subject,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.session.start == null ? 'Fecha no disponible' : _longDate(widget.session.start!.toLocal())} · Tutoría grupal',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const _StatusPill(text: 'Realizada'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _openHistory,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: Color(0xFFD5E4F5)),
                    ),
                    child: const Text('Ver registro de clase'),
                  ),
                  const Spacer(),
                  if (widget.showRating)
                    IconButton(
                      tooltip: _rated ? 'Reporte enviado' : 'Calificar clase',
                      onPressed: _sending || _rated ? null : _rate,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _rated ? Icons.check_circle : Icons.star_border,
                        color: _rated ? Colors.green : Colors.amber,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
