import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/widgets/brand_logo.dart';
import '../auth/auth_repository.dart';
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
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      backgroundColor: _canvas,
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadFailure(
          error: error,
          onRetry: () => ref.invalidate(studentDashboardProvider),
        ),
        data: (value) => Column(
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
                          data: value,
                          onBrowse: () => _openTutorSection('disponibles'),
                          onHistory: () => _openTutorSection('historial'),
                        ),
                        StudentTutoringView(
                          data: value,
                          focusSection: _focusTutoring,
                          focusRequest: _focusRequest,
                          onEnroll: (tutor) => _enroll(value, tutor),
                          onProjectEnrollment: _toggleProjectEnrollment,
                          onLeaveGroupSession: _leaveGroupSession,
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
                        StudentAlertsView(data: value),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : data.whenOrNull(
              data: (_) => NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _selectTab,
                destinations: const [
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
                      icon: Icon(Icons.notifications_none_outlined),
                      selectedIcon: Icon(Icons.notifications),
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
    final subject = TextEditingController();
    var date = _nextDate(tutor.day);
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
                  Autocomplete<String>(
                    optionsBuilder: (value) {
                      final studentCareer = data.profile.career.trim();
                      final options = tutor.subjects
                          .where((item) =>
                              studentCareer.isEmpty ||
                              item.careers.contains(studentCareer))
                          .map((item) => item.name);
                      final query = value.text.trim().toLowerCase();
                      return options
                          .where((name) => name.toLowerCase().contains(query));
                    },
                    onSelected: (value) => subject.text = value,
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmitted) =>
                            TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      onChanged: (value) => subject.text = value,
                      decoration: const InputDecoration(
                        labelText: 'Materia o tema',
                        hintText: 'Elige una materia que dicta el tutor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setDialogState(() => date = picked);
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(_dateLabel(date)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                      'Tutoría de 1 hora, de ${tutor.startTime} a ${tutor.endTime}',
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
                  if (subject.text.trim().isEmpty) {
                    _showMessage('Escribe la materia o el tema de la tutoría.');
                    return;
                  }
                  if (tutor.subjects.isNotEmpty) {
                    final selectedSubject = tutor.subjects.where((item) =>
                        item.name.toLowerCase() ==
                        subject.text.trim().toLowerCase());
                    final studentCareer = data.profile.career.trim();
                    if (selectedSubject.isEmpty ||
                        (studentCareer.isNotEmpty &&
                            !selectedSubject.first.careers
                                .contains(studentCareer))) {
                      _showMessage(
                          'Esa materia no está disponible para tu tecnología.');
                      return;
                    }
                  }
                  if (_weekday(date) != tutor.day) {
                    _showMessage(
                        'Selecciona un ${tutor.day} para este horario.');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Inscribirme'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      await enrollInTutoring(
        dio: ref.read(dioProvider),
        tutor: tutor,
        subject: subject.text,
        start: date,
      );
      ref.invalidate(studentDashboardProvider);
      _showMessage('Te inscribiste en la sesión grupal.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    } on FormatException catch (error) {
      _showMessage(error.message);
    } finally {
      subject.dispose();
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
      if (space.enrolled) {
        await leaveClassroomProject(dio: dio, space: space);
      } else {
        await enrollInClassroomProject(dio: dio, space: space);
      }
      ref.invalidate(studentDashboardProvider);
      _showMessage(space.enrolled
          ? 'Saliste del espacio de proyecto de aula.'
          : 'Te inscribiste en el proyecto de aula.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  Future<void> _leaveGroupSession(StudentGroupSession session) async {
    try {
      await leaveGroupTutoring(
          dio: ref.read(dioProvider), sessionId: session.id);
      ref.invalidate(studentDashboardProvider);
      _showMessage('Saliste de la sesión grupal.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
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

  String _weekday(DateTime date) => const [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ][date.weekday - 1];

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
