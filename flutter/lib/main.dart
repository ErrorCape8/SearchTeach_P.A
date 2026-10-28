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

  @override
  void initState() {
    super.initState();
    _authExpiredSubscription = authExpiredEvents.listen((_) {
      _router.go('/login');
    });
  }

  @override
  void dispose() {
    _authExpiredSubscription?.cancel();
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
