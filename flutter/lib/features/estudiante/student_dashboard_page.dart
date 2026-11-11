import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/role_theme.dart';
import '../../core/tutoring_updates.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/role_toast.dart';
import '../../core/widgets/sliding_pill_navigation_bar.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import 'student_dashboard_models.dart';
import 'student_dashboard_views.dart';

part 'student_dashboard_navigation.dart';

const _blue = Color(0xFF1769AA);
const _navy = Color(0xFF17324F);
const _canvas = Color(0xFFF5F7FB);

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() =>
      _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage>
    with WidgetsBindingObserver {
  int _tab = 0;
  String? _focusTutoring;
  int _focusRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(studentGroupSessionsProvider);
      ref.invalidate(studentDashboardProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) {
        ref.invalidate(studentGroupSessionsProvider);
        ref.invalidate(studentDashboardProvider);
      }
    });
    final data = ref.watch(studentDashboardProvider);
    final groupSessions = ref.watch(studentGroupSessionsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 760;
    final showAside = width >= 760 && _tab == 0;
    return Theme(
      data: withRoleAccent(
        Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _blue,
            brightness: Theme.of(context).brightness,
          ).copyWith(primary: _blue),
        ),
        _blue,
      ),
      child: Scaffold(
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
              return Row(
                children: [
                  if (wide)
                    _StudentSidebar(
                      tab: _tab,
                      profile: value.profile,
                      onSelect: _selectTab,
                      onLogout: _logout,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        _StudentHeader(
                          profile: value.profile,
                          tab: _tab,
                          tutoringSection: _tab == 1 ? _focusTutoring : null,
                          showProfileShortcut: !wide,
                          onProfile: () => _selectTab(2),
                          onNotifications: () => _selectTab(3),
                          onBack: () => _openTutorSection('menu'),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: wide ? 3 : 1,
                                  child: IndexedStack(
                                    index: _tab,
                                    children: [
                                      StudentHomeView(
                                        data: dashboard,
                                        onOpenSessions: () =>
                                            _openTutorSection('sesiones'),
                                        onOpenHistory: () =>
                                            _openTutorSection('historial'),
                                      ),
                                      StudentTutoringView(
                                        key: const ValueKey('student-tutoring'),
                                        data: dashboard,
                                        focusSection:
                                            _tab == 1 && _focusTutoring != null
                                                ? _focusTutoring
                                                : 'menu',
                                        focusRequest: _focusRequest,
                                        onEnroll: (tutor) =>
                                            _enroll(value, tutor),
                                        onProjectEnrollment:
                                            _toggleProjectEnrollment,
                                        onJoinProjectCode: _joinProjectByCode,
                                        onLeaveGroupSession: _leaveGroupSession,
                                        onJoinPublishedSession: (session) =>
                                            _joinPublishedSession(session),
                                        onAction: _tutoringAction,
                                        onShowMessage: _showMessage,
                                        onSectionChanged: (section) => setState(
                                            () => _focusTutoring = section),
                                      ),
                                      StudentProfileView(
                                        profile: value.profile,
                                        onTeacherMode: value.profile.role
                                                .toLowerCase()
                                                .contains('docente')
                                            ? () => context.go('/docente')
                                            : null,
                                        onLogout: _logout,
                                      ),
                                      const NotificationsInbox(
                                        accentColor: _blue,
                                      ),
                                    ],
                                  ),
                                ),
                                if (showAside)
                                  SizedBox(
                                    width: 250,
                                    child: _StudentSidePanel(data: dashboard),
                                  ),
                              ],
                            ),
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
                data: (_) => SlidingPillNavigationBar(
                  selectedColor: _blue,
                  indicatorColor: const Color(0xFFDCEEFF),
                  selectedIndex: _tab.clamp(0, 3),
                  onDestinationSelected: _selectTab,
                  destinations: const [
                    SlidingPillDestination(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: 'Inicio'),
                    SlidingPillDestination(
                        icon: Icons.event_note_outlined,
                        selectedIcon: Icons.event_note,
                        label: 'Tutorías'),
                    SlidingPillDestination(
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: 'Perfil'),
                    SlidingPillDestination(
                        icon: Icons.notifications_none_outlined,
                        selectedIcon: Icons.notifications,
                        label: 'Avisos'),
                  ],
                ),
              ),
      ),
    );
  }

  void _selectTab(int tab) => setState(() {
        _tab = tab;
        _focusTutoring = tab == 1 ? 'menu' : null;
        _focusRequest++;
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
    if (!space.createProjectSlot) return;
    try {
      final details = await _askProjectDetails(space);
      if (details == null) return;
      final created = await createClassroomProject(
        dio: ref.read(dioProvider),
        tutoringId: space.tutoringId,
        name: details.name,
        semester: space.semester,
        description: details.description,
      );
      ref.invalidate(studentDashboardProvider);
      ref.invalidate(studentProjectFollowupProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Proyecto creado'),
          content: Text(
              'Se creó “${details.name}” para el semestre ${space.semester}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      final code = created['codigoInscripcion'] as String? ?? '';
      if (code.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Código para integrantes'),
            content: SelectableText(code,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 5)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Listo')),
            ],
          ),
        );
      }
      _openTutorSection('seguimiento-proyecto');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
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
        await _showInvalidProjectCode();
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
            'Proyecto: ${project['nombre'] ?? 'Proyecto de aula'}\n\n'
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
      _openTutorSection('seguimiento-proyecto');
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 400 || status == 404) {
        await _showInvalidProjectCode();
      } else {
        _showMessage(_apiMessage(error));
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showInvalidProjectCode() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Código incorrecto'),
          content: const Text(
              'Confirma que la tutoría exista o que el código esté bien escrito.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Entendido')),
          ],
        ),
      );

  Future<({String name, String description})?> _askProjectDetails(
      ClassroomProjectSpace space) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    try {
      return await showDialog<({String name, String description})>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Crear proyecto de aula'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(space.career),
                    Text('Semestre ${space.semester}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      maxLength: 120,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Título del proyecto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLength: 1000,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Descripción del proyecto',
                        hintText: 'Explica brevemente qué desarrollarán.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ])),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: nameController.text.trim().isEmpty ||
                              descriptionController.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(dialogContext, (
                                name: nameController.text.trim(),
                                description: descriptionController.text.trim(),
                              )),
                      child: const Text('Continuar'),
                    ),
                  ],
                )),
      );
    } finally {
      nameController.dispose();
      descriptionController.dispose();
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
    RoleToast.show(context, message: message, roleColor: _blue);
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
