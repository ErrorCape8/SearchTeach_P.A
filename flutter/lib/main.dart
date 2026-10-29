import 'dart:async';

import 'package:flutter/material.dart';
import 'package:searchteach_mobile/core/api_client.dart';
import 'core/session_persistence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/admin/admin_main_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/session_restore_page.dart';
import 'features/auth/register_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/tutorias/coordinacion_tutorias_page.dart';
import 'features/tutorias/coordinacion_programar_tutorias_page.dart';
import 'features/tutorias/coordinacion_dashboard_page.dart';
import 'features/tutorias/docente_dashboard_page.dart';
import 'features/estudiante/student_dashboard_page.dart';
import 'features/notifications/notifications_page.dart';

final _router = GoRouter(
  initialLocation: '/session',
  routes: [
    GoRoute(path: '/session', builder: (_, __) => const SessionRestorePage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(
        path: '/notificaciones', builder: (_, __) => const NotificationsPage()),
    GoRoute(
      path: '/home',
      builder: (_, __) => const DashboardPage(),
    ),
    GoRoute(
      path: '/coordinacion',
      builder: (_, __) => const CoordinacionDashboardPage(),
    ),
    GoRoute(
      path: '/coordinacion/tutorias-colectivas',
      builder: (_, __) => const CoordinacionTutoriasPage(),
    ),
    GoRoute(
      path: '/coordinacion/programar-tutorias',
      builder: (_, __) => const CoordinacionProgramarTutoriasPage(),
    ),
    GoRoute(
      path: '/docente',
      builder: (_, __) => const DocenteDashboardPage(),
    ),
    GoRoute(
      path: '/estudiante',
      builder: (_, __) => const StudentDashboardPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminMainPage(),
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSessionPersistence();
  runApp(const ProviderScope(child: App()));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription<void>? _authExpiredSubscription;
  Timer? _sessionHeartbeat;
  late final _SessionLifecycleObserver _lifecycleObserver =
      _SessionLifecycleObserver(
    onPaused: _pauseSessionHeartbeat,
    onResumed: () => unawaited(_resumeTransientSession()),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _startSessionHeartbeat();
    _authExpiredSubscription = authExpiredEvents.listen((_) {
      _router.go('/login');
    });
  }

  Future<void> _resumeTransientSession() async {
    final valid = await resumeTransientSession();
    if (!valid) _router.go('/login');
    _startSessionHeartbeat();
  }

  void _pauseSessionHeartbeat() {
    _sessionHeartbeat?.cancel();
    _sessionHeartbeat = null;
    unawaited(markTransientSessionActive());
  }

  void _startSessionHeartbeat() {
    _sessionHeartbeat?.cancel();
    _sessionHeartbeat = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(markTransientSessionActive()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _authExpiredSubscription?.cancel();
    _sessionHeartbeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'SearchTeach',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFA9154F),
            primary: const Color(0xFFA9154F),
          ),
          useMaterial3: true,
        ),
        routerConfig: _router,
      );
}

class _SessionLifecycleObserver extends WidgetsBindingObserver {
  _SessionLifecycleObserver({required this.onPaused, required this.onResumed});

  final VoidCallback onPaused;
  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      onPaused();
    }
  }
}
