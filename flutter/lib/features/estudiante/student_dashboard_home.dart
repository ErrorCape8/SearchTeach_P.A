part of 'student_dashboard_views.dart';

class StudentHomeView extends StatelessWidget {
  const StudentHomeView({
    required this.data,
    required this.onOpenSessions,
    required this.onOpenHistory,
    super.key,
  });

  final StudentDashboardData data;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final pendingIndividual = data.tutorings
        .where((t) =>
            t.status == 'SOLICITADA' || t.status == 'ALTERNATIVA_PROPUESTA')
        .length;
    final pendingGroup = data.groupSessions
        .where((session) => session.state == 'PROGRAMADA')
        .length;
    final pending = pendingIndividual + pendingGroup;
    final completed = data.tutorings
            .where((tutoring) => tutoring.status == 'REALIZADA')
            .length +
        data.groupSessions
            .where((session) => session.state == 'FINALIZADA')
            .length;
    final hasProject = data.projectSpaces.any((space) => space.enrolled);
    final activityCount = pending +
        data.tutorings
            .where((tutoring) =>
                tutoring.status == 'PROGRAMADA' ||
                tutoring.status == 'EN_CURSO')
            .length +
        data.groupSessions
            .where((session) => session.state == 'EN_CURSO')
            .length;
    final upcoming = <({String subject, String teacher, DateTime start})>[];
    for (final tutoring in data.tutorings.where(
        (item) => item.status == 'PROGRAMADA' || item.status == 'EN_CURSO')) {
      final start = tutoring.start?.toLocal();
      if (start != null) {
        upcoming.add((subject: tutoring.subject, teacher: '', start: start));
      }
    }
    for (final session in data.groupSessions.where(
        (item) => item.state == 'PROGRAMADA' || item.state == 'EN_CURSO')) {
      final start = session.start?.toLocal();
      if (start != null) {
        final teacher = data.tutors
            .where((item) => item.teacherId == session.teacherId)
            .map((item) => item.name)
            .firstOrNull;
        upcoming.add(
            (subject: session.subject, teacher: teacher ?? '', start: start));
      }
    }
    upcoming.sort((a, b) => a.start.compareTo(b.start));
    final recent = <({String subject, DateTime? start})>[
      for (final tutoring
          in data.tutorings.where((item) => item.status == 'REALIZADA'))
        (subject: tutoring.subject, start: tutoring.start),
      for (final session
          in data.groupSessions.where((item) => item.state == 'FINALIZADA'))
        (subject: session.subject, start: session.start),
    ]..sort(
        (a, b) => (b.start ?? DateTime(0)).compareTo(a.start ?? DateTime(0)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 24, 32),
      children: [
        if (upcoming.isNotEmpty) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE7F1FC),
                      child: Icon(Icons.play_circle_outline, color: _blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${_studentDate(upcoming.first.start)} · ${_studentClock(upcoming.first.start)}',
                              style: const TextStyle(
                                  color: _navy, fontWeight: FontWeight.w800)),
                          Text(upcoming.first.subject,
                              style: const TextStyle(color: _muted)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenSessions,
                      child: const Text('Ver sesión'),
                    ),
                  ]),
                  const Divider(height: 20),
                  Text(
                    upcoming.first.teacher.isEmpty
                        ? 'Revisa los detalles y el enlace en Mis sesiones.'
                        : 'Docente ${upcoming.first.teacher} · ${upcoming.first.start.day}/${upcoming.first.start.month}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _ActivitySummaryCard(
          pending: pending,
          activityCount: activityCount,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Pendientes',
                value: '$pending',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Realizadas',
                value: '$completed',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Proyecto de aula',
                value: hasProject ? 'Sí' : 'No',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Últimas tutorías',
                style: TextStyle(
                    color: _navy, fontWeight: FontWeight.w800, fontSize: 16)),
            TextButton(onPressed: onOpenHistory, child: const Text('Ver todo')),
          ],
        ),
        Card(
          margin: EdgeInsets.zero,
          child: recent.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Tus tutorías realizadas aparecerán aquí.',
                      style: TextStyle(color: _muted)),
                )
              : Column(
                  children: [
                    for (final tutoring in recent.take(3))
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE7F1FC),
                          child: Icon(Icons.menu_book_outlined, color: _blue),
                        ),
                        title: Text(tutoring.subject,
                            style: const TextStyle(
                                color: _navy, fontWeight: FontWeight.w700)),
                        subtitle: Text(_studentDate(tutoring.start),
                            style: const TextStyle(color: _muted)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

String _studentClock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _studentDate(DateTime? date) => date == null
    ? 'Fecha por confirmar'
    : '${date.day} ${_studentMonth(date.month)}';

String _studentMonth(int month) => const [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ][month - 1];

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.pending,
    required this.activityCount,
  });

  final int pending;
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now();
    const weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
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
      'diciembre',
    ];
    return Container(
      height: 148,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFE7EEFF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${weekdays[date.weekday - 1]} ${date.day} de ${months[date.month - 1]} de ${date.year}',
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tu actividad',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  pending == 0
                      ? 'No tienes tutorías pendientes.'
                      : 'Tienes $pending tutoría(s) pendiente(s).',
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            '$activityCount',
            style: const TextStyle(
              color: Color(0xFFC9D8FA),
              fontSize: 52,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentProfileView extends ConsumerWidget {
  const StudentProfileView({
    required this.profile,
    required this.onLogout,
    this.onTeacherMode,
    super.key,
  });

  final StudentProfile profile;
  final VoidCallback onLogout;
  final VoidCallback? onTeacherMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ProfileSectionTitle('Datos que puedes editar'),
        _ProfileActionCard(
          icon: Icons.phone_outlined,
          title: profile.phone.isEmpty ? 'Agregar teléfono' : profile.phone,
          subtitle: 'Teléfono',
          onTap: () => _editPhone(context, ref),
        ),
        const SizedBox(height: 12),
        const _ProfileSectionTitle('Seguridad'),
        _ProfileActionCard(
          icon: Icons.lock_outline,
          title: 'Cambiar contraseña',
          subtitle: 'Mínimo 8 caracteres',
          onTap: () => _changePassword(context, ref),
        ),
        if (onTeacherMode != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onTeacherMode,
            icon: const Icon(Icons.co_present_outlined),
            label: const Text('Cambiar a vista docente'),
          ),
        ],
      ],
    );
    final institutional = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ProfileSectionTitle('Datos institucionales'),
        Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          child: Column(
            children: [
              _InstitutionalDataRow(
                icon: Icons.mail_outline,
                title: 'Correo',
                value: profile.email,
              ),
              _InstitutionalDataRow(
                icon: Icons.badge_outlined,
                title: 'Documento',
                value: profile.id,
              ),
              _InstitutionalDataRow(
                icon: Icons.lock_outline,
                title: 'Rol',
                value: _roleLabel(profile.role),
              ),
              _InstitutionalDataRow(
                icon: Icons.school_outlined,
                title: 'Tecnología',
                value: profile.career.isEmpty
                    ? 'No registrada'
                    : '${profile.career}${profile.semester > 0 ? ' · Semestre ${profile.semester}' : ''}',
                showDivider: false,
              ),
            ],
          ),
        ),
        if (profile.semester <= 0 &&
            profile.role.toLowerCase().contains('estudiante')) ...[
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _registerSemester(context, ref),
              icon: const Icon(Icons.edit_outlined, size: 13),
              label: const Text(
                'Registrar semestre',
                style: TextStyle(fontSize: 9),
              ),
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 4, 2, 10),
          child: Text(
            'Estos datos los gestiona TI y están bloqueados.',
            style: TextStyle(color: _muted, fontSize: 8),
          ),
        ),
        FilledButton(
          onPressed: onLogout,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFECEC),
            foregroundColor: const Color(0xFF9D2525),
            elevation: 0,
          ),
          child: const Text('Cerrar sesión', style: TextStyle(fontSize: 9)),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 22),
      children: [
        editable,
        const SizedBox(height: 18),
        institutional,
      ],
    );
  }

  Future<void> _editPhone(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: profile.phone);
    try {
      final phone = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Actualizar teléfono'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (phone == null) return;
      if (phone.isEmpty) {
        _showProfileMessage(context, 'El teléfono no puede quedar vacío.');
        return;
      }
      await ref.read(dioProvider).patch<void>(
        '/api/usuarios/perfil/telefono',
        data: {'telefono': phone},
      );
      ref.invalidate(studentDashboardProvider);
      if (!context.mounted) return;
      _showProfileMessage(context, 'Teléfono actualizado.');
    } on DioException catch (error) {
      if (!context.mounted) return;
      _showProfileMessage(context, _profileApiMessage(error));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final values = await showDialog<({String current, String next})>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Campo obligatorio'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? 'Usa al menos 8 caracteres'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nueva contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value != next.text
                      ? 'Las contraseñas no coinciden'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, (
                    current: current.text,
                    next: next.text,
                  ));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (values == null) return;
      await ref.read(dioProvider).patch<void>(
        '/api/usuarios/perfil/contrasena',
        data: {
          'contrasenaActual': values.current,
          'nuevaContrasena': values.next,
        },
      );
      if (!context.mounted) return;
      _showProfileMessage(context, 'Contraseña actualizada.');
    } on DioException catch (error) {
      if (!context.mounted) return;
      _showProfileMessage(context, _profileApiMessage(error));
    } finally {
      current.dispose();
      next.dispose();
      confirmation.dispose();
    }
  }

  Future<void> _registerSemester(BuildContext context, WidgetRef ref) async {
    var selectedSemester = 1;
    final semester = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar semestre'),
          content: DropdownButtonFormField<int>(
            initialValue: selectedSemester,
            decoration: const InputDecoration(
              labelText: 'Semestre actual',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var value = 1; value <= 6; value++)
                DropdownMenuItem(
                  value: value,
                  child: Text('Semestre $value'),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                setDialogState(() => selectedSemester = value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedSemester),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (semester == null) return;
    try {
      await ref.read(dioProvider).patch<void>(
        '/api/usuarios/perfil/semestre',
        data: {'semestre': semester},
      );
      ref.invalidate(studentDashboardProvider);
    } on DioException catch (error) {
      if (!context.mounted) return;
      _showProfileMessage(context, _profileApiMessage(error));
    }
  }

  void _showProfileMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    RoleToast.show(context, message: message, roleColor: _blue);
  }

  String _profileApiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'No se pudo actualizar el perfil.';
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
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
        margin: EdgeInsets.zero,
        color: Colors.white,
        child: ListTile(
          dense: false,
          onTap: onTap,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE6EEFF),
            child: Icon(icon, size: 16, color: _blue),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right, size: 14, color: _muted),
        ),
      );
}

class _InstitutionalDataRow extends StatelessWidget {
  const _InstitutionalDataRow({
    required this.icon,
    required this.title,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFE6EEFF),
              child: Icon(icon, size: 14, color: _blue),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              value.isEmpty ? 'No registrado' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
          if (showDivider)
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Divider(height: 1),
            ),
        ],
      );
}
