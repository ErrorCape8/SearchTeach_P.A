part of 'student_dashboard_views.dart';

class StudentHomeView extends StatelessWidget {
  const StudentHomeView({required this.data, super.key});

  final StudentDashboardData data;

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
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 16, 24),
      children: [
        _ActivitySummaryCard(
          pending: pending,
          activityCount: activityCount,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Pendientes',
                value: '$pending',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MetricCard(
                label: 'Realizadas',
                value: '$completed',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MetricCard(
                label: 'Proyecto de aula',
                value: hasProject ? 'Sí' : 'No',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
      height: 72,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                  style: const TextStyle(color: _muted, fontSize: 7),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Tu actividad',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  pending == 0
                      ? 'No tienes tutorías pendientes.'
                      : 'Tienes $pending tutoría(s) pendiente(s).',
                  style: const TextStyle(color: _muted, fontSize: 8),
                ),
              ],
            ),
          ),
          Text(
            '$activityCount',
            style: const TextStyle(
              color: Color(0xFFC9D8FA),
              fontSize: 40,
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
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
        builder: (context, constraints) {
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
              if (constraints.maxWidth >= 620)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: editable),
                    const SizedBox(width: 14),
                    Expanded(child: institutional),
                  ],
                )
              else ...[
                editable,
                const SizedBox(height: 18),
                institutional,
              ],
            ],
          );
        },
      );

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
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
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
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Campo obligatorio' : null,
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
            fontSize: 9,
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
          dense: true,
          onTap: onTap,
          leading: CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFFE6EEFF),
            child: Icon(icon, size: 12, color: _blue),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 7),
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
              radius: 10,
              backgroundColor: const Color(0xFFE6EEFF),
              child: Icon(icon, size: 10, color: _blue),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              value.isEmpty ? 'No registrado' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 7),
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
