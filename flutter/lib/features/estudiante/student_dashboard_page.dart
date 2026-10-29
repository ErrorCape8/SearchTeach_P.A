import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/widgets/brand_logo.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import 'student_dashboard_models.dart';
import 'student_dashboard_views.dart';

part 'student_dashboard_navigation.dart';

const _blue = Color(0xFF1769AA);
const _navy = Color(0xFF17324F);
const _canvas = Color(0xFFF4F7FB);

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() =>
      _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  int _tab = 0;
  String? _focusTutoring;
  int _focusRequest = 0;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(studentDashboardProvider);
    final groupSessions = ref.watch(studentGroupSessionsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      backgroundColor: _canvas,
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadFailure(
          error: error,
          onRetry: () => ref.invalidate(studentDashboardProvider),
        ),
        data: (value) => groupSessions.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadFailure(
            error: error,
            onRetry: () => ref.invalidate(studentGroupSessionsProvider),
          ),
          data: (groups) {
            final dashboard = value.withGroupSessions(groups);
            return Column(
              children: [
                _TopBar(profile: value.profile, wide: wide, onLogout: _logout),
                Expanded(
                  child: Row(
                    children: [
                      if (wide)
                        _DesktopNavigation(
                          tab: _tab,
                          profile: value.profile,
                          onSelect: _selectTab,
                          onLogout: _logout,
                        ),
                      Expanded(
                        child: IndexedStack(
                          index: _tab,
                          children: [
                            StudentHomeView(
                              data: dashboard,
                              onBrowse: () => _openTutorSection('publicadas'),
                              onHistory: () => _openTutorSection('historial'),
                            ),
                            StudentTutoringView(
                              data: dashboard,
                              focusSection: _focusTutoring,
                              focusRequest: _focusRequest,
                              onEnroll: (tutor) => _enroll(value, tutor),
                              onProjectEnrollment: _toggleProjectEnrollment,
                              onJoinProjectCode: _joinProjectByCode,
                              onLeaveGroupSession: _leaveGroupSession,
                              onJoinPublishedSession: (session) =>
                                  _joinPublishedSession(session),
                              onAction: _tutoringAction,
                              onShowMessage: _showMessage,
                            ),
                            StudentProfileView(
                              profile: value.profile,
                              onTeacherMode: value.profile.role
                                      .toLowerCase()
                                      .contains('docente')
                                  ? () => context.go('/docente')
                                  : null,
                            ),
                            const NotificationsInbox(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : data.whenOrNull(
              data: (_) => NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _selectTab,
                destinations: [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Inicio'),
                  NavigationDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book),
                      label: 'Tutorías'),
                  NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Perfil'),
                  NavigationDestination(
                      icon: const NotificationUnreadIcon(
                        icon: Icons.notifications_none_outlined,
                      ),
                      selectedIcon: const NotificationUnreadIcon(
                        icon: Icons.notifications,
                      ),
                      label: 'Avisos'),
                ],
              ),
            ),
    );
  }

  void _selectTab(int tab) => setState(() {
        if (tab != _tab && tab != 1) {
          _focusTutoring = null;
          _focusRequest++;
        }
        _tab = tab;
      });

  void _openTutorSection(String section) => setState(() {
        _focusTutoring = section;
        _focusRequest++;
        _tab = 1;
      });

  Future<void> _enroll(
    StudentDashboardData data,
    AvailableTutor tutor,
  ) async {
    final availableSubjects = tutor.subjects
        .where((item) =>
            data.profile.career.trim().isEmpty ||
            item.careers.contains(data.profile.career.trim()))
        .map((item) => item.name)
        .toSet()
        .toList();
    String? selectedSubject =
        availableSubjects.isEmpty ? null : availableSubjects.first;
    final date = _nextDate(tutor.day);
    if (availableSubjects.isEmpty) {
      _showMessage(
          'Este docente aún no tiene materias configuradas para tu tecnología.');
      return;
    }
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Inscribirse en tutoría grupal'),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${tutor.name} · ${tutor.day} '
                            '${tutor.startTime}–${tutor.endTime}'),
                        const SizedBox(height: 16),
                        Text(
                          'Materia asignada por coordinación: $selectedSubject',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                                'Próxima fecha disponible: ${_dateLabel(date)}'),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                            'Horario del docente: ${tutor.startTime}–${tutor.endTime}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Volver'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (selectedSubject == null) {
                          _showMessage(
                              'Selecciona una materia configurada por coordinación.');
                          return;
                        }
                        Navigator.pop(dialogContext, true);
                      },
                      child: const Text('Inscribirme'),
                    ),
                  ],
                )),
      );
      if (confirmed != true) return;
      await enrollInTutoring(
        dio: ref.read(dioProvider),
        tutor: tutor,
        subject: selectedSubject!,
        start: date,
      );
      ref.invalidate(studentGroupSessionsProvider);
      _showMessage('Te inscribiste en la sesión grupal.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _tutoringAction(
    StudentTutoring tutoring,
    String action,
  ) async {
    try {
      await updateTutoring(
        dio: ref.read(dioProvider),
        tutoring: tutoring,
        action: action,
      );
      ref.invalidate(studentDashboardProvider);
      _showMessage(action == 'cancelar'
          ? 'La tutoría fue cancelada.'
          : 'La propuesta de horario fue aceptada.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  Future<void> _toggleProjectEnrollment(ClassroomProjectSpace space) async {
    try {
      final dio = ref.read(dioProvider);
      if (space.createOrJoin) {
        final details = await _askProjectName(space);
        if (details == null) return;
        final name = details.name;
        final created = await createOrJoinClassroomProject(
          dio: dio,
          tutoringId: space.tutoringId,
          name: details.name,
          description: details.description,
          semester: details.semester,
        );
        ref.invalidate(studentDashboardProvider);
        ref.invalidate(studentProjectFollowupProvider);
        final code = created['codigoInscripcion'];
        if (code is String && mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Proyecto creado'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    'Comparte este código para que tus integrantes se unan a “${name.trim()}”:'),
                const SizedBox(height: 12),
                SelectableText(code,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5)),
                const SizedBox(height: 8),
                Text('Semestre ${space.semester}'),
                const SizedBox(height: 8),
                Text('Descripción: ${details.description}'),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Listo'))
              ],
            ),
          );
        }
        if (mounted) _openTutorSection('seguimiento-proyecto');
        return;
      } else if (space.enrolled) {
        await leaveClassroomProject(dio: dio, space: space);
      } else {
        await _joinProjectByCode();
        return;
      }
      ref.invalidate(studentDashboardProvider);
      _showMessage(space.enrolled
          ? 'Saliste del espacio de proyecto de aula.'
          : 'Te inscribiste en el proyecto de aula.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  // ignore: unused_element
  Future<({int semester, String name, String description})?> _askProjectName(
      ClassroomProjectSpace space) async {
    final controller = TextEditingController();
    final descriptionController = TextEditingController();
    try {
      return await showDialog<({int semester, String name, String description})>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Registrar proyecto de aula'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(space.career),
                    const SizedBox(height: 12),
                    Text('Semestre ${space.semester}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLength: 120,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del proyecto de aula',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLength: 1000,
                      maxLines: 3,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Descripción breve del proyecto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: controller.text.trim().isEmpty || descriptionController.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(dialogContext, (
                                semester: space.semester,
                                name: controller.text.trim(),
                                description: descriptionController.text.trim(),
                              )),
                      child: const Text('Continuar'),
                    ),
                  ],
                )),
      );
    } finally {
      controller.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _joinProjectByCode() async {
    final controller = TextEditingController();
    try {
      final code = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ingresar código de inscripción'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Código de 6 dígitos',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Buscar proyecto')),
          ],
        ),
      );
      if (code == null) return;
      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
        _showMessage('El código debe contener seis dígitos.');
        return;
      }
      final dio = ref.read(dioProvider);
      final project = await previewClassroomProjectCode(dio: dio, code: code);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirma el proyecto'),
          content: Text(
            'Lo registra ${project['creador'] ?? 'un estudiante'}\n'
            'Semestre ${project['semestre'] ?? '—'} · ${project['tecnologia'] ?? ''}\n'
            'Proyecto: ${project['nombre'] ?? 'Proyecto de aula'}\n'
            'Descripción: ${project['descripcion'] ?? 'Sin descripción'}\n\n'
            '¿Quieres unirte a este proyecto?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirmar inscripción')),
          ],
        ),
      );
      if (confirmed != true) return;
      await enrollInClassroomProjectCode(dio: dio, code: code);
      ref.invalidate(studentDashboardProvider);
      ref.invalidate(studentProjectFollowupProvider);
      _showMessage('Te uniste al proyecto de aula.');
      if (mounted) _openTutorSection('seguimiento-proyecto');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _leaveGroupSession(StudentGroupSession session) async {
    try {
      await leaveGroupTutoring(
          dio: ref.read(dioProvider), sessionId: session.id);
      ref.invalidate(studentGroupSessionsProvider);
      _showMessage('Saliste de la sesión grupal.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  Future<void> _joinPublishedSession(StudentGroupSession session) async {
    try {
      await enrollInPublishedGroupTutoring(
        dio: ref.read(dioProvider),
        session: session,
        modality: session.modality,
      );
      ref.invalidate(studentGroupSessionsProvider);
      _showMessage('Te inscribiste en la tutoría grupal.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (mounted) context.go('/login');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime _nextDate(String day) {
    final now = DateTime.now();
    final targetDay = switch (day.toLowerCase()) {
      'lunes' => DateTime.monday,
      'martes' => DateTime.tuesday,
      'miércoles' || 'miercoles' => DateTime.wednesday,
      'jueves' => DateTime.thursday,
      'viernes' => DateTime.friday,
      'sábado' || 'sabado' => DateTime.saturday,
      'domingo' => DateTime.sunday,
      _ => now.weekday,
    };
    var difference = (targetDay - now.weekday) % 7;
    if (difference == 0) difference = 7;
    return DateTime(now.year, now.month, now.day + difference);
  }

  String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _apiMessage(DioException error) {
    final response = error.response?.data;
    if (response is Map && response['message'] is String) {
      return response['message'] as String;
    }
    if (response is Map && response['detail'] is String) {
      return response['detail'] as String;
    }
    return 'No se pudo completar la solicitud. Inténtalo de nuevo.';
  }
}
