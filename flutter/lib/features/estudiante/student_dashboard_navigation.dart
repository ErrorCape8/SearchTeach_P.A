part of 'student_dashboard_page.dart';

const _studentMuted = Color(0xFF64748B);

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
    required this.profile,
    required this.tab,
    required this.showProfileShortcut,
    required this.onProfile,
    required this.onNotifications,
    required this.onBack,
  });

  final StudentProfile profile;
  final int tab;
  final bool showProfileShortcut;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final title = switch (tab) {
      0 => 'Hola, ${profile.name.trim().split(' ').first}',
      1 => 'Tutorías retroalimentativas',
      2 => 'Mis tutorías',
      3 => 'Historial',
      4 => 'Proyectos de aula',
      5 => profile.name,
      _ => 'Avisos',
    };
    final subtitle = switch (tab) {
      0 => 'Estudiante · ${profile.career} · Semestre ${profile.semester}',
      1 => 'Únete a tutorías y consulta su estado',
      2 => 'Únete a tutorías y revisa las que tienes registradas',
      3 => 'Todas las tutorías que has realizado',
      4 => 'Proyectos de aula de tu tecnología',
      5 => 'Estudiante',
      _ => 'Notificaciones dentro de la aplicación',
    };
    final initials = _studentInitials(profile.name);
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
              if (tab > 4)
                IconButton(
                  tooltip: 'Volver al inicio',
                  onPressed: onBack,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 12,
                  ),
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
              if (tab <= 4 && showProfileShortcut)
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
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Avisos',
                  onPressed: onNotifications,
                  visualDensity: VisualDensity.compact,
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
    (Icons.desktop_windows_outlined, 'Tutorías retroalimentativas'),
    (Icons.check_box_outline_blank, 'Mis tutorías'),
    (Icons.history, 'Historial'),
    (Icons.groups_outlined, 'Proyectos de aula'),
  ];

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        child: SizedBox(
          width: 204,
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
                      color: tab == index
                          ? const Color(0xFFDCEEFF)
                          : Colors.transparent,
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
                              color: tab == index ? _blue : _studentMuted,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _items[index].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tab == index ? _blue : _navy,
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
                        tab == 5 ? const Color(0xFFDCEEFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => onSelect(5),
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
                          onTap: () => onSelect(5),
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

class _StudentSidePanel extends StatelessWidget {
  const _StudentSidePanel({required this.data});

  final StudentDashboardData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sessions = <({
      String subject,
      DateTime start,
      String modality,
      String location,
      String status
    })>[];
    for (final session in data.groupSessions) {
      final start = session.start?.toLocal();
      if (start != null &&
          (session.state == 'PROGRAMADA' || session.state == 'EN_CURSO') &&
          (start.isAfter(now) || session.state == 'EN_CURSO')) {
        sessions.add((
          subject: session.subject,
          start: start,
          modality: session.modality,
          location: session.location,
          status: session.state == 'EN_CURSO' ? 'En curso' : 'Pendiente',
        ));
      }
    }
    for (final tutoring in data.tutorings) {
      final start = tutoring.start?.toLocal();
      if (start != null &&
          (tutoring.status == 'PROGRAMADA' || tutoring.status == 'EN_CURSO') &&
          (start.isAfter(now) || tutoring.status == 'EN_CURSO')) {
        sessions.add((
          subject: tutoring.subject,
          start: start,
          modality: tutoring.modality,
          location: '',
          status: tutoring.status == 'EN_CURSO' ? 'En curso' : 'Pendiente',
        ));
      }
    }
    sessions.sort((a, b) => a.start.compareTo(b.start));
    final bookedDates = sessions.map((item) => item.start).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 14, 16, 20),
      children: [
        _StudentCalendarCard(now: now, bookedDates: bookedDates),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text(
            'Próximas sesiones',
            style: TextStyle(
              color: _navy,
              fontSize: 10,
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
                    'Tus próximas sesiones aparecerán aquí.',
                    style: TextStyle(color: _studentMuted, fontSize: 8),
                  ),
                )
              : Column(
                  children: [
                    for (final item in sessions.take(3))
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
  });

  final DateTime now;
  final List<DateTime> bookedDates;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$month ${now.year}',
              style: const TextStyle(
                color: Color(0xFF202B3A),
                fontSize: 9,
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
            const SizedBox(height: 3),
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
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 5),
            const Text(
              'Hoy y los días con sesiones están marcados.',
              style: TextStyle(color: _studentMuted, fontSize: 7),
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
    final selected = isToday || hasSession;
    return SizedBox(
      height: 19,
      child: Center(
        child: Container(
          width: 21,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday
                ? const Color(0xFF0D4FC4)
                : hasSession
                    ? const Color(0xFFE6EEFF)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '$day',
            style: TextStyle(
              color: isToday
                  ? Colors.white
                  : selected
                      ? const Color(0xFF0D4FC4)
                      : const Color(0xFF273444),
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
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
    String modality,
    String location,
    String status
  }) item;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(item.start).format(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 10,
            backgroundColor: Color(0xFFE6EEFF),
            child: Icon(Icons.groups_outlined, color: _blue, size: 11),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${item.start.day} ${_shortMonth(item.start.month)} · $time · '
                  '${_studentModalityLabel(item.modality)}'
                  '${item.location.isEmpty ? '' : ' · ${item.location}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _studentMuted, fontSize: 7),
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
