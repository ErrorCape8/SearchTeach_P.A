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
    final now = DateTime.now();
    final upcoming = <({
      String subject,
      String teacher,
      String modality,
      String location,
      DateTime start
    })>[];
    for (final tutoring in data.tutorings.where((item) =>
        item.status == 'EN_CURSO' || item.status == 'PROGRAMADA')) {
      final start = tutoring.start?.toLocal();
      if (start != null &&
          (tutoring.status == 'EN_CURSO' || start.isAfter(now))) {
        upcoming.add((
          subject: tutoring.subject,
          teacher: data.tutors
                  .where((item) => item.teacherId == tutoring.teacherId)
                  .map((item) => item.name)
                  .firstOrNull ??
              '',
          modality: tutoring.modality,
          location: '',
          start: start,
        ));
      }
    }
    for (final session in data.groupSessions.where(
        (item) => item.state == 'PROGRAMADA' || item.state == 'EN_CURSO')) {
      final start = session.start?.toLocal();
      if (start != null &&
          (session.state == 'EN_CURSO' || start.isAfter(now))) {
        final teacher = data.tutors
            .where((item) => item.teacherId == session.teacherId)
            .map((item) => item.name)
            .firstOrNull;
        upcoming.add((
          subject: session.subject,
          teacher: teacher ?? '',
          modality: session.modality,
          location: session.location,
          start: start,
        ));
      }
    }
    upcoming.sort((a, b) => a.start.compareTo(b.start));
    final recent = <({String subject, String teacher, DateTime? start})>[
      for (final tutoring
          in data.tutorings.where((item) => item.status == 'REALIZADA'))
        (
          subject: tutoring.subject,
          teacher: data.tutors
                  .where((item) => item.teacherId == tutoring.teacherId)
                  .map((item) => item.name)
                  .firstOrNull ??
              '',
          start: tutoring.start,
        ),
      for (final session
          in data.groupSessions.where((item) => item.state == 'FINALIZADA'))
        (
          subject: session.subject,
          teacher: data.tutors
                  .where((item) => item.teacherId == session.teacherId)
                  .map((item) => item.name)
                  .firstOrNull ??
              '',
          start: session.start,
        ),
    ]..sort(
        (a, b) => (b.start ?? DateTime(0)).compareTo(a.start ?? DateTime(0)));
    final totalTutorings = data.tutorings.length + data.groupSessions.length;
    final projects = data.projectSpaces.where((space) => space.enrolled).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 18, 32),
      children: [
        _NextTutoringCard(
          session: upcoming.isEmpty ? null : upcoming.first,
          onOpenSessions: onOpenSessions,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Tutorías',
                value: '$totalTutorings',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'Próximas',
                value: '${upcoming.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'Proyectos',
                value: '$projects',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Últimas tutorías',
                style: TextStyle(
                    color: _navy, fontWeight: FontWeight.w800, fontSize: 15)),
            TextButton(
              onPressed: onOpenHistory,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('Ver todo'),
            ),
          ],
        ),
        Card(
          margin: EdgeInsets.zero,
          child: recent.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tus tutorías realizadas aparecerán aquí.',
                      style: TextStyle(color: _muted, fontSize: 12)),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      for (var index = 0;
                          index < recent.take(3).length;
                          index++) ...[
                        if (index > 0) const Divider(height: 1, color: _line),
                        _RecentTutoringTile(item: recent[index]),
                      ],
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => paPush(context, const PaCronogramaPage(), accent: _blue),
            leading: const Icon(Icons.event_note_outlined, color: _blue),
            title: const Text(
              'Tutorías colectivas',
              style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Cronograma de tu programa: fechas, aulas y tutores',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
          ),
        ),
      ],
    );
  }
}

class _NextTutoringCard extends StatelessWidget {
  const _NextTutoringCard({
    required this.session,
    required this.onOpenSessions,
  });

  final ({
    String subject,
    String teacher,
    String modality,
    String location,
    DateTime start
  })? session;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context) {
    final item = session;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10141E3C),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                const _StudentIconBox(
                  icon: Icons.play_circle_outline,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item == null
                            ? 'No tienes tutorías programadas'
                            : '${_studentDate(item.start)} · ${_studentClock(item.start)}',
                        style: const TextStyle(
                          color: Color(0xFF202B3A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item == null
                            ? 'Las tutorías asignadas aparecerán aquí'
                            : '${item.subject}${item.teacher.isEmpty ? '' : ' · ${item.teacher}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (item != null)
                  FilledButton(
                    onPressed: onOpenSessions,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Unirme'),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFE7F1FC),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: _blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item == null
                        ? 'No tienes clases próximas asignadas.'
                        : '${item.modality.isEmpty ? 'Modalidad por confirmar' : _groupSessionModalityLabel(item.modality)}${item.location.isEmpty ? ' · Revisa el enlace en Mis sesiones.' : ' · ${item.location}'}',
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTutoringTile extends StatelessWidget {
  const _RecentTutoringTile({required this.item});

  final ({String subject, String teacher, DateTime? start}) item;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: Row(
          children: [
            const _StudentIconBox(icon: Icons.menu_book_outlined, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    '${item.teacher.isEmpty ? '' : '${item.teacher} · '}${_studentDate(item.start)}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StudentIconBox extends StatelessWidget {
  const _StudentIconBox({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F1FC),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Icon(icon, color: _blue, size: size * .48),
      );
}

String _studentClock(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

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
        const SizedBox(height: 16),
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
                title: 'Programa',
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
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 4, 2, 12),
          child: Text(
            'Estos datos los gestiona TI y están bloqueados.',
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ),
        FilledButton(
          onPressed: onLogout,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFECEC),
            foregroundColor: const Color(0xFF9D2525),
            elevation: 0,
            minimumSize: const Size.fromHeight(44),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Cerrar sesión', style: TextStyle(fontSize: 13)),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 24),
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
            fontSize: 14,
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
        elevation: 1,
        shadowColor: const Color(0x12141E3C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        child: ListTile(
          dense: false,
          onTap: onTap,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE7F1FC),
            child: Icon(icon, size: 16, color: _blue),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20, color: _muted),
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
            dense: false,
            leading: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE7F1FC),
              child: Icon(icon, size: 17, color: _blue),
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
