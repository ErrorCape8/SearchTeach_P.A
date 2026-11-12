part of 'student_dashboard_page.dart';

const _studentMuted = Color(0xFF64748B);

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
    required this.profile,
    required this.tab,
    required this.tutoringSection,
    required this.showProfileShortcut,
    required this.onRefresh,
    required this.onProfile,
    required this.onNotifications,
    required this.onBack,
  });

  final StudentProfile profile;
  final int tab;
  final String? tutoringSection;
  final bool showProfileShortcut;
  final VoidCallback onRefresh;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final section = tutoringSection ?? 'menu';
    final title = tab == 0
        ? 'Hola, ${profile.name.trim().split(' ').first}'
        : tab == 1
            ? switch (section) {
                'tutores' => 'Tutorías colectivas',
                'publicadas' => 'Sesiones disponibles',
                'proyectos' => 'Proyecto de aula',
                'seguimiento-proyecto' => 'Seguimiento de mi proyecto',
                'proyectos-historial' => 'Proyectos de aula',
                'sesiones' => 'Mis sesiones',
                'historial' => 'Historial de clases',
                'calificar' => 'Calificar tutorías',
                'chats-videoconferencias' => 'Videoconferencias',
                _ => 'Tutorías',
              }
            : tab == 2
                ? profile.name
                : 'Avisos';
    final subtitle = tab == 0
        ? [
            'Estudiante',
            if (profile.career.isNotEmpty) profile.career,
            if (profile.semester > 0) 'Semestre ${profile.semester}',
          ].join(' · ')
        : tab == 1
            ? section == 'menu'
                ? 'Todo sobre tus sesiones'
                : 'Estudiante · ${profile.career}'
            : tab == 2
                ? 'Estudiante'
                : 'Notificaciones';
    final initials = _studentInitials(profile.name);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1769AA), Color(0xFF164B83)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -66,
            right: -44,
            child: Container(
              width: 164,
              height: 164,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: .07), width: 12),
              ),
            ),
          ),
          Positioned(
            top: -48,
            right: -26,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: .07), width: 12),
              ),
            ),
          ),
          Row(
            children: [
              if (tab == 1 && section != 'menu')
                IconButton(
                  tooltip: 'Volver a Tutorías',
                  onPressed: onBack,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 16),
                )
              else
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (tab <= 1 && showProfileShortcut)
                IconButton(
                  tooltip: 'Mi perfil',
                  onPressed: onProfile,
                  visualDensity: VisualDensity.compact,
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white.withValues(alpha: .18),
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync, color: Colors.white, size: 15),
                        if (MediaQuery.sizeOf(context).width >= 600) ...[
                          const SizedBox(width: 5),
                          const Text(
                            'Actualizar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white.withValues(alpha: .16),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Avisos',
                  onPressed: onNotifications,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 38, height: 38),
                  icon: const NotificationUnreadIcon(
                    icon: Icons.notifications_none_outlined,
                  ),
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentSidebar extends StatelessWidget {
  const _StudentSidebar({
    required this.tab,
    required this.profile,
    required this.onSelect,
    required this.onLogout,
  });

  final int tab;
  final StudentProfile profile;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  static const _items = [
    (Icons.home_outlined, 'Inicio'),
    (Icons.event_note_outlined, 'Tutorías'),
    (Icons.person_outline, 'Perfil'),
    (Icons.notifications_none_outlined, 'Avisos'),
  ];

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        child: SizedBox(
          width: 190,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  height: 68,
                  child: Transform.scale(
                    scale: 1.06,
                    child: const BrandLogo(
                      width: 104,
                      height: 64,
                      accentColor: _blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ESTUDIANTE',
                  style: TextStyle(
                    color: _studentMuted,
                    fontSize: 10,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Divider(height: 1, color: Color(0xFFE4EAF1)),
              ),
              const SizedBox(height: 5),
              for (var index = 0; index < _items.length; index++)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: SizedBox(
                    height: 42,
                    child: Material(
                      color: tab == index ? _blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(7),
                        onTap: () => onSelect(index),
                        child: Row(
                          children: [
                            const SizedBox(width: 7),
                            Icon(
                              _items[index].$1,
                              size: 18,
                              color:
                                  tab == index ? Colors.white : _studentMuted,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _items[index].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tab == index ? Colors.white : _navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Divider(height: 1, color: Color(0xFFE4EAF1)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 5, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        tab == 2 ? const Color(0xFFDCEEFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => onSelect(2),
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFDCEEFF),
                          child: Text(
                            _studentInitials(profile.name),
                            style: const TextStyle(
                              color: _blue,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: InkWell(
                          onTap: () => onSelect(2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _navy,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                'Estudiante',
                                style: TextStyle(
                                  color: _studentMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: onLogout,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(
                          Icons.logout,
                          color: _blue,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StudentSidePanel extends StatefulWidget {
  const _StudentSidePanel({required this.data});

  final StudentDashboardData data;

  @override
  State<_StudentSidePanel> createState() => _StudentSidePanelState();
}

class _StudentSidePanelState extends State<_StudentSidePanel> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sessions = <({
      String subject,
      DateTime start,
      DateTime? end,
      String teacher,
      String modality,
      String location,
      String status
    })>[];
    for (final session in widget.data.groupSessions) {
      final start = session.start?.toLocal();
      if (start != null &&
          (session.state == 'PROGRAMADA' || session.state == 'EN_CURSO') &&
          (start.isAfter(now) || session.state == 'EN_CURSO')) {
        sessions.add((
          subject: session.subject,
          start: start,
          end: session.end?.toLocal(),
          teacher: widget.data.tutors
                  .where((tutor) => tutor.teacherId == session.teacherId)
                  .map((tutor) => tutor.name)
                  .firstOrNull ??
              session.teacherId,
          modality: session.modality,
          location: session.location,
          status: session.state == 'EN_CURSO' ? 'En curso' : 'Pendiente',
        ));
      }
    }
    for (final tutoring in widget.data.tutorings) {
      final start = tutoring.start?.toLocal();
      if (start != null &&
          (tutoring.status == 'PROGRAMADA' || tutoring.status == 'EN_CURSO') &&
          (start.isAfter(now) || tutoring.status == 'EN_CURSO')) {
        sessions.add((
          subject: tutoring.subject,
          start: start,
          end: tutoring.end?.toLocal(),
          teacher: widget.data.tutors
                  .where((tutor) => tutor.teacherId == tutoring.teacherId)
                  .map((tutor) => tutor.name)
                  .firstOrNull ??
              tutoring.teacherId,
          modality: tutoring.modality,
          location: '',
          status: tutoring.status == 'EN_CURSO' ? 'En curso' : 'Pendiente',
        ));
      }
    }
    sessions.sort((a, b) => a.start.compareTo(b.start));
    final bookedDates = sessions.map((item) => item.start).toList();
    final selectedDate = _selectedDate ?? now;
    final selectedSessions = sessions
        .where((item) =>
            item.start.year == selectedDate.year &&
            item.start.month == selectedDate.month &&
            item.start.day == selectedDate.day)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 18, 16, 20),
      children: [
        _StudentCalendarCard(
          now: now,
          bookedDates: bookedDates,
          selectedDate: selectedDate,
          onSelectDate: (date) => setState(() => _selectedDate = date),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text(
            'Sesiones del día',
            style: TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x14000000),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: sessions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Tus sesiones aparecerán aquí.',
                    style: TextStyle(color: _studentMuted, fontSize: 8),
                  ),
                )
              : selectedSessions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Sin sesiones el ${selectedDate.day} de ${_shortMonth(selectedDate.month)}.',
                        style: const TextStyle(
                            color: _studentMuted, fontSize: 10),
                      ),
                    )
                  : Column(
                  children: [
                    for (final item in selectedSessions)
                      _UpcomingSessionTile(item: item),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StudentCalendarCard extends StatelessWidget {
  const _StudentCalendarCard({
    required this.now,
    required this.bookedDates,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final DateTime now;
  final List<DateTime> bookedDates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = (DateTime(now.year, now.month, 1).weekday + 6) % 7;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final month = switch (now.month) {
      1 => 'Enero',
      2 => 'Febrero',
      3 => 'Marzo',
      4 => 'Abril',
      5 => 'Mayo',
      6 => 'Junio',
      7 => 'Julio',
      8 => 'Agosto',
      9 => 'Septiembre',
      10 => 'Octubre',
      11 => 'Noviembre',
      _ => 'Diciembre',
    };
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$month ${now.year}',
              style: const TextStyle(
                color: Color(0xFF202B3A),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                for (final day in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          color: _studentMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            for (var week = 0; week < 6; week++)
              Row(
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    Expanded(
                      child: _calendarDay(
                        week * 7 + weekday + 1,
                        daysInMonth,
                        now,
                        firstWeekday,
                        selectedDate,
                        onSelectDate,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 5),
            const Text(
              'Hoy y los días con sesiones están marcados.',
              style: TextStyle(color: _studentMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarDay(
    int offsetDay,
    int daysInMonth,
    DateTime today,
    int firstWeekday,
    DateTime selectedDate,
    ValueChanged<DateTime> onSelectDate,
  ) {
    final day = offsetDay - firstWeekday;
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 19);
    final date = DateTime(today.year, today.month, day);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final hasSession = bookedDates.any((item) =>
        item.year == date.year &&
        item.month == date.month &&
        item.day == date.day);
    final isSelected = selectedDate.year == date.year &&
        selectedDate.month == date.month &&
        selectedDate.day == date.day;
    return SizedBox(
      height: 25,
      child: Center(
        child: InkWell(
          onTap: () => onSelectDate(date),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            width: 25,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0D4FC4)
                  : hasSession
                      ? const Color(0xFFE6EEFF)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : hasSession
                        ? const Color(0xFF0D4FC4)
                        : const Color(0xFF273444),
                fontSize: 11,
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingSessionTile extends StatelessWidget {
  const _UpcomingSessionTile({required this.item});

  final ({
    String subject,
    DateTime start,
    DateTime? end,
    String teacher,
    String modality,
    String location,
    String status
  }) item;

  @override
  Widget build(BuildContext context) {
    final time = item.end == null
        ? TimeOfDay.fromDateTime(item.start).format(context)
        : '${TimeOfDay.fromDateTime(item.start).format(context)} – '
            '${TimeOfDay.fromDateTime(item.end!).format(context)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFFE6EEFF),
            child: Icon(Icons.groups_outlined, color: _blue, size: 13),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF202B3A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$time · ${item.teacher.isEmpty ? 'Docente por confirmar' : item.teacher} · '
                  '${_studentModalityLabel(item.modality)}'
                  '${item.location.isEmpty ? '' : ' · ${item.location}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _studentMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1DF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.status,
              style: const TextStyle(
                color: Color(0xFF9A5A00),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortMonth(int month) => switch (month) {
      1 => 'ene',
      2 => 'feb',
      3 => 'mar',
      4 => 'abr',
      5 => 'may',
      6 => 'jun',
      7 => 'jul',
      8 => 'ago',
      9 => 'sep',
      10 => 'oct',
      11 => 'nov',
      _ => 'dic',
    };

String _studentInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _studentModalityLabel(String value) => switch (value.toUpperCase()) {
      'PRESENCIAL' => 'Presencial',
      'HIBRIDA' => 'Híbrida',
      'VIRTUAL' => 'Virtual',
      _ => value,
    };

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42, color: _blue),
                const SizedBox(height: 14),
                const Text(
                  'No pudimos cargar tu panel',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
}
