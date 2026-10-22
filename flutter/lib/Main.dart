import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/admin/admin_main_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/tutorias/coordinacion_tutorias_page.dart';
import 'features/tutorias/coordinacion_dashboard_page.dart';
import 'features/tutorias/docente_informes_page.dart';
import 'features/estudiante/student_dashboard_page.dart';
import 'features/notifications/notifications_page.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(path: '/notificaciones', builder: (_, __) => const NotificationsPage()),
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
      path: '/docente',
      builder: (_, __) => const DocenteInformesPage(),
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

void main() => runApp(const ProviderScope(child: App()));

class App extends StatelessWidget {
  const App({super.key});
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
